#!/bin/bash

# AWS EC2 + RDS + Vercel Deployment Script (Alternative to ECS)
# Deploys Backend to EC2, Database to RDS, Frontend to Vercel

set -e

echo "🚀 Starting AWS EC2+RDS+Vercel Deployment..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-ec2"
DB_USERNAME="ecommerceadmin"
VERCEL_APP_NAME="mahavirfaral"
INSTANCE_TYPE="t2.micro"  # Free tier eligible
KEY_NAME="$APP_NAME-key"

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

create_key_pair() {
    echo "🔑 Creating EC2 Key Pair..."
    
    if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $AWS_REGION &> /dev/null; then
        aws ec2 create-key-pair --key-name $KEY_NAME --region $AWS_REGION --query 'KeyMaterial' --output text > $KEY_NAME.pem
        chmod 400 $KEY_NAME.pem
        echo -e "${GREEN}✅ Key pair created: $KEY_NAME.pem${NC}"
    else
        echo -e "${YELLOW}⚠️  Key pair already exists${NC}"
    fi
}

find_or_create_rds_instance() {
    echo "🗄️  Finding or Creating RDS Instance..."
    
    DB_PASSWORD="MyPassword123"
    
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

create_security_group() {
    echo "🔒 Creating Security Group..."
    
    VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    SG_NAME="$APP_NAME-sg"
    
    SG_ID=$(aws ec2 create-security-group \
        --group-name $SG_NAME \
        --description "Security group for $APP_NAME" \
        --vpc-id $VPC_ID \
        --region $AWS_REGION \
        --query 'GroupId' --output text 2>/dev/null || \
        aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$SG_NAME" --query 'SecurityGroups[0].GroupId' --output text)
    
    # Add inbound rules
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $AWS_REGION 2>/dev/null || true
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region $AWS_REGION 2>/dev/null || true
    
    echo "Security Group ID: $SG_ID"
    echo "$SG_ID" > sg-id.txt
}

create_user_data_script() {
    echo "📝 Creating user data script..."
    
    # Get database endpoint from existing or new instance
    if [ -f ".db-instance-id" ]; then
        DB_INSTANCE_ID=$(cat .db-instance-id)
    else
        DB_INSTANCE_ID=$APP_NAME-db
    fi
    
    DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)
    
    cat > user-data.sh << EOF
#!/bin/bash
yum update -y
yum install -y java-17-amazon-corretto

# Create application directory
mkdir -p /opt/ecommerce
cd /opt/ecommerce

# Create application.properties
cat > application.properties << 'PROPS'
spring.datasource.url=jdbc:postgresql://$DB_ENDPOINT:5432/ecommerce_db
spring.datasource.username=$DB_USERNAME
spring.datasource.password=MyPassword123
spring.jpa.hibernate.ddl-auto=update
spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect
server.port=8080
jwt.secret=$(openssl rand -base64 32)
PROPS

echo "Application setup completed" > /var/log/ecommerce-setup.log
EOF
}

launch_ec2_instance() {
    echo "🚀 Launching EC2 Instance..."
    
    create_user_data_script
    
    # Get latest Amazon Linux 2 AMI
    AMI_ID=$(aws ec2 describe-images \
        --owners amazon \
        --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
        --region $AWS_REGION \
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
        --output text)
    
    SG_ID=$(cat sg-id.txt)
    
    # Launch instance
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --count 1 \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --security-group-ids $SG_ID \
        --user-data file://user-data.sh \
        --region $AWS_REGION \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    echo "Instance ID: $INSTANCE_ID"
    echo "$INSTANCE_ID" > instance-id.txt
    
    # Wait for instance to be running
    echo "⏳ Waiting for instance to be running..."
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
    
    # Get public IP
    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo -e "${GREEN}✅ EC2 Instance launched: $PUBLIC_IP${NC}"
    
    # Store API URL
    API_URL="http://$PUBLIC_IP:8080"
    aws ssm put-parameter --name "ecommerce-api-url" --value "$API_URL" --type "String" --overwrite --region $AWS_REGION
    
    echo "API URL: $API_URL"
}

deploy_application() {
    echo "📦 Deploying Application to EC2..."
    
    # Build JAR file
    for dir in "../../../backend" "../../backend" "../backend" "./backend"; do
        if [ -d "$dir" ]; then
            cd "$dir"
            break
        fi
    done
    
    mvn clean package -DskipTests -Dmaven.javadoc.skip=true -Dmaven.source.skip=true
    JAR_FILE=$(find target -name "*.jar" -not -name "*-sources.jar" | head -1)
    
    # Get instance details
    cd ../ec2
    INSTANCE_ID=$(cat instance-id.txt)
    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    
    echo "Deploying to: $PUBLIC_IP"
    
    # Wait for SSH to be available
    echo "⏳ Waiting for SSH access..."
    sleep 60
    
    # Copy JAR file and start application
    scp -i $KEY_NAME.pem -o StrictHostKeyChecking=no $JAR_FILE ec2-user@$PUBLIC_IP:/opt/ecommerce/app.jar
    
    # Start application
    ssh -i $KEY_NAME.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP << 'REMOTE'
cd /opt/ecommerce
nohup java -jar app.jar --spring.config.location=application.properties > app.log 2>&1 &
echo "Application started"
REMOTE
    
    echo -e "${GREEN}✅ Application deployed${NC}"
    
    # Test the application
    echo "🔍 Testing application..."
    sleep 30
    API_URL="http://$PUBLIC_IP:8080"
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/auth/test" --max-time 30 || echo "000")
    echo "Application test: HTTP $HTTP_STATUS"
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
        API_URL="https://your-api-gateway-url.execute-api.$AWS_REGION.amazonaws.com/prod"
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
    
    # Store URL (shared across all deployments)
    aws ssm put-parameter --name "ecommerce-vercel-url" --value "$VERCEL_URL" --type "String" --overwrite --region $AWS_REGION
    
    echo -e "${GREEN}✅ Deployed to Vercel: $VERCEL_URL${NC}"
    echo -e "${YELLOW}ℹ️  Vercel URL is shared across all deployment types${NC}"
}

main() {
    echo "🎯 Deployment Options:"
    echo "1. Full deployment (RDS + EC2 + Vercel)"
    echo "2. Backend only (RDS + EC2)"
    echo "3. Frontend only (Vercel)"
    echo "4. Create infrastructure only"
    echo "5. Deploy application only"
    
    read -p "Choice (1-5): " choice
    
    check_dependencies
    
    case $choice in
        1)
            create_key_pair
            find_or_create_rds_instance
            create_security_group
            launch_ec2_instance
            deploy_application
            setup_vercel
            deploy_vercel
            ;;
        2)
            create_key_pair
            find_or_create_rds_instance
            create_security_group
            launch_ec2_instance
            deploy_application
            ;;
        3)
            setup_vercel
            deploy_vercel
            ;;
        4)
            create_key_pair
            create_rds_instance
            create_security_group
            launch_ec2_instance
            ;;
        5)
            deploy_application
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}🎉 Deployment completed!${NC}"
}

main "$@"