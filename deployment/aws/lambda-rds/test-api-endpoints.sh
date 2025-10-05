#!/bin/bash

# Test API Gateway endpoints

AWS_REGION=$(aws configure get region || echo "ap-south-1")
API_URL="https://upx6x8knve.execute-api.ap-south-1.amazonaws.com/prod"

echo "Testing API Gateway endpoints..."
echo "Base URL: $API_URL"

# Test different endpoints
endpoints=(
    "/api/products/all"
    "/api/products/available" 
    "/api/auth/test"
    "/api/auth/create-admin"
)

for endpoint in "${endpoints[@]}"; do
    echo ""
    echo "Testing: $API_URL$endpoint"
    
    # Get HTTP status and response
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$API_URL$endpoint" --max-time 30 2>/dev/null || echo "HTTPSTATUS:000")
    
    http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo $response | sed -e 's/HTTPSTATUS\:.*//g')
    
    echo "HTTP Status: $http_code"
    if [ ${#body} -gt 0 ] && [ ${#body} -lt 500 ]; then
        echo "Response: $body"
    elif [ ${#body} -gt 500 ]; then
        echo "Response: [Large response - ${#body} characters]"
    fi
done

# Test Lambda function directly
echo ""
echo "Checking Lambda function status..."
LAMBDA_STATUS=$(aws lambda get-function --function-name ecommerce-lambda-function --region $AWS_REGION --query 'Configuration.State' --output text 2>/dev/null || echo "NotFound")
echo "Lambda Status: $LAMBDA_STATUS"

# Check API Gateway routes
echo ""
echo "API Gateway Routes:"
API_ID="upx6x8knve"
aws apigatewayv2 get-routes --api-id $API_ID --region $AWS_REGION --query 'Items[].{RouteKey:RouteKey,Target:Target}' --output table