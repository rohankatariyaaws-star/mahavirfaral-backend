#!/bin/bash

# Script to check application logs on EC2 server
# Usage: ./check-logs.sh [follow]

set -e

# Load config
source "$(dirname "$0")/config.sh"

# Get EC2 IP
if [ -f ".ec2-ip" ]; then
    EC2_IP=$(cat .ec2-ip)
else
    echo "EC2 IP not found. Run deployment first."
    exit 1
fi

echo "Connecting to EC2 instance: $EC2_IP"
echo "Checking application logs..."

# SSH command to check logs
if [ "$1" = "follow" ]; then
    echo "Following logs in real-time (Ctrl+C to exit)..."
    ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no "$SSH_USER@$EC2_IP" << 'EOF'
echo "=== Application Service Status ==="
sudo systemctl status ecommerce-backend --no-pager

echo -e "\n=== Following Application Logs (Ctrl+C to exit) ==="
sudo journalctl -u ecommerce-backend -f
EOF
else
    echo "Showing recent logs..."
    ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no "$SSH_USER@$EC2_IP" << 'EOF'
echo "=== Application Service Status ==="
sudo systemctl status ecommerce-backend --no-pager

echo -e "\n=== Recent Application Logs ==="
sudo journalctl -u ecommerce-backend --no-pager -n 50

echo -e "\n=== System Logs (last 20 lines) ==="
sudo tail -20 /var/log/messages

echo -e "\n=== Application Process ==="
ps aux | grep java

echo -e "\n=== Port 8080 Status ==="
sudo netstat -tlnp | grep :8080 || echo "Port 8080 not listening"

echo -e "\n=== Test API Endpoint ==="
curl -s http://localhost:8080/api/products | head -100 || echo "API not responding"
EOF
fi