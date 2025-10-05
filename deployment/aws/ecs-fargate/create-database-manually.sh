#!/bin/bash

# Manually Create Database

AWS_REGION="ap-south-1"
DB_USERNAME="ecommerceadmin"
DB_PASSWORD="MyPassword123"

echo "🗄️ Creating ecommerce_db database manually..."

# Get database endpoint
if [ -f ".db-instance-id" ]; then
    DB_INSTANCE_ID=$(cat .db-instance-id)
else
    echo "❌ Database instance ID not found"
    exit 1
fi

DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)

echo "Database endpoint: $DB_ENDPOINT"

# Create database using Docker (since psql might not be available)
echo "Creating database using Docker..."

docker run --rm postgres:13-alpine psql \
    "postgresql://$DB_USERNAME:$DB_PASSWORD@$DB_ENDPOINT:5432/postgres" \
    -c "CREATE DATABASE ecommerce_db;" 2>/dev/null || echo "Database may already exist"

echo "✅ Database creation attempted"

# Restart ECS service to retry connection
echo "🔄 Restarting ECS service..."
aws ecs update-service \
    --cluster ecommerce-fargate-cluster \
    --service ecommerce-fargate-service \
    --force-new-deployment \
    --region $AWS_REGION

echo "✅ Service restarted. Wait 2-3 minutes for application to start."