#!/usr/bin/env bash
set -euo pipefail

# Complete EC2 deployment with RDS setup
ROOT_DIR=$(cd "$(dirname "$0")/../../" && pwd)
source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/utils.sh"
source "$(dirname "$0")/rds.sh"

if [ -z "${APP_NAME:-}" ]; then
  echo "Please create deployment/aws-ec2/.env from .env.example and set APP_NAME, AWS_REGION"
  exit 1
fi

log_info "Starting complete EC2 deployment for $APP_NAME"

# Step 1: Setup RDS
find_or_create_rds_instance
get_rds_endpoint

# Step 2: Build backend
log_info "Building backend JAR"
(cd "$ROOT_DIR/backend" && mvn clean package -DskipTests)
BACKEND_JAR=$(ls "$ROOT_DIR/backend/target"/*.jar | head -n1)

# Step 3: Ensure keypair
ensure_keypair() {
  if ! run_aws_cli ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    log_info "Creating keypair $KEY_NAME"
    run_aws_cli ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$KEY_NAME.pem"
    chmod 600 "$KEY_NAME.pem"
  else
    log_info "Keypair exists: $KEY_NAME"
  fi
}

# Step 4: Ensure security group
ensure_sg() {
  SG_ID=$(run_aws_cli ec2 describe-security-groups --filters Name=group-name,Values="$SECURITY_GROUP_NAME" --region "$AWS_REGION" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
  if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
    log_info "Creating security group $SECURITY_GROUP_NAME"
    SG_ID=$(run_aws_cli ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "EC2 SG for $APP_NAME" --region "$AWS_REGION" --query 'GroupId' --output text)
    run_aws_cli ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    run_aws_cli ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    run_aws_cli ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    run_aws_cli ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region "$AWS_REGION"
  else
    log_info "Using existing security group $SG_ID"
  fi
}

# Step 5: Launch instance with complete setup
launch_instance() {
  log_info "Launching EC2 instance with complete setup"
  
  USER_DATA=$(cat <<EOF
#!/bin/bash
set -e
yum update -y

# Install Java 17 and nginx
yum install -y java-17-amazon-corretto
amazon-linux-extras install -y nginx1

# Download and start backend
curl -L -o /home/ec2-user/app.jar "file://$BACKEND_JAR" || wget -O /home/ec2-user/app.jar "file://$BACKEND_JAR"
chown ec2-user:ec2-user /home/ec2-user/app.jar

# Create application.yml with RDS connection
cat > /home/ec2-user/application.yml << EOL
spring:
  datasource:
    url: jdbc:postgresql://$DB_ENDPOINT:5432/postgres
    username: $DB_USERNAME
    password: $DB_PASSWORD
    driver-class-name: org.postgresql.Driver
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: false
server:
  port: 8080
jwt:
  secret: myVerySecureSecretKeyThatIsLongEnoughForJWTHMACSHA256AlgorithmForTest
  expiration: 86400000
EOL

# Create systemd service for backend
cat > /etc/systemd/system/ecommerce-backend.service << EOL
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
EOL

# Create nginx config
cat > /etc/nginx/conf.d/default.conf << EOL
server {
    listen 80;
    server_name _;

    location /api/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        return 200 'Backend is running! API available at /api/';
        add_header Content-Type text/plain;
    }
}
EOL

# Start services
systemctl daemon-reload
systemctl enable ecommerce-backend
systemctl start ecommerce-backend
systemctl enable nginx
systemctl start nginx

# Wait for backend to start
sleep 30
systemctl status ecommerce-backend
EOF
)

  # Check if instance already exists
  EXISTING_INSTANCE=$(run_aws_cli ec2 describe-instances --filters "Name=tag:Name,Values=$APP_NAME-instance" "Name=instance-state-name,Values=running,pending" --region "$AWS_REGION" --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "None")
  
  if [ "$EXISTING_INSTANCE" != "None" ] && [ -n "$EXISTING_INSTANCE" ]; then
    log_info "Using existing instance: $EXISTING_INSTANCE"
    INSTANCE_ID="$EXISTING_INSTANCE"
  else
    INSTANCE_ID=$(run_aws_cli ec2 run-instances --image-id "$AMI_ID" --count 1 --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" --security-group-ids "$SG_ID" --user-data "$USER_DATA" --region "$AWS_REGION" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$APP_NAME-instance}]" --query 'Instances[0].InstanceId' --output text)
    log_info "Instance launched: $INSTANCE_ID"
  fi
  
  run_aws_cli ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
  PUBLIC_IP=$(run_aws_cli ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
  
  log_info "Instance public IP: $PUBLIC_IP"
  log_info "Backend API (HTTPS): https://$PUBLIC_IP/api/"
  log_info "Backend API (HTTP): http://$PUBLIC_IP/api/"
  log_info "Direct backend: http://$PUBLIC_IP:8080/"
  
  # Upload JAR file to instance
  log_info "Uploading JAR file to instance..."
  scp -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no "$BACKEND_JAR" "$SSH_USER@$PUBLIC_IP:/home/ec2-user/app.jar"
  
  # Setup backend service properly
  log_info "Setting up backend service..."
  ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no "$SSH_USER@$PUBLIC_IP" << 'SETUP_EOF'
set -e

# Create application.yml with RDS connection
sudo tee /home/ec2-user/application.yml > /dev/null << EOF
spring:
  datasource:
    url: jdbc:postgresql://$DB_ENDPOINT:5432/postgres
    username: $DB_USERNAME
    password: $DB_PASSWORD
    driver-class-name: org.postgresql.Driver
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: false
server:
  port: 8080
jwt:
  secret: myVerySecureSecretKeyThatIsLongEnoughForJWTHMACSHA256AlgorithmForTest
  expiration: 86400000
EOF

# Create systemd service for backend
sudo tee /etc/systemd/system/ecommerce-backend.service > /dev/null << EOF
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
EOF

# Create self-signed SSL certificate
sudo mkdir -p /etc/ssl/private
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/selfsigned.key \
  -out /etc/ssl/certs/selfsigned.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Create nginx config with HTTPS
sudo tee /etc/nginx/conf.d/default.conf > /dev/null << EOF
server {
    listen 80;
    server_name _;
    return 301 https://\$server_name\$request_uri;
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
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        return 200 'Backend is running! API available at /api/';
        add_header Content-Type text/plain;
    }
}
EOF

# Start services
sudo systemctl daemon-reload
sudo systemctl enable ecommerce-backend
sudo systemctl start ecommerce-backend
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "Services setup complete!"
SETUP_EOF
  
  # Wait for services to start
  sleep 10
  
  # Test the connection
  log_info "Testing backend connection..."
  if curl -s "http://$PUBLIC_IP:8080/api/products" > /dev/null; then
    log_info "✅ Backend is responding successfully!"
  else
    log_warn "⚠️ Backend may still be starting up"
  fi
  
  echo "$PUBLIC_IP" > .ec2-ip
}

# Execute deployment steps
ensure_keypair
ensure_sg
launch_instance

log_info "EC2 deployment complete!"
log_info "Access your application at:"
log_info "  HTTPS: https://$(cat .ec2-ip)/api/ (self-signed certificate)"
log_info "  HTTP:  http://$(cat .ec2-ip)/api/"
log_info "  Direct: http://$(cat .ec2-ip):8080/api/"