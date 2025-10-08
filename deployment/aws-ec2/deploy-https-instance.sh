#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../../" && pwd)
source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/utils.sh"
source "$(dirname "$0")/rds.sh"

log_info "Deploying new EC2 instance with HTTPS support"

# Use existing RDS
get_rds_endpoint

# Build backend
(cd "$ROOT_DIR/backend" && mvn clean package -DskipTests)
BACKEND_JAR=$(ls "$ROOT_DIR/backend/target"/*.jar | head -n1)

# Get security group
SG_ID=$(run_aws_cli ec2 describe-security-groups --filters Name=group-name,Values="$SECURITY_GROUP_NAME" --region "$AWS_REGION" --query 'SecurityGroups[0].GroupId' --output text)

# Terminate old instance
OLD_INSTANCE=$(run_aws_cli ec2 describe-instances --filters "Name=tag:Name,Values=$APP_NAME-instance" "Name=instance-state-name,Values=running" --region "$AWS_REGION" --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "None")
if [ "$OLD_INSTANCE" != "None" ] && [ -n "$OLD_INSTANCE" ]; then
  log_info "Terminating old instance: $OLD_INSTANCE"
  run_aws_cli ec2 terminate-instances --instance-ids "$OLD_INSTANCE" --region "$AWS_REGION"
  run_aws_cli ec2 wait instance-terminated --instance-ids "$OLD_INSTANCE" --region "$AWS_REGION"
fi

# Launch new instance with HTTPS
USER_DATA=$(cat <<'EOF'
#!/bin/bash
set -e
yum update -y
yum install -y java-17-amazon-corretto
amazon-linux-extras install -y nginx1

# Create SSL certificate
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/selfsigned.key \
  -out /etc/ssl/certs/selfsigned.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Create nginx HTTPS config
cat > /etc/nginx/conf.d/default.conf << 'NGINX_EOF'
server {
    listen 80;
    server_name _;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate /etc/ssl/certs/selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location /api/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        return 200 'Backend is running! API available at /api/';
        add_header Content-Type text/plain;
    }
}
NGINX_EOF

systemctl enable nginx
systemctl start nginx
EOF
)

INSTANCE_ID=$(run_aws_cli ec2 run-instances --image-id "$AMI_ID" --count 1 --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" --security-group-ids "$SG_ID" --user-data "$USER_DATA" --region "$AWS_REGION" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$APP_NAME-instance}]" --query 'Instances[0].InstanceId' --output text)

log_info "New instance launched: $INSTANCE_ID"
run_aws_cli ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
PUBLIC_IP=$(run_aws_cli ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

log_info "New instance IP: $PUBLIC_IP"

# Upload JAR and setup backend
sleep 30  # Wait for instance to be ready
scp -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no "$BACKEND_JAR" "$SSH_USER@$PUBLIC_IP:/home/ec2-user/app.jar"

ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no "$SSH_USER@$PUBLIC_IP" << SETUP_EOF
# Create application config
cat > /home/ec2-user/application.yml << APP_EOF
spring:
  datasource:
    url: jdbc:postgresql://$DB_ENDPOINT:5432/postgres
    username: $DB_USERNAME
    password: $DB_PASSWORD
    driver-class-name: org.postgresql.Driver
  jpa:
    hibernate:
      ddl-auto: update
server:
  port: 8080
jwt:
  secret: myVerySecureSecretKeyThatIsLongEnoughForJWTHMACSHA256AlgorithmForTest
  expiration: 86400000
APP_EOF

# Create backend service
sudo tee /etc/systemd/system/ecommerce-backend.service > /dev/null << SERVICE_EOF
[Unit]
Description=Ecommerce Backend
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user
ExecStart=/usr/bin/java -jar /home/ec2-user/app.jar --spring.config.location=/home/ec2-user/application.yml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reload
sudo systemctl enable ecommerce-backend
sudo systemctl start ecommerce-backend
SETUP_EOF

echo "$PUBLIC_IP" > .ec2-ip
log_info "HTTPS deployment complete!"
log_info "HTTPS API: https://$PUBLIC_IP/api/"
log_info "HTTP redirects to HTTPS automatically"