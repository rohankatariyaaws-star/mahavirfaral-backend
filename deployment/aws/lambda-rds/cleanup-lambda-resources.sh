#!/bin/bash

# Cleanup Lambda Resources Script
# Deletes Lambda function, API Gateway, WAF, IAM roles, and other Lambda-related resources

set -e

echo "🧹 Starting Lambda Resources Cleanup..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-lambda"

confirm_deletion() {
    echo -e "${YELLOW}⚠️  This will DELETE the following Lambda resources:${NC}"
    echo "- Lambda function: $APP_NAME-function"
    echo "- API Gateway: $APP_NAME-api"
    echo "- WAF Web ACL: $APP_NAME-waf"
    echo "- IAM Role: $APP_NAME-lambda-role"
    echo "- CloudWatch Log Groups"
    echo "- SSM Parameters (API URLs)"
    echo ""
    echo -e "${RED}⚠️  RDS database will NOT be deleted (shared with other deployments)${NC}"
    echo ""
    read -p "Are you sure you want to delete these resources? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Cleanup cancelled"
        exit 0
    fi
}

delete_api_gateway() {
    echo "🌐 Deleting API Gateway..."
    
    API_ID=$(aws apigatewayv2 get-apis --region $AWS_REGION --query "Items[?Name=='$APP_NAME-api'].ApiId" --output text 2>/dev/null || echo "")
    
    if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
        echo "Deleting API Gateway: $API_ID"
        aws apigatewayv2 delete-api --api-id $API_ID --region $AWS_REGION
        echo -e "${GREEN}✅ API Gateway deleted${NC}"
    else
        echo -e "${YELLOW}⚠️  API Gateway not found${NC}"
    fi
}

delete_waf() {
    echo "🔒 Deleting WAF Web ACL..."
    
    # List WAF Web ACLs and find ours
    WAF_ID=$(aws wafv2 list-web-acls --scope REGIONAL --region $AWS_REGION --query "WebACLs[?Name=='$APP_NAME-waf'].Id" --output text 2>/dev/null || echo "")
    
    if [ -n "$WAF_ID" ] && [ "$WAF_ID" != "None" ]; then
        echo "Deleting WAF Web ACL: $WAF_ID"
        
        # Get lock token
        LOCK_TOKEN=$(aws wafv2 get-web-acl --scope REGIONAL --id $WAF_ID --region $AWS_REGION --query 'LockToken' --output text 2>/dev/null || echo "")
        
        if [ -n "$LOCK_TOKEN" ]; then
            aws wafv2 delete-web-acl --scope REGIONAL --id $WAF_ID --lock-token $LOCK_TOKEN --region $AWS_REGION 2>/dev/null || true
            echo -e "${GREEN}✅ WAF Web ACL deleted${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  WAF Web ACL not found${NC}"
    fi
}

delete_lambda_function() {
    echo "⚡ Deleting Lambda function..."
    
    if aws lambda get-function --function-name $APP_NAME-function --region $AWS_REGION &> /dev/null; then
        echo "Deleting Lambda function: $APP_NAME-function"
        aws lambda delete-function --function-name $APP_NAME-function --region $AWS_REGION
        echo -e "${GREEN}✅ Lambda function deleted${NC}"
    else
        echo -e "${YELLOW}⚠️  Lambda function not found${NC}"
    fi
}

delete_iam_role() {
    echo "🔑 Deleting IAM role..."
    
    ROLE_NAME="$APP_NAME-lambda-role"
    
    if aws iam get-role --role-name $ROLE_NAME &> /dev/null; then
        echo "Detaching policies from role: $ROLE_NAME"
        
        # Detach managed policies
        aws iam detach-role-policy --role-name $ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
        
        # Delete inline policies if any
        POLICY_NAMES=$(aws iam list-role-policies --role-name $ROLE_NAME --query 'PolicyNames' --output text 2>/dev/null || echo "")
        for policy in $POLICY_NAMES; do
            if [ "$policy" != "None" ]; then
                aws iam delete-role-policy --role-name $ROLE_NAME --policy-name $policy 2>/dev/null || true
            fi
        done
        
        # Delete role
        echo "Deleting IAM role: $ROLE_NAME"
        aws iam delete-role --role-name $ROLE_NAME
        echo -e "${GREEN}✅ IAM role deleted${NC}"
    else
        echo -e "${YELLOW}⚠️  IAM role not found${NC}"
    fi
}

delete_cloudwatch_logs() {
    echo "📊 Deleting CloudWatch log groups..."
    
    LOG_GROUP="/aws/lambda/$APP_NAME-function"
    
    if aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP --region $AWS_REGION --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$LOG_GROUP"; then
        echo "Deleting log group: $LOG_GROUP"
        aws logs delete-log-group --log-group-name $LOG_GROUP --region $AWS_REGION
        echo -e "${GREEN}✅ CloudWatch log group deleted${NC}"
    else
        echo -e "${YELLOW}⚠️  CloudWatch log group not found${NC}"
    fi
}

delete_ssm_parameters() {
    echo "🔧 Deleting SSM parameters..."
    
    PARAMETERS=(
        "ecommerce-api-url"
        "ecommerce-jwt-secret"
    )
    
    for param in "${PARAMETERS[@]}"; do
        if aws ssm get-parameter --name $param --region $AWS_REGION &> /dev/null; then
            echo "Deleting parameter: $param"
            aws ssm delete-parameter --name $param --region $AWS_REGION
        else
            echo -e "${YELLOW}⚠️  Parameter $param not found${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ SSM parameters deleted${NC}"
}

cleanup_local_files() {
    echo "🗂️  Cleaning up local files..."
    
    # Remove Lambda deployment files
    rm -f lambda-deployment.zip
    rm -f task-definition.json
    rm -f user-data.sh
    rm -f test-event.json
    rm -f response.json
    rm -f simple-test.json
    rm -f simple-response.json
    
    echo -e "${GREEN}✅ Local files cleaned up${NC}"
}

show_remaining_resources() {
    echo ""
    echo "📋 Remaining resources (NOT deleted):"
    echo ""
    
    # Check RDS
    if aws rds describe-db-instances --db-instance-identifier ecommerce-lambda-db --region $AWS_REGION &> /dev/null; then
        echo "✅ RDS Database: ecommerce-lambda-db (shared resource)"
    fi
    
    if aws rds describe-db-instances --db-instance-identifier ecommerce-fargate-db --region $AWS_REGION &> /dev/null; then
        echo "✅ RDS Database: ecommerce-fargate-db (ECS deployment)"
    fi
    
    if aws rds describe-db-instances --db-instance-identifier ecommerce-ec2-db --region $AWS_REGION &> /dev/null; then
        echo "✅ RDS Database: ecommerce-ec2-db (EC2 deployment)"
    fi
    
    # Check Vercel URL parameter
    if aws ssm get-parameter --name "ecommerce-vercel-url" --region $AWS_REGION &> /dev/null; then
        VERCEL_URL=$(aws ssm get-parameter --name "ecommerce-vercel-url" --region $AWS_REGION --query 'Parameter.Value' --output text)
        echo "✅ Vercel Deployment: $VERCEL_URL (shared resource)"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Lambda resources cleanup completed!${NC}"
    echo ""
    echo "To delete RDS databases, use the respective cleanup scripts:"
    echo "- For ECS: deployment/aws/ecs-fargate/cleanup-ecs-resources.sh"
    echo "- For EC2: deployment/aws/ec2/cleanup-ec2-resources.sh"
}

main() {
    echo "🎯 Lambda Cleanup Options:"
    echo "1. Delete all Lambda resources (recommended)"
    echo "2. Delete API Gateway only"
    echo "3. Delete Lambda function only"
    echo "4. Delete IAM role only"
    echo "5. Show what will be deleted (dry run)"
    
    read -p "Choice (1-5): " choice
    
    case $choice in
        1)
            confirm_deletion
            delete_api_gateway
            delete_waf
            delete_lambda_function
            delete_iam_role
            delete_cloudwatch_logs
            delete_ssm_parameters
            cleanup_local_files
            show_remaining_resources
            ;;
        2)
            echo "Deleting API Gateway only..."
            delete_api_gateway
            delete_waf
            ;;
        3)
            echo "Deleting Lambda function only..."
            delete_lambda_function
            delete_cloudwatch_logs
            ;;
        4)
            echo "Deleting IAM role only..."
            delete_iam_role
            ;;
        5)
            echo "🔍 Resources that would be deleted:"
            echo "- Lambda function: $APP_NAME-function"
            echo "- API Gateway: $APP_NAME-api"
            echo "- WAF Web ACL: $APP_NAME-waf"
            echo "- IAM Role: $APP_NAME-lambda-role"
            echo "- CloudWatch Log Groups: /aws/lambda/$APP_NAME-function"
            echo "- SSM Parameters: ecommerce-api-url, ecommerce-jwt-secret"
            echo ""
            echo "Resources that would NOT be deleted:"
            echo "- RDS databases (shared with other deployments)"
            echo "- Vercel deployment (shared resource)"
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
}

main "$@"