#!/usr/bin/env bash
set -euo pipefail

# Rollback script for EC2 deployment
source "$(dirname "$0")/.env" 2>/dev/null || true

if [ -z "${APP_NAME:-}" ]; then
  echo "Please create .env from .env.example"
  exit 1
fi

# Get EC2 instance details
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$APP_NAME*" "Name=instance-state-name,Values=running" --region $AWS_REGION --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  echo "No running EC2 instance found."
  exit 1
fi

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Rolling back deployment on: $INSTANCE_ID ($PUBLIC_IP)"

# Create rollback script
ROLLBACK_SCRIPT=$(cat <<EOF
#!/bin/bash
set -e

if [ ! -f /home/ec2-user/app-backup.jar ]; then
  echo "No backup found to rollback to"
  exit 1
fi

echo "Rolling back to previous version..."

# Stop service
sudo systemctl stop $APP_NAME-backend

# Restore backup
cp /home/ec2-user/app-backup.jar /home/ec2-user/app.jar
chown ec2-user:ec2-user /home/ec2-user/app.jar

# Start service
sudo systemctl start $APP_NAME-backend

# Check status
sleep 10
sudo systemctl status $APP_NAME-backend --no-pager

echo "Rollback completed!"
EOF
)

# Execute rollback on EC2
echo "$ROLLBACK_SCRIPT" | ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP 'bash -s'

echo "Rollback complete!"