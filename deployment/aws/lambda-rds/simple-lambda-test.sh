#!/bin/bash

# Simple Lambda Test

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-lambda"

echo "Testing Lambda with simple payload..."

# Create simple test event
echo '{"test": "hello"}' > simple-test.json

# Test Lambda
aws lambda invoke \
    --function-name $APP_NAME-function \
    --region $AWS_REGION \
    --payload file://simple-test.json \
    --cli-binary-format raw-in-base64-out \
    simple-response.json

echo "Lambda Response:"
cat simple-response.json
echo ""

# Check if there are any logs now
echo "Checking for logs..."
LOG_GROUP="/aws/lambda/$APP_NAME-function"
aws logs describe-log-groups --region $AWS_REGION --log-group-name-prefix "/aws/lambda/$APP_NAME" --query 'logGroups[].logGroupName' --output text

# Try to get recent log streams
aws logs describe-log-streams \
    --log-group-name $LOG_GROUP \
    --region $AWS_REGION \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text 2>/dev/null || echo "No log streams found"

# Cleanup
rm -f simple-test.json simple-response.json