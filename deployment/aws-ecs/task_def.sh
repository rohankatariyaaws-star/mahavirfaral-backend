#!/usr/bin/env bash
# Create ECS task definition using ECR image and DB env variables

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

create_task_definition() {
    log_info "Creating task definition: $TASK_FAMILY"

    # Determine DB endpoint
    if [ -f "$DB_INSTANCE_FILE" ]; then
        DB_INSTANCE_ID=$(cat "$DB_INSTANCE_FILE")
    else
        DB_INSTANCE_ID="$APP_NAME-db"
    fi
    DB_ENDPOINT=$(run_aws_cli rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" --region "$AWS_REGION" --query 'DBInstances[0].Endpoint.Address' --output text 2>/dev/null || echo "")

    # Get ECR repo
    if [ -f "$ECR_INFO_FILE" ]; then
        # shellcheck disable=SC1090
        source "$ECR_INFO_FILE"
    fi
    if [ -z "${ECR_REPO:-}" ]; then
        local ACCOUNT_ID
        ACCOUNT_ID=$(run_aws_cli sts get-caller-identity --query Account --output text)
        ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
    fi

    # Create execution role
    ROLE_NAME="$APP_NAME-execution-role"
    if ! run_aws_cli iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
        log_info "Creating IAM role: $ROLE_NAME"
        run_aws_cli iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
        run_aws_cli iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy || true
        sleep 5
    fi
    ROLE_ARN=$(run_aws_cli iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

    # Ensure log group
    if run_aws_cli logs describe-log-groups --log-group-name-prefix "$CLOUDWATCH_LOG_GROUP_PREFIX" --region "$AWS_REGION" --query "logGroups[?logGroupName=='$CLOUDWATCH_LOG_GROUP_NAME'].logGroupName" --output text | grep -q "$CLOUDWATCH_LOG_GROUP_NAME"; then
        log_info "CloudWatch log group exists"
    else
        log_info "Creating CloudWatch log group: $CLOUDWATCH_LOG_GROUP_NAME"
        run_aws_cli logs create-log-group --log-group-name "$CLOUDWATCH_LOG_GROUP_NAME" --region "$AWS_REGION"
    fi

    JWT_SECRET=$(openssl rand -base64 32)

    cat > task-definition.json <<EOF
{
    "family": "$TASK_FAMILY",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "512",
    "memory": "1024",
    "executionRoleArn": "$ROLE_ARN",
    "containerDefinitions": [
        {
            "name": "$APP_NAME-container",
            "image": "$ECR_REPO:latest",
            "portMappings": [ { "containerPort": 8080, "protocol": "tcp" } ],
            "environment": [
                { "name": "DATABASE_URL", "value": "jdbc:postgresql://$DB_ENDPOINT:5432/ecommerce_db" },
                { "name": "DB_USERNAME", "value": "$DB_USERNAME" },
                { "name": "DB_PASSWORD", "value": "$DB_PASSWORD" },
                { "name": "JWT_SECRET", "value": "$JWT_SECRET" },
                { "name": "SPRING_PROFILES_ACTIVE", "value": "production" }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "$CLOUDWATCH_LOG_GROUP_NAME",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "essential": true
        }
    ]
}
EOF

    TASK_DEF_ARN=$(run_aws_cli ecs register-task-definition --cli-input-json file://task-definition.json --region "$AWS_REGION" --query 'taskDefinition.taskDefinitionArn' --output text)
    log_info "Task definition registered: $TASK_DEF_ARN"
}
