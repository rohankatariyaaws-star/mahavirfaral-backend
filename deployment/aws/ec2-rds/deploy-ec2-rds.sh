#!/bin/bash

# AWS EC2 + RDS + S3 Deployment Script
# Deploys Frontend to S3, Backend to EC2, Database to RDS

set -e

echo "🚀 Starting AWS EC2+RDS Deployment..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_REGION="us-east-1"
APP_NAME="ecommerce-app"
KEY_NAME="${APP_NAME}-key"
SECURITY_GROUP="${APP_NAME}-sg"
DB_NAME="ecommerce_db"
DB_USERNAME="admin"
S3_BUCKET="${APP_NAME}-frontend-$(date +%s)"

check_dependencies() {
    echo "📋 Checking dependencies..."
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not installed${NC}"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}❌ npm not installed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Dependencies checked${NC}"
}

create_key_pair() {
    echo "🔑 Creating EC2 Key Pair..."
    
    if ! aws ec2 describe-key-pairs --key-names $KEY_NAME &> /dev/null; then
        aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
        chmod 400 ${KEY_NAME}.pem
        echo -e "${GREEN}✅ Key pair created: ${KEY_NAME}.pem${NC}"
    else
        echo -e "${YELLOW}⚠️  Key pair already exists${NC}"
    fi
}

create_security_group() {
    echo "🛡️  Creating Security Group..."
    
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)
    
    if ! aws ec2 describe-security-groups --group-names $SECURITY_GROUP &> /dev/null; then
        SG_ID=$(aws ec2 create-security-group --group-name $SECURITY_GROUP --description "Security group for $APP_NAME" --vpc-id $VPC_ID --query 'GroupId' --output text)
        
        # Allow SSH
        aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
        # Allow HTTP
        aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
        # Allow HTTPS
        aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
        # Allow Spring Boot
        aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0
        
        echo -e "${GREEN}✅ Security group created: $SG_ID${NC}"
    else
        echo -e "${YELLOW}⚠️  Security group already exists${NC}"
    fi
}

create_rds_instance() {
    echo "🗄️  Creating RDS Instance..."
    
    DB_PASSWORD=$(openssl rand -base64 12)
    echo "Database password: $DB_PASSWORD" > db-credentials.txt
    
    if ! aws rds describe-db-instances --db-instance-identifier $APP_NAME-db &> /dev/null; then
        aws rds create-db-instance \
            --db-instance-identifier $APP_NAME-db \
            --db-instance-class db.t3.micro \
            --engine postgres \
            --master-username $DB_USERNAME \
            --master-user-password $DB_PASSWORD \
            --allocated-storage 20 \
            --vpc-security-group-ids $(aws ec2 describe-security-groups --group-names $SECURITY_GROUP --query 'SecurityGroups[0].GroupId' --output text) \
            --publicly-accessible \
            --no-multi-az \
            --storage-type gp2
        
        echo "⏳ Waiting for RDS instance to be available..."
        aws rds wait db-instance-available --db-instance-identifier $APP_NAME-db
        
        echo -e "${GREEN}✅ RDS instance created${NC}"
    else
        echo -e "${YELLOW}⚠️  RDS instance already exists${NC}"
    fi
}

create_ec2_instance() {
    echo "💻 Creating EC2 Instance..."
    
    # Get latest Amazon Linux 2 AMI
    AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text)
    
    if ! aws ec2 describe-instances --filters "Name=tag:Name,Values=$APP_NAME-backend" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text | grep -v "None"; then
        INSTANCE_ID=$(aws ec2 run-instances \
            --image-id $AMI_ID \
            --count 1 \
            --instance-type t2.micro \
            --key-name $KEY_NAME \
            --security-groups $SECURITY_GROUP \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$APP_NAME-backend}]" \
            --query 'Instances[0].InstanceId' \
            --output text)
        
        echo "⏳ Waiting for EC2 instance to be running..."
        aws ec2 wait instance-running --instance-ids $INSTANCE_ID
        
        echo -e "${GREEN}✅ EC2 instance created: $INSTANCE_ID${NC}"
    else
        echo -e "${YELLOW}⚠️  EC2 instance already exists${NC}"
    fi
}

deploy_backend() {
    echo "🔧 Deploying Backend to EC2..."
    
    INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$APP_NAME-backend" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text)
    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    
    # Get RDS endpoint
    DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $APP_NAME-db --query 'DBInstances[0].Endpoint.Address' --output text)
    DB_PASSWORD=$(cat db-credentials.txt | cut -d' ' -f3)
    
    # Create deployment script
    cat > deploy-backend.sh << EOF
#!/bin/bash
sudo yum update -y
sudo yum install -y java-17-amazon-corretto git

# Clone and build application
git clone https://github.com/your-repo/ecommerce-app.git
cd ecommerce-app/backend

# Set environment variables
export DATABASE_URL="jdbc:postgresql://$DB_ENDPOINT:5432/$DB_NAME"
export DB_USERNAME="$DB_USERNAME"
export DB_PASSWORD="$DB_PASSWORD"
export JWT_SECRET="$(openssl rand -base64 32)"
export FRONTEND_URL="http://$S3_BUCKET.s3-website-$AWS_REGION.amazonaws.com"

# Build and run
./mvnw clean package -DskipTests
nohup java -jar target/ecommerce-0.0.1-SNAPSHOT.jar > app.log 2>&1 &
EOF
    
    # Copy and execute deployment script
    scp -i ${KEY_NAME}.pem -o StrictHostKeyChecking=no deploy-backend.sh ec2-user@$PUBLIC_IP:/tmp/
    ssh -i ${KEY_NAME}.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "chmod +x /tmp/deploy-backend.sh && /tmp/deploy-backend.sh"
    
    echo -e "${GREEN}✅ Backend deployed to EC2${NC}"
}

create_s3_bucket() {
    echo "🪣 Creating S3 Bucket..."
    
    if ! aws s3 ls s3://$S3_BUCKET &> /dev/null; then
        aws s3 mb s3://$S3_BUCKET --region $AWS_REGION
        
        # Configure for static website hosting
        aws s3 website s3://$S3_BUCKET --index-document index.html --error-document index.html
        
        # Set public read policy
        cat > bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$S3_BUCKET/*"
        }
    ]
}
EOF
        aws s3api put-bucket-policy --bucket $S3_BUCKET --policy file://bucket-policy.json
        
        echo -e "${GREEN}✅ S3 bucket created: $S3_BUCKET${NC}"
    else
        echo -e "${YELLOW}⚠️  S3 bucket already exists${NC}"
    fi
}

deploy_frontend() {
    echo "🎨 Deploying Frontend to S3..."
    
    cd ../../../frontend
    
    # Get backend URL
    INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$APP_NAME-backend" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text)
    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    
    # Set environment variable
    echo "REACT_APP_API_URL=http://$PUBLIC_IP:8080/api" > .env.production
    
    # Build and deploy
    npm install
    npm run build
    
    aws s3 sync build/ s3://$S3_BUCKET --delete
    
    echo -e "${GREEN}✅ Frontend deployed to S3${NC}"
    echo -e "${GREEN}🌐 Frontend URL: http://$S3_BUCKET.s3-website-$AWS_REGION.amazonaws.com${NC}"
}

main() {
    echo "🎯 AWS EC2+RDS Deployment Options:"
    echo "1. Full deployment"
    echo "2. Infrastructure only"
    echo "3. Backend only"
    echo "4. Frontend only"
    
    read -p "Enter your choice (1-4): " choice
    
    check_dependencies
    
    case $choice in
        1)
            create_key_pair
            create_security_group
            create_rds_instance
            create_ec2_instance
            create_s3_bucket
            deploy_backend
            deploy_frontend
            ;;
        2)
            create_key_pair
            create_security_group
            create_rds_instance
            create_ec2_instance
            create_s3_bucket
            ;;
        3)
            deploy_backend
            ;;
        4)
            deploy_frontend
            ;;
        *)
            echo -e "${RED}❌ Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}🎉 Deployment completed!${NC}"
}

main "$@"