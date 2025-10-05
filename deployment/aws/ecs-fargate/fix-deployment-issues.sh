#!/bin/bash

# Fix ECS Fargate Deployment Issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "🔧 Fixing ECS Fargate Deployment Issues..."

fix_java_version() {
    echo "1. Fixing Java version mismatch..."
    
    # Navigate to backend directory
    for dir in "../../../backend" "../../backend" "../backend" "./backend"; do
        if [ -d "$dir" ]; then
            cd "$dir"
            break
        fi
    done
    
    # Update pom.xml to use Java 17
    sed -i 's/<java.version>11<\/java.version>/<java.version>17<\/java.version>/' pom.xml
    echo -e "${GREEN}✅ Updated Java version to 17 in pom.xml${NC}"
}

fix_dockerfile_health_check() {
    echo "2. Fixing Dockerfile health check..."
    
    # Create improved Dockerfile
    cat > Dockerfile << 'EOF'
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Install curl and netcat for health checks
RUN apk add --no-cache curl netcat-openbsd

# Copy JAR file
COPY target/*.jar app.jar

# Expose port
EXPOSE 8080

# Improved health check - test if port is listening first, then try endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=5 \
    CMD nc -z localhost 8080 && curl -f http://localhost:8080/api/products/all || exit 1

# Run application with proper JVM settings for container
ENTRYPOINT ["java", "-Xmx400m", "-Xms200m", "-jar", "app.jar"]
EOF
    
    echo -e "${GREEN}✅ Updated Dockerfile with better health check${NC}"
}

create_health_endpoint() {
    echo "3. Adding health endpoint to application..."
    
    # Create a simple health controller
    mkdir -p src/main/java/com/ecommerce/controller
    
    cat > src/main/java/com/ecommerce/controller/HealthController.java << 'EOF'
package com.ecommerce.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.ResponseEntity;

@RestController
public class HealthController {
    
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("OK");
    }
    
    @GetMapping("/")
    public ResponseEntity<String> root() {
        return ResponseEntity.ok("Ecommerce API is running");
    }
}
EOF
    
    echo -e "${GREEN}✅ Added health endpoint${NC}"
}

fix_database_security_groups() {
    echo "4. Fixing database security groups..."
    
    # Get database instance ID
    if [ -f ".db-instance-id" ]; then
        DB_INSTANCE_ID=$(cat .db-instance-id)
    else
        echo -e "${RED}❌ Database instance ID not found${NC}"
        return 1
    fi
    
    # Get ECS security group
    ECS_SG=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$APP_NAME-sg" --query 'SecurityGroups[0].GroupId' --output text)
    
    # Get RDS security group
    RDS_SG=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
    
    # Add rule to allow ECS to connect to RDS
    aws ec2 authorize-security-group-ingress \
        --group-id $RDS_SG \
        --protocol tcp \
        --port 5432 \
        --source-group $ECS_SG \
        --region $AWS_REGION 2>/dev/null || echo "Rule may already exist"
    
    echo -e "${GREEN}✅ Fixed database security group rules${NC}"
}

create_improved_task_definition() {
    echo "5. Creating improved task definition..."
    
    # Get database endpoint
    if [ -f ".db-instance-id" ]; then
        DB_INSTANCE_ID=$(cat .db-instance-id)
    else
        DB_INSTANCE_ID="$APP_NAME-db"
    fi
    
    DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)
    
    # Get ECR repository URI
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
    
    # Get execution role ARN
    ROLE_ARN=$(aws iam get-role --role-name "$APP_NAME-execution-role" --query 'Role.Arn' --output text)
    
    # Create improved task definition with logging
    cat > task-definition-fixed.json << EOF
{
    "family": "$APP_NAME-task",
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
                    "value": "ecommerceadmin"
                },
                {
                    "name": "DB_PASSWORD",
                    "value": "MyPassword123"
                },
                {
                    "name": "JWT_SECRET",
                    "value": "$(openssl rand -base64 32)"
                },
                {
                    "name": "SPRING_PROFILES_ACTIVE",
                    "value": "production"
                },
                {
                    "name": "JAVA_OPTS",
                    "value": "-Xmx800m -Xms400m -XX:+UseG1GC"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/$APP_NAME",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "essential": true,
            "healthCheck": {
                "command": [
                    "CMD-SHELL",
                    "curl -f http://localhost:8080/health || exit 1"
                ],
                "interval": 30,
                "timeout": 10,
                "retries": 3,
                "startPeriod": 90
            }
        }
    ]
}
EOF
    
    echo -e "${GREEN}✅ Created improved task definition${NC}"
}

create_log_group() {
    echo "6. Creating CloudWatch log group..."
    
    aws logs create-log-group --log-group-name "/ecs/$APP_NAME" --region $AWS_REGION 2>/dev/null || echo "Log group may already exist"
    
    echo -e "${GREEN}✅ Created CloudWatch log group${NC}"
}

initialize_database() {
    echo "7. Initializing database schema..."
    
    # Get database connection details
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
CREATE DATABASE IF NOT EXISTS ecommerce_db;

-- Connect to the database
\c ecommerce_db;

-- Create basic tables (Spring Boot will handle the rest with ddl-auto: update)
-- This ensures the database is accessible
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255),
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'USER',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert admin user if not exists
INSERT INTO users (name, phone_number, email, password, role) 
VALUES ('Administrator', '+1234567890', 'admin@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'ADMIN')
ON CONFLICT (phone_number) DO NOTHING;
EOF
    
    echo "Database initialization script created"
    echo "To run manually: psql -h $DB_ENDPOINT -U ecommerceadmin -d postgres -f init-database.sql"
    echo -e "${GREEN}✅ Database initialization script ready${NC}"
}

rebuild_and_deploy() {
    echo "8. Rebuilding and deploying..."
    
    # Build new Docker image
    mvn clean package -DskipTests
    
    # Get ECR details
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
    
    # Login to ECR
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
    
    # Build and push new image
    docker build --no-cache -t $APP_NAME .
    docker tag $APP_NAME:latest $ECR_REPO:latest
    docker push $ECR_REPO:latest
    
    # Create log group
    aws logs create-log-group --log-group-name "/ecs/$APP_NAME" --region $AWS_REGION 2>/dev/null || true
    
    # Register new task definition
    aws ecs register-task-definition --cli-input-json file://task-definition-fixed.json --region $AWS_REGION
    
    # Update service
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --task-definition "$APP_NAME-task" \
        --region $AWS_REGION
    
    echo -e "${GREEN}✅ Rebuilt and deployed with fixes${NC}"
}

main() {
    echo "🎯 Fix Options:"
    echo "1. Fix all issues and redeploy"
    echo "2. Fix Java version only"
    echo "3. Fix Dockerfile only"
    echo "4. Fix database security groups only"
    echo "5. Create database initialization script"
    echo "6. Rebuild and deploy only"
    
    read -p "Choice (1-6): " choice
    
    case $choice in
        1)
            fix_java_version
            fix_dockerfile_health_check
            create_health_endpoint
            fix_database_security_groups
            create_improved_task_definition
            create_log_group
            initialize_database
            rebuild_and_deploy
            ;;
        2)
            fix_java_version
            ;;
        3)
            fix_dockerfile_health_check
            create_health_endpoint
            ;;
        4)
            fix_database_security_groups
            ;;
        5)
            initialize_database
            ;;
        6)
            rebuild_and_deploy
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}🎉 Fixes applied!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Wait 2-3 minutes for the service to restart"
    echo "2. Check logs: ./check-container-logs.sh"
    echo "3. Test endpoints: ./debug-ecs-service.sh"
}

main "$@"