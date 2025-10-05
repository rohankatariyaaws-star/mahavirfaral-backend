#!/bin/bash

echo "🔧 Setting up Vercel environment variables for Lambda automation..."

echo "To enable automatic Vercel environment variable updates:"
echo ""
echo "1. Get your Vercel token:"
echo "   - Go to https://vercel.com/account/tokens"
echo "   - Create a new token"
echo ""
echo "2. Get your Vercel project ID:"
echo "   - Go to your project settings in Vercel dashboard"
echo "   - Copy the Project ID"
echo ""
echo "3. Update Lambda environment variables:"

AWS_REGION="ap-south-1"
APP_NAME="ecommerce-fargate"

read -p "Enter your Vercel token: " VERCEL_TOKEN
read -p "Enter your Vercel project ID: " VERCEL_PROJECT_ID

if [ -n "$VERCEL_TOKEN" ] && [ -n "$VERCEL_PROJECT_ID" ]; then
    echo "Updating Lambda function environment variables..."
    
    aws lambda update-function-configuration \
        --function-name $APP_NAME-ip-updater \
        --environment Variables="{LAMBDA_REGION=$AWS_REGION,CLUSTER_NAME=$APP_NAME-cluster,SERVICE_NAME=$APP_NAME-service,APP_NAME=$APP_NAME,VERCEL_TOKEN=$VERCEL_TOKEN,VERCEL_PROJECT_ID=$VERCEL_PROJECT_ID}" \
        --region $AWS_REGION
    
    echo "✅ Lambda function updated with Vercel credentials"
    echo "🤖 Now Lambda will automatically update Vercel environment variables when ECS IP changes"
else
    echo "❌ Missing Vercel token or project ID"
fi