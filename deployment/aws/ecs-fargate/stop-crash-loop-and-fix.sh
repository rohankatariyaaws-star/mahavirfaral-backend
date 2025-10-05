#!/bin/bash

# Stop Crash Loop and Fix Database Issue

AWS_REGION="ap-south-1"
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"
DB_USERNAME="ecommerceadmin"
DB_PASSWORD="MyPassword123"

echo "🛑 Stopping crash loop and fixing database..."

# 1. Scale service to 0 to stop crash loop
echo "1. Stopping all tasks..."
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0 --region $AWS_REGION
sleep 30

# 2. Create database using postgres default database
echo "2. Creating ecommerce_db database..."
DB_INSTANCE_ID=$(cat .db-instance-id)
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)

# Create database using Docker
docker run --rm postgres:13-alpine psql \
    "postgresql://$DB_USERNAME:$DB_PASSWORD@$DB_ENDPOINT:5432/postgres" \
    -c "CREATE DATABASE ecommerce_db;" 2>/dev/null || echo "Database may already exist"

# 3. Update task definition to use postgres database initially
echo "3. Creating fixed task definition..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
ROLE_ARN=$(aws iam get-role --role-name "$APP_NAME-execution-role" --query 'Role.Arn' --output text)

cat > task-definition-fixed.json << EOF
{
    "family": "$APP_NAME-task",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "512",
    "memory": "1024",
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
                    "value": "jdbc:postgresql://$DB_ENDPOINT:5432/postgres"
                },
                {
                    "name": "DB_USERNAME",
                    "value": "$DB_USERNAME"
                },
                {
                    "name": "DB_PASSWORD",
                    "value": "$DB_PASSWORD"
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

# 4. Register new task definition
aws ecs register-task-definition --cli-input-json file://task-definition-fixed.json --region $AWS_REGION

# 5. Scale service back to 1
echo "4. Starting service with fixed configuration..."
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition "$APP_NAME-task" --desired-count 1 --region $AWS_REGION

rm -f task-definition-fixed.json

echo "✅ Fixed! Service should start successfully now."
echo "Wait 2-3 minutes and check: ./debug-ecs-service.sh"