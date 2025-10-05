#!/bin/bash

# Minimal Free-Tier Fix for ECS Fargate

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "🔧 Minimal Free-Tier Fix..."

cd ../../../backend

echo "1. 🔧 Fixing database security groups..."
if [ -f "../deployment/aws/ecs-fargate/.db-instance-id" ]; then
    DB_INSTANCE_ID=$(cat ../deployment/aws/ecs-fargate/.db-instance-id)
    ECS_SG=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$APP_NAME-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
    RDS_SG=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
    
    aws ec2 authorize-security-group-ingress \
        --group-id $RDS_SG \
        --protocol tcp \
        --port 5432 \
        --source-group $ECS_SG \
        --region $AWS_REGION 2>/dev/null || echo "Rule exists"
fi

echo "2. 📦 Rebuilding with fixes..."
mvn clean package -DskipTests -q

echo "3. 🐳 Pushing new image..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
docker build -t $APP_NAME .
docker tag $APP_NAME:latest $ECR_REPO:latest
docker push $ECR_REPO:latest

echo "4. 🚀 Restarting service..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --force-new-deployment \
    --region $AWS_REGION

echo -e "${GREEN}✅ Minimal fix applied! Wait 2-3 minutes for restart.${NC}"