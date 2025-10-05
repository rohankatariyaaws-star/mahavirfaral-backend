#!/bin/bash

# Fix Task Definition and Clear Failed Tasks

AWS_REGION="ap-south-1"
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "🧹 Clearing all failed tasks and fixing task definition..."

# 1. Stop all running tasks
echo "1. Stopping all tasks..."
TASK_ARNS=$(aws ecs list-tasks --cluster $CLUSTER_NAME --region $AWS_REGION --query 'taskArns[]' --output text)
if [ -n "$TASK_ARNS" ]; then
    for task in $TASK_ARNS; do
        aws ecs stop-task --cluster $CLUSTER_NAME --task $task --region $AWS_REGION
        echo "Stopped task: $task"
    done
else
    echo "No tasks to stop"
fi

# 2. Scale service to 0
echo "2. Scaling service to 0..."
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0 --region $AWS_REGION

# 3. Wait for tasks to stop
echo "3. Waiting for tasks to stop..."
sleep 30

# 4. Get current task definition and fix log group
echo "4. Fixing task definition..."
CURRENT_TASK_DEF=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].taskDefinition' --output text)

# Download current task definition
aws ecs describe-task-definition --task-definition $CURRENT_TASK_DEF --region $AWS_REGION --query 'taskDefinition' > current-task-def.json

# Create fixed task definition with correct log group
cat current-task-def.json | jq '
  .containerDefinitions[0].logConfiguration.options."awslogs-group" = "ecommerce-fargate-debug" |
  del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
' > fixed-task-def.json

# 5. Register new task definition
echo "5. Registering fixed task definition..."
aws ecs register-task-definition --cli-input-json file://fixed-task-def.json --region $AWS_REGION

# 6. Update service with new task definition
echo "6. Updating service..."
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition "$APP_NAME-task" --desired-count 1 --region $AWS_REGION

# 7. Cleanup
rm -f current-task-def.json fixed-task-def.json

echo "✅ Task definition fixed and service restarted!"
echo "Wait 2-3 minutes for new task to start with correct log group."