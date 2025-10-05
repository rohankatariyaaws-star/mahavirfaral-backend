#!/usr/bin/env bash
# Database schema initialization using a temporary ECS task with postgres image or psql via docker

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/rds.sh"

create_database_schema() {
    log_info "Creating database schema..."

    if [ -f "$DB_INSTANCE_FILE" ]; then
        DB_INSTANCE_ID=$(cat "$DB_INSTANCE_FILE")
    else
        log_error "DB instance ID not found in $DB_INSTANCE_FILE"
        return 1
    fi

    DB_ENDPOINT=$(run_aws_cli rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" --region "$AWS_REGION" --query 'DBInstances[0].Endpoint.Address' --output text)
    log_info "DB endpoint: $DB_ENDPOINT"

    # Create init SQL
    cat > init-database.sql <<'EOF'
-- Create database if not exists
CREATE DATABASE ecommerce_db;

-- Connect to the database
\c ecommerce_db;

-- Create admin user table
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255),
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'USER',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert admin
INSERT INTO users (name, phone_number, email, password, role) 
VALUES ('Administrator', '+1234567890', 'admin@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'ADMIN')
ON CONFLICT (phone_number) DO NOTHING;
EOF

    TMP_SQL=$(create_tmp_file "init-db-XXXX.sql")
    mv init-database.sql "$TMP_SQL"


    # Prefer running psql inside a short-lived docker container
    if have_cmd docker; then
        log_info "Running DB init via postgres docker container"
        if [ "$DRY_RUN" = "true" ]; then
            log_info "Dry-run: skipping actual psql execution"
            return 0
        fi

    docker run --rm -v "$TMP_SQL":/tmp/init-database.sql postgres:15 sh -c "PGPASSWORD='$DB_PASSWORD' psql -h '$DB_ENDPOINT' -U '$DB_USERNAME' -d postgres -tc \"SELECT 1 FROM pg_database WHERE datname='ecommerce_db'\" | grep -q 1 || PGPASSWORD='$DB_PASSWORD' psql -h '$DB_ENDPOINT' -U '$DB_USERNAME' -d postgres -f /tmp/init-database.sql"
    else
        log_warn "Docker not available, attempting to run psql if installed locally"
        if have_cmd psql; then
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_ENDPOINT" -U "$DB_USERNAME" -d postgres -f "$TMP_SQL"
        else
            log_error "No mechanism available to run SQL (docker or psql). Aborting schema init."
            return 1
        fi
    fi

    log_info "Database schema initialization complete"
}
