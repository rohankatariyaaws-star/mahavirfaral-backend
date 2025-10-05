#!/usr/bin/env bash
# ECS cluster creation

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

create_ecs_cluster() {
    log_info "Creating or reusing ECS cluster: $CLUSTER_NAME"
    run_aws_cli ecs create-cluster --cluster-name "$CLUSTER_NAME" --capacity-providers FARGATE --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 --region "$AWS_REGION" 2>/dev/null || log_info "Cluster may already exist"
    log_info "ECS cluster ensured: $CLUSTER_NAME"
}
