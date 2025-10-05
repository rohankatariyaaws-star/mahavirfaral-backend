#!/usr/bin/env bash
# Central configuration for aws-ecs deployment scripts
# Loads .env if present and exports variables used across modules

set -u

# Load .env (if exists) to override defaults
ENV_FILE_DIR=$(dirname "${BASH_SOURCE[0]}")
if [ -f "$ENV_FILE_DIR/.env" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE_DIR/.env"
fi

# Defaults (can be overridden by .env)
: "${AWS_REGION:=ap-south-1}"
: "${APP_NAME:=ecommerce-fargate}"
: "${DB_USERNAME:=ecommerceadmin}"
: "${DB_PASSWORD:=MyPassword123}"
: "${NETLIFY_SITE_ID:=}"
: "${NETLIFY_TOKEN:=}"
: "${NETLIFY_BUILD_HOOK:=}"
: "${CLUSTER_NAME:=$APP_NAME-cluster}"
: "${SERVICE_NAME:=$APP_NAME-service}"
: "${TASK_FAMILY:=$APP_NAME-task}"

# Filenames for persisted IDs/hashes
DB_INSTANCE_FILE=".db-instance-id"
ECR_INFO_FILE="ecr-info.env"
DOCKER_HASH_FILE=".docker-hash"
FRONTEND_HASH_FILE=".frontend-hash"
PACKAGE_HASH_FILE=".package-hash"
ALB_INFO_FILE="alb-info.env"

# CloudWatch
CLOUDWATCH_LOG_GROUP_NAME="/ecs/$APP_NAME"
CLOUDWATCH_LOG_GROUP_PREFIX="/ecs"

# Defaults for retries/timeouts
RETRY_COUNT=30
RETRY_SLEEP=10

# Dry run flag
: "${DRY_RUN:=false}"

# Export variables so sourced modules can use them
export AWS_REGION APP_NAME DB_USERNAME DB_PASSWORD NETLIFY_SITE_ID NETLIFY_TOKEN NETLIFY_BUILD_HOOK CLUSTER_NAME SERVICE_NAME TASK_FAMILY
export DB_INSTANCE_FILE ECR_INFO_FILE DOCKER_HASH_FILE FRONTEND_HASH_FILE PACKAGE_HASH_FILE ALB_INFO_FILE
export CLOUDWATCH_LOG_GROUP_NAME CLOUDWATCH_LOG_GROUP_PREFIX
export RETRY_COUNT RETRY_SLEEP DRY_RUN
