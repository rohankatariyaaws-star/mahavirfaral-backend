#!/bin/bash

# Diagnose ECS Fargate Issues

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "🔍 Diagnosing ECS Fargate Issues..."

check_java_version() {
    echo "1. Checking Java version compatibility..."
    
    # Check pom.xml
    if [ -f "../../../backend/pom.xml" ]; then
        JAVA_VERSION=$(grep -o '<java.version>[^<]*' ../../../backend/pom.xml | sed 's/<java.version>//')
        echo "POM Java version: $JAVA_VERSION"
    fi
    
    # Check Dockerfile
    if [ -f "../../../backend/Dockerfile" ]; then
        DOCKER_JAVA=$(grep -o 'eclipse-temurin:[^-]*' ../../../backend/Dockerfile | sed 's/eclipse-temurin://')
        echo "Dockerfile Java version: $DOCKER_JAVA"
        
        if [ "$JAVA_VERSION" != "$DOCKER_JAVA" ]; then
            echo -e "${RED}❌ Java version mismatch detected!${NC}"
        else
            echo -e "${GREEN}✅ Java versions match${NC}"
        fi
    fi
}

check_health_endpoint() {
    echo ""
    echo "2. Checking health check configuration..."
    
    # Check Dockerfile health check
    if [ -f "../../../backend/Dockerfile" ]; then
        HEALTH_CHECK=$(grep -A1 "HEALTHCHECK" ../../../backend/Dockerfile | grep "CMD")
        echo "Current health check: $HEALTH_CHECK"
        
        if echo "$HEALTH_CHECK" | grep -q "/api/auth/test"; then
            echo -e "${RED}❌ Health check uses POST endpoint with GET request!${NC}"
        else
            echo -e "${GREEN}✅ Health check looks correct${NC}"
        fi
    fi
}

check_task_status() {
    echo ""
    echo "3. Checking current task status..."
    
    # Get task ARN
    TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text 2>/dev/null)
    
    if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
        echo "Task ARN: $TASK_ARN"
        
        # Get task details
        TASK_STATUS=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].lastStatus' --output text)
        HEALTH_STATUS=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].healthStatus' --output text)
        
        echo "Task Status: $TASK_STATUS"
        echo "Health Status: $HEALTH_STATUS"
        
        # Get container details
        CONTAINER_STATUS=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].containers[0].lastStatus' --output text)
        EXIT_CODE=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].containers[0].exitCode' --output text)
        REASON=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].containers[0].reason' --output text)
        
        echo "Container Status: $CONTAINER_STATUS"
        if [ "$EXIT_CODE" != "None" ] && [ -n "$EXIT_CODE" ]; then
            echo -e "${RED}Exit Code: $EXIT_CODE${NC}"
        fi
        if [ "$REASON" != "None" ] && [ -n "$REASON" ]; then
            echo "Reason: $REASON"
        fi
        
    else
        echo -e "${RED}❌ No running tasks found${NC}"
    fi
}

check_database_connectivity() {
    echo ""
    echo "4. Checking database connectivity..."
    
    if [ -f ".db-instance-id" ]; then
        DB_INSTANCE_ID=$(cat .db-instance-id)
        DB_STATUS=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].DBInstanceStatus' --output text)
        DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)
        
        echo "Database: $DB_INSTANCE_ID"
        echo "Status: $DB_STATUS"
        echo "Endpoint: $DB_ENDPOINT"
        
        # Check security groups
        RDS_SG=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
        ECS_SG=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$APP_NAME-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
        
        echo "RDS Security Group: $RDS_SG"
        echo "ECS Security Group: $ECS_SG"
        
        # Check if RDS allows connections from ECS
        if [ -n "$RDS_SG" ] && [ -n "$ECS_SG" ]; then
            RULE_EXISTS=$(aws ec2 describe-security-groups --group-ids $RDS_SG --region $AWS_REGION --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\` && ToPort==\`5432\`].UserIdGroupPairs[?GroupId==\`$ECS_SG\`]" --output text 2>/dev/null)
            
            if [ -n "$RULE_EXISTS" ]; then
                echo -e "${GREEN}✅ Security group rule exists for ECS->RDS${NC}"
            else
                echo -e "${RED}❌ Missing security group rule for ECS->RDS${NC}"
            fi
        fi
    else
        echo -e "${RED}❌ Database instance ID not found${NC}"
    fi
}

check_logs() {
    echo ""
    echo "5. Checking for logs..."
    
    # Check if log group exists
    LOG_GROUP="/ecs/$APP_NAME"
    LOG_EXISTS=$(aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP --region $AWS_REGION --query 'logGroups[0].logGroupName' --output text 2>/dev/null)
    
    if [ "$LOG_EXISTS" = "$LOG_GROUP" ]; then
        echo -e "${GREEN}✅ CloudWatch log group exists${NC}"
        
        # Get recent log streams
        STREAMS=$(aws logs describe-log-streams --log-group-name $LOG_GROUP --region $AWS_REGION --order-by LastEventTime --descending --max-items 3 --query 'logStreams[].logStreamName' --output text 2>/dev/null)
        
        if [ -n "$STREAMS" ]; then
            echo "Recent log streams found:"
            for stream in $STREAMS; do
                echo "  - $stream"
            done
        else
            echo -e "${YELLOW}⚠️  No log streams found${NC}"
        fi
    else
        echo -e "${RED}❌ CloudWatch log group not found${NC}"
    fi
}

check_task_definition() {
    echo ""
    echo "6. Checking task definition..."
    
    TASK_DEF_ARN=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].taskDefinition' --output text 2>/dev/null)
    
    if [ "$TASK_DEF_ARN" != "None" ] && [ -n "$TASK_DEF_ARN" ]; then
        echo "Task Definition: $TASK_DEF_ARN"
        
        # Check CPU and memory
        CPU=$(aws ecs describe-task-definition --task-definition $TASK_DEF_ARN --region $AWS_REGION --query 'taskDefinition.cpu' --output text)
        MEMORY=$(aws ecs describe-task-definition --task-definition $TASK_DEF_ARN --region $AWS_REGION --query 'taskDefinition.memory' --output text)
        
        echo "CPU: $CPU"
        echo "Memory: $MEMORY"
        
        if [ "$CPU" = "256" ] && [ "$MEMORY" = "512" ]; then
            echo -e "${YELLOW}⚠️  Low resource allocation (256 CPU, 512 MB RAM)${NC}"
        fi
        
        # Check environment variables
        DB_URL=$(aws ecs describe-task-definition --task-definition $TASK_DEF_ARN --region $AWS_REGION --query 'taskDefinition.containerDefinitions[0].environment[?name==`DATABASE_URL`].value' --output text)
        echo "Database URL: $DB_URL"
        
    else
        echo -e "${RED}❌ Task definition not found${NC}"
    fi
}

echo ""
echo "=== DIAGNOSIS SUMMARY ==="

check_java_version
check_health_endpoint
check_task_status
check_database_connectivity
check_logs
check_task_definition

echo ""
echo "=== RECOMMENDATIONS ==="
echo "1. Run ./fix-deployment-issues.sh to fix all identified issues"
echo "2. Check logs with ./check-container-logs.sh after fixes"
echo "3. Monitor service with ./debug-ecs-service.sh"