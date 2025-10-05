#!/bin/bash

# Quick Fix and Deploy Script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "🚀 Quick Fix and Deploy for ECS Fargate..."

# Navigate to backend directory
cd ../../../backend

echo "1. 🔧 Fixing database security groups..."
# Get database instance ID
if [ -f "../deployment/aws/ecs-fargate/.db-instance-id" ]; then
    DB_INSTANCE_ID=$(cat ../deployment/aws/ecs-fargate/.db-instance-id)
    
    # Get security groups
    ECS_SG=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$APP_NAME-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
    RDS_SG=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
    
    # Add rule to allow ECS to connect to RDS
    aws ec2 authorize-security-group-ingress \
        --group-id $RDS_SG \
        --protocol tcp \
        --port 5432 \
        --source-group $ECS_SG \
        --region $AWS_REGION 2>/dev/null || echo "Security group rule may already exist"
    
    echo -e "${GREEN}✅ Fixed database security groups${NC}"
fi

echo "2. 📦 Building application..."
mvn clean package -DskipTests -q

echo "3. 🐳 Building and pushing Docker image..."
# Get ECR details
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

# Build and push image
docker build --no-cache -t $APP_NAME .
docker tag $APP_NAME:latest $ECR_REPO:latest
docker push $ECR_REPO:latest

echo "4. 📋 Creating improved task definition..."
# Get database endpoint
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)

# Get execution role ARN
ROLE_ARN=$(aws iam get-role --role-name "$APP_NAME-execution-role" --query 'Role.Arn' --output text)

# Create CloudWatch log group
aws logs create-log-group --log-group-name "/ecs/$APP_NAME" --region $AWS_REGION 2>/dev/null || true

# Create improved task definition
cat > task-definition-fixed.json << EOF
{
    "family": "$APP_NAME-task",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "512",
    "memory": "1024",
    "executionRoleArn": "$ROLE_ARN",
    "containerDefinitions": [
        {
            "name": "$APP_NAME-container",
            "image": "$ECR_REPO:latest",
            "portMappings": [
                {
                    "containerPort": 8080,
                    "protocol": "tcp"
                }
            ],
            "environment": [
                {
                    "name": "DATABASE_URL",
                    "value": "jdbc:postgresql://$DB_ENDPOINT:5432/ecommerce_db"
                },
                {
                    "name": "DB_USERNAME",
                    "value": "ecommerceadmin"
                },
                {
                    "name": "DB_PASSWORD",
                    "value": "MyPassword123"
                },
                {
                    "name": "JWT_SECRET",
                    "value": "$(openssl rand -base64 32)"
                },
                {
                    "name": "SPRING_PROFILES_ACTIVE",
                    "value": "production"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/$APP_NAME",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "essential": true
        }
    ]
}
EOF

echo "5. 🚀 Deploying new task definition..."
# Register new task definition
aws ecs register-task-definition --cli-input-json file://task-definition-fixed.json --region $AWS_REGION

# Update service
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --task-definition "$APP_NAME-task" \
    --region $AWS_REGION

echo -e "${GREEN}✅ Deployment completed!${NC}"
echo ""
echo "🔍 Monitoring deployment..."
echo "Wait 2-3 minutes for the service to restart, then check:"
echo "1. Service status: aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION"
echo "2. Task logs: aws logs tail /ecs/$APP_NAME --follow --region $AWS_REGION"
echo "3. Run: ./debug-ecs-service.sh to test endpoints"

# Wait a bit and show initial status
sleep 30
echo ""
echo "📊 Initial Status Check:"
aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' --output table