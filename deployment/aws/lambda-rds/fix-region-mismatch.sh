#!/bin/bash

# Fix Region Mismatch - Recreate API Gateway in correct region

APP_NAME="ecommerce-lambda"
LAMBDA_REGION=$(aws lambda get-function --function-name $APP_NAME-function --query 'Configuration.{Region:FunctionArn}' --output text | cut -d':' -f4)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Lambda function is in region: $LAMBDA_REGION"
echo "Account ID: $ACCOUNT_ID"

# Delete existing API Gateway in wrong region
OLD_API_ID=$(aws apigatewayv2 get-apis --region us-east-1 --query "Items[?Name=='$APP_NAME-api'].ApiId" --output text 2>/dev/null)
if [ -n "$OLD_API_ID" ] && [ "$OLD_API_ID" != "None" ]; then
    echo "Deleting API Gateway in us-east-1: $OLD_API_ID"
    aws apigatewayv2 delete-api --api-id $OLD_API_ID --region us-east-1
fi

# Create new API Gateway in correct region
echo "Creating API Gateway in $LAMBDA_REGION..."
API_ID=$(aws apigatewayv2 create-api \
    --name $APP_NAME-api \
    --protocol-type HTTP \
    --region $LAMBDA_REGION \
    --query 'ApiId' --output text)

echo "New API Gateway ID: $API_ID"

# Create integration
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id $API_ID \
    --integration-type AWS_PROXY \
    --integration-uri "arn:aws:lambda:$LAMBDA_REGION:$ACCOUNT_ID:function:$APP_NAME-function" \
    --payload-format-version "2.0" \
    --region $LAMBDA_REGION \
    --query 'IntegrationId' --output text)

echo "Integration ID: $INTEGRATION_ID"

# Create routes
aws apigatewayv2 create-route \
    --api-id $API_ID \
    --route-key 'ANY /api/{proxy+}' \
    --target "integrations/$INTEGRATION_ID" \
    --region $LAMBDA_REGION

aws apigatewayv2 create-route \
    --api-id $API_ID \
    --route-key 'ANY /api' \
    --target "integrations/$INTEGRATION_ID" \
    --region $LAMBDA_REGION

# Create stage
aws apigatewayv2 create-stage \
    --api-id $API_ID \
    --stage-name prod \
    --auto-deploy \
    --region $LAMBDA_REGION

# Add Lambda permission
aws lambda remove-permission \
    --function-name $APP_NAME-function \
    --statement-id api-gateway-invoke \
    --region $LAMBDA_REGION 2>/dev/null || true

aws lambda add-permission \
    --function-name $APP_NAME-function \
    --statement-id api-gateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$LAMBDA_REGION:$ACCOUNT_ID:$API_ID/*/*" \
    --region $LAMBDA_REGION

# Update parameter store
API_URL="https://$API_ID.execute-api.$LAMBDA_REGION.amazonaws.com/prod"
aws ssm put-parameter --name "ecommerce-api-url" --value "$API_URL" --type "String" --overwrite --region $LAMBDA_REGION

echo "✅ API Gateway created in correct region: $API_URL"

# Test
sleep 10
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/products/all" --max-time 30 || echo "000")
echo "API Test Result: HTTP $HTTP_STATUS"