#!/bin/bash

# Fix by removing CloudWatch logging completely

AWS_REGION="ap-south-1"
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "🔧 Creating task definition WITHOUT logging..."

# Get current details
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $(cat .db-instance-id) --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
ROLE_ARN=$(aws iam get-role --role-name "$APP_NAME-execution-role" --query 'Role.Arn' --output text)

# Create task definition WITHOUT logging
cat > task-definition-no-logs.json << EOF
{
    "family": "$APP_NAME-task",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "$ROLE_ARN",
    "containerDefinitions": [
        {
            "name": "$APP_NAME-container",
            "image": "$ECR_REPO:latest",
            "portMappings": [
                {
                    "containerPort": 8080,
                    "protocol": "tcp"
                }
            ],
            "environment": [
                {
                    "name": "DATABASE_URL",
                    "value": "jdbc:postgresql://$DB_ENDPOINT:5432/ecommerce_db"
                },
                {
                    "name": "DB_USERNAME",
                    "value": "ecommerceadmin"
                },
                {
                    "name": "DB_PASSWORD",
                    "value": "MyPassword123"
                },
                {
                    "name": "JWT_SECRET",
                    "value": "$(openssl rand -base64 32)"
                },
                {
                    "name": "SPRING_PROFILES_ACTIVE",
                    "value": "production"
                }
            ],
            "essential": true
        }
    ]
}
EOF

# Register new task definition
aws ecs register-task-definition --cli-input-json file://task-definition-no-logs.json --region $AWS_REGION

# Update service
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition "$APP_NAME-task" --region $AWS_REGION

rm -f task-definition-no-logs.json

echo "✅ Task definition updated WITHOUT logging. Wait 2-3 minutes for container to start."
echo "Check status: aws ecs describe-services --cluster $CLUSTER_NAME --service $SERVICE_NAME --region $AWS_REGION"