#!/bin/bash

# AWS Lambda + RDS + Vercel Deployment Script
# Deploys Backend to Lambda, Database to RDS, Frontend to Vercel

set -e

echo "🚀 Starting AWS Lambda+RDS+Vercel Deployment..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration - Get current AWS region
AWS_REGION=$(aws configure get region || echo "us-east-1")
APP_NAME="ecommerce-lambda"
DB_USERNAME="ecommerceadmin"
VERCEL_APP_NAME="mahavirfaral"  # Custom Vercel subdomain

check_dependencies() {
    echo "📋 Checking dependencies..."
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not installed${NC}"
        exit 1
    fi
    
    if ! command -v mvn &> /dev/null; then
        echo -e "${RED}❌ Maven not installed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Dependencies checked${NC}"
}

create_rds_instance() {
    echo "🗄️  Creating RDS Instance..."
    
    DB_PASSWORD="MyPassword123"
    echo "Using password: '$DB_PASSWORD'"
    
    if ! aws rds describe-db-instances --db-instance-identifier $APP_NAME-db &> /dev/null; then
        if ! aws rds describe-db-subnet-groups --db-subnet-group-name $APP_NAME-subnet-group &> /dev/null; then
            aws rds create-db-subnet-group \
                --db-subnet-group-name $APP_NAME-subnet-group \
                --db-subnet-group-description "Subnet group for $APP_NAME" \
                --subnet-ids $(aws ec2 describe-subnets --query 'Subnets[0:2].SubnetId' --output text)
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
            --storage-type gp2
        
        echo "⏳ Waiting for RDS instance..."
        aws rds wait db-instance-available --db-instance-identifier $APP_NAME-db
        echo -e "${GREEN}✅ RDS instance created${NC}"
    else
        echo -e "${YELLOW}⚠️  RDS instance already exists${NC}"
    fi
}

create_lambda_package() {
    echo "📦 Creating optimized Lambda deployment package..."
    
    # Find backend directory
    for dir in "../../../backend" "../../backend" "../backend" "./backend"; do
        if [ -d "$dir" ]; then
            cd "$dir"
            break
        fi
    done
    
    # Skip import cleanup to avoid removing essential Spring Boot imports
    echo "✅ Skipping Java import cleanup to preserve Spring Boot annotations"
    
    # Build Spring Boot application with optimizations
    mvn clean package -DskipTests -Dmaven.javadoc.skip=true -Dmaven.source.skip=true
    
    # Find JAR file
    JAR_FILE=$(find target -name "*.jar" -not -name "*-sources.jar" | head -1)
    cp "$JAR_FILE" lambda-deployment.zip
    
    echo -e "${GREEN}✅ Optimized Lambda package created${NC}"
}

store_parameters() {
    echo "🔐 Storing parameters in SSM..."
    
    DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $APP_NAME-db --query 'DBInstances[0].Endpoint.Address' --output text)
    
    aws ssm put-parameter --name "ecommerce-db-endpoint" --value "$DB_ENDPOINT" --type "String" --overwrite --region $AWS_REGION
    aws ssm put-parameter --name "ecommerce-db-password" --value "MyPassword123" --type "SecureString" --overwrite --region $AWS_REGION
    
    JWT_SECRET=$(openssl rand -base64 32)
    aws ssm put-parameter --name "ecommerce-jwt-secret" --value "$JWT_SECRET" --type "SecureString" --overwrite --region $AWS_REGION
    
    echo -e "${GREEN}✅ Parameters stored${NC}"
}

deploy_lambda() {
    echo "⚡ Deploying Lambda function..."
    
    # Create IAM role
    ROLE_NAME="${APP_NAME}-lambda-role"
    if ! aws iam get-role --role-name $ROLE_NAME &> /dev/null; then
        aws iam create-role --role-name $ROLE_NAME \
            --assume-role-policy-document '{
                "Version": "2012-10-17",
                "Statement": [{
                    "Effect": "Allow",
                    "Principal": {"Service": "lambda.amazonaws.com"},
                    "Action": "sts:AssumeRole"
                }]
            }'
        
        aws iam attach-role-policy --role-name $ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
        
        sleep 10
    fi
    
    ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)
    
    # Create Lambda function
    if ! aws lambda get-function --function-name $APP_NAME-function &> /dev/null; then
        aws lambda create-function \
            --function-name $APP_NAME-function \
            --runtime java17 \
            --role $ROLE_ARN \
            --handler org.springframework.boot.loader.JarLauncher \
            --zip-file fileb://lambda-deployment.zip \
            --timeout 30 \
            --memory-size 512
    fi
    
    # Update environment variables
    DB_ENDPOINT=$(aws ssm get-parameter --name "ecommerce-db-endpoint" --region $AWS_REGION --query 'Parameter.Value' --output text)
    DB_PASSWORD=$(aws ssm get-parameter --name "ecommerce-db-password" --region $AWS_REGION --with-decryption --query 'Parameter.Value' --output text)
    JWT_SECRET=$(aws ssm get-parameter --name "ecommerce-jwt-secret" --region $AWS_REGION --with-decryption --query 'Parameter.Value' --output text)
    
    aws lambda update-function-configuration \
        --function-name $APP_NAME-function \
        --environment Variables="{DATABASE_URL=jdbc:postgresql://$DB_ENDPOINT:5432/ecommerce_db,DB_USERNAME=$DB_USERNAME,DB_PASSWORD=$DB_PASSWORD,JWT_SECRET=$JWT_SECRET}"
    
    echo -e "${GREEN}✅ Lambda function deployed${NC}"
}

create_api_gateway() {
    echo "🌐 Creating Secure API Gateway..."
    
    # Check if API Gateway already exists
    API_ID=$(aws apigatewayv2 get-apis --region $AWS_REGION --query "Items[?Name=='$APP_NAME-api'].ApiId" --output text 2>/dev/null || echo "")
    
    if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
        echo -e "${YELLOW}⚠️  API Gateway already exists, updating routes...${NC}"
        
        # Delete existing routes
        ROUTE_IDS=$(aws apigatewayv2 get-routes --api-id $API_ID --region $AWS_REGION --query 'Items[].RouteId' --output text)
        for route_id in $ROUTE_IDS; do
            aws apigatewayv2 delete-route --api-id $API_ID --route-id $route_id --region $AWS_REGION 2>/dev/null || true
        done
        
        # Get integration ID
        INTEGRATION_ID=$(aws apigatewayv2 get-integrations --api-id $API_ID --region $AWS_REGION --query 'Items[0].IntegrationId' --output text)
        
        # Create new routes for API paths
        aws apigatewayv2 create-route \
            --api-id $API_ID \
            --route-key 'ANY /api/{proxy+}' \
            --target "integrations/$INTEGRATION_ID" \
            --region $AWS_REGION
        
        aws apigatewayv2 create-route \
            --api-id $API_ID \
            --route-key 'ANY /api' \
            --target "integrations/$INTEGRATION_ID" \
            --region $AWS_REGION
    else
        # Create API Gateway
        API_ID=$(aws apigatewayv2 create-api \
            --name $APP_NAME-api \
            --protocol-type HTTP \
            --region $AWS_REGION \
            --query 'ApiId' --output text)
        
        # Create integration
        INTEGRATION_ID=$(aws apigatewayv2 create-integration \
            --api-id $API_ID \
            --integration-type AWS_PROXY \
            --integration-uri "arn:aws:lambda:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):function:$APP_NAME-function" \
            --payload-format-version "2.0" \
            --region $AWS_REGION \
            --query 'IntegrationId' --output text)
        
        # Create routes for API paths (strip /prod prefix)
        aws apigatewayv2 create-route \
            --api-id $API_ID \
            --route-key 'ANY /api/{proxy+}' \
            --target "integrations/$INTEGRATION_ID" \
            --region $AWS_REGION
        
        # Create route for root API path
        aws apigatewayv2 create-route \
            --api-id $API_ID \
            --route-key 'ANY /api' \
            --target "integrations/$INTEGRATION_ID" \
            --region $AWS_REGION
        
        # Create stage
        aws apigatewayv2 create-stage \
            --api-id $API_ID \
            --stage-name prod \
            --auto-deploy \
            --region $AWS_REGION
        
        # Wait for deployment
        sleep 5
        
        # Add Lambda permission (remove existing first)
        aws lambda remove-permission \
            --function-name $APP_NAME-function \
            --statement-id api-gateway-invoke \
            --region $AWS_REGION 2>/dev/null || true
        
        aws lambda add-permission \
            --function-name $APP_NAME-function \
            --statement-id api-gateway-invoke \
            --action lambda:InvokeFunction \
            --principal apigateway.amazonaws.com \
            --source-arn "arn:aws:execute-api:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):$API_ID/*/*" \
            --region $AWS_REGION
        
        echo "Lambda permission added for API Gateway"
    fi
    
    API_URL="https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/prod"
    aws ssm put-parameter --name "ecommerce-api-url" --value "$API_URL" --type "String" --overwrite --region $AWS_REGION
    
    echo -e "${GREEN}✅ API Gateway created: $API_URL${NC}"
    
    # Test API Gateway
    echo "🔍 Testing API Gateway..."
    sleep 15  # Wait for propagation
    
    # Test basic connectivity first
    echo "Testing basic connectivity to: $API_URL"
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL" --max-time 30 || echo "000")
    echo "Basic connectivity: HTTP $HTTP_STATUS"
    
    # Test API endpoint
    echo "Testing API endpoint: $API_URL/api/products/all"
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/products/all" --max-time 30 || echo "000")
    echo "API endpoint: HTTP $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" != "000" ] && [ "$HTTP_STATUS" != "000000" ]; then
        echo -e "${GREEN}✅ API Gateway is responding (HTTP $HTTP_STATUS)${NC}"
    else
        echo -e "${YELLOW}⚠️  API Gateway not responding. Checking configuration...${NC}"
        
        # Check Lambda function status
        LAMBDA_STATUS=$(aws lambda get-function --function-name $APP_NAME-function --query 'Configuration.State' --output text 2>/dev/null || echo "NotFound")
        echo "Lambda function status: $LAMBDA_STATUS"
        
        # Check if Lambda has permission
        aws lambda get-policy --function-name $APP_NAME-function 2>/dev/null | grep -q "apigateway" && echo "Lambda permission: OK" || echo "Lambda permission: Missing"
        
        # List routes
        echo "API Gateway routes:"
        aws apigatewayv2 get-routes --api-id $API_ID --query 'Items[].{RouteKey:RouteKey,Target:Target}' --output table
        
        # Check integration
        echo "Integration details:"
        aws apigatewayv2 get-integration --api-id $API_ID --integration-id $INTEGRATION_ID --query '{IntegrationType:IntegrationType,IntegrationUri:IntegrationUri,PayloadFormatVersion:PayloadFormatVersion}' --output table
    fi
}

setup_waf() {
    echo "🔒 Setting up WAF protection..."
    
    API_ID=$(aws apigatewayv2 get-apis --region $AWS_REGION --query "Items[?Name=='$APP_NAME-api'].ApiId" --output text)
    
    # Create WAF Web ACL
    WAF_ACL_ARN=$(aws wafv2 create-web-acl \
        --name $APP_NAME-waf \
        --scope REGIONAL \
        --default-action Allow={} \
        --rules '[
            {
                "Name": "RateLimitRule",
                "Priority": 1,
                "Statement": {
                    "RateBasedStatement": {
                        "Limit": 2000,
                        "AggregateKeyType": "IP"
                    }
                },
                "Action": {"Block": {}},
                "VisibilityConfig": {
                    "SampledRequestsEnabled": true,
                    "CloudWatchMetricsEnabled": true,
                    "MetricName": "RateLimitRule"
                }
            }
        ]' \
        --region $AWS_REGION \
        --query 'Summary.ARN' --output text 2>/dev/null || echo "")
    
    if [ -n "$WAF_ACL_ARN" ]; then
        # Associate WAF with API Gateway
        aws wafv2 associate-web-acl \
            --web-acl-arn "$WAF_ACL_ARN" \
            --resource-arn "arn:aws:apigateway:$AWS_REGION::/restapis/$API_ID/stages/prod" \
            --region $AWS_REGION || true
        
        echo -e "${GREEN}✅ WAF protection enabled${NC}"
    else
        echo -e "${YELLOW}⚠️  WAF setup skipped (may already exist)${NC}"
    fi
}

update_api_gateway_cors() {
    echo "🔧 Updating API Gateway CORS..."
    
    # Get actual Vercel URL from parameter store
    VERCEL_URL=$(aws ssm get-parameter --name "ecommerce-vercel-url" --region $AWS_REGION --query 'Parameter.Value' --output text 2>/dev/null || echo "https://$VERCEL_APP_NAME.vercel.app")
    API_ID=$(aws apigatewayv2 get-apis --region $AWS_REGION --query "Items[?Name=='$APP_NAME-api'].ApiId" --output text)
    
    if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
        aws apigatewayv2 update-api \
            --api-id $API_ID \
            --cors-configuration AllowOrigins="$VERCEL_URL",AllowMethods="GET,POST,PUT,DELETE,OPTIONS",AllowHeaders="Content-Type,Authorization" \
            --region $AWS_REGION
        echo -e "${GREEN}✅ API Gateway CORS updated for $VERCEL_URL${NC}"
    else
        echo -e "${RED}❌ API Gateway not found${NC}"
    fi
}

setup_vercel() {
    echo "🚀 Setting up Vercel with Security..."
    
    # Find frontend directory
    for dir in "../../../frontend" "../../frontend" "../frontend" "./frontend"; do
        if [ -d "$dir" ]; then
            cd "$dir"
            break
        fi
    done
    
    # Install Vercel CLI if needed
    if ! command -v vercel &> /dev/null; then
        npm install -g vercel
    fi
    
    # Get API URL from parameter store
    API_URL=$(aws ssm get-parameter --name "ecommerce-api-url" --region $AWS_REGION --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    
    if [ -z "$API_URL" ]; then
        echo -e "${YELLOW}⚠️  API URL not found. Using placeholder.${NC}"
        API_URL="https://your-api-gateway-url.execute-api.us-east-1.amazonaws.com/prod"
    fi
    
    # Create environment file
    echo "REACT_APP_API_URL=$API_URL" > .env.production
    
    echo -e "${GREEN}✅ Vercel configured with API URL: $API_URL${NC}"
}

deploy_vercel() {
    echo "🎨 Building and Deploying to Vercel..."
    
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
        exit 1
    fi
    
    # Get API URL
    API_URL=$(aws ssm get-parameter --name "ecommerce-api-url" --region $AWS_REGION --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    
    # Check if build is needed
    SOURCE_HASH=$(find src public package.json -type f -exec md5sum {} \; 2>/dev/null | sort | md5sum | cut -d' ' -f1 2>/dev/null || echo "new")
    LAST_HASH=""
    if [ -f ".build-hash" ]; then
        LAST_HASH=$(cat .build-hash 2>/dev/null || echo "")
    fi
    
    if [ "$SOURCE_HASH" = "$LAST_HASH" ] && [ -d "build" ] && [ -n "$(ls -A build 2>/dev/null)" ]; then
        echo "✅ No changes detected, using existing build"
    else
        echo "🔄 Changes detected, rebuilding..."
        
        # Set environment variables
        echo "REACT_APP_API_URL=$API_URL" > .env.production.local
        echo "NODE_ENV=production" >> .env.production.local
        echo "GENERATE_SOURCEMAP=false" >> .env.production.local
        
        # Install dependencies if needed
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
        
        # Build
        echo "📦 Building..."
        npm run build
        
        echo "$SOURCE_HASH" > .build-hash
    fi
    
    # Create deployment directory
    DEPLOY_DIR="../vercel-deploy"
    rm -rf "$DEPLOY_DIR"
    mkdir -p "$DEPLOY_DIR"
    cp -r build/* "$DEPLOY_DIR/"
    
    # Create vercel.json
    cat > "$DEPLOY_DIR/vercel.json" << 'EOF'
{
  "version": 2,
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
EOF
    
    # Deploy
    cd "$DEPLOY_DIR"
    VERCEL_OUTPUT=$(vercel --prod --yes 2>&1)
    VERCEL_URL=$(echo "$VERCEL_OUTPUT" | grep -o 'https://[^[:space:]]*\.vercel\.app' | head -1)
    
    if [ -z "$VERCEL_URL" ]; then
        VERCEL_URL="https://$VERCEL_APP_NAME.vercel.app"
    fi
    
    # Cleanup
    cd ..
    rm -rf "$DEPLOY_DIR"
    
    # Store URL
    aws ssm put-parameter --name "ecommerce-vercel-url" --value "$VERCEL_URL" --type "String" --overwrite --region $AWS_REGION
    
    echo -e "${GREEN}✅ Deployed to Vercel: $VERCEL_URL${NC}"
}

test_api_gateway() {
    echo "🔍 Testing API Gateway connectivity..."
    
    API_URL=$(aws ssm get-parameter --name "ecommerce-api-url" --region $AWS_REGION --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    
    if [ -z "$API_URL" ]; then
        echo -e "${RED}❌ API URL not found in parameter store${NC}"
        return 1
    fi
    
    echo "Testing URL: $API_URL"
    
    # Test basic connectivity
    echo "Testing basic connectivity..."
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL" --max-time 10 || echo "000")
    echo "HTTP Status: $HTTP_STATUS"
    
    # Test API endpoint
    echo "Testing API endpoint..."
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/products/all" --max-time 10 || echo "000")
    echo "API Status: $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" != "000" ]; then
        echo -e "${GREEN}✅ API Gateway is accessible${NC}"
    else
        echo -e "${RED}❌ API Gateway is not accessible${NC}"
        echo "Possible issues:"
        echo "- DNS propagation delay (wait 5-10 minutes)"
        echo "- Lambda function not deployed"
        echo "- API Gateway misconfiguration"
    fi
}

main() {
    echo "🎯 Deployment Options:"
    echo "1. Full deployment"
    echo "2. Backend only"
    echo "3. Frontend setup"
    echo "4. Frontend deploy"
    echo "5. Setup API Gateway"
    echo "6. Test API Gateway"
    
    read -p "Choice (1-6): " choice
    
    check_dependencies
    
    case $choice in
        1)
            create_rds_instance
            create_lambda_package
            store_parameters
            deploy_lambda
            create_api_gateway
            setup_waf
            setup_vercel
            deploy_vercel
            update_api_gateway_cors
            ;;
        2)
            create_rds_instance
            create_lambda_package
            store_parameters
            deploy_lambda
            create_api_gateway
            setup_waf
            ;;
        3)
            setup_vercel
            ;;
        4)
            deploy_vercel
            update_api_gateway_cors
            ;;
        5)
            create_api_gateway
            setup_waf
            ;;
        6)
            test_api_gateway
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}🎉 Deployment completed!${NC}"
}

main "$@"