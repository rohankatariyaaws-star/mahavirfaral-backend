#!/bin/bash

# Check Security Group Configuration

AWS_REGION="ap-south-1"
APP_NAME="ecommerce-fargate"

echo "🔒 Checking Security Group Configuration..."

# Get ECS security group
SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$APP_NAME-sg" --query 'SecurityGroups[0].GroupId' --output text)

echo "ECS Security Group: $SG_ID"

# Check inbound rules
echo ""
echo "📥 Inbound Rules:"
aws ec2 describe-security-groups --group-ids $SG_ID --region $AWS_REGION --query 'SecurityGroups[0].IpPermissions' --output table

# Check outbound rules
echo ""
echo "📤 Outbound Rules:"
aws ec2 describe-security-groups --group-ids $SG_ID --region $AWS_REGION --query 'SecurityGroups[0].IpPermissionsEgress' --output table

echo ""
echo "🔧 Fixing security group rules..."

# Add inbound rules for both ports
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION 2>/dev/null || echo "Port 80 rule may already exist"

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 8080 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION 2>/dev/null || echo "Port 8080 rule may already exist"

# Add outbound rule for all traffic (if not exists)
aws ec2 authorize-security-group-egress \
    --group-id $SG_ID \
    --protocol -1 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION 2>/dev/null || echo "Outbound rule may already exist"

echo ""
echo "✅ Security group rules updated!"
echo ""
echo "📥 Updated Inbound Rules:"
aws ec2 describe-security-groups --group-ids $SG_ID --region $AWS_REGION --query 'SecurityGroups[0].IpPermissions' --output table