#!/bin/bash

# Recreate ECS Service with CloudWatch Logging for Debugging

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"
TASK_FAMILY="$APP_NAME-task"

echo "🔧 Recreating ECS service with logging for debugging..."

# Create CloudWatch log group
LOG_GROUP_NAME="/ecs/$APP_NAME-debug"
aws logs create-log-group --log-group-name "$LOG_GROUP_NAME" --region $AWS_REGION 2>/dev/null || echo "Log group exists"

# Get database info
if [ -f ".db-instance-id" ]; then
    DB_INSTANCE_ID=$(cat .db-instance-id)
    DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)
else
    echo "❌ Database instance ID not found"
    exit 1
fi

# Get ECR repository URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"

# Get IAM role
ROLE_ARN=$(aws iam get-role --role-name "$APP_NAME-execution-role" --query 'Role.Arn' --output text)

# Create new task definition with logging
cat > debug-task-definition.json << EOF
{
    "family": "$TASK_FAMILY-debug",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "$ROLE_ARN",
    "containerDefinitions": [
        {
            "name": "$APP_NAME-container-debug",
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
                    "value": "debug-secret-key-12345"
                },
                {
                    "name": "SPRING_PROFILES_ACTIVE",
                    "value": "production"
                },
                {
                    "name": "LOGGING_LEVEL_ROOT",
                    "value": "INFO"
                },
                {
                    "name": "JAVA_OPTS",
                    "value": "-Xms256m -Xmx512m"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "$LOG_GROUP_NAME",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "debug",
                    "awslogs-create-group": "true"
                }
            },
            "essential": true
        }
    ]
}
EOF

# Register debug task definition
echo "Registering debug task definition..."
aws ecs register-task-definition \
    --cli-input-json file://debug-task-definition.json \
    --region $AWS_REGION

# Stop current service
echo "Stopping current service..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --desired-count 0 \
    --region $AWS_REGION

# Wait for tasks to stop
echo "Waiting for tasks to stop..."
sleep 30

# Update service to use debug task definition
echo "Starting service with debug task definition..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --task-definition "$TASK_FAMILY-debug" \
    --desired-count 1 \
    --region $AWS_REGION

echo "✅ Debug service started"
echo ""
echo "⏳ Wait 2-3 minutes, then check logs with:"
echo "aws logs tail $LOG_GROUP_NAME --follow --region $AWS_REGION"
echo ""
echo "Or check specific log stream:"
echo "aws logs describe-log-streams --log-group-name $LOG_GROUP_NAME --region $AWS_REGION"