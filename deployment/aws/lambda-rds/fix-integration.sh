#!/bin/bash

# Fix API Gateway Integration

AWS_REGION=$(aws configure get region || echo "ap-south-1")
API_ID="upx6x8knve"
APP_NAME="ecommerce-lambda"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Checking integration details..."

# Get current integration
INTEGRATION_ID=$(aws apigatewayv2 get-integrations --api-id $API_ID --region $AWS_REGION --query 'Items[0].IntegrationId' --output text)
echo "Integration ID: $INTEGRATION_ID"

# Check integration details
aws apigatewayv2 get-integration --api-id $API_ID --integration-id $INTEGRATION_ID --region $AWS_REGION --query '{IntegrationType:IntegrationType,IntegrationUri:IntegrationUri,PayloadFormatVersion:PayloadFormatVersion}' --output table

# Check if Lambda function exists in correct region
echo ""
echo "Checking Lambda function..."
LAMBDA_ARN=$(aws lambda get-function --function-name $APP_NAME-function --region $AWS_REGION --query 'Configuration.FunctionArn' --output text 2>/dev/null || echo "NotFound")
echo "Lambda ARN: $LAMBDA_ARN"

if [ "$LAMBDA_ARN" = "NotFound" ]; then
    echo "❌ Lambda function not found in region $AWS_REGION"
    exit 1
fi

# Update integration URI to correct Lambda ARN
echo ""
echo "Updating integration URI..."
aws apigatewayv2 update-integration \
    --api-id $API_ID \
    --integration-id $INTEGRATION_ID \
    --integration-uri "$LAMBDA_ARN" \
    --region $AWS_REGION

# Ensure Lambda permission is correct
echo ""
echo "Updating Lambda permission..."
aws lambda remove-permission \
    --function-name $APP_NAME-function \
    --statement-id api-gateway-invoke \
    --region $AWS_REGION 2>/dev/null || true

aws lambda add-permission \
    --function-name $APP_NAME-function \
    --statement-id api-gateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$AWS_REGION:$ACCOUNT_ID:$API_ID/*/*" \
    --region $AWS_REGION

echo "✅ Integration and permissions updated"

# Test after fix
echo ""
echo "Testing after fix..."
sleep 5
API_URL="https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/prod"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/auth/test" --max-time 30 || echo "000")
echo "Test Result: HTTP $HTTP_STATUS"