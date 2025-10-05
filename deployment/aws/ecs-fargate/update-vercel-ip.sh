#!/bin/bash

# Auto-update Vercel with new ECS IP when service starts
# This runs as a Lambda function triggered by ECS events

set -e

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "🔄 Checking for new ECS task IP..."

# Get current running task
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text)

if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    # Get public IP
    ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
    PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $AWS_REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
    
    if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
        NEW_API_URL="http://$PUBLIC_IP:8080"
        
        # Check if IP changed
        CURRENT_API_URL=$(aws ssm get-parameter --name "ecommerce-api-url" --region $AWS_REGION --query 'Parameter.Value' --output text 2>/dev/null || echo "")
        
        if [ "$NEW_API_URL" != "$CURRENT_API_URL" ]; then
            echo "📍 New IP detected: $PUBLIC_IP"
            
            # Update parameter store
            aws ssm put-parameter --name "ecommerce-api-url" --value "$NEW_API_URL" --type "String" --overwrite --region $AWS_REGION
            
            # Trigger Vercel rebuild with new API URL
            echo "🚀 Triggering Vercel rebuild with new IP..."
            
            # Find frontend directory
            for dir in "../../../frontend" "../../frontend" "../frontend" "./frontend"; do
                if [ -d "$dir" ]; then
                    cd "$dir"
                    break
                fi
            done
            
            # Update environment and redeploy
            echo "REACT_APP_API_URL=$NEW_API_URL" > .env.production.local
            
            # Force rebuild by removing cache files
            rm -f .build-hash .api-url
            
            # Redeploy to existing Vercel project
            if command -v vercel &> /dev/null; then
                # Link to existing project if needed
                if [ ! -f ".vercel/project.json" ]; then
                    vercel link --yes --project="mahavirfaral" 2>/dev/null || true
                fi
                vercel --prod --yes
                echo "✅ Vercel updated with new IP: $PUBLIC_IP"
            else
                echo "⚠️  Vercel CLI not found. Please redeploy frontend manually."
            fi
        else
            echo "✅ IP unchanged: $PUBLIC_IP"
        fi
    fi
else
    echo "⚠️  No running tasks found"
fi