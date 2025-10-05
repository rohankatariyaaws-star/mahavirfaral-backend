#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

AWS_REGION="ap-south-1"
LOG_GROUP="/ecs/ecommerce-fargate-debug"

echo "🔍 Checking ECS Container Logs..."

# Method 1: Use MSYS_NO_PATHCONV to prevent path conversion
export MSYS_NO_PATHCONV=1

echo "📋 Available log streams:"
aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --region $AWS_REGION \
    --query 'logStreams[*].{Stream:logStreamName,LastEvent:lastEventTime}' \
    --output table

echo ""
echo "📖 Recent logs (last 50 lines):"
aws logs tail "$LOG_GROUP" \
    --region $AWS_REGION \
    --since 1h \
    --format short

echo ""
echo "🔄 To follow logs in real-time, run:"
echo "export MSYS_NO_PATHCONV=1 && aws logs tail '$LOG_GROUP' --follow --region $AWS_REGION"