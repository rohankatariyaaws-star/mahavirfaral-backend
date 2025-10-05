#!/usr/bin/env bash
# Create or update ECS service (Fargate)

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

create_ecs_service() {
    log_info "Creating/updating ECS service: $SERVICE_NAME in cluster $CLUSTER_NAME"

    local VPC_ID
    VPC_ID=$(run_aws_cli ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    local SUBNET_IDS
    SUBNET_IDS=$(run_aws_cli ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0:2].SubnetId' --output text | tr '\t' ',')

    # Create security group
    local SG_NAME="$APP_NAME-sg"
    local SG_ID
    SG_ID=$(run_aws_cli ec2 create-security-group --group-name "$SG_NAME" --description "Security group for $APP_NAME" --vpc-id "$VPC_ID" --region "$AWS_REGION" --query 'GroupId' --output text 2>/dev/null || run_aws_cli ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=$SG_NAME" --query 'SecurityGroups[0].GroupId' --output text)

    # Add inbound rules
    run_aws_cli ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$AWS_REGION" 2>/dev/null || true
    run_aws_cli ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region "$AWS_REGION" 2>/dev/null || true

    # Create or update service
    if run_aws_cli ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$AWS_REGION" &> /dev/null; then
        log_info "Updating existing service"
        run_aws_cli ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --task-definition "$TASK_FAMILY" --region "$AWS_REGION"
    else
        log_info "Creating new service"
        run_aws_cli ecs create-service --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --task-definition "$TASK_FAMILY" --desired-count 1 --launch-type FARGATE --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" --region "$AWS_REGION"
    fi

    log_info "ECS service ensured"
}
