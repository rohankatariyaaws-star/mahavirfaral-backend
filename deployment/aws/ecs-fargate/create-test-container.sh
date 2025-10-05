#!/bin/bash

# Create Test Container to verify basic functionality

AWS_REGION="ap-south-1"
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "🧪 Creating test container without database dependency..."

# Get current details
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
ROLE_ARN=$(aws iam get-role --role-name "$APP_NAME-execution-role" --query 'Role.Arn' --output text)

# Create test task definition with minimal config
cat > task-definition-test.json << EOF
{
    "family": "$APP_NAME-test",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "$ROLE_ARN",
    "containerDefinitions": [
        {
            "name": "$APP_NAME-test-container",
            "image": "nginx:alpine",
            "portMappings": [
                {
                    "containerPort": 80,
                    "protocol": "tcp"
                }
            ],
            "essential": true
        }
    ]
}
EOF

# Register test task definition
aws ecs register-task-definition --cli-input-json file://task-definition-test.json --region $AWS_REGION

# Update service to use test container
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition "$APP_NAME-test" --region $AWS_REGION

rm -f task-definition-test.json

echo "✅ Test container deployed. Wait 2 minutes then test:"
echo "curl http://[PUBLIC_IP]:80"
echo ""
echo "If this works, the issue is with your Java application, not ECS."