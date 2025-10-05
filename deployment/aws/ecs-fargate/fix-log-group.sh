#!/bin/bash

# Fix CloudWatch Log Group Issue

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"

echo "🔧 Creating missing CloudWatch log group..."

# Create the log group with /ecs/ prefix (escape for Git Bash)
aws logs create-log-group --log-group-name "//ecs//ecommerce-fargate-debug" --region $AWS_REGION

echo "✅ Log group created: /ecs/ecommerce-fargate-debug"

# Restart the ECS service to pick up the new log group
echo "🔄 Restarting ECS service..."
aws ecs update-service \
    --cluster "$APP_NAME-cluster" \
    --service "$APP_NAME-service" \
    --force-new-deployment \
    --region $AWS_REGION

echo "✅ Service restarted. Wait 2-3 minutes for new task to start."