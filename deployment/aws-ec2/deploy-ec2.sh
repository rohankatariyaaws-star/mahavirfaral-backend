#!/usr/bin/env bash
set -euo pipefail

# Simple, cost-optimized EC2 deploy script for backend + frontend on a single t2.micro (Free Tier eligible)
# Usage: copy .env.example to .env, edit, then run: ./deploy-ec2.sh

ROOT_DIR=$(cd "$(dirname "$0")/../../" && pwd)
source "$(dirname "$0")/.env" 2>/dev/null || true

if [ -z "${APP_NAME:-}" ]; then
  echo "Please create deployment/aws-ec2/.env from .env.example and set APP_NAME, AWS_REGION"
  exit 1
fi

source "$(dirname "$0")/../aws-ecs/utils.sh" 2>/dev/null || true

S3_BUCKET=${S3_BUCKET_PREFIX:-"$APP_NAME-ec2-artifacts-$AWS_REGION-$(date +%s)"}

log_info "Using bucket: $S3_BUCKET"

function ensure_bucket() {
  if ! aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
    log_info "Creating S3 bucket $S3_BUCKET"
    aws s3api create-bucket --bucket "$S3_BUCKET" --create-bucket-configuration LocationConstraint=$AWS_REGION
  else
    log_info "Bucket exists"
  fi
}

function upload_artifacts() {
  log_info "Packaging backend and frontend artifacts"
  # Backend: assume backend/target/*.jar exists
  BACKEND_JAR=$(ls $ROOT_DIR/backend/target/*.jar 2>/dev/null | head -n1 || true)
  if [ -z "$BACKEND_JAR" ]; then
    log_info "Backend jar not found, attempting mvn package"
    (cd $ROOT_DIR/backend && mvn clean package -DskipTests)
    BACKEND_JAR=$(ls $ROOT_DIR/backend/target/*.jar | head -n1)
  fi

  FRONTEND_BUILD_DIR=$ROOT_DIR/frontend/build
  if [ ! -d "$FRONTEND_BUILD_DIR" ]; then
    log_info "Building frontend"
    (cd $ROOT_DIR/frontend && npm install && npm run build)
  fi

  aws s3 cp "$BACKEND_JAR" "s3://$S3_BUCKET/" --region $AWS_REGION
  aws s3 sync "$FRONTEND_BUILD_DIR" "s3://$S3_BUCKET/frontend/" --region $AWS_REGION

  BACKEND_KEY=$(basename "$BACKEND_JAR")
  FRONTEND_PREFIX=frontend/

  BACKEND_URL=$(aws s3 presign "s3://$S3_BUCKET/$BACKEND_KEY" --region $AWS_REGION --expires-in ${PRESIGN_EXPIRY:-43200})
  FRONTEND_URL=$(aws s3 presign "s3://$S3_BUCKET/$FRONTEND_PREFIX" --region $AWS_REGION --expires-in ${PRESIGN_EXPIRY:-43200}) || true

  echo "$BACKEND_URL" > /tmp/ecommerce-backend-url || true
  log_info "Backend presigned URL: $BACKEND_URL"
}

function ensure_keypair() {
  if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region $AWS_REGION >/dev/null 2>&1; then
    log_info "Creating keypair $KEY_NAME"
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$KEY_NAME.pem"
    chmod 600 "$KEY_NAME.pem"
  else
    log_info "Keypair exists: $KEY_NAME"
  fi
}

function ensure_sg() {
  SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=$SECURITY_GROUP_NAME --region $AWS_REGION --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
  if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
    log_info "Creating security group $SECURITY_GROUP_NAME"
    SG_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "EC2 SG for $APP_NAME" --region $AWS_REGION --query 'GroupId' --output text)
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $AWS_REGION
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $AWS_REGION
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region $AWS_REGION
  else
    log_info "Using existing security group $SG_ID"
  fi
}

function launch_instance() {
  log_info "Launching EC2 instance"
  USER_DATA=$(cat <<EOF
#!/bin/bash
yum update -y
# Install Java and nginx
amazon-linux-extras install -y java-openjdk11
yum install -y nginx
systemctl enable nginx
systemctl start nginx

# Download backend jar
curl -o /home/ec2-user/app.jar "$BACKEND_URL"
nohup java -jar /home/ec2-user/app.jar > /home/ec2-user/backend.log 2>&1 &

# Serve frontend via nginx
mkdir -p /usr/share/nginx/html
aws s3 sync s3://$S3_BUCKET/frontend/ /usr/share/nginx/html/ --region $AWS_REGION
systemctl restart nginx

EOF
)

  INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --security-group-ids $SG_ID --user-data "$USER_DATA" --region $AWS_REGION --query 'Instances[0].InstanceId' --output text)
  log_info "Instance launched: $INSTANCE_ID"
  aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
  PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
  log_info "Instance public IP: $PUBLIC_IP"
  echo "http://$PUBLIC_IP/" > /tmp/ecommerce-ec2-url
  # Provide a free DNS using nip.io
  log_info "You can access the site at: http://$PUBLIC_IP.nip.io/"
}

ensure_bucket
upload_artifacts
ensure_keypair
ensure_sg
launch_instance

log_info "EC2 deploy complete"
