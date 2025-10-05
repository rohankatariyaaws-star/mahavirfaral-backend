#!/usr/bin/env bash
# Netlify deployment helper: update BACKEND_API_URL and trigger Netlify build

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

deploy_netlify() {
    log_info "Configuring Netlify deployment and triggering build"

    # Enforce NETLIFY_PROXY_API
    if [ "${NETLIFY_PROXY_API:-}" != "true" ]; then
        log_error "NETLIFY_PROXY_API must be set to 'true' to enable proxy configuration"
        return 1
    fi

    # Retrieve API URL from SSM
    API_URL=""
    API_URL=$(run_aws_cli ssm get-parameter --name "ecommerce-api-url" --region "$AWS_REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    if [ -z "$API_URL" ]; then
        log_error "Failed to retrieve BACKEND_API_URL from SSM"
        return 1
    fi
    log_info "BACKEND_API_URL set to $API_URL"

    # Set BACKEND_API_URL in Netlify
    if [ -n "$NETLIFY_TOKEN" ] && [ -n "$NETLIFY_SITE_ID" ] && [ -n "$NETLIFY_ACCOUNT_ID" ] && [ -n "$API_URL" ]; then
        log_info "Ensuring Netlify BACKEND_API_URL is set"
        netlify_set_env "BACKEND_API_URL" "$API_URL" || {
            log_error "Failed to set BACKEND_API_URL in Netlify"
            return 1
        }
    else
        log_error "Netlify credentials or API_URL missing"
        return 1
    fi

    # Trigger Netlify build hook
    if [ -n "$NETLIFY_BUILD_HOOK" ]; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$NETLIFY_BUILD_HOOK") || HTTP_CODE="000"
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
            log_info "Netlify build hook triggered (HTTP $HTTP_CODE)"
            return 0
        else
            log_error "Netlify build hook failed (HTTP $HTTP_CODE)"
            return 1
        fi
    else
        log_error "NETLIFY_BUILD_HOOK not set; cannot trigger Netlify build"
        return 1
    fi
}

netlify_set_env() {
    local key="$1"; shift
    local value="$1"; shift

    if [ -z "$NETLIFY_TOKEN" ] || [ -z "$NETLIFY_SITE_ID" ] || [ -z "$NETLIFY_ACCOUNT_ID" ]; then
        log_error "Netlify credentials missing (NETLIFY_TOKEN, NETLIFY_SITE_ID, NETLIFY_ACCOUNT_ID)"
        return 1
    fi

    log_info "Ensuring Netlify env var $key is set to $value"
    local env_base_url="https://api.netlify.com/api/v1/accounts/$NETLIFY_ACCOUNT_ID/env"
    local site_query="?site_id=$NETLIFY_SITE_ID"

    local check_url="$env_base_url/$key$site_query"
    local resp
    resp=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $NETLIFY_TOKEN" "$check_url") || resp="\n000"
    local code=$(echo "$resp" | tail -n1)
    local body=$(echo "$resp" | sed '$d')
    local exists=false
    if [ "$code" = "200" ]; then
        exists=true
        log_info "Netlify env var $key exists"
    elif [ "$code" = "404" ]; then
        log_info "Netlify env var $key does not exist"
    else
        log_error "Failed to check Netlify env var $key (HTTP $code). Response: $body"
        return 1
    fi

    local payload
    payload=$(printf '{"key":"%s","scopes":["builds","functions","post_processing","runtime"],"values":[{"context":"all","value":"%s"}],"is_secret":false}' "$key" "$value")
    if $exists; then
        log_info "Updating existing Netlify env var $key"
        resp=$(curl -s -w "\n%{http_code}" -X PUT "$env_base_url/$key$site_query" -H "Authorization: Bearer $NETLIFY_TOKEN" -H "Content-Type: application/json" -d "$payload") || resp="\n000"
        code=$(echo "$resp" | tail -n1)
        body=$(echo "$resp" | sed '$d')
        if [ "$code" = "200" ]; then
            log_info "Netlify env var $key updated"
        else
            log_error "Failed to update Netlify env var $key (HTTP $code). Response: $body"
            return 1
        fi
    else
        log_info "Creating new Netlify env var $key"
        resp=$(curl -s -w "\n%{http_code}" -X POST "$env_base_url$site_query" -H "Authorization: Bearer $NETLIFY_TOKEN" -H "Content-Type: application/json" -d "[$payload]") || resp="\n000"
        code=$(echo "$resp" | tail -n1)
        body=$(echo "$resp" | sed '$d')
        if [ "$code" = "201" ] || [ "$code" = "200" ]; then
            log_info "Netlify env var $key created"
        else
            log_error "Failed to create Netlify env var $key (HTTP $code). Response: $body"
            return 1
        fi
    fi
}