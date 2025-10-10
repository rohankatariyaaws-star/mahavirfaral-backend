#!/usr/bin/env bash
set -euo pipefail

# Hot deployment script for running EC2 instance
ROOT_DIR=$(cd "$(dirname "$0")/../../" && pwd)
source "$(dirname "$0")/.env" 2>/dev/null || true

if [ -z "${APP_NAME:-}" ]; then
  echo "Please create .env from .env.example"
  exit 1
fi

source "$(dirname "$0")/../aws-ecs/utils.sh" 2>/dev/null || true

# Get EC2 instance details - try multiple methods
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$APP_NAME*" "Name=instance-state-name,Values=running" --region $AWS_REGION --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")

# If not found by tag, try by security group
if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" "Name=instance-state-name,Values=running" --region $AWS_REGION --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")
fi

# If still not found, show all running instances
if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  echo "Available running instances:"
  aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --region $AWS_REGION --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' --output table
  echo ""
  read -p "Enter Instance ID manually: " INSTANCE_ID
fi

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  echo "No running EC2 instance found. Use deploy-backend-only.sh to create one."
  exit 1
fi

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

log_info "Found running instance: $INSTANCE_ID ($PUBLIC_IP)"

function build_and_upload() {
  log_info "Building backend JAR (forcing rebuild)"
  # Always rebuild to ensure latest code
  (cd $ROOT_DIR/backend && mvn clean package -DskipTests)
  BACKEND_JAR=$(ls $ROOT_DIR/backend/target/*.jar | head -n1)
  
  # Create temp S3 bucket for JAR transfer
  TEMP_BUCKET="$APP_NAME-update-$(date +%s)"
  aws s3 mb "s3://$TEMP_BUCKET" --region $AWS_REGION
  aws s3 cp "$BACKEND_JAR" "s3://$TEMP_BUCKET/app-new.jar" --region $AWS_REGION
  
  log_info "JAR uploaded to S3: $(basename "$BACKEND_JAR")"
}

function ensure_iam_role() {
  # Check if instance has IAM role, if not attach one
  ROLE_NAME="$APP_NAME-ec2-role"
  
  # Create IAM role if it doesn't exist
  if ! aws iam get-role --role-name $ROLE_NAME >/dev/null 2>&1; then
    log_info "Creating IAM role for EC2"
    
    # Create role with inline trust policy
    aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }'
    aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
    
    # Create instance profile
    aws iam create-instance-profile --instance-profile-name $ROLE_NAME
    aws iam add-role-to-instance-profile --instance-profile-name $ROLE_NAME --role-name $ROLE_NAME
    
    sleep 10  # Wait for role to propagate
  fi
  
  # Check if instance has role attached
  CURRENT_PROFILE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text 2>/dev/null || echo "None")
  
  if [ "$CURRENT_PROFILE" = "None" ]; then
    log_info "Attaching IAM role to EC2 instance"
    aws ec2 associate-iam-instance-profile --instance-id $INSTANCE_ID --iam-instance-profile Name=$ROLE_NAME
    sleep 30  # Wait for role to be active
  fi
}

function deploy_to_ec2() {
  log_info "Deploying to EC2 instance"
  
  # Create deployment script
  DEPLOY_SCRIPT=$(cat <<'EOF'
#!/bin/bash
set -e

# Find the correct service name
SERVICE_NAME=$(sudo systemctl list-units --type=service | grep -E '(backend|ecommerce)' | head -1 | awk '{print $1}' || echo "APP_NAME-backend")
echo "Found service: $SERVICE_NAME"

# Download new JAR
aws s3 cp "s3://TEMP_BUCKET/app-new.jar" /home/ec2-user/app-new.jar --region AWS_REGION

# Backup current JAR
cp /home/ec2-user/app.jar /home/ec2-user/app-backup.jar

# Stop service
sudo systemctl stop $SERVICE_NAME

# Replace JAR
mv /home/ec2-user/app-new.jar /home/ec2-user/app.jar
chown ec2-user:ec2-user /home/ec2-user/app.jar

# Start service
sudo systemctl start $SERVICE_NAME

# Wait and check status
sleep 10
sudo systemctl status $SERVICE_NAME --no-pager

# Clean up S3
aws s3 rm "s3://TEMP_BUCKET/app-new.jar" --region AWS_REGION
aws s3 rb "s3://TEMP_BUCKET" --region AWS_REGION

echo "Deployment completed successfully!"
EOF
)

  # Replace placeholders
  DEPLOY_SCRIPT=${DEPLOY_SCRIPT//TEMP_BUCKET/$TEMP_BUCKET}
  DEPLOY_SCRIPT=${DEPLOY_SCRIPT//AWS_REGION/$AWS_REGION}
  DEPLOY_SCRIPT=${DEPLOY_SCRIPT//APP_NAME/$APP_NAME}
  
  # Execute deployment on EC2
  echo "$DEPLOY_SCRIPT" | ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP 'bash -s'
}

function verify_deployment() {
  log_info "Verifying deployment"
  sleep 5
  
  # Test API endpoint
  if curl -f -s "http://$PUBLIC_IP:8080/api/products" > /dev/null; then
    log_info "✅ API is responding"
    log_info "Backend updated successfully at: http://$PUBLIC_IP:8080"
  else
    log_info "⚠️  API not responding, checking logs..."
    ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP 'sudo journalctl -u '$APP_NAME'-backend --no-pager -n 20'
  fi
}

build_and_upload
ensure_iam_role
deploy_to_ec2
verify_deployment

log_info "Hot deployment complete!"