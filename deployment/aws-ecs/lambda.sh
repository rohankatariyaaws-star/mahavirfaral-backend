#!/usr/bin/env bash
# Lambda function to update SSM and Netlify when ECS IP changes

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

create_lambda_ip_updater() {
    log_info "Creating/updating Lambda IP updater"

    local LAMBDA_ROLE_NAME="$APP_NAME-lambda-role"
    if ! run_aws_cli iam get-role --role-name "$LAMBDA_ROLE_NAME" &> /dev/null; then
        run_aws_cli iam create-role --role-name "$LAMBDA_ROLE_NAME" --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
        run_aws_cli iam attach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole || true
        run_aws_cli iam attach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess || true
        run_aws_cli iam attach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess || true
        run_aws_cli iam attach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess || true
        run_aws_cli iam attach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess || true
        run_aws_cli iam attach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess || true
        sleep 10
    fi

    local LAMBDA_ROLE_ARN
    LAMBDA_ROLE_ARN=$(run_aws_cli iam get-role --role-name "$LAMBDA_ROLE_NAME" --query 'Role.Arn' --output text)

    # Create inline python file
    cat > lambda_ip_updater.py <<'EOF'
import json
import boto3
import urllib.request
import urllib.error
import os
import time
import traceback

def _request_with_retries(url, data=None, headers=None, method='GET', max_tries=3, timeout=10):
    attempt = 0
    last_exc = None
    response_body = None
    while attempt < max_tries:
        try:
            print(f'Sending {method} request to URL: {url}')
            if data:
                print(f'Request payload: {data.decode("utf-8", errors="replace")}')
            req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                code = getattr(r, 'status', None) or r.getcode()
                response_body = r.read().decode('utf-8', errors='replace') if method != 'DELETE' else ''
                print(f'Received response code: {code}, body: {response_body[:4000]}')
                if 200 <= int(code) < 300:
                    return True, int(code), response_body
                else:
                    last_exc = Exception(f'HTTP {code}: {response_body}')
        except Exception as e:
            if isinstance(e, urllib.error.HTTPError):
                try:
                    response_body = e.read().decode('utf-8', errors='replace')
                except Exception:
                    response_body = str(e)
                last_exc = Exception(f'HTTPError {e.code}: {response_body}')
            else:
                last_exc = e
            print(f'Attempt {attempt + 1} failed: {last_exc}')
        attempt += 1
        time.sleep(2 ** attempt)
    return False, last_exc, response_body

def lambda_handler(event, context):
    try:
        print('Lambda invoked. Event:', json.dumps(event)[:2000])
        print('Lambda env keys:', list(os.environ.keys()))
        region = os.environ.get('LAMBDA_REGION', 'ap-south-1')
        ecs = boto3.client('ecs', region_name=region)
        ssm = boto3.client('ssm', region_name=region)
        ec2 = boto3.client('ec2', region_name=region)

        detail = event.get('detail', {})
        cluster_arn = detail.get('clusterArn', '')
        task_arn = detail.get('taskArn', '')
        last_status = detail.get('lastStatus', '')

        print(f'detail cluster_arn={cluster_arn} task_arn={task_arn} last_status={last_status}')

        # If event didn't include a running taskArn, try to discover one
        if not task_arn:
            service_name = os.environ.get('SERVICE_NAME')
            cluster_for_list = cluster_arn if cluster_arn else os.environ.get('CLUSTER_NAME')
            print('No task_arn in event; trying to list tasks', {'service_name': service_name, 'cluster': cluster_for_list})
            if service_name and cluster_for_list:
                try:
                    list_resp = ecs.list_tasks(cluster=cluster_for_list, serviceName=service_name, desiredStatus='RUNNING', maxResults=1)
                    task_arns = list_resp.get('taskArns', [])
                    if task_arns:
                        task_arn = task_arns[0]
                        print('Discovered task_arn:', task_arn)
                except Exception as e:
                    print('list_tasks failed:', e)

        if not task_arn:
            print('No taskArn available to describe; exiting')
            return {'statusCode': 400, 'body': 'No taskArn available to describe'}

        if last_status and last_status != 'RUNNING':
            print('Task not running according to event last_status; exiting')
            return {'statusCode': 200, 'body': 'Task not running'}

        response = ecs.describe_tasks(cluster=cluster_arn or os.environ.get('CLUSTER_NAME'), tasks=[task_arn])
        if not response.get('tasks'):
            print('describe_tasks returned no tasks for', task_arn)
            return {'statusCode': 404, 'body': 'Task not found'}

        task = response['tasks'][0]
        eni_id = None
        for attachment in task.get('attachments', []):
            for d in attachment.get('details', []):
                if d.get('name') == 'networkInterfaceId':
                    eni_id = d.get('value')
        if not eni_id:
            print('ENI not found in task attachments')
            return {'statusCode': 404, 'body': 'ENI not found'}

        response = ec2.describe_network_interfaces(NetworkInterfaceIds=[eni_id])
        if not response.get('NetworkInterfaces'):
            print('Network interfaces not found for eni', eni_id)
            return {'statusCode': 404, 'body': 'NI not found'}
        public_ip = response['NetworkInterfaces'][0].get('Association', {}).get('PublicIp')
        if not public_ip:
            print('Public IP not found for eni', eni_id)
            return {'statusCode': 404, 'body': 'Public IP not found'}

        new_api_url = f"http://{public_ip}:8080"
        print('Determined new_api_url:', new_api_url)
        try:
            current_url = ssm.get_parameter(Name='ecommerce-api-url')['Parameter']['Value']
        except Exception:
            current_url = ''
        print('Current SSM api url:', current_url)
        if new_api_url == current_url:
            print('SSM already has same API URL; skipping SSM put but will ensure Netlify env is updated')
            ssm_changed = False
        else:
            ssm.put_parameter(Name='ecommerce-api-url', Value=new_api_url, Type='String', Overwrite=True)
            print('Updated SSM ecommerce-api-url')
            ssm_changed = True

        netlify_token = os.environ.get('NETLIFY_TOKEN')
        netlify_site_id = os.environ.get('NETLIFY_SITE_ID')
        netlify_account_id = os.environ.get('NETLIFY_ACCOUNT_ID')
        netlify_build_hook = os.environ.get('NETLIFY_BUILD_HOOK')

        if not (netlify_token and netlify_site_id and netlify_account_id):
            error_msg = f'Missing Netlify credentials: token={bool(netlify_token)}, site_id={bool(netlify_site_id)}, account_id={bool(netlify_account_id)}'
            print(error_msg)
            return {'statusCode': 400, 'body': error_msg}

        headers = {'Authorization': f'Bearer {netlify_token}', 'Content-Type': 'application/json'}
        key = 'REACT_APP_API_URL'
        env_base_url = f'https://api.netlify.com/api/v1/accounts/{netlify_account_id}/env'
        site_query = f'?site_id={netlify_site_id}'

        # Check if variable exists
        check_url = f'{env_base_url}/{key}{site_query}'
        print(f'Checking if env var exists: {check_url}')
        exists = False
        try:
            ok, code, body = _request_with_retries(check_url, headers=headers, method='GET')
            if ok:
                print('Environment variable exists')
                exists = True
            elif code and 'HTTPError 404' in str(code):
                print('Environment variable does not exist')
            else:
                print(f'Unexpected response checking env var: {code}')
                return {'statusCode': 500, 'body': f'Failed to check env var: {str(code)}'}
        except Exception as check_e:
            print('Failed to check env var existence:', str(check_e), traceback.format_exc())
            return {'statusCode': 500, 'body': f'Failed to check env var: {str(check_e)}'}

        # Prepare payload
        payload = {
            'key': key,
            'scopes': ['builds', 'functions', 'post_processing', 'runtime'],
            'values': [{'context': 'all', 'value': new_api_url}],
            'is_secret': False
        }

        if exists:
            # Update existing variable
            update_url = f'{env_base_url}/{key}{site_query}'
            data = json.dumps(payload).encode('utf-8')
            print(f'Updating existing env var at: {update_url}')
            ok, resp_code, resp_body = _request_with_retries(update_url, data=data, headers=headers, method='PUT')
        else:
            # Create new variable
            create_url = f'{env_base_url}{site_query}'
            data = json.dumps([payload]).encode('utf-8')  # POST expects an array
            print(f'Creating new env var at: {create_url}')
            ok, resp_code, resp_body = _request_with_retries(create_url, data=data, headers=headers, method='POST')

        if not ok:
            print('Netlify env update failed:', str(resp_code))
            return {'statusCode': 500, 'body': f'Netlify env update failed: {str(resp_code)}'}
        else:
            print('Netlify env update successful, code:', resp_code)
            # Post-update GET to verify
            list_url = f'{env_base_url}{site_query}'
            try:
                ok, code, body = _request_with_retries(list_url, headers=headers, method='GET')
                if ok:
                    print('Netlify env list response:', body[:4000])
                else:
                    print('Netlify env GET failed after update:', str(code))
            except Exception as eget:
                print('Netlify env GET failed after update:', str(eget), traceback.format_exc())

            if netlify_build_hook:
                print(f'Triggering build hook: {netlify_build_hook}')
                ok2, resp2, _ = _request_with_retries(netlify_build_hook, data=None, headers=None, method='POST')
                if not ok2:
                    print('Netlify build hook trigger failed:', str(resp2))
                else:
                    print('Netlify build hook triggered successfully')

        return {'statusCode': 200, 'body': 'Updated'}
    except Exception as exc:
        print('Unhandled exception in lambda_handler:', str(exc), traceback.format_exc())
        return {'statusCode': 500, 'body': str(exc)}
EOF

    # Package
    if have_cmd zip; then
        zip -r lambda_ip_updater.zip lambda_ip_updater.py
    else
        powershell -Command "Compress-Archive -Path lambda_ip_updater.py -DestinationPath lambda_ip_updater.zip -Force"
    fi

    if run_aws_cli lambda get-function --function-name "$APP_NAME-ip-updater" --region "$AWS_REGION" &> /dev/null; then
        log_info "Updating existing lambda"
        run_aws_cli lambda update-function-code --function-name "$APP_NAME-ip-updater" --zip-file fileb://lambda_ip_updater.zip --region "$AWS_REGION"
        ENV_FILE=$(create_tmp_file "lambda-env-XXXX.json")
        printf '{"Variables":{' > "$ENV_FILE"
        printf '"LAMBDA_REGION":"%s","CLUSTER_NAME":"%s","SERVICE_NAME":"%s","APP_NAME":"%s"' "$AWS_REGION" "$CLUSTER_NAME" "$SERVICE_NAME" "$APP_NAME" >> "$ENV_FILE"
        if [ -n "$NETLIFY_TOKEN" ]; then printf ',"NETLIFY_TOKEN":"%s"' "$NETLIFY_TOKEN" >> "$ENV_FILE"; fi
        if [ -n "$NETLIFY_SITE_ID" ]; then printf ',"NETLIFY_SITE_ID":"%s"' "$NETLIFY_SITE_ID" >> "$ENV_FILE"; fi
        if [ -n "$NETLIFY_BUILD_HOOK" ]; then printf ',"NETLIFY_BUILD_HOOK":"%s"' "$NETLIFY_BUILD_HOOK" >> "$ENV_FILE"; fi
        if [ -n "$NETLIFY_ACCOUNT_ID" ]; then printf ',"NETLIFY_ACCOUNT_ID":"%s"' "$NETLIFY_ACCOUNT_ID" >> "$ENV_FILE"; fi
        printf '}}' >> "$ENV_FILE"
        run_aws_cli lambda update-function-configuration --function-name "$APP_NAME-ip-updater" --handler lambda_ip_updater.lambda_handler --timeout 300 --memory-size 256 --environment file://$ENV_FILE --region "$AWS_REGION"
        # ENV_FILE will be removed by cleanup_tmp on exit
    else
        log_info "Creating new lambda function"
        ENV_FILE=$(create_tmp_file "lambda-env-XXXX.json")
        printf '{"Variables":{' > "$ENV_FILE"
        printf '"LAMBDA_REGION":"%s","CLUSTER_NAME":"%s","SERVICE_NAME":"%s","APP_NAME":"%s"' "$AWS_REGION" "$CLUSTER_NAME" "$SERVICE_NAME" "$APP_NAME" >> "$ENV_FILE"
        if [ -n "$NETLIFY_TOKEN" ]; then printf ',"NETLIFY_TOKEN":"%s"' "$NETLIFY_TOKEN" >> "$ENV_FILE"; fi
        if [ -n "$NETLIFY_SITE_ID" ]; then printf ',"NETLIFY_SITE_ID":"%s"' "$NETLIFY_SITE_ID" >> "$ENV_FILE"; fi
        if [ -n "$NETLIFY_BUILD_HOOK" ]; then printf ',"NETLIFY_BUILD_HOOK":"%s"' "$NETLIFY_BUILD_HOOK" >> "$ENV_FILE"; fi
        if [ -n "$NETLIFY_ACCOUNT_ID" ]; then printf ',"NETLIFY_ACCOUNT_ID":"%s"' "$NETLIFY_ACCOUNT_ID" >> "$ENV_FILE"; fi
        printf '}}' >> "$ENV_FILE"
        run_aws_cli lambda create-function --function-name "$APP_NAME-ip-updater" --runtime python3.9 --role "$LAMBDA_ROLE_ARN" --handler lambda_ip_updater.lambda_handler --zip-file fileb://lambda_ip_updater.zip --timeout 300 --memory-size 256 --environment file://$ENV_FILE --region "$AWS_REGION"
    fi

    # EventBridge rule
    run_aws_cli events put-rule --name "$APP_NAME-task-state-rule" --event-pattern "{\"source\":[\"aws.ecs\"],\"detail-type\":[\"ECS Task State Change\"],\"detail\":{\"clusterArn\":[\"arn:aws:ecs:$AWS_REGION:$(run_aws_cli sts get-caller-identity --query Account --output text):cluster/$CLUSTER_NAME\"],\"lastStatus\":[\"RUNNING\"]}}" --region "$AWS_REGION" 2>/dev/null || true

    run_aws_cli lambda add-permission --function-name "$APP_NAME-ip-updater" --statement-id allow-eventbridge --action lambda:InvokeFunction --principal events.amazonaws.com --source-arn arn:aws:events:$AWS_REGION:$(run_aws_cli sts get-caller-identity --query Account --output text):rule/$APP_NAME-task-state-rule --region "$AWS_REGION" 2>/dev/null || true

    run_aws_cli events put-targets --rule "$APP_NAME-task-state-rule" --targets "Id=1,Arn=arn:aws:lambda:$AWS_REGION:$(run_aws_cli sts get-caller-identity --query Account --output text):function:$APP_NAME-ip-updater" --region "$AWS_REGION" 2>/dev/null || true

    rm -f lambda_ip_updater.py lambda_ip_updater.zip
    log_info "Lambda IP updater configured"
}

setup_netlify_credentials() {
    if [ -z "$NETLIFY_TOKEN" ] || [ -z "$NETLIFY_SITE_ID" ] || [ -z "$NETLIFY_ACCOUNT_ID" ]; then
        log_warn "Netlify credentials (NETLIFY_TOKEN, NETLIFY_SITE_ID, NETLIFY_ACCOUNT_ID) not provided. Skipping Netlify wiring."
        return 0
    fi
    # Update existing lambda env if exists
    if run_aws_cli lambda get-function --function-name "$APP_NAME-ip-updater" --region "$AWS_REGION" &> /dev/null; then
        ENV_FILE=$(create_tmp_file "lambda-env-XXXX.json")
        printf '{"Variables":{' > "$ENV_FILE"
        printf '"LAMBDA_REGION":"%s","CLUSTER_NAME":"%s","SERVICE_NAME":"%s","APP_NAME":"%s","NETLIFY_TOKEN":"%s","NETLIFY_SITE_ID":"%s","NETLIFY_ACCOUNT_ID":"%s"' "$AWS_REGION" "$CLUSTER_NAME" "$SERVICE_NAME" "$APP_NAME" "$NETLIFY_TOKEN" "$NETLIFY_SITE_ID" "$NETLIFY_ACCOUNT_ID" >> "$ENV_FILE"
        if [ -n "$NETLIFY_BUILD_HOOK" ]; then printf ',"NETLIFY_BUILD_HOOK":"%s"' "$NETLIFY_BUILD_HOOK" >> "$ENV_FILE"; fi
        printf '}}' >> "$ENV_FILE"
        run_aws_cli lambda update-function-configuration --function-name "$APP_NAME-ip-updater" --environment file://$ENV_FILE --region "$AWS_REGION"
        log_info "Lambda updated with Netlify credentials"
    else
        log_warn "Lambda not created yet. Credentials will be added when lambda is created."
    fi
}

update_netlify_ip() {
    log_info "Triggering lambda to update Netlify with current ECS IP"
    if run_aws_cli lambda get-function --function-name "$APP_NAME-ip-updater" --region "$AWS_REGION" &> /dev/null; then
        TASK_ARN=$(run_aws_cli ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --region "$AWS_REGION" --query 'taskArns[0]' --output text 2>/dev/null || echo "")
        if [ -n "$TASK_ARN" ]; then
            TEST_EVENT_FILE=$(create_tmp_file "test-event-XXXX.json")
            ACCOUNT_ID=$(run_aws_cli sts get-caller-identity --query Account --output text)
            cat > "$TEST_EVENT_FILE" <<EOF
{ "detail": { "clusterArn": "arn:aws:ecs:$AWS_REGION:$ACCOUNT_ID:cluster/$CLUSTER_NAME", "taskArn": "$TASK_ARN", "lastStatus": "RUNNING" } }
EOF
            LAMBDA_OUTPUT=$(create_tmp_file "lambda-response-XXXX.json")
            : > "$LAMBDA_OUTPUT" 2>/dev/null || true
            run_aws_cli lambda invoke --function-name "$APP_NAME-ip-updater" --payload fileb://"$TEST_EVENT_FILE" --region "$AWS_REGION" "$LAMBDA_OUTPUT" || true

            if [ -f "$LAMBDA_OUTPUT" ]; then
                cat "$LAMBDA_OUTPUT" || true
            else
                if have_cmd cygpath; then
                    WINPATH=$(cygpath -w "$LAMBDA_OUTPUT" 2>/dev/null || echo "")
                    if [ -n "$WINPATH" ]; then
                        if powershell -NoProfile -Command "Test-Path -Path '$WINPATH'" >/dev/null 2>&1; then
                            powershell -NoProfile -Command "Get-Content -Raw -Path '$WINPATH'" || true
                        fi
                    fi
                fi
            fi
        else
            log_warn "No running tasks found to populate IP"
        fi
    else
        log_error "Lambda $APP_NAME-ip-updater not found"
    fi
}

lambda_test() {
    log_info "Running lambda smoke test: invoke lambda and verify Netlify env + build"
    if ! run_aws_cli lambda get-function --function-name "$APP_NAME-ip-updater" --region "$AWS_REGION" &> /dev/null; then
        log_error "Lambda $APP_NAME-ip-updater not found"
        return 1
    fi

    TEST_EVENT_FILE=$(create_tmp_file "test-event-XXXX.json")
    ACCOUNT_ID=$(run_aws_cli sts get-caller-identity --query Account --output text)
    cat > "$TEST_EVENT_FILE" <<EOF
{ "detail": { "clusterArn": "arn:aws:ecs:$AWS_REGION:$ACCOUNT_ID:cluster/$CLUSTER_NAME", "taskArn": "", "lastStatus": "RUNNING" } }
EOF
    LAMBDA_OUTPUT=$(create_tmp_file "lambda-response-XXXX.json")
    : > "$LAMBDA_OUTPUT" 2>/dev/null || true
    run_aws_cli lambda invoke --function-name "$APP_NAME-ip-updater" --payload fileb://"$TEST_EVENT_FILE" --region "$AWS_REGION" "$LAMBDA_OUTPUT" || true

    sleep 3

    if [ -n "$NETLIFY_TOKEN" ] && [ -n "$NETLIFY_SITE_ID" ] && [ -n "$NETLIFY_ACCOUNT_ID" ]; then
        if have_cmd jq; then
            val=$(curl -s -H "Authorization: Bearer $NETLIFY_TOKEN" "https://api.netlify.com/api/v1/accounts/$NETLIFY_ACCOUNT_ID/env?site_id=$NETLIFY_SITE_ID" | jq -r '.[] | select(.key=="REACT_APP_API_URL") | .values[].value' 2>/dev/null || echo "")
        else
            val=$(curl -s -H "Authorization: Bearer $NETLIFY_TOKEN" "https://api.netlify.com/api/v1/accounts/$NETLIFY_ACCOUNT_ID/env?site_id=$NETLIFY_SITE_ID" | grep -oP '"key"\s*:\s*"REACT_APP_API_URL".*?"value"\s*:\s*"\K[^"]+' || echo "")
        fi
        if [ -n "$val" ]; then
            log_info "Netlify REACT_APP_API_URL = $val"
        else
            log_warn "Netlify REACT_APP_API_URL not found after lambda invocation"
        fi
    else
        log_warn "Netlify credentials not provided; cannot verify Netlify env"
    fi

    ssm_val=$(run_aws_cli ssm get-parameter --name "ecommerce-api-url" --region "$AWS_REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    if [ -n "$ssm_val" ]; then
        log_info "SSM ecommerce-api-url = $ssm_val"
    else
        log_warn "SSM ecommerce-api-url not found after lambda invocation"
    fi

    if [ -n "$NETLIFY_TOKEN" ] && [ -n "$NETLIFY_SITE_ID" ]; then
        pre_deploy_ts=$(curl -s -H "Authorization: Bearer $NETLIFY_TOKEN" "https://api.netlify.com/api/v1/sites/$NETLIFY_SITE_ID/deploys?per_page=1" | (have_cmd jq && jq -r '.[0].created_at' || sed -n 's/.*"created_at"\s*:\s*"\([^"]*\)".*/\1/p'))

        if [ -n "$NETLIFY_BUILD_HOOK" ]; then
            log_info "Build hook configured; polling for new Netlify deploy (timeout 60s)"
            start_ts=$(date +%s)
            timeout_sec=60
            found=0
            while [ $(( $(date +%s) - start_ts )) -lt $timeout_sec ]; do
                sleep 3
                latest=$(curl -s -H "Authorization: Bearer $NETLIFY_TOKEN" "https://api.netlify.com/api/v1/sites/$NETLIFY_SITE_ID/deploys?per_page=1")
                latest_ts=$(echo "$latest" | (have_cmd jq && jq -r '.[0].created_at' || sed -n 's/.*"created_at"\s*:\s*"\([^"]*\)".*/\1/p'))
                if [ -n "$latest_ts" ] && [ "$latest_ts" != "$pre_deploy_ts" ]; then
                    log_info "Detected new Netlify deploy at $latest_ts"
                    found=1
                    break
                fi
            done
            if [ $found -eq 0 ]; then
                log_warn "No new Netlify deploy detected within ${timeout_sec}s after invoking lambda/build hook"
            fi
        else
            deploys=$(curl -s -H "Authorization: Bearer $NETLIFY_TOKEN" "https://api.netlify.com/api/v1/sites/$NETLIFY_SITE_ID/deploys?per_page=1")
            if [ -n "$deploys" ]; then
                if have_cmd jq; then
                    status=$(echo "$deploys" | jq -r '.[0].state' 2>/dev/null || echo "")
                else
                    status=$(echo "$deploys" | grep -oP '"state"\s*:\s*"\K[^"]+' || echo "")
                fi
                log_info "Latest Netlify deploy state: $status"
            fi
        fi
    fi
}