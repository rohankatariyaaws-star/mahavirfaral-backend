#!/usr/bin/env bash
# Central configuration for aws-ec2 deployment scripts

set -u

# Load .env (if exists) to override defaults
ENV_FILE_DIR=$(dirname "${BASH_SOURCE[0]}")
if [ -f "$ENV_FILE_DIR/.env" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE_DIR/.env"
fi

# Defaults (can be overridden by .env)
: "${AWS_REGION:=ap-south-1}"
: "${APP_NAME:=mahavirfaral}"
: "${DB_USERNAME:=ecommerceadmin}"
: "${DB_PASSWORD:=MyPassword123}"
: "${INSTANCE_TYPE:=t3.micro}"
: "${KEY_NAME:=mahavirfaral-ec2-key}"
: "${SECURITY_GROUP_NAME:=mahavirfaral-ec2-sg}"
: "${AMI_ID:=ami-00be607689b5407d1}"
: "${SSH_USER:=ec2-user}"

# Filenames for persisted IDs
DB_INSTANCE_FILE=".db-instance-id"

# Defaults for retries/timeouts
RETRY_COUNT=30
RETRY_SLEEP=10

# Dry run flag
: "${DRY_RUN:=false}"

# Export variables
export AWS_REGION APP_NAME DB_USERNAME DB_PASSWORD INSTANCE_TYPE KEY_NAME SECURITY_GROUP_NAME AMI_ID SSH_USER
export DB_INSTANCE_FILE RETRY_COUNT RETRY_SLEEP DRY_RUN