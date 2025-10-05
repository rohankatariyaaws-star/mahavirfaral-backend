#!/bin/bash

# Fix Lambda Handler Configuration

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-lambda"

echo "🔧 Fixing Lambda Handler Configuration..."

# Spring Boot Lambda functions might need a different handler
# Try updating to use AWS Lambda Web Adapter or Spring Cloud Function

echo "Current handler: org.springframework.boot.loader.JarLauncher"
echo "This might not work properly with API Gateway integration"

# Option 1: Try updating handler to use Spring Cloud Function
echo ""
echo "Updating Lambda configuration..."

# Increase timeout and memory for Spring Boot startup
aws lambda update-function-configuration \
    --function-name $APP_NAME-function \
    --region $AWS_REGION \
    --timeout 60 \
    --memory-size 1024 \
    --environment Variables="{DATABASE_URL=jdbc:postgresql://ecommerce-lambda-db.c3wm66u2mamb.ap-south-1.rds.amazonaws.com:5432/ecommerce_db,DB_USERNAME=ecommerceadmin,DB_PASSWORD=MyPassword123,JWT_SECRET=ks+gyyVr2jgGvtS4bVci20XIxg2zU4lloUx+HPXfiT4=,SPRING_PROFILES_ACTIVE=lambda}"

echo "✅ Updated Lambda timeout to 60s and memory to 1024MB"

# Test with increased timeout
echo ""
echo "Testing with updated configuration..."
sleep 10

API_URL="https://upx6x8knve.execute-api.ap-south-1.amazonaws.com/prod"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/auth/test" --max-time 60 || echo "000")
echo "Test Result: HTTP $HTTP_STATUS"

if [ "$HTTP_STATUS" = "404" ]; then
    echo ""
    echo "Still getting 404. The issue might be:"
    echo "1. Spring Boot app not starting properly in Lambda"
    echo "2. Wrong handler for API Gateway integration"
    echo "3. Application.properties missing Lambda profile"
    echo ""
    echo "Consider redeploying the backend with Lambda-specific configuration"
fi