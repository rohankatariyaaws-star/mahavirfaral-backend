#!/bin/bash

AWS_REGION="ap-south-1"
CLUSTER_NAME="ecommerce-fargate-cluster"
SERVICE_NAME="ecommerce-fargate-service"

echo "Getting current ECS IP..."

TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text 2>/dev/null)

if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
    ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text 2>/dev/null)
    
    if [ -n "$ENI_ID" ]; then
        PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $AWS_REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text 2>/dev/null)
        
        if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
            BACKEND_URL="http://$PUBLIC_IP:8080"
            echo "✅ Current ECS backend URL: $BACKEND_URL"
            echo ""
            echo "📝 Set this environment variable in Vercel:"
            echo "   BACKEND_API_URL = $BACKEND_URL"
            echo ""
            echo "🚀 Or use Vercel CLI:"
            echo "   vercel env add BACKEND_API_URL"
            echo "   (Enter: $BACKEND_URL)"
        else
            echo "❌ Could not get public IP"
        fi
    else
        echo "❌ Could not get network interface"
    fi
else
    echo "❌ No running ECS tasks found"
fi