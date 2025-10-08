#!/usr/bin/env bash
# Scheduled scaling via Application Auto Scaling

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

create_scheduled_scaling() {
    log_info "Configuring scheduled scaling for $SERVICE_NAME"

    local SCALING_ROLE_NAME="$APP_NAME-scaling-role"
    if ! run_aws_cli iam get-role --role-name "$SCALING_ROLE_NAME" &> /dev/null; then
        run_aws_cli iam create-role --role-name "$SCALING_ROLE_NAME" --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"application-autoscaling.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
        run_aws_cli iam attach-role-policy --role-name "$SCALING_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/application-autoscaling/AWSApplicationAutoscalingECSServicePolicy || true
        sleep 5
    fi

    log_info "Manually setting desired capacity to 1 to start the service"
    run_aws_cli ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --desired-count 1 \
        --region "$AWS_REGION"
    run_aws_cli application-autoscaling register-scalable-target --service-namespace ecs --resource-id service/$CLUSTER_NAME/$SERVICE_NAME --scalable-dimension ecs:service:DesiredCount --min-capacity 0 --max-capacity 1 --region "$AWS_REGION" 2>/dev/null || true

    run_aws_cli application-autoscaling put-scheduled-action --service-namespace ecs --resource-id service/$CLUSTER_NAME/$SERVICE_NAME --scalable-dimension ecs:service:DesiredCount --scheduled-action-name "$APP_NAME-scale-up" --schedule "cron(0 15 20 * * ?)" --scalable-target-action MinCapacity=1,MaxCapacity=1 --region "$AWS_REGION" 2>/dev/null || true

    run_aws_cli application-autoscaling put-scheduled-action --service-namespace ecs --resource-id service/$CLUSTER_NAME/$SERVICE_NAME --scalable-dimension ecs:service:DesiredCount --scheduled-action-name "$APP_NAME-scale-down" --schedule "cron(30 17 * * ? *)" --scalable-target-action MinCapacity=0,MaxCapacity=0 --region "$AWS_REGION" 2>/dev/null || true

    log_info "Scheduled scaling created (6 AM - 12 AM IST)"
}

deploy_scheduler_only() {
    create_scheduled_scaling
    source "$(dirname "${BASH_SOURCE[0]}")/lambda.sh"
    create_lambda_ip_updater
}
