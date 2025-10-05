#!/usr/bin/env bash
# Docker build & ECR push with hashing to avoid unnecessary builds

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

build_docker_image() {
    log_info "Building Docker image for backend..."

    # Locate backend dir relative to script
    local backend_dir
    for dir in "../../../backend" "../../backend" "../backend" "./backend" "$PWD/backend"; do
        if [ -d "$dir" ]; then
            backend_dir="$dir"
            break
        fi
    done
    if [ -z "$backend_dir" ]; then
        log_error "Backend directory not found"
        return 1
    fi

    pushd "$backend_dir" > /dev/null || return 1

    # Determine source hash
    local SOURCE_HASH
    SOURCE_HASH=$(compute_hash_for_dir "src" || echo "new")
    local LAST_HASH=""
    if [ -f "$DOCKER_HASH_FILE" ]; then
        LAST_HASH=$(cat "$DOCKER_HASH_FILE" || echo "")
    fi

    if [ "$SOURCE_HASH" = "$LAST_HASH" ] && [ -f "target/*.jar" ]; then
        log_info "No backend changes detected; skipping rebuild"
    else
        log_info "Changes detected or build missing; building JAR"
        if have_cmd mvn; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "Dry-run: skipping mvn package"
            else
                mvn clean package -DskipTests -Dmaven.javadoc.skip=true -Dmaven.source.skip=true
            fi
        else
            log_warn "Maven not found; cannot build backend JAR"
        fi

        # Write Dockerfile
        cat > Dockerfile <<'EOF'
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
RUN apk add --no-cache curl
COPY target/*.jar app.jar
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
ENTRYPOINT ["java","-jar","app.jar"]
EOF

        # ECR operations
    local ACCOUNT_ID
    ACCOUNT_ID=$(run_aws_cli sts get-caller-identity --query Account --output text)
    local ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
    run_aws_cli ecr create-repository --repository-name "$APP_NAME" --region "$AWS_REGION" 2>/dev/null || true

    run_aws_cli ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REPO"

        # Clear cache
        docker system prune -f 2>/dev/null || true
        docker builder prune -f 2>/dev/null || true

        docker build --no-cache -t "$APP_NAME" .
        docker tag "$APP_NAME:latest" "$ECR_REPO:latest"
        if [ "$DRY_RUN" = "true" ]; then
            log_info "Dry-run: skipping docker push"
        else
            docker push "$ECR_REPO:latest"
        fi

        echo "$SOURCE_HASH" > "$DOCKER_HASH_FILE"
        echo "ECR_REPO=$ECR_REPO" > "$ECR_INFO_FILE"
    fi

    popd > /dev/null || true
    log_info "Docker/ECR operations complete"
}
