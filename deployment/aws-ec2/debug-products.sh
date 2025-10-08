#!/usr/bin/env bash

# Debug script to check products issue
source "$(dirname "$0")/.env" 2>/dev/null || true

# Get EC2 instance details
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" "Name=instance-state-name,Values=running" --region $AWS_REGION --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "🔍 Debugging products issue on: $PUBLIC_IP"
echo ""

# Test API endpoints
echo "📡 Testing API endpoints:"
echo "1. All products:"
curl -s "http://$PUBLIC_IP:8080/api/products" | jq '.' || echo "Failed or no JSON response"
echo ""

echo "2. Available products:"
curl -s "http://$PUBLIC_IP:8080/api/products/available" | jq '.' || echo "Failed or no JSON response"
echo ""

# Check database connection and logs
echo "📝 Checking backend logs:"
ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP << 'EOF'
echo "=== Service Status ==="
sudo systemctl status ecommerce-fargate-backend --no-pager || sudo systemctl status mahavirfaral-backend --no-pager

echo ""
echo "=== Recent Logs ==="
sudo journalctl -u ecommerce-fargate-backend --no-pager -n 30 | grep -E "(ERROR|WARN|product|database)" || sudo journalctl -u mahavirfaral-backend --no-pager -n 30 | grep -E "(ERROR|WARN|product|database)"

echo ""
echo "=== Database Connection Test ==="
java -jar /home/ec2-user/app.jar --spring.profiles.active=test --logging.level.org.springframework.jdbc=DEBUG 2>&1 | head -20 || echo "Cannot test database connection"
EOF