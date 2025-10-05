#!/bin/bash

# Fix Lambda Permission for API Gateway

APP_NAME="ecommerce-lambda"
AWS_REGION="us-east-1"

# Get API Gateway ID
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='$APP_NAME-api'].ApiId" --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "API Gateway ID: $API_ID"
echo "Account ID: $ACCOUNT_ID"

# Remove existing permission
echo "Removing existing Lambda permission..."
aws lambda remove-permission \
    --function-name $APP_NAME-function \
    --statement-id api-gateway-invoke 2>/dev/null || true

# Add new permission with correct source ARN
echo "Adding Lambda permission for API Gateway..."
aws lambda add-permission \
    --function-name $APP_NAME-function \
    --statement-id api-gateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$AWS_REGION:$ACCOUNT_ID:$API_ID/*/*"

echo "Permission added successfully"

# Test the API
echo "Testing API Gateway..."
sleep 5
API_URL="https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/prod"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/products/all" --max-time 30 || echo "000")
echo "API Test Result: HTTP $HTTP_STATUS"