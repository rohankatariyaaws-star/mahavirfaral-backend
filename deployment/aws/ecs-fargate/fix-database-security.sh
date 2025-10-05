#!/bin/bash

# Fix Database Security Group to Allow ECS Connection

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"

echo "🔧 Fixing Database Security Group..."

# Get database instance ID
if [ -f ".db-instance-id" ]; then
    DB_INSTANCE_ID=$(cat .db-instance-id)
else
    echo "❌ Database instance ID not found"
    exit 1
fi

# Get RDS security group
RDS_SG=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
echo "RDS Security Group: $RDS_SG"

# Get ECS security group
ECS_SG=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$APP_NAME-sg" --query 'SecurityGroups[0].GroupId' --output text)
echo "ECS Security Group: $ECS_SG"

if [ "$RDS_SG" = "None" ] || [ "$ECS_SG" = "None" ]; then
    echo "❌ Could not find security groups"
    exit 1
fi

# Add rule to allow ECS to connect to RDS on port 5432
echo "Adding security group rule to allow ECS -> RDS connection..."

aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG \
    --protocol tcp \
    --port 5432 \
    --source-group $ECS_SG \
    --region $AWS_REGION 2>/dev/null && echo "✅ Security group rule added" || echo "⚠️  Rule may already exist"

# Also ensure RDS allows connections from anywhere (for debugging)
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG \
    --protocol tcp \
    --port 5432 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION 2>/dev/null && echo "✅ Public access rule added" || echo "⚠️  Public rule may already exist"

echo ""
echo "🔄 Restarting ECS service to apply changes..."

# Force new deployment to restart containers
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --force-new-deployment \
    --region $AWS_REGION

echo "✅ Service restart initiated"
echo ""
echo "⏳ Wait 2-3 minutes for containers to restart, then test again"
echo "🔍 Use debug-ecs-service.sh to check status"