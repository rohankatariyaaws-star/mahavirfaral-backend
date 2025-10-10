#!/bin/bash

# Quick backend update script
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

echo "Quick backend update for EC2: $EC2_IP"

# Build backend
echo "=== Building backend JAR ==="
cd "$(dirname "$0")/../../backend"
mvn clean package -DskipTests -q
BACKEND_JAR=$(ls target/*.jar | head -n1)
echo "Built: $BACKEND_JAR"

# Upload and restart
echo "=== Uploading and restarting backend ==="
cd "$(dirname "$0")"
PEM_FILE="$(pwd)/mahavirfaral-ec2-key.pem"
scp -i "$PEM_FILE" -o StrictHostKeyChecking=no "$BACKEND_JAR" "$SSH_USER@$EC2_IP:/home/ec2-user/app.jar"

ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no "$SSH_USER@$EC2_IP" << 'EOF'
echo "Restarting backend service..."
echo "Restarting backend service..."
sudo systemctl restart ecommerce-backend
sleep 5
sudo systemctl status ecommerce-backend --no-pager
echo "Backend updated successfully!"
EOF

echo "=== Backend update complete! ==="
echo "You can now test the order creation and check logs with:"
echo "./check-logs.sh follow"