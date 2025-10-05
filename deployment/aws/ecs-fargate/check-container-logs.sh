#!/bin/bash

# Check ECS Container Logs

AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"

echo "📋 Checking Container Logs..."

# Get task ARN
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text)

if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    echo "Task ARN: $TASK_ARN"
    
    # Get container name
    CONTAINER_NAME=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].containers[0].name' --output text)
    echo "Container: $CONTAINER_NAME"
    
    # Try to get logs from CloudWatch (if logging was enabled)
    LOG_GROUP="/ecs/$APP_NAME"
    echo ""
    echo "🔍 Checking CloudWatch logs..."
    
    # Get log streams
    LOG_STREAMS=$(aws logs describe-log-streams --log-group-name $LOG_GROUP --region $AWS_REGION --query 'logStreams[].logStreamName' --output text 2>/dev/null || echo "")
    
    if [ -n "$LOG_STREAMS" ]; then
        echo "Found log streams in $LOG_GROUP"
        for stream in $LOG_STREAMS; do
            echo "Stream: $stream"
            aws logs get-log-events --log-group-name $LOG_GROUP --log-stream-name $stream --region $AWS_REGION --query 'events[].message' --output text | tail -20
        done
    else
        echo "❌ No CloudWatch logs found (logging disabled)"
    fi
    
    # Check task definition environment variables
    echo ""
    echo "🔧 Task Definition Environment:"
    aws ecs describe-task-definition --task-definition $APP_NAME-task --region $AWS_REGION --query 'taskDefinition.containerDefinitions[0].environment' --output table
    
    # Check database connectivity from container perspective
    echo ""
    echo "🗄️ Database Connection Test:"
    
    if [ -f ".db-instance-id" ]; then
        DB_INSTANCE_ID=$(cat .db-instance-id)
        DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)
        
        echo "Database Endpoint: $DB_ENDPOINT"
        echo "Testing database connectivity..."
        
        # Test if database port is reachable
        nc -z -w5 $DB_ENDPOINT 5432 && echo "✅ Database port 5432 is reachable" || echo "❌ Database port 5432 is not reachable"
        
        # Check security groups
        echo ""
        echo "🔒 Security Group Analysis:"
        
        # Get RDS security groups
        RDS_SG=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
        echo "RDS Security Group: $RDS_SG"
        
        # Get ECS security group
        ECS_SG=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$APP_NAME-sg" --query 'SecurityGroups[0].GroupId' --output text)
        echo "ECS Security Group: $ECS_SG"
        
        # Check if RDS allows connections from ECS
        RDS_RULES=$(aws ec2 describe-security-groups --group-ids $RDS_SG --region $AWS_REGION --query 'SecurityGroups[0].IpPermissions[?FromPort==`5432`]' --output text 2>/dev/null || echo "")
        
        if [ -n "$RDS_RULES" ]; then
            echo "✅ RDS has inbound rules for port 5432"
        else
            echo "❌ RDS missing inbound rules for port 5432"
            echo "💡 Need to add security group rule to allow ECS to connect to RDS"
        fi
    fi
    
else
    echo "❌ No running tasks found"
fi

echo ""
echo "🔧 Troubleshooting Steps:"
echo "1. Check if database allows connections from ECS security group"
echo "2. Verify database credentials in task definition"
echo "3. Check if Spring Boot application.properties are correct"
echo "4. Restart the ECS service to get fresh logs"