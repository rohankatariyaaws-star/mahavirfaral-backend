#!/usr/bin/env bash

# Quick status check for EC2 deployment
source "$(dirname "$0")/.env" 2>/dev/null || true

if [ -z "${APP_NAME:-}" ]; then
  echo "Please create .env from .env.example"
  exit 1
fi

# Get EC2 instance details
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$APP_NAME*" "Name=instance-state-name,Values=running" --region $AWS_REGION --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  echo "❌ No running EC2 instance found"
  exit 1
fi

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "🖥️  Instance: $INSTANCE_ID"
echo "🌐 Public IP: $PUBLIC_IP"
echo "🔗 API URL: http://$PUBLIC_IP:8080"
echo ""

# Check service status
echo "📊 Service Status:"
ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "sudo systemctl is-active $APP_NAME-backend" || echo "Service not running"

# Test API
echo ""
echo "🔍 API Health Check:"
if curl -f -s "http://$PUBLIC_IP:8080/api/products" > /dev/null; then
  echo "✅ API is responding"
else
  echo "❌ API not responding"
fi

# Show recent logs
echo ""
echo "📝 Recent Logs (last 10 lines):"
ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "sudo journalctl -u $APP_NAME-backend --no-pager -n 10"