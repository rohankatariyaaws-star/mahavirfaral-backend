#!/bin/bash

# Debug Lambda Function

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-lambda"

echo "🔍 Debugging Lambda Function..."

# Check Lambda function details
echo "Lambda Function Details:"
aws lambda get-function --function-name $APP_NAME-function --region $AWS_REGION --query '{Runtime:Configuration.Runtime,Handler:Configuration.Handler,State:Configuration.State,LastModified:Configuration.LastModified}' --output table

# Check environment variables
echo ""
echo "Environment Variables:"
aws lambda get-function-configuration --function-name $APP_NAME-function --region $AWS_REGION --query 'Environment.Variables' --output table

# Test Lambda function directly with a simple event
echo ""
echo "Testing Lambda function directly..."
cat > test-event.json << 'EOF'
{
  "version": "2.0",
  "routeKey": "ANY /api/auth/test",
  "rawPath": "/api/auth/test",
  "rawQueryString": "",
  "headers": {
    "accept": "*/*",
    "content-length": "0",
    "host": "upx6x8knve.execute-api.ap-south-1.amazonaws.com",
    "user-agent": "curl/7.68.0",
    "x-amzn-trace-id": "Root=1-123456789-abcdef"
  },
  "requestContext": {
    "accountId": "556173312286",
    "apiId": "upx6x8knve",
    "domainName": "upx6x8knve.execute-api.ap-south-1.amazonaws.com",
    "domainPrefix": "upx6x8knve",
    "http": {
      "method": "POST",
      "path": "/api/auth/test",
      "protocol": "HTTP/1.1",
      "sourceIp": "127.0.0.1",
      "userAgent": "curl/7.68.0"
    },
    "requestId": "test-request-id",
    "routeKey": "ANY /api/auth/test",
    "stage": "prod",
    "time": "01/Jan/2024:00:00:00 +0000",
    "timeEpoch": 1704067200000
  },
  "body": "",
  "isBase64Encoded": false
}
EOF

# Invoke Lambda function
LAMBDA_RESPONSE=$(aws lambda invoke --function-name $APP_NAME-function --region $AWS_REGION --payload file://test-event.json response.json 2>&1)
echo "Lambda Invoke Result: $LAMBDA_RESPONSE"

if [ -f response.json ]; then
    echo ""
    echo "Lambda Response:"
    cat response.json
    echo ""
fi

# Check recent logs
echo ""
echo "Recent Lambda Logs (last 5 minutes):"
LOG_GROUP="/aws/lambda/$APP_NAME-function"
aws logs filter-log-events \
    --log-group-name $LOG_GROUP \
    --region $AWS_REGION \
    --start-time $(date -d '5 minutes ago' +%s)000 \
    --query 'events[].message' \
    --output text 2>/dev/null || echo "No logs found or log group doesn't exist"

# Cleanup
rm -f test-event.json response.json