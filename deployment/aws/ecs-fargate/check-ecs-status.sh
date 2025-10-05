#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

AWS_REGION="ap-south-1"
APP_NAME="ecommerce-fargate"

echo "🔍 Checking ECS Service Status..."

# Check if service exists
SERVICE_ARN=$(aws ecs describe-services \
    --cluster $APP_NAME-cluster \
    --services $APP_NAME-service \
    --region $AWS_REGION \
    --query 'services[0].serviceArn' \
    --output text 2>/dev/null)

if [ "$SERVICE_ARN" = "None" ] || [ -z "$SERVICE_ARN" ]; then
    echo -e "${RED}❌ ECS Service not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ ECS Service found${NC}"

# Get service details
echo "📋 Service Status:"
aws ecs describe-services \
    --cluster $APP_NAME-cluster \
    --services $APP_NAME-service \
    --region $AWS_REGION \
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}' \
    --output table

# Get task details
echo ""
echo "📋 Task Status:"
TASK_ARNS=$(aws ecs list-tasks \
    --cluster $APP_NAME-cluster \
    --service-name $APP_NAME-service \
    --region $AWS_REGION \
    --query 'taskArns' \
    --output text)

if [ -n "$TASK_ARNS" ] && [ "$TASK_ARNS" != "None" ]; then
    aws ecs describe-tasks \
        --cluster $APP_NAME-cluster \
        --tasks $TASK_ARNS \
        --region $AWS_REGION \
        --query 'tasks[*].{TaskArn:taskArn,LastStatus:lastStatus,HealthStatus:healthStatus,CreatedAt:createdAt}' \
        --output table
    
    # Get container details
    echo ""
    echo "📋 Container Status:"
    aws ecs describe-tasks \
        --cluster $APP_NAME-cluster \
        --tasks $TASK_ARNS \
        --region $AWS_REGION \
        --query 'tasks[*].containers[*].{Name:name,Status:lastStatus,Health:healthStatus,ExitCode:exitCode,Reason:reason}' \
        --output table
else
    echo -e "${YELLOW}⚠️  No tasks found${NC}"
fi

# Check task definition
echo ""
echo "📋 Current Task Definition:"
TASK_DEF_ARN=$(aws ecs describe-services \
    --cluster $APP_NAME-cluster \
    --services $APP_NAME-service \
    --region $AWS_REGION \
    --query 'services[0].taskDefinition' \
    --output text)

aws ecs describe-task-definition \
    --task-definition $TASK_DEF_ARN \
    --region $AWS_REGION \
    --query 'taskDefinition.containerDefinitions[0].{Image:image,Memory:memory,CPU:cpu,LogDriver:logConfiguration.logDriver}' \
    --output table