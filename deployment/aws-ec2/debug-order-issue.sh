#!/bin/bash

# Script to debug the order items issue
# This will place a test order and check the logs

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

echo "Debugging order items issue on EC2: $EC2_IP"

# Test order creation
echo "=== Testing Order Creation ==="
curl -X POST "https://$EC2_IP/api/orders" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "userId": 3,
    "items": [
      {
        "productId": 68,
        "quantity": 1,
        "size": "250gm",
        "price": 40
      },
      {
        "productId": 68,
        "quantity": 1,
        "size": "500g",
        "price": 75
      }
    ],
    "paymentMethod": "Cash on Delivery",
    "notes": "Test order",
    "shippingCost": 0,
    "totalAmount": 115
  }' || echo "Order creation failed"

echo -e "\n=== Checking Application Logs for Order Creation ==="
ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no "$SSH_USER@$EC2_IP" << 'EOF'
echo "Recent logs from order creation:"
sudo journalctl -u ecommerce-backend --no-pager -n 30 | grep -E "(Received order items|Processing item|Saved order item|Final order has)"

echo -e "\nAll recent application logs:"
sudo journalctl -u ecommerce-backend --no-pager -n 50
EOF