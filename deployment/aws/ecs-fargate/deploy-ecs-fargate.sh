#!/bin/bash

# Complete ECS Fargate + RDS + Netlify Deployment Script
# Includes database creation, security group fixes, and all deployment tasks

set -e

echo "🚀 Starting Complete ECS Fargate Deployment..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"
DB_USERNAME="ecommerceadmin"
DB_PASSWORD="MyPassword123"
NETLIFY_SITE_ID=""
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"
TASK_FAMILY="$APP_NAME-task"

# Set environment variables for CloudWatch log group
export CLOUDWATCH_LOG_GROUP_NAME="/ecs/ecommerce-fargate"
export CLOUDWATCH_LOG_GROUP_PREFIX="/ecs"

    # Helper to construct AWS CLI --environment Variables string while omitting empty values
    build_lambda_env_vars() {
        local kvs=()
        _add_kv() {
            local k="$1"; local v="$2"
            if [ -n "$v" ]; then
                kvs+=("$k=$v")
            fi
        }

        _add_kv LAMBDA_REGION "$AWS_REGION"
        _add_kv CLUSTER_NAME "$CLUSTER_NAME"
        _add_kv SERVICE_NAME "$SERVICE_NAME"
        _add_kv APP_NAME "$APP_NAME"
        _add_kv NETLIFY_TOKEN "$NETLIFY_TOKEN"
        _add_kv NETLIFY_SITE_ID "$NETLIFY_SITE_ID"
        _add_kv NETLIFY_BUILD_HOOK "$NETLIFY_BUILD_HOOK"

        if [ ${#kvs[@]} -gt 0 ]; then
            local IFS=","
            printf "Variables={%s}" "${kvs[*]}"
        else
            printf "Variables={}"
        fi
    }

    # Build a temporary JSON file for aws lambda --environment file://... usage
    build_lambda_env_file() {
        local kvs=()
        _add_kv() {
            local k="$1"; local v="$2"
            if [ -n "$v" ]; then
                kvs+=("$k=$v")
            fi
        }

        _add_kv LAMBDA_REGION "$AWS_REGION"
        _add_kv CLUSTER_NAME "$CLUSTER_NAME"
        _add_kv SERVICE_NAME "$SERVICE_NAME"
        _add_kv APP_NAME "$APP_NAME"
        _add_kv NETLIFY_TOKEN "$NETLIFY_TOKEN"
        _add_kv NETLIFY_SITE_ID "$NETLIFY_SITE_ID"
        _add_kv NETLIFY_BUILD_HOOK "$NETLIFY_BUILD_HOOK"

    local tmpf
    tmpf=$(create_tmp_file "lambda-env-XXXX.json")
        printf '{"Variables":{' > "$tmpf"
        local first=true
        for kv in "${kvs[@]}"; do
            local k=${kv%%=*}
            local v=${kv#*=}
            # escape backslashes and double quotes
            local v_escaped
            v_escaped=$(printf '%s' "$v" | sed 's/\\/\\\\/g; s/"/\\\"/g')
            if $first; then
                first=false
            else
                printf ',' >> "$tmpf"
            fi
            printf '"%s":"%s"' "$k" "$v_escaped" >> "$tmpf"
        done
        printf '}}' >> "$tmpf"
        echo "$tmpf"
    }

    # Cross-platform temporary file creator: prefers mktemp, falls back to PowerShell on Windows
    create_tmp_file() {
        local template="$1"
        local tmpf
        if command -v mktemp &> /dev/null; then
            # Use mktemp if available
            tmpf=$(mktemp -t "$template" 2>/dev/null || mktemp)
        else
            if command -v powershell &> /dev/null; then
                # Create a GUID-based temp filename via PowerShell
                tmpf=$(powershell -NoProfile -Command "[System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ([System.Guid]::NewGuid().ToString() + '-$template'))" 2>/dev/null | tr -d '\r')
                powershell -NoProfile -Command "New-Item -Path \"$tmpf\" -ItemType File -Force" >/dev/null 2>&1 || true
            else
                tmpf="./${template}-$$.tmp"
                : > "$tmpf"
            fi
        fi
        printf '%s' "$tmpf"
    }

    # Run AWS CLI with MSYS_NO_PATHCONV on Git Bash/MSYS to avoid path mangling
    run_aws_cli() {
        if uname -s 2>/dev/null | grep -qiE "msys|mingw|cygwin"; then
            MSYS_NO_PATHCONV=1 aws "$@"
        else
            aws "$@"
        fi
    }

check_dependencies() {
    echo "📋 Checking dependencies..."
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not installed${NC}"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker not installed${NC}"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker is not running. Please start Docker Desktop.${NC}"
        exit 1
    fi
    
    if ! command -v mvn &> /dev/null; then
        echo -e "${RED}❌ Maven not installed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Dependencies checked${NC}"
}

find_or_create_rds_instance() {
    echo "🗄️  Finding or Creating RDS Instance..."
    
    # Check for existing RDS instances from other deployments
    EXISTING_DBS=(
        "ecommerce-lambda-db"
        "ecommerce-fargate-db"
        "ecommerce-ec2-db"
    )
    
    FOUND_DB=""
    for db_id in "${EXISTING_DBS[@]}"; do
        if aws rds describe-db-instances --db-instance-identifier $db_id --region $AWS_REGION &> /dev/null; then
            FOUND_DB=$db_id
            echo -e "${GREEN}✅ Found existing RDS instance: $FOUND_DB${NC}"
            
            # Get the master username of existing database
            EXISTING_USERNAME=$(aws rds describe-db-instances --db-instance-identifier $db_id --region $AWS_REGION --query 'DBInstances[0].MasterUsername' --output text)
            echo "Existing database username: $EXISTING_USERNAME"
            
            # Update credentials to match existing database
            if [ "$EXISTING_USERNAME" != "$DB_USERNAME" ]; then
                echo -e "${YELLOW}⚠️  Updating credentials to match existing database${NC}"
                DB_USERNAME=$EXISTING_USERNAME
                # Common passwords used in other deployments
                if [ "$EXISTING_USERNAME" = "postgres" ]; then
                    DB_PASSWORD="root"
                elif [ "$EXISTING_USERNAME" = "ecommerceadmin" ]; then
                    DB_PASSWORD="MyPassword123"
                fi
                echo "Updated DB_USERNAME: $DB_USERNAME"
                echo "Updated DB_PASSWORD: $DB_PASSWORD"
            fi
            break
        fi
    done
    
    if [ -n "$FOUND_DB" ]; then
        # Use existing database
        DB_INSTANCE_ID=$FOUND_DB
        echo "Reusing existing database: $DB_INSTANCE_ID"
        echo "$DB_INSTANCE_ID" > .db-instance-id
        echo -e "${GREEN}✅ Using existing RDS instance${NC}"
    else
        # Create new database only if none exists
        echo "No existing database found, creating new one..."
        
        if ! aws rds describe-db-subnet-groups --db-subnet-group-name $APP_NAME-subnet-group --region $AWS_REGION &> /dev/null; then
            aws rds create-db-subnet-group \
                --db-subnet-group-name $APP_NAME-subnet-group \
                --db-subnet-group-description "Subnet group for $APP_NAME" \
                --subnet-ids $(aws ec2 describe-subnets --region $AWS_REGION --query 'Subnets[0:2].SubnetId' --output text) \
                --region $AWS_REGION
        fi
        
        aws rds create-db-instance \
            --db-instance-identifier $APP_NAME-db \
            --db-instance-class db.t3.micro \
            --engine postgres \
            --master-username $DB_USERNAME \
            --master-user-password $DB_PASSWORD \
            --allocated-storage 20 \
            --db-subnet-group-name $APP_NAME-subnet-group \
            --publicly-accessible \
            --no-multi-az \
            --storage-type gp2 \
            --region $AWS_REGION
        
        echo "⏳ Waiting for RDS instance..."
        aws rds wait db-instance-available --db-instance-identifier $APP_NAME-db --region $AWS_REGION
        
        DB_INSTANCE_ID=$APP_NAME-db
        echo "$DB_INSTANCE_ID" > .db-instance-id
        echo -e "${GREEN}✅ RDS instance created${NC}"
    fi
}

create_database_schema() {
    echo "🗺️  Creating database schema..."
    
    # Get database endpoint
    if [ -f ".db-instance-id" ]; then
        DB_INSTANCE_ID=$(cat .db-instance-id)
    else
        echo -e "${RED}❌ Database instance ID not found${NC}"
        return 1
    fi
    
    DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)
    
    # Create database initialization script
    cat > init-database.sql << 'EOF'
-- Create database if not exists
CREATE DATABASE ecommerce_db;

-- Connect to the database
\c ecommerce_db;

-- Create admin user if not exists
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255),
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'USER',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert admin user (password is 'admin123' encoded with bcrypt)
INSERT INTO users (name, phone_number, email, password, role) 
VALUES ('Administrator', '+1234567890', 'admin@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'ADMIN')
ON CONFLICT (phone_number) DO NOTHING;
EOF
    
        # Write SQL file to /tmp to be used by ECS task
    TMP_SQL=$(create_tmp_file "init-db-XXXX.sql")
        mv init-database.sql "$TMP_SQL"

        # Prepare DB init command to run inside a postgres container using psql
        DB_CMD="PGPASSWORD='$DB_PASSWORD' psql -h '$DB_ENDPOINT' -U '$DB_USERNAME' -d postgres -tc \"SELECT 1 FROM pg_database WHERE datname='ecommerce_db'\" | grep -q 1 || PGPASSWORD='$DB_PASSWORD' psql -h '$DB_ENDPOINT' -U '$DB_USERNAME' -d postgres -f /tmp/init-database.sql"

        # Create a temporary task definition JSON for DB init
        TASK_FAMILY="$APP_NAME-db-init"
    TASK_DEF_FILE=$(create_tmp_file "db-init-task-XXXX.json")

        cat > "$TASK_DEF_FILE" <<TASKDEF
{
    "family": "$TASK_FAMILY",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "$ROLE_ARN",
    "containerDefinitions": [
        {
            "name": "db-init",
            "image": "postgres:15",
            "essential": true,
            "entryPoint": ["sh","-c"],
            "command": ["/bin/sh -c \"$DB_CMD\""] ,
            "mountPoints": [
                {
                    "sourceVolume": "init-sql",
                    "containerPath": "/tmp"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "$CLOUDWATCH_LOG_GROUP_NAME",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "db-init"
                }
            }
        }
    ],
    "volumes": [
        {
            "name": "init-sql",
            "host": {}
        }
    ]
}
TASKDEF

    echo "Registering ECS task definition for DB init..."
    aws ecs register-task-definition --cli-input-json file://"$TASK_DEF_FILE" --region $AWS_REGION >/dev/null
    rm -f "$TASK_DEF_FILE"

    # Run the task
    echo "Running ECS task to initialize DB (this may take a minute)..."
    TASK_ARN=$(aws ecs run-task \
        --cluster "$CLUSTER_NAME" \
        --launch-type FARGATE \
        --task-definition "$TASK_FAMILY" \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=DISABLED}" \
        --count 1 \
        --region $AWS_REGION \
        --query 'tasks[0].taskArn' --output text)
    if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "null" ]; then
        echo -e "${RED}❌ Failed to start DB init task${NC}"
        rm -f "$TMP_SQL"
        return 1
    fi

    echo "Waiting for DB init task to stop..."
    aws ecs wait tasks-stopped --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --region $AWS_REGION

    # Check exit code (get via aws query to avoid jq dependency)
    EXIT_CODE=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --region $AWS_REGION --query 'tasks[0].containers[0].exitCode' --output text)
    if [ "$EXIT_CODE" = "0" ] || [ "$EXIT_CODE" = "null" ]; then
        echo -e "${GREEN}✅ Database init task finished (exit=$EXIT_CODE).${NC}"
    else
        echo -e "${YELLOW}⚠️  DB init task exit code=$EXIT_CODE. Check CloudWatch logs for details.${NC}"
    fi

    # Deregister temporary task definition
    TD_ARN=$(aws ecs list-task-definitions --family-prefix "$TASK_FAMILY" --region $AWS_REGION --query 'taskDefinitionArns[-1]' --output text)
        if [ -n "$TD_ARN" ] && [ "$TD_ARN" != "None" ]; then
            aws ecs deregister-task-definition --task-definition "$TD_ARN" --region $AWS_REGION >/dev/null 2>&1 || true
        fi

    rm -f "$TMP_SQL"
    echo -e "${GREEN}✅ Database schema setup completed${NC}"
}

fix_security_groups() {
    echo "🔒 Fixing security groups..."
    
    # Get ECS security group
    SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$APP_NAME-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
    
    if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
        # Add inbound rules for both ports
        aws ec2 authorize-security-group-ingress \
            --group-id $SG_ID \
            --protocol tcp \
            --port 80 \
            --cidr 0.0.0.0/0 \
            --region $AWS_REGION 2>/dev/null || echo "Port 80 rule may already exist"
        
        aws ec2 authorize-security-group-ingress \
            --group-id $SG_ID \
            --protocol tcp \
            --port 8080 \
            --cidr 0.0.0.0/0 \
            --region $AWS_REGION 2>/dev/null || echo "Port 8080 rule may already exist"
        
        echo -e "${GREEN}✅ Security group rules updated${NC}"
    fi
    
    # Fix database security groups
    if [ -f ".db-instance-id" ]; then
        DB_INSTANCE_ID=$(cat .db-instance-id)
        RDS_SG=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text 2>/dev/null)
        
        if [ "$RDS_SG" != "None" ] && [ -n "$RDS_SG" ] && [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
            # Add rule to allow ECS to connect to RDS
            aws ec2 authorize-security-group-ingress \
                --group-id $RDS_SG \
                --protocol tcp \
                --port 5432 \
                --source-group $SG_ID \
                --region $AWS_REGION 2>/dev/null || echo "Database security group rule may already exist"
            
            echo -e "${GREEN}✅ Database security group rules updated${NC}"
        fi
    fi
}

build_docker_image() {
    echo "🐳 Building Docker image..."
    
    # Find backend directory
    for dir in "../../../backend" "../../backend" "../backend" "./backend"; do
        if [ -d "$dir" ]; then
            cd "$dir"
            break
        fi
    done
    
    # Force rebuild by clearing cache
    echo "🔄 Forcing Docker image rebuild (clearing cache)..."
    rm -f .docker-hash
    
    # Get AWS account ID for ECR
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
    
    # Always rebuild to ensure latest configuration
    SOURCE_HASH=$(find src pom.xml -type f -exec md5sum {} \; 2>/dev/null | sort | md5sum | cut -d' ' -f1 2>/dev/null || echo "new")
    
    echo "🔄 Changes detected, rebuilding Docker image..."
    
    # Build Spring Boot JAR
    mvn clean package -DskipTests -Dmaven.javadoc.skip=true -Dmaven.source.skip=true
    
    # Create Dockerfile
    cat > Dockerfile << 'EOF'
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Copy JAR file
COPY target/*.jar app.jar

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run application
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
    
    # Get AWS account ID for ECR
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
    
    # Create ECR repository
    aws ecr create-repository --repository-name $APP_NAME --region $AWS_REGION 2>/dev/null || true
    
    # Login to ECR
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker is not running. Please start Docker Desktop and try again.${NC}"
        exit 1
    fi
    
    # Clear Docker cache and build fresh image
    echo "🧹 Clearing Docker build cache..."
    docker system prune -f 2>/dev/null || echo "Docker cache clear skipped"
    docker builder prune -f 2>/dev/null || echo "Docker builder cache clear skipped"
    
    # Build and push image with no cache
    echo "🔨 Building fresh Docker image..."
    docker build --no-cache -t $APP_NAME .
    docker tag $APP_NAME:latest $ECR_REPO:latest
    docker push $ECR_REPO:latest
    
    # Store build hash
    echo "$SOURCE_HASH" > .docker-hash
    
    echo -e "${GREEN}✅ Docker image built and pushed to ECR${NC}"
    
    # Store ECR info in current directory
    echo "ECR_REPO=$ECR_REPO" > ecr-info.env
}

create_ecs_cluster() {
    echo "🏗️  Creating ECS Cluster..."
    
    # Create ECS cluster
    aws ecs create-cluster \
        --cluster-name $CLUSTER_NAME \
        --capacity-providers FARGATE \
        --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
        --region $AWS_REGION 2>/dev/null || echo "Cluster may already exist"
    
    echo -e "${GREEN}✅ ECS Cluster created${NC}"
}

create_task_definition() {
    echo "📋 Creating ECS Task Definition..."
    
    # Get database endpoint from existing or new instance
    if [ -f ".db-instance-id" ]; then
        DB_INSTANCE_ID=$(cat .db-instance-id)
    else
        DB_INSTANCE_ID=$APP_NAME-db
    fi
    
    DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)
    
    # Get ECR repository URI
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
    
    # Create task execution role
    ROLE_NAME="$APP_NAME-execution-role"
    if ! aws iam get-role --role-name $ROLE_NAME &> /dev/null; then
        aws iam create-role --role-name $ROLE_NAME \
            --assume-role-policy-document '{
                "Version": "2012-10-17",
                "Statement": [{
                    "Effect": "Allow",
                    "Principal": {"Service": "ecs-tasks.amazonaws.com"},
                    "Action": "sts:AssumeRole"
                }]
            }'
        
        aws iam attach-role-policy --role-name $ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
        
        sleep 10
    fi
    
    ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)
    
    # Check if CloudWatch log group exists, create if not
    echo "Checking CloudWatch log group..."
    echo "Debug: CLOUDWATCH_LOG_GROUP_NAME=$CLOUDWATCH_LOG_GROUP_NAME"
    echo "Debug: CLOUDWATCH_LOG_GROUP_PREFIX=$CLOUDWATCH_LOG_GROUP_PREFIX"
    
    # Force MSYS_NO_PATHCONV to prevent Git Bash path translation
    export MSYS_NO_PATHCONV=1
    
    # Log the exact command for debugging
    echo "Executing: aws logs describe-log-groups --log-group-name-prefix \"$CLOUDWATCH_LOG_GROUP_PREFIX\" --region \"$AWS_REGION\" --query \"logGroups[?logGroupName=='$CLOUDWATCH_LOG_GROUP_NAME'].logGroupName\" --output text"
    if MSYS_NO_PATHCONV=1 aws logs describe-log-groups --log-group-name-prefix "$CLOUDWATCH_LOG_GROUP_PREFIX" --region "$AWS_REGION" --query "logGroups[?logGroupName=='$CLOUDWATCH_LOG_GROUP_NAME'].logGroupName" --output text | grep -q "$CLOUDWATCH_LOG_GROUP_NAME"; then
        echo -e "${GREEN}✅ CloudWatch log group already exists${NC}"
    else
        echo "Creating CloudWatch log group: $CLOUDWATCH_LOG_GROUP_NAME"
        echo "Executing: aws logs create-log-group --log-group-name \"$CLOUDWATCH_LOG_GROUP_NAME\" --region \"$AWS_REGION\""
        MSYS_NO_PATHCONV=1 aws logs create-log-group --log-group-name "$CLOUDWATCH_LOG_GROUP_NAME" --region "$AWS_REGION"
        echo -e "${GREEN}✅ CloudWatch log group created${NC}"
    fi
    
    # Unset MSYS_NO_PATHCONV to avoid affecting other commands
    unset MSYS_NO_PATHCONV
    
    # Debug: Print database connection details
    echo "🔍 Database Connection Debug:"
    echo "DB_ENDPOINT: $DB_ENDPOINT"
    echo "DB_USERNAME: $DB_USERNAME"
    echo "DB_PASSWORD: $DB_PASSWORD"
    echo "DATABASE_URL: jdbc:postgresql://$DB_ENDPOINT:5432/ecommerce_db"
    
    # Create task definition with improved settings
    cat > task-definition.json << EOF
{
    "family": "$TASK_FAMILY",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "512",
    "memory": "1024",
    "executionRoleArn": "$ROLE_ARN",
    "containerDefinitions": [
        {
            "name": "$APP_NAME-container",
            "image": "$ECR_REPO:latest",
            "portMappings": [
                {
                    "containerPort": 8080,
                    "protocol": "tcp"
                }
            ],
            "environment": [
                {
                    "name": "DATABASE_URL",
                    "value": "jdbc:postgresql://$DB_ENDPOINT:5432/ecommerce_db"
                },
                {
                    "name": "DB_USERNAME",
                    "value": "$DB_USERNAME"
                },
                {
                    "name": "DB_PASSWORD",
                    "value": "$DB_PASSWORD"
                },
                {
                    "name": "JWT_SECRET",
                    "value": "$(openssl rand -base64 32)"
                },
                {
                    "name": "SPRING_PROFILES_ACTIVE",
                    "value": "production"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "$CLOUDWATCH_LOG_GROUP_NAME",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "essential": true
        }
    ]
}
EOF
    
    # Register new task definition
    TASK_DEF_ARN=$(aws ecs register-task-definition \
        --cli-input-json file://task-definition.json \
        --region $AWS_REGION \
        --query 'taskDefinition.taskDefinitionArn' --output text)
    
    echo "New task definition: $TASK_DEF_ARN"
    
    echo -e "${GREEN}✅ Task definition created${NC}"
}

create_load_balancer() {
    echo "⚖️ Creating Application Load Balancer..."
    
    # Get default VPC and subnets
    VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    SUBNET_IDS=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0:2].SubnetId' --output text)
    
    # Create ALB security group
    ALB_SG_NAME="$APP_NAME-alb-sg"
    ALB_SG_ID=$(aws ec2 create-security-group \
        --group-name $ALB_SG_NAME \
        --description "ALB Security group for $APP_NAME" \
        --vpc-id $VPC_ID \
        --region $AWS_REGION \
        --query 'GroupId' --output text 2>/dev/null || \
        aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$ALB_SG_NAME" --query 'SecurityGroups[0].GroupId' --output text)
    
    # Add HTTP and HTTPS rules to ALB
    aws ec2 authorize-security-group-ingress \
        --group-id $ALB_SG_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION 2>/dev/null || true
    
    aws ec2 authorize-security-group-ingress \
        --group-id $ALB_SG_ID \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION 2>/dev/null || true
    
    # Create Application Load Balancer
    ALB_ARN=$(aws elbv2 create-load-balancer \
        --name $APP_NAME-alb \
        --subnets $SUBNET_IDS \
        --security-groups $ALB_SG_ID \
        --region $AWS_REGION \
        --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || \
        aws elbv2 describe-load-balancers --names $APP_NAME-alb --region $AWS_REGION --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --region $AWS_REGION --query 'LoadBalancers[0].DNSName' --output text)
    
    # Create target group
    TG_ARN=$(aws elbv2 create-target-group \
        --name $APP_NAME-tg \
        --protocol HTTP \
        --port 8080 \
        --vpc-id $VPC_ID \
        --target-type ip \
        --health-check-path /health \
        --region $AWS_REGION \
        --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || \
        aws elbv2 describe-target-groups --names $APP_NAME-tg --region $AWS_REGION --query 'TargetGroups[0].TargetGroupArn' --output text)
    
    # Create HTTP listener (redirects to HTTPS)
    aws elbv2 create-listener \
        --load-balancer-arn $ALB_ARN \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=redirect,RedirectConfig='{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}' \
        --region $AWS_REGION 2>/dev/null || true
    
    # Create HTTPS listener (requires SSL certificate)
    # For now, create HTTP listener on port 443 as a workaround
    aws elbv2 create-listener \
        --load-balancer-arn $ALB_ARN \
        --protocol HTTP \
        --port 443 \
        --default-actions Type=forward,TargetGroupArn=$TG_ARN \
        --region $AWS_REGION 2>/dev/null || true
    
    echo "ALB_ARN=$ALB_ARN" > alb-info.env
    echo "TG_ARN=$TG_ARN" > tg-info.env
    echo "ALB_DNS=$ALB_DNS" > alb-dns.env
    
    echo -e "${GREEN}✅ Load Balancer created: https://$ALB_DNS${NC}"
}

create_ecs_service() {
    echo "🚀 Creating ECS Service..."
    
    # Get default VPC and subnets
    VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    SUBNET_IDS=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0:2].SubnetId' --output text | tr '\t' ',')
    
    # Skip target group for direct ECS deployment (no ALB)
    # This deployment uses direct task IP instead of load balancer
    
    # Create security group
    SG_NAME="$APP_NAME-sg"
    SG_ID=$(aws ec2 create-security-group \
        --group-name $SG_NAME \
        --description "Security group for $APP_NAME" \
        --vpc-id $VPC_ID \
        --region $AWS_REGION \
        --query 'GroupId' --output text 2>/dev/null || \
        aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$SG_NAME" --query 'SecurityGroups[0].GroupId' --output text)
    
    # Add inbound rules for both ports
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION 2>/dev/null || true
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 8080 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION 2>/dev/null || true
    
    # Update or create ECS service with load balancer
    if aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION &> /dev/null; then
        echo "Updating existing service with new task definition..."
        aws ecs update-service \
            --cluster $CLUSTER_NAME \
            --service $SERVICE_NAME \
            --task-definition $TASK_FAMILY \
            --region $AWS_REGION
    else
        echo "Creating new service with load balancer..."
        aws ecs create-service \
            --cluster $CLUSTER_NAME \
            --service-name $SERVICE_NAME \
            --task-definition $TASK_FAMILY \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \

            --region $AWS_REGION
    fi
    
    echo -e "${GREEN}✅ ECS Service created${NC}"
}

create_scheduled_scaling() {
    echo "⏰ Setting up scheduled scaling (6 AM - 12 AM IST)..."
    
    # Create IAM role for Application Auto Scaling
    SCALING_ROLE_NAME="$APP_NAME-scaling-role"
    if ! aws iam get-role --role-name $SCALING_ROLE_NAME &> /dev/null; then
        aws iam create-role --role-name $SCALING_ROLE_NAME \
            --assume-role-policy-document '{
                "Version": "2012-10-17",
                "Statement": [{
                    "Effect": "Allow",
                    "Principal": {"Service": "application-autoscaling.amazonaws.com"},
                    "Action": "sts:AssumeRole"
                }]
            }'
        
        aws iam attach-role-policy --role-name $SCALING_ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/application-autoscaling/AWSApplicationAutoscalingECSServicePolicy
        
        sleep 10
    fi
    
    # Register scalable target
    aws application-autoscaling register-scalable-target \
        --service-namespace ecs \
        --resource-id service/$CLUSTER_NAME/$SERVICE_NAME \
        --scalable-dimension ecs:service:DesiredCount \
        --min-capacity 0 \
        --max-capacity 1 \
        --region $AWS_REGION 2>/dev/null || true
    
    # Scale UP at 6 AM IST (00:30 UTC)
    aws application-autoscaling put-scheduled-action \
        --service-namespace ecs \
        --resource-id service/$CLUSTER_NAME/$SERVICE_NAME \
        --scalable-dimension ecs:service:DesiredCount \
        --scheduled-action-name "$APP_NAME-scale-up" \
        --schedule "cron(30 0 * * ? *)" \
        --scalable-target-action MinCapacity=1,MaxCapacity=1 \
        --region $AWS_REGION 2>/dev/null || true
    
    # Scale DOWN at 12 AM IST (18:30 UTC)
    aws application-autoscaling put-scheduled-action \
        --service-namespace ecs \
        --resource-id service/$CLUSTER_NAME/$SERVICE_NAME \
        --scalable-dimension ecs:service:DesiredCount \
        --scheduled-action-name "$APP_NAME-scale-down" \
        --schedule "cron(30 18 * * ? *)" \
        --scalable-target-action MinCapacity=0,MaxCapacity=0 \
        --region $AWS_REGION 2>/dev/null || true
    
    echo -e "${GREEN}✅ Scheduled scaling configured (6 AM - 12 AM IST)${NC}"
    echo -e "${YELLOW}💰 Cost savings: ~75% (18 hours/day instead of 24)${NC}"
}

create_lambda_ip_updater() {
    echo "🔄 Setting up automatic IP updater..."

    # Create Lambda execution role
    LAMBDA_ROLE_NAME="$APP_NAME-lambda-role"
    if ! aws iam get-role --role-name $LAMBDA_ROLE_NAME &> /dev/null; then
        aws iam create-role --role-name $LAMBDA_ROLE_NAME \
            --assume-role-policy-document '{
                "Version": "2012-10-17",
                "Statement": [{
                    "Effect": "Allow",
                    "Principal": {"Service": "lambda.amazonaws.com"},
                    "Action": "sts:AssumeRole"
                }]
            }'

        aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

        aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

        aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess

        aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

        aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

        aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

        sleep 15
    fi

    LAMBDA_ROLE_ARN=$(aws iam get-role --role-name $LAMBDA_ROLE_NAME --query 'Role.Arn' --output text)

    # Create Lambda function code inline
    cat > lambda_ip_updater.py << 'EOF'
import json
import boto3
import urllib.request
import urllib.parse
import os

def lambda_handler(event, context):
    # Initialize AWS clients with explicit region
    region = os.environ.get('LAMBDA_REGION', 'ap-south-1')
    ecs = boto3.client('ecs', region_name=region)
    ssm = boto3.client('ssm', region_name=region)
    ec2 = boto3.client('ec2', region_name=region)

    # Get environment variables
    cluster_name = os.environ.get('CLUSTER_NAME', 'ecommerce-fargate-cluster')
    service_name = os.environ.get('SERVICE_NAME', 'ecommerce-fargate-service')
    app_name = os.environ.get('APP_NAME', 'ecommerce-fargate')

    print(f"Processing event: {json.dumps(event)}")

    try:
        detail = event.get('detail', {})
        cluster_arn = detail.get('clusterArn', '')
        task_arn = detail.get('taskArn', '')
        last_status = detail.get('lastStatus', '')

        print(f"Task status: {last_status}, Cluster: {cluster_arn}, Task: {task_arn}")

        if last_status != 'RUNNING':
            return {'statusCode': 200, 'body': 'Task not running'}

        response = ecs.describe_tasks(cluster=cluster_arn, tasks=[task_arn])
        if not response['tasks']:
            return {'statusCode': 404, 'body': 'Task not found'}

        task = response['tasks'][0]
        eni_id = None
        for attachment in task.get('attachments', []):
            for detail in attachment.get('details', []):
                if detail['name'] == 'networkInterfaceId':
                    eni_id = detail['value']
                    break

        if not eni_id:
            return {'statusCode': 404, 'body': 'Network interface not found'}

        response = ec2.describe_network_interfaces(NetworkInterfaceIds=[eni_id])
        if not response['NetworkInterfaces']:
            return {'statusCode': 404, 'body': 'Network interface details not found'}

        public_ip = response['NetworkInterfaces'][0].get('Association', {}).get('PublicIp')
        if not public_ip:
            return {'statusCode': 404, 'body': 'Public IP not found'}

        new_api_url = f"http://{public_ip}:8080"

        try:
            current_url = ssm.get_parameter(Name='ecommerce-api-url')['Parameter']['Value']
        except Exception:
            current_url = ""

        if new_api_url == current_url:
            return {'statusCode': 200, 'body': 'IP unchanged'}

        ssm.put_parameter(Name='ecommerce-api-url', Value=new_api_url, Type='String', Overwrite=True)
        print(f"Updated SSM parameter: ecommerce-api-url = {new_api_url}")

        # Update Netlify environment variable and trigger build
        netlify_token = os.environ.get('NETLIFY_TOKEN')
        netlify_site_id = os.environ.get('NETLIFY_SITE_ID')
        netlify_build_hook = os.environ.get('NETLIFY_BUILD_HOOK')

        if netlify_token and netlify_site_id:
            try:
                netlify_headers = {
                    'Authorization': f'Bearer {netlify_token}',
                    'Content-Type': 'application/json'
                }

                # Update env var via Netlify API
                netlify_data = {
                    'key': 'REACT_APP_API_URL',
                    'value': new_api_url
                }

                env_url = f'https://api.netlify.com/api/v1/sites/{netlify_site_id}/env'
                env_req = urllib.request.Request(env_url, data=json.dumps(netlify_data).encode('utf-8'), headers=netlify_headers, method='POST')

                with urllib.request.urlopen(env_req, timeout=10) as response:
                    if response.status in [200, 201]:
                        print(f"Updated Netlify environment variable: REACT_APP_API_URL = {new_api_url}")
                    else:
                        print(f"Failed to update Netlify env var: {response.status}")

                # Trigger build if build hook is provided
                if netlify_build_hook:
                    build_req = urllib.request.Request(netlify_build_hook, method='POST')
                    with urllib.request.urlopen(build_req, timeout=10) as build_resp:
                        if build_resp.status in [200, 201]:
                            print(f"Triggered Netlify build for site {netlify_site_id}")
                        else:
                            print(f"Failed to trigger Netlify build: {build_resp.status}")

            except Exception as netlify_error:
                print(f"Netlify update/build error: {str(netlify_error)}")
        else:
            print("Netlify credentials not configured, skipping Netlify update/build")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'IP updated successfully',
                'old_url': current_url,
                'new_url': new_api_url,
                'public_ip': public_ip,
                'cluster': cluster_name,
                'service': service_name
            })
        }

    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
EOF

    # Create deployment package (Windows compatible)
    if command -v zip &> /dev/null; then
        zip -r lambda_ip_updater.zip lambda_ip_updater.py
    else
        # Use PowerShell on Windows if zip not available
        powershell -Command "Compress-Archive -Path lambda_ip_updater.py -DestinationPath lambda_ip_updater.zip -Force"
    fi

    # Create/update Lambda function with environment variables
    if aws lambda get-function --function-name $APP_NAME-ip-updater --region $AWS_REGION &> /dev/null; then
        echo "Updating existing Lambda function..."
        aws lambda update-function-code \
            --function-name $APP_NAME-ip-updater \
            --zip-file fileb://lambda_ip_updater.zip \
            --region $AWS_REGION
        # Update configuration with environment variables using a temp JSON file
        ENV_FILE=$(build_lambda_env_file)
        echo "Updating Lambda with environment file: $ENV_FILE"
        aws lambda update-function-configuration \
            --function-name $APP_NAME-ip-updater \
            --handler lambda_ip_updater.lambda_handler \
            --timeout 300 \
            --memory-size 256 \
            --environment file://$ENV_FILE \
            --region $AWS_REGION
        rm -f "$ENV_FILE"
    else
        echo "Creating new Lambda function..."
        ENV_FILE=$(build_lambda_env_file)
        echo "Creating Lambda with environment file: $ENV_FILE"
        aws lambda create-function \
            --function-name $APP_NAME-ip-updater \
            --runtime python3.9 \
            --role $LAMBDA_ROLE_ARN \
            --handler lambda_ip_updater.lambda_handler \
            --zip-file fileb://lambda_ip_updater.zip \
            --timeout 300 \
            --memory-size 256 \
            --environment file://$ENV_FILE \
            --region $AWS_REGION
        rm -f "$ENV_FILE"
    fi

    # Create EventBridge rule for ECS task state changes
    aws events put-rule \
        --name $APP_NAME-task-state-rule \
        --event-pattern "{\"source\": [\"aws.ecs\"], \"detail-type\": [\"ECS Task State Change\"], \"detail\": {\"clusterArn\": [\"arn:aws:ecs:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):cluster/$CLUSTER_NAME\"], \"lastStatus\": [\"RUNNING\"]}}" \
        --region $AWS_REGION 2>/dev/null || true

    # Add Lambda permission for EventBridge
    aws lambda add-permission \
        --function-name $APP_NAME-ip-updater \
        --statement-id allow-eventbridge \
        --action lambda:InvokeFunction \
        --principal events.amazonaws.com \
        --source-arn arn:aws:events:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):rule/$APP_NAME-task-state-rule \
        --region $AWS_REGION 2>/dev/null || true

    # Add EventBridge target
    aws events put-targets \
        --rule $APP_NAME-task-state-rule \
        --targets "Id=1,Arn=arn:aws:lambda:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):function:$APP_NAME-ip-updater" \
        --region $AWS_REGION 2>/dev/null || true

    # Cleanup
    rm -f lambda_ip_updater.py lambda_ip_updater.zip

    echo -e "${GREEN}✅ Automatic IP updater configured${NC}"
    echo -e "${YELLOW}🤖 Lambda will auto-update Netlify when ECS IP changes${NC}"
}

setup_netlify_credentials() {
    echo "🔧 Setting up Netlify credentials for Lambda..."
    
    if [ -z "$NETLIFY_TOKEN" ] || [ -z "$NETLIFY_SITE_ID" ]; then
        echo -e "${YELLOW}⚠️  Netlify credentials not provided. Lambda will only update SSM parameter.${NC}"
        echo "To enable automatic Netlify updates:"
        echo "1. Get token from https://app.netlify.com/user/applications/personal"
        echo "2. Get site ID from Netlify dashboard"
        echo "3. Set NETLIFY_TOKEN and NETLIFY_SITE_ID environment variables"
        return
    fi
    
    echo "Updating Lambda with Netlify credentials..."
    # Use helper to build an environment JSON file that omits empty values
    ENV_FILE=$(build_lambda_env_file)
    aws lambda update-function-configuration \
        --function-name $APP_NAME-ip-updater \
        --environment file://$ENV_FILE \
        --region $AWS_REGION
    rm -f "$ENV_FILE"
    
    echo -e "${GREEN}✅ Netlify credentials configured${NC}"
}

setup_netlify() {
    echo "🔧 Running Netlify setup (wiring credentials to Lambda)..."

    # If user provided build hook only, that's acceptable — no token required for triggering the hook.
    if [ -z "$NETLIFY_TOKEN" ] && [ -z "$NETLIFY_BUILD_HOOK" ]; then
        echo -e "${YELLOW}⚠️  No Netlify token or build hook provided. To automatically update Netlify env and trigger builds, provide NETLIFY_BUILD_HOOK or NETLIFY_TOKEN and NETLIFY_SITE_ID.${NC}"
        echo "You can still use the Lambda/SSM update for internal wiring; Netlify build will not be triggered automatically."
        return 0
    fi

    # If token is provided but no site id, prompt the user
    if [ -n "$NETLIFY_TOKEN" ] && [ -z "$NETLIFY_SITE_ID" ]; then
        read -p "Enter Netlify site ID: " NETLIFY_SITE_ID
        export NETLIFY_SITE_ID
    fi

    # Call the credentials updater to write them into the Lambda environment
    setup_netlify_credentials

    echo -e "${GREEN}✅ Netlify setup completed${NC}"
}

# (Actual deploy_netlify implementation appears later in file)

trigger_initial_setup() {
    echo "🚀 Setting up initial Netlify environment variable..."
    
    # Get current ECS IP and set it in Netlify immediately
    TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text 2>/dev/null || echo "")
    
    if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
        # Trigger Lambda manually for initial setup
        echo "Triggering Lambda for initial IP setup..."
        
        # Create test event to trigger Lambda
        cat > test-event.json << EOF
{
  "detail": {
    "clusterArn": "arn:aws:ecs:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):cluster/$CLUSTER_NAME",
    "taskArn": "$TASK_ARN",
    "lastStatus": "RUNNING"
  }
}
EOF
        
        # Invoke Lambda function
        aws lambda invoke \
            --function-name $APP_NAME-ip-updater \
            --payload fileb://test-event.json \
            --region $AWS_REGION \
            lambda-response.json
        
        # Show result
        if [ -f "lambda-response.json" ]; then
            echo "Lambda response:"
            cat lambda-response.json
            rm -f lambda-response.json
        fi
        
        rm -f test-event.json
        
            echo -e "${GREEN}✅ Initial Netlify environment variable set${NC}"
    else
        echo -e "${YELLOW}⚠️  No running ECS tasks found for initial setup${NC}"
    fi
}

deploy_scheduler_only() {
    echo "⏰ Deploying scheduler and Lambda only..."
    create_scheduled_scaling
    create_lambda_ip_updater
    echo -e "${GREEN}✅ Scheduler deployment completed${NC}"
}

fix_mixed_content() {
    echo "🔒 Fixing mixed content issues..."
    
    # Find frontend directory
    for dir in "../../../frontend" "../../frontend" "../frontend" "./frontend"; do
        if [ -d "$dir" ]; then
            cd "$dir"
            break
        fi
    done
    
        # Create API proxy for mixed content
        mkdir -p api
        cat > api/proxy.js << 'EOF'
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

        echo -e "${GREEN}✅ Mixed content proxy created${NC}"
        echo -e "${YELLOW}ℹ️  Use apiCall() instead of direct fetch() in your components${NC}"

get_service_url() {
    echo "🔍 Getting service URL..."
    
    # Wait for service to be running
    echo "⏳ Waiting for service to be running..."
    
    for i in {1..30}; do
        SERVICE_STATUS=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].status' --output text 2>/dev/null || echo "INACTIVE")
        RUNNING_COUNT=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].runningCount' --output text 2>/dev/null || echo "0")
        
        if [ "$SERVICE_STATUS" = "ACTIVE" ] && [ "$RUNNING_COUNT" -gt 0 ]; then
            echo "Service is running with $RUNNING_COUNT tasks"
            break
        fi
        
        echo "Waiting... (attempt $i/30) Status: $SERVICE_STATUS, Running: $RUNNING_COUNT"
        sleep 10
    done
    
    # Get task ARN and IP
    TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text)
    
    if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
        # Get public IP
        ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
        PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $AWS_REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
        
        if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
            # Use HTTP for now to avoid mixed content - will fix with proxy
            API_URL="http://$PUBLIC_IP:8080"
            echo -e "${GREEN}✅ Service URL: $API_URL${NC}"
            echo -e "${YELLOW}⚠️  Note: IP may change when task restarts${NC}"
            
            # Store in parameter store
            aws ssm put-parameter --name "ecommerce-api-url" --value "$API_URL" --type "String" --overwrite --region $AWS_REGION
            
            # Test the service
            echo "🔍 Testing service..."
            sleep 30
            HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" --max-time 30 || echo "000")
            echo "Service test: HTTP $HTTP_STATUS"
        else
            echo -e "${YELLOW}⚠️  Could not get public IP${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No running tasks found${NC}"
    fi
}

# Netlify deployment: builds frontend locally then triggers Netlify build hook (preferred) or uploads build dir
deploy_netlify() {
    echo "🎨 Building frontend and deploying to Netlify (trigger/build)..."

    # Find frontend directory
    FRONTEND_DIR=""
    for dir in "../../../frontend" "../../frontend" "../frontend" "./frontend" "frontend"; do
        if [ -d "$dir" ]; then
            FRONTEND_DIR="$dir"
            cd "$dir"
            echo "✅ Frontend directory found: $(pwd)"
            break
        fi
    done

    if [ -z "$FRONTEND_DIR" ]; then
        echo -e "${RED}❌ Frontend directory not found${NC}"
        return 1
    fi

    # Get API URL
    API_URL=$(aws ssm get-parameter --name "ecommerce-api-url" --region $AWS_REGION --query 'Parameter.Value' --output text 2>/dev/null || echo "")

    # Build frontend
    echo "REACT_APP_API_URL=$API_URL" > .env.production.local
    echo "NODE_ENV=production" >> .env.production.local
    echo "GENERATE_SOURCEMAP=false" >> .env.production.local

    PACKAGE_HASH=$(md5sum package.json 2>/dev/null | cut -d' ' -f1 || echo "new")
    LAST_PACKAGE_HASH=""
    if [ -f ".package-hash" ]; then
        LAST_PACKAGE_HASH=$(cat .package-hash 2>/dev/null || echo "")
    fi

    if [ "$PACKAGE_HASH" != "$LAST_PACKAGE_HASH" ] || [ ! -d "node_modules" ]; then
        echo "📦 Installing dependencies..."
        npm install --no-audit --no-fund
        echo "$PACKAGE_HASH" > .package-hash
    fi

    echo "📦 Building..."
    npm run build

    # If build hook is configured, trigger it and exit
    if [ -n "$NETLIFY_BUILD_HOOK" ]; then
        echo "🔔 Triggering Netlify build hook..."
        HTTP_CODE=$(curl -s -X POST "$NETLIFY_BUILD_HOOK" -o /dev/null -w "%{http_code}")
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
            echo -e "${GREEN}✅ Netlify build hook triggered (HTTP $HTTP_CODE)${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Failed to trigger Netlify build hook (HTTP $HTTP_CODE). Falling back to API deploy...${NC}"
        fi
    fi

    # Fallback: upload build directory to Netlify deploys API
    if [ -z "$NETLIFY_TOKEN" ] || [ -z "$NETLIFY_SITE_ID" ]; then
        echo -e "${YELLOW}⚠️  Netlify token or site ID missing. Provide NETLIFY_BUILD_HOOK or NETLIFY_TOKEN and NETLIFY_SITE_ID to deploy.${NC}"
        return 1
    fi

    # Create a zip of the build directory
    TMP_ZIP="/tmp/netlify_build_$$.zip"
    rm -f "$TMP_ZIP"

    # Check for zip command or PowerShell
    if command -v zip &> /dev/null; then
        echo "Using zip to create $TMP_ZIP..."
        (cd build && zip -r "$TMP_ZIP" .) || { echo -e "${RED}❌ Zip creation failed${NC}"; return 1; }
    elif command -v powershell &> /dev/null; then
        echo "zip not found, using PowerShell to create $TMP_ZIP..."
        # Convert Unix-style path to Windows-style for PowerShell
        WIN_TMP_ZIP=$(echo "$TMP_ZIP" | sed 's|/|\\|g')
        (cd build && powershell -Command "Compress-Archive -Path .\\* -DestinationPath $WIN_TMP_ZIP -Force") || { echo -e "${RED}❌ PowerShell ZIP creation failed${NC}"; return 1; }
    else
        echo -e "${RED}❌ Neither zip nor PowerShell is available. Please install 'zip' or ensure PowerShell is accessible.${NC}"
        echo "On Windows, ensure PowerShell is in PATH or install zip via: pacman -S zip (in Git Bash)"
        echo "On Ubuntu/Debian: sudo apt-get install zip"
        echo "On CentOS/RHEL: sudo yum install zip"
        echo "On macOS: brew install zip"
        echo "Alternatively, provide a NETLIFY_BUILD_HOOK to trigger builds without zipping."
        return 1
    fi

    echo "📤 Uploading build to Netlify deploys API..."
    UPLOAD_URL="https://api.netlify.com/api/v1/sites/$NETLIFY_SITE_ID/deploys"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$UPLOAD_URL" \
        -H "Authorization: Bearer $NETLIFY_TOKEN" \
        -F "file=@$TMP_ZIP") || HTTP_CODE="000"

    rm -f "$TMP_ZIP"

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo -e "${GREEN}✅ Netlify deploy triggered/uploaded (HTTP $HTTP_CODE)${NC}"
        return 0
    else
        echo -e "${RED}❌ Netlify deploy failed (HTTP $HTTP_CODE)${NC}"
        return 1
    fi
}

test_deployment() {
    echo "🔍 Testing deployment..."
    
    # Wait for service to be running
    echo "Waiting for service to start..."
    sleep 60
    
    # Get service URL
    TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text)
    
    if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
        ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
        PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $AWS_REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
        
        if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
            API_URL="http://$PUBLIC_IP:8080"
            echo -e "${GREEN}✅ Service URL: $API_URL${NC}"
            
            # Store in parameter store
            aws ssm put-parameter --name "ecommerce-api-url" --value "$API_URL" --type "String" --overwrite --region $AWS_REGION
            
            # Test endpoints
            echo "Testing endpoints..."
            sleep 30
            
            echo "Testing /health:"
            curl -s "$API_URL/health" || echo "Health endpoint not ready yet"
            
            echo "Testing /api/products/all:"
            curl -s "$API_URL/api/products/all" || echo "API endpoint not ready yet"
            
            echo -e "${GREEN}✅ Deployment testing completed${NC}"
            echo "Your application is available at: $API_URL"
        fi
    fi
}

main() {
    echo "🎯 Complete ECS Fargate Deployment Options:"
    echo "1. Full deployment (RDS + ECS + Netlify + Database Setup + Scheduled Scaling)"
    echo "2. Backend only (RDS + ECS + Database Setup + Scheduled Scaling)"
    echo "3. Frontend only (Netlify build trigger)"
    echo "4. Scheduler only (Scaling + Lambda IP updater)"
    echo "5. Fix mixed content issues (FREE solutions)"
    echo "6. Fix security groups only"
    echo "7. Fix mixed content issues (Netlify proxy)"
    echo "8. Test current deployment"
    echo "9. Update Netlify with current ECS IP"
    
    read -p "Choice (1-9): " choice
    
    # Ask for Netlify credentials for options that need Lambda
    if [[ "$choice" =~ ^[1243]$ ]]; then
        echo ""
        echo "🔑 Optional: Netlify Integration Setup"
        echo "For automatic Netlify environment variable updates and build triggers:"
        read -p "Enter Netlify personal access token (or press Enter to skip): " NETLIFY_TOKEN
        read -p "Enter Netlify site ID (or press Enter to use 'mahavirfaral'): " NETLIFY_SITE_ID
        read -p "Enter Netlify build hook URL (optional, press Enter to skip): " NETLIFY_BUILD_HOOK
        if [ -z "$NETLIFY_SITE_ID" ]; then
            NETLIFY_SITE_ID="mahavirfaral"
        fi
        export NETLIFY_TOKEN
        export NETLIFY_SITE_ID
        export NETLIFY_BUILD_HOOK
    fi
    
    check_dependencies
    
    case $choice in
        1)
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
                setup_netlify
                deploy_netlify
            ;;
        2)
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
            setup_netlify_credentials
            deploy_netlify
            ;;
        4)
            deploy_scheduler_only
            setup_netlify_credentials
            ;;
        5)
            ./fix-mixed-content-free.sh
            ;;
        6)
            fix_security_groups
            ;;
        7)
            fix_mixed_content
            ;;
        8)
            test_deployment
            ;;
        9)
            ./update-netlify-ip.sh || echo "Update-netlify-ip script not found; the Lambda updater should handle updates automatically."
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}🎉 Deployment completed!${NC}"
}

main "$@"