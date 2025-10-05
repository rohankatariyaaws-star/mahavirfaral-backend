#!/bin/bash

# Debug ECS Service Script

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "🔍 Debugging ECS Service..."

# Get service status
echo "📊 Service Status:"
aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].{Status:status,RunningCount:runningCount,PendingCount:pendingCount,DesiredCount:desiredCount}' --output table

# Get task details
echo ""
echo "📋 Task Details:"
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text)

if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    echo "Task ARN: $TASK_ARN"
    
    # Get task status
    aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].{LastStatus:lastStatus,HealthStatus:healthStatus,CreatedAt:createdAt}' --output table
    
    # Get container status
    echo ""
    echo "🐳 Container Status:"
    aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].containers[0].{Name:name,LastStatus:lastStatus,HealthStatus:healthStatus,ExitCode:exitCode,Reason:reason}' --output table
    
    # Get public IP
    ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
    PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $AWS_REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
    
    echo ""
    echo "🌐 Network Details:"
    echo "Public IP: $PUBLIC_IP"
    echo "Service URL: http://$PUBLIC_IP:8080"
    
    # Test different endpoints
    echo ""
    echo "🔍 Testing Endpoints:"
    
    endpoints=(
        "/"
        "/api/auth/test"
        "/api/auth/create-admin"
        "/api/products/all"
    )
    
    for endpoint in "${endpoints[@]}"; do
        echo ""
        echo "Testing: http://$PUBLIC_IP:8080$endpoint"
        
        # Get detailed response
        response=$(curl -s -w "HTTPSTATUS:%{http_code}" "http://$PUBLIC_IP:8080$endpoint" --max-time 10 2>/dev/null || echo "HTTPSTATUS:000")
        
        http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
        body=$(echo $response | sed -e 's/HTTPSTATUS\:.*//g')
        
        echo "HTTP Status: $http_code"
        if [ ${#body} -gt 0 ] && [ ${#body} -lt 200 ]; then
            echo "Response: $body"
        elif [ ${#body} -gt 200 ]; then
            echo "Response: [Large response - ${#body} characters]"
        fi
    done
    
    # Check database connectivity
    echo ""
    echo "🗄️ Database Connectivity:"
    if [ -f ".db-instance-id" ]; then
        DB_INSTANCE_ID=$(cat .db-instance-id)
        DB_STATUS=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].DBInstanceStatus' --output text)
        DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)
        echo "Database: $DB_INSTANCE_ID"
        echo "Status: $DB_STATUS"
        echo "Endpoint: $DB_ENDPOINT"
    else
        echo "No database instance ID found"
    fi
    
else
    echo "❌ No running tasks found"
fi

echo ""
echo "💡 Troubleshooting Tips:"
echo "- If HTTP 000: Application might still be starting (Spring Boot takes 30-60s)"
echo "- If HTTP 404: Check if Spring Boot is running on port 8080"
echo "- If HTTP 500: Check database connectivity and credentials"
echo "- Wait 2-3 minutes and try again if application just started"