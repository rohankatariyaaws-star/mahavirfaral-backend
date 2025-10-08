#!/usr/bin/env bash
# RDS helpers: find existing DB or create a new one

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

find_or_create_rds_instance() {
    log_info "Finding or creating RDS instance..."

    local existing_dbs=("ecommerce-lambda-db" "ecommerce-fargate-db" "ecommerce-ec2-db" "mahavirfaral-db")
    local found_db=""

    for db in "${existing_dbs[@]}"; do
        if run_aws_cli rds describe-db-instances --db-instance-identifier "$db" --region "$AWS_REGION" &> /dev/null; then
            found_db="$db"
            log_info "Found existing RDS instance: $found_db"

            local existing_username
            existing_username=$(run_aws_cli rds describe-db-instances --db-instance-identifier "$db" --region "$AWS_REGION" --query 'DBInstances[0].MasterUsername' --output text 2>/dev/null || echo "")
            log_info "Existing DB username: $existing_username"

            if [ -n "$existing_username" ] && [ "$existing_username" != "$DB_USERNAME" ]; then
                log_warn "Updating DB_USERNAME to match existing: $existing_username"
                DB_USERNAME="$existing_username"
                export DB_USERNAME
                if [ "$existing_username" = "postgres" ]; then
                    DB_PASSWORD="root"
                elif [ "$existing_username" = "ecommerceadmin" ]; then
                    DB_PASSWORD="MyPassword123"
                fi
                export DB_PASSWORD
            fi
            break
        fi
    done

    if [ -n "$found_db" ]; then
        DB_INSTANCE_ID="$found_db"
        echo "$DB_INSTANCE_ID" > "$DB_INSTANCE_FILE"
        log_info "Using existing DB: $DB_INSTANCE_ID"
        return 0
    fi

    # Create DB subnet group if missing
    if ! run_aws_cli rds describe-db-subnet-groups --db-subnet-group-name "$APP_NAME-subnet-group" --region "$AWS_REGION" &> /dev/null; then
        log_info "Creating DB subnet group: $APP_NAME-subnet-group"
        local subnets
        subnets=$(run_aws_cli ec2 describe-subnets --region "$AWS_REGION" --query 'Subnets[0:2].SubnetId' --output text)
        run_aws_cli rds create-db-subnet-group --db-subnet-group-name "$APP_NAME-subnet-group" \
            --db-subnet-group-description "Subnet group for $APP_NAME" --subnet-ids $subnets --region "$AWS_REGION"
    fi

    log_info "Creating new RDS instance: $APP_NAME-db"
    if [ "$DRY_RUN" = "true" ]; then
        log_info "Dry-run mode, skipping actual RDS creation"
        DB_INSTANCE_ID="$APP_NAME-db"
        echo "$DB_INSTANCE_ID" > "$DB_INSTANCE_FILE"
        return 0
    fi

    run_aws_cli rds create-db-instance \
        --db-instance-identifier "$APP_NAME-db" \
        --db-instance-class db.t3.micro \
        --engine postgres \
        --master-username "$DB_USERNAME" \
        --master-user-password "$DB_PASSWORD" \
        --allocated-storage 20 \
        --db-subnet-group-name "$APP_NAME-subnet-group" \
        --publicly-accessible --no-multi-az --storage-type gp2 --region "$AWS_REGION"

    log_info "Waiting for DB to be available (this may take several minutes)..."
    run_aws_cli rds wait db-instance-available --db-instance-identifier "$APP_NAME-db" --region "$AWS_REGION"

    DB_INSTANCE_ID="$APP_NAME-db"
    echo "$DB_INSTANCE_ID" > "$DB_INSTANCE_FILE"
    log_info "RDS instance created: $DB_INSTANCE_ID"
}

get_rds_endpoint() {
    if [ -f "$DB_INSTANCE_FILE" ]; then
        DB_INSTANCE_ID=$(cat "$DB_INSTANCE_FILE")
        DB_ENDPOINT=$(run_aws_cli rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" --region "$AWS_REGION" --query 'DBInstances[0].Endpoint.Address' --output text)
        export DB_ENDPOINT
        log_info "RDS endpoint: $DB_ENDPOINT"
    else
        log_error "No DB instance file found. Run find_or_create_rds_instance first."
        return 1
    fi
}