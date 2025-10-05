#!/usr/bin/env bash
# Security helpers: fix security groups and provide mixed-content proxy options

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

fix_security_groups() {
    log_info "Fixing security groups for ECS and RDS..."

    local sg_id
    sg_id=$(run_aws_cli ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=$APP_NAME-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")

    if [ -n "$sg_id" ] && [ "$sg_id" != "None" ]; then
    run_aws_cli ec2 authorize-security-group-ingress --group-id "$sg_id" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$AWS_REGION" 2>/dev/null || log_warn "Port 80 rule may already exist"
    run_aws_cli ec2 authorize-security-group-ingress --group-id "$sg_id" --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region "$AWS_REGION" 2>/dev/null || log_warn "Port 8080 rule may already exist"
        log_info "Updated ECS security group: $sg_id"
    else
        log_warn "ECS security group $APP_NAME-sg not found"
    fi

    if [ -f "$DB_INSTANCE_FILE" ]; then
        DB_INSTANCE_ID=$(cat "$DB_INSTANCE_FILE")
        local rds_sg
        rds_sg=$(run_aws_cli rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" --region "$AWS_REGION" --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text 2>/dev/null || echo "")
        if [ -n "$rds_sg" ] && [ -n "$sg_id" ]; then
            run_aws_cli ec2 authorize-security-group-ingress --group-id "$rds_sg" --protocol tcp --port 5432 --source-group "$sg_id" --region "$AWS_REGION" 2>/dev/null || log_warn "DB SG rule may already exist"
            log_info "Updated RDS security group: $rds_sg to allow $sg_id"
        fi
    fi
}

fix_mixed_content_free() {
    log_info "Creating local proxy for mixed content fixes in frontend (free)"
    for dir in "../../../frontend" "../../frontend" "../frontend" "./frontend"; do
        if [ -d "$dir" ]; then
            cd "$dir" || true
            mkdir -p api
            cat > api/proxy.js <<'EOF'
export default async function handler(req, res) {
    const { path, ...query } = req.query;
    const apiUrl = process.env.REACT_APP_API_URL || 'http://localhost:8080';
    const targetUrl = `${apiUrl}/${Array.isArray(path) ? path.join('/') : path || ''}`;

    try {
        const response = await fetch(targetUrl, {
            method: req.method,
            headers: {
                'Content-Type': 'application/json',
                ...req.headers
            },
            body: req.method !== 'GET' ? JSON.stringify(req.body) : undefined
        });

        const data = await response.json();
        res.status(response.status).json(data);
    } catch (error) {
        res.status(500).json({ error: 'Proxy error' });
    }
}
EOF
            log_info "Created proxy at $dir/api/proxy.js"
            return 0
        fi
    done
    log_warn "Frontend directory not found for mixed content proxy creation"
}

fix_mixed_content_netlify_proxy() {
    log_info "Setting up Netlify proxy (creates api/proxy.js in frontend)"
    fix_mixed_content_free
}
