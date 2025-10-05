#!/bin/bash

# Add CloudWatch Logging to Current ECS Deployment

AWS_REGION="ap-south-1"
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "📋 Adding CloudWatch logging to current deployment..."

# 1. Create CloudWatch log group
echo "1. Creating CloudWatch log group..."
aws logs create-log-group --log-group-name "/ecs/$APP_NAME" --region $AWS_REGION 2>/dev/null || echo "Log group may already exist"

# 2. Get current task definition
echo "2. Getting current task definition..."
CURRENT_TASK_DEF=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].taskDefinition' --output text)

# Download current task definition
aws ecs describe-task-definition --task-definition $CURRENT_TASK_DEF --region $AWS_REGION --query 'taskDefinition' > current-task-def.json

# 3. Add logging configuration
echo "3. Adding logging configuration..."
cat current-task-def.json | jq '
  .containerDefinitions[0].logConfiguration = {
    "logDriver": "awslogs",
    "options": {
      "awslogs-group": "/ecs/'$APP_NAME'",
      "awslogs-region": "'$AWS_REGION'",
      "awslogs-stream-prefix": "ecs"
    }
  } |
  del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
' > task-def-with-logging.json

# 4. Register new task definition with logging
echo "4. Registering new task definition with logging..."
aws ecs register-task-definition --cli-input-json file://task-def-with-logging.json --region $AWS_REGION

# 5. Update service to use new task definition
echo "5. Updating service..."
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition "$APP_NAME-task" --region $AWS_REGION

# 6. Cleanup
rm -f current-task-def.json task-def-with-logging.json

echo "✅ CloudWatch logging added!"
echo "Wait 2-3 minutes for new task to start, then check logs:"
echo "aws logs tail /ecs/$APP_NAME --follow --region $AWS_REGION"