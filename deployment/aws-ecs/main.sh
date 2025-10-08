#!/usr/bin/env bash
# Orchestrator script for AWS ECS deployment modules
# Presents menu and calls module functions

set -euo pipefail

# Load core libraries
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/dependencies.sh"

# Source modules lazily when needed
MODULE_DIR="$(dirname "${BASH_SOURCE[0]}")"

show_menu() {
    cat <<EOF
Complete ECS Fargate Deployment Options:
1) Full deployment (RDS + ECS + Netlify + Database Setup + Scheduled Scaling)
2) Backend only (RDS + ECS + Database Setup + Scheduled Scaling)
3) Frontend only (Netlify build trigger)
4) Scheduler only (Scaling + Lambda IP updater)
5) Fix mixed content issues (FREE solutions)
6) Fix security groups only
7) Fix mixed content issues (Netlify proxy)
8) Test current deployment
9) Update Netlify with current ECS IP
10) Lambda smoke test (invoke + verify Netlify env and deploy)
11) Netlify credentials check
0) Exit
EOF
}

read_choice() {
    read -p "Choice (0-9): " choice
    echo "$choice"
}

main() {
    if ! check_common_deps; then
        log_error "Missing critical dependencies. Install AWS CLI and Docker and retry."
        exit 1
    fi

    show_menu
    choice=$(read_choice)

    case "$choice" in
        1)
            source "$MODULE_DIR/rds.sh"
            source "$MODULE_DIR/db_schema.sh"
            source "$MODULE_DIR/docker_build.sh"
            source "$MODULE_DIR/ecs_cluster.sh"
            source "$MODULE_DIR/task_def.sh"
            source "$MODULE_DIR/security.sh"
            source "$MODULE_DIR/ecs_service.sh"
            source "$MODULE_DIR/scaling.sh"
            source "$MODULE_DIR/lambda.sh"
            source "$MODULE_DIR/netlify.sh"
            source "$MODULE_DIR/test.sh"

            find_or_create_rds_instance
            create_database_schema
            build_docker_image
            create_ecs_cluster
            create_task_definition
            fix_security_groups
            create_ecs_service
            create_scheduled_scaling
            create_lambda_ip_updater
            setup_netlify_credentials
            get_service_url
            trigger_initial_setup
            deploy_netlify
            ;;
        2)
            source "$MODULE_DIR/rds.sh"
            source "$MODULE_DIR/db_schema.sh"
            source "$MODULE_DIR/docker_build.sh"
            source "$MODULE_DIR/ecs_cluster.sh"
            source "$MODULE_DIR/task_def.sh"
            source "$MODULE_DIR/security.sh"
            source "$MODULE_DIR/ecs_service.sh"
            source "$MODULE_DIR/scaling.sh"

            source "$MODULE_DIR/lambda.sh"
            source "$MODULE_DIR/test.sh"

            find_or_create_rds_instance
            create_database_schema
            build_docker_image
            create_ecs_cluster
            create_task_definition
            fix_security_groups
            create_ecs_service
            create_scheduled_scaling
            create_lambda_ip_updater
            setup_netlify_credentials
            get_service_url
            ;;
        3)
            source "$MODULE_DIR/lambda.sh"
            source "$MODULE_DIR/netlify.sh"
            setup_netlify_credentials
            trigger_initial_setup
            deploy_netlify
            ;;
        4)
            source "$MODULE_DIR/scaling.sh"
            source "$MODULE_DIR/lambda.sh"
            deploy_scheduler_only
            setup_netlify_credentials
            ;;
        5)
            source "$MODULE_DIR/security.sh"
            fix_mixed_content_free
            ;;
        6)
            source "$MODULE_DIR/security.sh"
            fix_security_groups
            ;;
        7)
            source "$MODULE_DIR/security.sh"
            fix_mixed_content_netlify_proxy
            ;;
        8)
            source "$MODULE_DIR/test.sh"
            test_deployment
            ;;
        9)
            source "$MODULE_DIR/lambda.sh"
            update_netlify_ip
            ;;
        10)
            source "$MODULE_DIR/lambda.sh"
            lambda_test
            ;;
        11)
            source "$MODULE_DIR/netlify.sh"
            netlify_check_credentials
            ;;
        0)
            log_info "Exit requested"
            exit 0
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac

    log_info "Done"
}

main "$@"
