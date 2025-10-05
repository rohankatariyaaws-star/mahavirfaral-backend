#!/usr/bin/env bash
# Test and helper functions: get service URL and test endpoints

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

get_service_url() {
    log_info "Retrieving service URL..."

    for i in $(seq 1 $RETRY_COUNT); do
    SERVICE_STATUS=$(run_aws_cli ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$AWS_REGION" --query 'services[0].status' --output text 2>/dev/null || echo "INACTIVE")
    RUNNING_COUNT=$(run_aws_cli ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$AWS_REGION" --query 'services[0].runningCount' --output text 2>/dev/null || echo "0")
        if [ "$SERVICE_STATUS" = "ACTIVE" ] && [ "$RUNNING_COUNT" -gt 0 ]; then
            log_info "Service running with $RUNNING_COUNT tasks"
            break
        fi
        log_info "Waiting for service (attempt $i/$RETRY_COUNT) Status: $SERVICE_STATUS, Running: $RUNNING_COUNT"
        sleep "$RETRY_SLEEP"
    done

    TASK_ARN=$(run_aws_cli ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --region "$AWS_REGION" --query 'taskArns[0]' --output text 2>/dev/null || echo "")
    if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
        ENI_ID=$(run_aws_cli ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --region "$AWS_REGION" --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
        PUBLIC_IP=$(run_aws_cli ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --region "$AWS_REGION" --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
        if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
            API_URL="http://$PUBLIC_IP:8080"
            log_info "Service URL: $API_URL"
            # Retry SSM updates to handle TooManyUpdates exceptions
            local put_attempt=0
            local put_max=5
            local put_sleep=2
            while [ $put_attempt -lt $put_max ]; do
                if run_aws_cli ssm put-parameter --name "ecommerce-api-url" --value "$API_URL" --type "String" --overwrite --region "$AWS_REGION"; then
                    break
                else
                    put_attempt=$((put_attempt+1))
                    log_warn "SSM put-parameter attempt $put_attempt failed (retrying in ${put_sleep}s)"
                    sleep $put_sleep
                    put_sleep=$((put_sleep*2))
                fi
            done
            if [ $put_attempt -ge $put_max ]; then
                log_warn "SSM put-parameter failed after $put_max attempts"
            fi
            echo "$API_URL"
            return 0
        fi
    fi
    log_warn "Could not determine public IP for service"
    return 1
}

test_deployment() {
    log_info "Testing deployment endpoints"
    local api_url
    api_url=$(get_service_url) || { log_error "Service URL not available"; return 1; }
    log_info "Testing /health"
    curl -s "$api_url/health" || log_warn "Health endpoint not reachable yet"
    log_info "Testing /api/products/all"
    curl -s "$api_url/api/products/all" || log_warn "Products endpoint not reachable yet"
}

test_netlify_proxy() {
    log_info "Testing Netlify proxy: fetching /api/health via site URL"
    if [ -z "$NETLIFY_SITE_URL" ]; then
        log_warn "NETLIFY_SITE_URL not set. Provide the published Netlify site URL (e.g. https://your-site.netlify.app) in .env as NETLIFY_SITE_URL"
        return 1
    fi
    # Ensure we use https
    site_url="$NETLIFY_SITE_URL"
    if [[ "$site_url" != https:* ]]; then
        log_warn "NETLIFY_SITE_URL should be HTTPS to avoid mixed-content; using provided value"
    fi
    health=$(curl -s -o /dev/null -w "%{http_code}" "$site_url/api/health" ) || health=000
    if [ "$health" = "200" ]; then
        log_info "Proxy test passed: $site_url/api/health returned 200"
    else
        log_warn "Proxy test failed: $site_url/api/health returned HTTP $health"
    fi
}
