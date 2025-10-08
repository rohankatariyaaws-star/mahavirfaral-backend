#!/usr/bin/env bash
set -euo pipefail

# Backend-only EC2 deployment - no frontend, no S3, no nginx
ROOT_DIR=$(cd "$(dirname "$0")/../../" && pwd)
source "$(dirname "$0")/.env" 2>/dev/null || true

if [ -z "${APP_NAME:-}" ]; then
  echo "Please create .env from .env.example"
  exit 1
fi

source "$(dirname "$0")/../aws-ecs/utils.sh" 2>/dev/null || true

function build_backend() {
  log_info "Building backend JAR"
  BACKEND_JAR=$(ls $ROOT_DIR/backend/target/*.jar 2>/dev/null | head -n1 || true)
  if [ -z "$BACKEND_JAR" ]; then
    (cd $ROOT_DIR/backend && mvn clean package -DskipTests)
    BACKEND_JAR=$(ls $ROOT_DIR/backend/target/*.jar | head -n1)
  fi
  
  # Create temp S3 bucket for JAR transfer
  TEMP_BUCKET="$APP_NAME-temp-$(date +%s)"
  aws s3 mb "s3://$TEMP_BUCKET" --region $AWS_REGION
  aws s3 cp "$BACKEND_JAR" "s3://$TEMP_BUCKET/app.jar" --region $AWS_REGION
  
  log_info "Backend JAR uploaded: $(basename "$BACKEND_JAR")"
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
    SG_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "Backend API for $APP_NAME" --region $AWS_REGION --query 'GroupId' --output text)
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $AWS_REGION
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region $AWS_REGION
  fi
}

function launch_instance() {
  log_info "Launching backend-only EC2 instance"
  
  USER_DATA=$(cat <<EOF
#!/bin/bash
set -e
yum update -y
amazon-linux-extras install -y java-openjdk11

# Download backend JAR from S3
aws s3 cp "s3://$TEMP_BUCKET/app.jar" /home/ec2-user/app.jar --region $AWS_REGION
chown ec2-user:ec2-user /home/ec2-user/app.jar

# Create systemd service for backend
cat > /etc/systemd/system/$APP_NAME-backend.service <<'SERVICE_EOF'
[Unit]
Description=$APP_NAME Backend API
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user
ExecStart=/usr/bin/java -jar /home/ec2-user/app.jar
Restart=always
RestartSec=10
Environment=SERVER_PORT=8080

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable $APP_NAME-backend
systemctl start $APP_NAME-backend

# Clean up temp S3 bucket
aws s3 rm "s3://$TEMP_BUCKET/app.jar" --region $AWS_REGION
aws s3 rb "s3://$TEMP_BUCKET" --region $AWS_REGION

# Wait for service to start
sleep 10
systemctl status $APP_NAME-backend

EOF
)

  INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --security-group-ids $SG_ID --user-data "$USER_DATA" --region $AWS_REGION --query 'Instances[0].InstanceId' --output text)
  log_info "Instance launched: $INSTANCE_ID"
  aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
  PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
  
  log_info "Backend API available at:"
  log_info "  http://$PUBLIC_IP:8080/"
  log_info "  http://$PUBLIC_IP.nip.io:8080/"
  
  echo "http://$PUBLIC_IP:8080" > /tmp/backend-api-url
}

build_backend
ensure_keypair
ensure_sg
launch_instance

log_info "Backend-only deployment complete!"
log_info "SSH: ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"