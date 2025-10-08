#!/bin/bash

PUBLIC_IP="3.109.157.122"
KEY_NAME="mahavirfaral-ec2-key"

echo "🔍 Checking backend service status..."

ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP << 'EOF'
echo "=== Service Status ==="
sudo systemctl status ecommerce-fargate-backend --no-pager || sudo systemctl status mahavirfaral-backend --no-pager

echo ""
echo "=== Recent Logs ==="
sudo journalctl -u ecommerce-fargate-backend --no-pager -n 20 || sudo journalctl -u mahavirfaral-backend --no-pager -n 20

echo ""
echo "=== Java Process ==="
ps aux | grep java

echo ""
echo "=== Port 8080 ==="
netstat -tlnp | grep 8080 || ss -tlnp | grep 8080

echo ""
echo "=== JAR File ==="
ls -la /home/ec2-user/app*.jar
EOF