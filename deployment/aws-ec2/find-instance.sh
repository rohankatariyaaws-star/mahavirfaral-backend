#!/usr/bin/env bash

source "$(dirname "$0")/.env" 2>/dev/null || true

echo "🔍 Finding your EC2 instances..."
echo ""

echo "All running instances:"
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --region $AWS_REGION --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress,PrivateIpAddress,InstanceType,KeyName]' --output table

echo ""
echo "Instances with Java/backend (checking security groups):"
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --region $AWS_REGION --query 'Reservations[].Instances[?SecurityGroups[?contains(GroupName, `backend`) || contains(GroupName, `ecommerce`) || contains(GroupName, `java`)]].[InstanceId,PublicIpAddress,SecurityGroups[0].GroupName]' --output table

echo ""
read -p "Enter the Public IP of your backend instance: " PUBLIC_IP

if [ -n "$PUBLIC_IP" ]; then
    echo ""
    echo "🧪 Testing API on $PUBLIC_IP..."
    
    echo "1. Health check:"
    curl -s "http://$PUBLIC_IP:8080/actuator/health" 2>/dev/null || echo "No health endpoint"
    
    echo ""
    echo "2. All products:"
    curl -s "http://$PUBLIC_IP:8080/api/products" 2>/dev/null || echo "API not responding"
    
    echo ""
    echo "3. Available products:"
    curl -s "http://$PUBLIC_IP:8080/api/products/available" 2>/dev/null || echo "API not responding"
    
    echo ""
    echo "✅ Your backend IP is: $PUBLIC_IP"
    echo "Update your .env file or use this IP directly"
fi