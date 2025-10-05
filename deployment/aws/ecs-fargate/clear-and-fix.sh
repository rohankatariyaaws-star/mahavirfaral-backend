#!/bin/bash

# Clear ECS Service and Fix Task Definition

AWS_REGION="ap-south-1"
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "🧹 Clearing ECS service and fixing task definition..."

# 1. Delete and recreate the service (this clears task history)
echo "1. Deleting service to clear task history..."
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0 --region $AWS_REGION
sleep 30
aws ecs delete-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --region $AWS_REGION

echo "2. Waiting for service deletion..."
sleep 60

# 3. Create new task definition with correct log group
echo "3. Creating fixed task definition..."
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $(cat .db-instance-id) --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
ROLE_ARN=$(aws iam get-role --role-name "$APP_NAME-execution-role" --query 'Role.Arn' --output text)

cat > task-definition-clean.json << EOF
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
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "ecommerce-fargate-debug",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "essential": true
        }
    ]
}
EOF

# 4. Register new task definition
aws ecs register-task-definition --cli-input-json file://task-definition-clean.json --region $AWS_REGION

# 5. Recreate service
echo "4. Creating new service..."
VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
SUBNET_IDS=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0:2].SubnetId' --output text | tr '\t' ',')
SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$APP_NAME-sg" --query 'SecurityGroups[0].GroupId' --output text)

aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --task-definition "$APP_NAME-task" \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
    --region $AWS_REGION

rm -f task-definition-clean.json

echo "✅ Service recreated with clean task history and correct log group!"
echo "Wait 2-3 minutes for new task to start."