#!/bin/bash

# Setup HTTPS ALB for ECS Fargate to solve mixed content issues
# This creates an Application Load Balancer with SSL certificate

set -e

echo "🔒 Setting up HTTPS ALB for ECS Fargate..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_REGION=$(aws configure get region || echo "ap-south-1")
APP_NAME="ecommerce-fargate"
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"
DOMAIN_NAME=""

echo "🎯 HTTPS ALB Setup Options:"
echo "1. Create ALB with self-signed certificate (for testing)"
echo "2. Create ALB with custom domain (requires Route53 domain)"
echo "3. Create ALB with existing certificate ARN"

read -p "Choice (1-3): " choice

case $choice in
    1)
        echo "Using self-signed certificate for testing..."
        USE_SELF_SIGNED=true
        ;;
    2)
        read -p "Enter your domain name (e.g., api.yourdomain.com): " DOMAIN_NAME
        if [ -z "$DOMAIN_NAME" ]; then
            echo -e "${RED}❌ Domain name required${NC}"
            exit 1
        fi
        USE_CUSTOM_DOMAIN=true
        ;;
    3)
        read -p "Enter your certificate ARN: " CERT_ARN
        if [ -z "$CERT_ARN" ]; then
            echo -e "${RED}❌ Certificate ARN required${NC}"
            exit 1
        fi
        USE_EXISTING_CERT=true
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

create_https_alb() {
    echo "⚖️ Creating HTTPS Application Load Balancer..."
    
    # Get default VPC and subnets
    VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    SUBNET_IDS=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0:2].SubnetId' --output text | tr '\t' ' ')
    
    # Create ALB security group
    ALB_SG_NAME="$APP_NAME-alb-sg"
    ALB_SG_ID=$(aws ec2 create-security-group \
        --group-name $ALB_SG_NAME \
        --description "HTTPS ALB Security group for $APP_NAME" \
        --vpc-id $VPC_ID \
        --region $AWS_REGION \
        --query 'GroupId' --output text 2>/dev/null || \
        aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$ALB_SG_NAME" --query 'SecurityGroups[0].GroupId' --output text)
    
    # Add HTTPS rules to ALB
    aws ec2 authorize-security-group-ingress \
        --group-id $ALB_SG_ID \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION 2>/dev/null || true
    
    aws ec2 authorize-security-group-ingress \
        --group-id $ALB_SG_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION 2>/dev/null || true
    
    # Create Application Load Balancer
    ALB_ARN=$(aws elbv2 create-load-balancer \
        --name $APP_NAME-https-alb \
        --subnets $SUBNET_IDS \
        --security-groups $ALB_SG_ID \
        --region $AWS_REGION \
        --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || \
        aws elbv2 describe-load-balancers --names $APP_NAME-https-alb --region $AWS_REGION --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --region $AWS_REGION --query 'LoadBalancers[0].DNSName' --output text)
    
    # Create target group
    TG_ARN=$(aws elbv2 create-target-group \
        --name $APP_NAME-https-tg \
        --protocol HTTP \
        --port 8080 \
        --vpc-id $VPC_ID \
        --target-type ip \
        --health-check-path /health \
        --health-check-protocol HTTP \
        --health-check-port 8080 \
        --region $AWS_REGION \
        --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || \
        aws elbv2 describe-target-groups --names $APP_NAME-https-tg --region $AWS_REGION --query 'TargetGroups[0].TargetGroupArn' --output text)
    
    echo "ALB_ARN=$ALB_ARN" > alb-https-info.env
    echo "TG_ARN=$TG_ARN" > tg-https-info.env
    echo "ALB_DNS=$ALB_DNS" > alb-https-dns.env
    
    echo -e "${GREEN}✅ HTTPS ALB created: $ALB_DNS${NC}"
}

setup_ssl_certificate() {
    echo "🔐 Setting up SSL certificate..."
    
    if [ "$USE_SELF_SIGNED" = true ]; then
        # Create self-signed certificate for testing
        echo "Creating self-signed certificate..."
        
        # Generate private key
        openssl genrsa -out private-key.pem 2048
        
        # Generate certificate signing request
        openssl req -new -key private-key.pem -out csr.pem -subj "/C=US/ST=State/L=City/O=Organization/CN=*.elb.amazonaws.com"
        
        # Generate self-signed certificate
        openssl x509 -req -in csr.pem -signkey private-key.pem -out certificate.pem -days 365
        
        # Import certificate to ACM
        CERT_ARN=$(aws acm import-certificate \
            --certificate fileb://certificate.pem \
            --private-key fileb://private-key.pem \
            --region $AWS_REGION \
            --query 'CertificateArn' --output text)
        
        # Cleanup
        rm -f private-key.pem csr.pem certificate.pem
        
    elif [ "$USE_CUSTOM_DOMAIN" = true ]; then
        # Request certificate for custom domain
        echo "Requesting certificate for domain: $DOMAIN_NAME"
        
        CERT_ARN=$(aws acm request-certificate \
            --domain-name $DOMAIN_NAME \
            --validation-method DNS \
            --region $AWS_REGION \
            --query 'CertificateArn' --output text)
        
        echo -e "${YELLOW}⚠️  Certificate requested. You need to validate it via DNS.${NC}"
        echo -e "${YELLOW}   Check ACM console and add the DNS validation records to your domain.${NC}"
        echo -e "${YELLOW}   This script will wait for validation...${NC}"
        
        # Wait for certificate validation
        echo "Waiting for certificate validation..."
        aws acm wait certificate-validated --certificate-arn $CERT_ARN --region $AWS_REGION
        
    elif [ "$USE_EXISTING_CERT" = true ]; then
        # Use existing certificate
        echo "Using existing certificate: $CERT_ARN"
    fi
    
    echo "CERT_ARN=$CERT_ARN" > cert-info.env
    echo -e "${GREEN}✅ SSL certificate ready: $CERT_ARN${NC}"
}

create_https_listeners() {
    echo "🔗 Creating HTTPS listeners..."
    
    # Load ALB and certificate info
    ALB_ARN=$(cat alb-https-info.env | grep ALB_ARN | cut -d'=' -f2)
    TG_ARN=$(cat tg-https-info.env | grep TG_ARN | cut -d'=' -f2)
    CERT_ARN=$(cat cert-info.env | grep CERT_ARN | cut -d'=' -f2)
    
    # Create HTTP listener (redirects to HTTPS)
    aws elbv2 create-listener \
        --load-balancer-arn $ALB_ARN \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=redirect,RedirectConfig='{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}' \
        --region $AWS_REGION 2>/dev/null || true
    
    # Create HTTPS listener
    aws elbv2 create-listener \
        --load-balancer-arn $ALB_ARN \
        --protocol HTTPS \
        --port 443 \
        --certificates CertificateArn=$CERT_ARN \
        --default-actions Type=forward,TargetGroupArn=$TG_ARN \
        --region $AWS_REGION 2>/dev/null || true
    
    echo -e "${GREEN}✅ HTTPS listeners created${NC}"
}

update_ecs_service() {
    echo "🔄 Updating ECS service to use ALB..."
    
    # Load target group info
    TG_ARN=$(cat tg-https-info.env | grep TG_ARN | cut -d'=' -f2)
    
    # Get current service configuration
    SERVICE_EXISTS=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].status' --output text 2>/dev/null || echo "INACTIVE")
    
    if [ "$SERVICE_EXISTS" = "ACTIVE" ]; then
        echo "Updating existing service to use load balancer..."
        
        # Get current task definition
        TASK_DEF=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].taskDefinition' --output text)
        
        # Get VPC configuration
        VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
        SUBNET_IDS=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0:2].SubnetId' --output text | tr '\t' ',')
        
        # Get ECS security group
        SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$APP_NAME-sg" --query 'SecurityGroups[0].GroupId' --output text)
        
        # Delete current service
        aws ecs update-service \
            --cluster $CLUSTER_NAME \
            --service $SERVICE_NAME \
            --desired-count 0 \
            --region $AWS_REGION
        
        # Wait for service to scale down
        echo "Waiting for service to scale down..."
        aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION
        
        # Delete the service
        aws ecs delete-service \
            --cluster $CLUSTER_NAME \
            --service $SERVICE_NAME \
            --region $AWS_REGION
        
        # Wait a bit
        sleep 30
        
        # Create new service with load balancer
        aws ecs create-service \
            --cluster $CLUSTER_NAME \
            --service-name $SERVICE_NAME \
            --task-definition $TASK_DEF \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
            --load-balancers targetGroupArn=$TG_ARN,containerName=$APP_NAME-container,containerPort=8080 \
            --region $AWS_REGION
        
        echo -e "${GREEN}✅ ECS service updated with ALB${NC}"
    else
        echo -e "${YELLOW}⚠️  ECS service not found. Please deploy ECS service first.${NC}"
    fi
}

update_ssm_parameters() {
    echo "📝 Updating SSM parameters..."
    
    ALB_DNS=$(cat alb-https-dns.env | grep ALB_DNS | cut -d'=' -f2)
    
    if [ "$USE_CUSTOM_DOMAIN" = true ]; then
        HTTPS_URL="https://$DOMAIN_NAME"
    else
        HTTPS_URL="https://$ALB_DNS"
    fi
    
    # Update API URL to HTTPS
    aws ssm put-parameter --name "ecommerce-api-url" --value "$HTTPS_URL" --type "String" --overwrite --region $AWS_REGION
    
    echo -e "${GREEN}✅ API URL updated to: $HTTPS_URL${NC}"
}

setup_route53() {
    if [ "$USE_CUSTOM_DOMAIN" = true ]; then
        echo "🌐 Setting up Route53 record..."
        
        ALB_DNS=$(cat alb-https-dns.env | grep ALB_DNS | cut -d'=' -f2)
        
        # Extract domain parts
        DOMAIN_PARTS=(${DOMAIN_NAME//./ })
        if [ ${#DOMAIN_PARTS[@]} -ge 2 ]; then
            ROOT_DOMAIN="${DOMAIN_PARTS[-2]}.${DOMAIN_PARTS[-1]}"
        else
            ROOT_DOMAIN="$DOMAIN_NAME"
        fi
        
        # Get hosted zone ID
        HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='$ROOT_DOMAIN.'].Id" --output text | cut -d'/' -f3)
        
        if [ -n "$HOSTED_ZONE_ID" ] && [ "$HOSTED_ZONE_ID" != "None" ]; then
            # Create Route53 record
            cat > route53-record.json << EOF
{
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "$DOMAIN_NAME",
            "Type": "CNAME",
            "TTL": 300,
            "ResourceRecords": [{"Value": "$ALB_DNS"}]
        }
    }]
}
EOF
            
            aws route53 change-resource-record-sets \
                --hosted-zone-id $HOSTED_ZONE_ID \
                --change-batch file://route53-record.json
            
            rm -f route53-record.json
            
            echo -e "${GREEN}✅ Route53 record created for $DOMAIN_NAME${NC}"
        else
            echo -e "${YELLOW}⚠️  Hosted zone not found for $ROOT_DOMAIN. Please create DNS record manually.${NC}"
            echo -e "${YELLOW}   Point $DOMAIN_NAME to $ALB_DNS${NC}"
        fi
    fi
}

main() {
    create_https_alb
    setup_ssl_certificate
    create_https_listeners
    update_ecs_service
    update_ssm_parameters
    setup_route53
    
    echo -e "${GREEN}🎉 HTTPS ALB setup completed!${NC}"
    
    if [ "$USE_CUSTOM_DOMAIN" = true ]; then
        echo -e "${GREEN}✅ Your HTTPS API is available at: https://$DOMAIN_NAME${NC}"
    else
        ALB_DNS=$(cat alb-https-dns.env | grep ALB_DNS | cut -d'=' -f2)
        echo -e "${GREEN}✅ Your HTTPS API is available at: https://$ALB_DNS${NC}"
    fi
    
    echo -e "${YELLOW}ℹ️  Mixed content issues should now be resolved!${NC}"
    echo -e "${YELLOW}ℹ️  Redeploy your Vercel frontend to use the new HTTPS URL${NC}"
}

main "$@"