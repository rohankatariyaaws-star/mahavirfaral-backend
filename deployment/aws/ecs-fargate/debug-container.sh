#!/bin/bash

# Debug Container Issues

AWS_REGION="ap-south-1"
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "🔍 Deep debugging container..."

# Get task ARN
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text)

if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    echo "Task ARN: $TASK_ARN"
    
    # Check if ECS Exec is enabled
    echo "🔧 Enabling ECS Exec..."
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --enable-execute-command \
        --region $AWS_REGION
    
    echo "⏳ Wait 30 seconds for exec to be enabled..."
    sleep 30
    
    # Try to connect to container
    echo "🐳 Attempting to connect to container..."
    echo "Running: aws ecs execute-command --cluster $CLUSTER_NAME --task $TASK_ARN --container $APP_NAME-container --interactive --command '/bin/sh' --region $AWS_REGION"
    
    # Check what's running in the container
    echo ""
    echo "📋 Checking container processes..."
    aws ecs execute-command \
        --cluster $CLUSTER_NAME \
        --task $TASK_ARN \
        --container "$APP_NAME-container" \
        --command "ps aux" \
        --region $AWS_REGION || echo "ECS Exec not available"
    
    echo ""
    echo "📋 Checking Java processes..."
    aws ecs execute-command \
        --cluster $CLUSTER_NAME \
        --task $TASK_ARN \
        --container "$APP_NAME-container" \
        --command "ps aux | grep java" \
        --region $AWS_REGION || echo "No Java processes found"
    
    echo ""
    echo "📋 Checking port 8080..."
    aws ecs execute-command \
        --cluster $CLUSTER_NAME \
        --task $TASK_ARN \
        --container "$APP_NAME-container" \
        --command "netstat -tlnp | grep 8080" \
        --region $AWS_REGION || echo "Port 8080 not listening"
    
    echo ""
    echo "📋 Checking if JAR file exists..."
    aws ecs execute-command \
        --cluster $CLUSTER_NAME \
        --task $TASK_ARN \
        --container "$APP_NAME-container" \
        --command "ls -la /app/" \
        --region $AWS_REGION || echo "Cannot list /app directory"
    
else
    echo "❌ No running tasks found"
fi

echo ""
echo "🔧 Alternative debugging - Check task definition environment:"
aws ecs describe-task-definition --task-definition $APP_NAME-task --region $AWS_REGION --query 'taskDefinition.containerDefinitions[0].environment' --output table

echo ""
echo "💡 Manual debugging steps:"
echo "1. Connect to container: aws ecs execute-command --cluster $CLUSTER_NAME --task $TASK_ARN --container $APP_NAME-container --interactive --command '/bin/sh' --region $AWS_REGION"
echo "2. Check Java: java -version"
echo "3. Check JAR: ls -la /app/"
echo "4. Run manually: java -jar /app/app.jar"
echo "5. Check logs: tail -f /var/log/messages"