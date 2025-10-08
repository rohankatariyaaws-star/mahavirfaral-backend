#!/usr/bin/env bash
set -euo pipefail

# S3-free EC2 deploy script - everything embedded in user-data
ROOT_DIR=$(cd "$(dirname "$0")/../../" && pwd)
source "$(dirname "$0")/.env" 2>/dev/null || true

if [ -z "${APP_NAME:-}" ]; then
  echo "Please create .env from .env.example"
  exit 1
fi

source "$(dirname "$0")/../aws-ecs/utils.sh" 2>/dev/null || true

function build_artifacts() {
  log_info "Building artifacts locally"
  
  # Build backend
  BACKEND_JAR=$(ls $ROOT_DIR/backend/target/*.jar 2>/dev/null | head -n1 || true)
  if [ -z "$BACKEND_JAR" ]; then
    (cd $ROOT_DIR/backend && mvn clean package -DskipTests)
    BACKEND_JAR=$(ls $ROOT_DIR/backend/target/*.jar | head -n1)
  fi
  
  # Build frontend
  FRONTEND_BUILD_DIR=$ROOT_DIR/frontend/build
  if [ ! -d "$FRONTEND_BUILD_DIR" ]; then
    (cd $ROOT_DIR/frontend && npm install && npm run build)
  fi
  
  # Base64 encode JAR for embedding
  JAR_BASE64=$(base64 -w 0 "$BACKEND_JAR")
  
  # Create frontend tar.gz and base64 encode
  (cd "$FRONTEND_BUILD_DIR" && tar czf - .) | base64 -w 0 > /tmp/frontend.tar.gz.b64
  FRONTEND_BASE64=$(cat /tmp/frontend.tar.gz.b64)
  
  log_info "Artifacts prepared for embedding"
}

function ensure_keypair() {
  if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region $AWS_REGION >/dev/null 2>&1; then
    log_info "Creating keypair $KEY_NAME"
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$KEY_NAME.pem"
    chmod 600 "$KEY_NAME.pem"
  fi
}

function ensure_sg() {
  SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=$SECURITY_GROUP_NAME --region $AWS_REGION --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
  if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
    log_info "Creating security group $SECURITY_GROUP_NAME"
    SG_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "EC2 SG for $APP_NAME" --region $AWS_REGION --query 'GroupId' --output text)
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $AWS_REGION
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $AWS_REGION
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $AWS_REGION
  fi
}

function launch_instance() {
  log_info "Launching EC2 instance with embedded artifacts"
  
  USER_DATA=$(cat <<EOF
#!/bin/bash
set -e
yum update -y
amazon-linux-extras install -y java-openjdk11
yum install -y nginx openssl

# Create SSL certificate
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/selfsigned.key \
  -out /etc/ssl/certs/selfsigned.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Create nginx config
cat > /etc/nginx/conf.d/default.conf <<'NGINX_EOF'
server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name _;
    
    ssl_certificate /etc/ssl/certs/selfsigned.crt;
    ssl_private_key /etc/ssl/private/selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX_EOF

systemctl enable nginx
systemctl start nginx

# Decode and install backend JAR
echo "$JAR_BASE64" | base64 -d > /home/ec2-user/app.jar
chown ec2-user:ec2-user /home/ec2-user/app.jar

# Create backend service
cat > /etc/systemd/system/ecommerce-backend.service <<'SERVICE_EOF'
[Unit]
Description=Ecommerce Backend
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user
ExecStart=/usr/bin/java -jar /home/ec2-user/app.jar
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable ecommerce-backend
systemctl start ecommerce-backend

# Decode and install frontend
mkdir -p /usr/share/nginx/html
echo "$FRONTEND_BASE64" | base64 -d | tar xz -C /usr/share/nginx/html/
systemctl restart nginx

EOF
)

  INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --security-group-ids $SG_ID --user-data "$USER_DATA" --region $AWS_REGION --query 'Instances[0].InstanceId' --output text)
  log_info "Instance launched: $INSTANCE_ID"
  aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
  PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
  log_info "Instance public IP: $PUBLIC_IP"
  log_info "Access at: https://$PUBLIC_IP.nip.io/"
}

build_artifacts
ensure_keypair
ensure_sg
launch_instance

log_info "S3-free EC2 deploy complete"