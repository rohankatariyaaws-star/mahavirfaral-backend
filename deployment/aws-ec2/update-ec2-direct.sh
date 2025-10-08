#!/usr/bin/env bash
set -euo pipefail

# Direct deployment script - no S3 needed
ROOT_DIR=$(cd "$(dirname "$0")/../../" && pwd)
source "$(dirname "$0")/.env" 2>/dev/null || true

if [ -z "${APP_NAME:-}" ]; then
  echo "Please create .env from .env.example"
  exit 1
fi

source "$(dirname "$0")/../aws-ecs/utils.sh" 2>/dev/null || true

# Get EC2 instance details
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" "Name=instance-state-name,Values=running" --region $AWS_REGION --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  echo "Available running instances:"
  aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --region $AWS_REGION --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress]' --output table
  read -p "Enter Instance ID: " INSTANCE_ID
fi

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

log_info "Deploying to: $INSTANCE_ID ($PUBLIC_IP)"

function build_backend() {
  log_info "Building backend JAR"
  BACKEND_JAR=$(ls $ROOT_DIR/backend/target/*.jar 2>/dev/null | head -n1 || true)
  if [ -z "$BACKEND_JAR" ]; then
    (cd $ROOT_DIR/backend && mvn clean package -DskipTests)
    BACKEND_JAR=$(ls $ROOT_DIR/backend/target/*.jar | head -n1)
  fi
  log_info "JAR ready: $(basename "$BACKEND_JAR")"
}

function deploy_direct() {
  log_info "Uploading JAR directly via SCP"
  
  # Upload JAR file
  scp -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no "$BACKEND_JAR" ec2-user@$PUBLIC_IP:/home/ec2-user/app-new.jar
  
  # Deploy via SSH
  ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP << EOF
set -e

echo "Backing up current JAR..."
cp /home/ec2-user/app.jar /home/ec2-user/app-backup.jar

echo "Stopping service..."
sudo systemctl stop $APP_NAME-backend

echo "Replacing JAR..."
mv /home/ec2-user/app-new.jar /home/ec2-user/app.jar
chown ec2-user:ec2-user /home/ec2-user/app.jar

echo "Starting service..."
sudo systemctl start $APP_NAME-backend

echo "Waiting for service to start..."
sleep 15

echo "Checking service status..."
sudo systemctl status $APP_NAME-backend --no-pager || true

echo "Deployment completed!"
EOF
}

function verify_deployment() {
  log_info "Verifying deployment"
  sleep 5
  
  if curl -f -s "http://$PUBLIC_IP:8080/api/products/available" > /dev/null; then
    log_info "✅ API is responding"
    log_info "Backend updated at: http://$PUBLIC_IP:8080"
  else
    log_info "⚠️  API not responding, checking logs..."
    ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP 'sudo journalctl -u '$APP_NAME'-backend --no-pager -n 20'
  fi
}

build_backend
deploy_direct
verify_deployment

log_info "Direct deployment complete!"