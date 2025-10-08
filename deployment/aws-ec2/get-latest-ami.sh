#!/bin/bash

# Get latest Amazon Linux 2 AMI ID for any region
REGION=${1:-ap-south-1}

echo "Getting latest Amazon Linux 2 AMI for region: $REGION"

AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
  --region $REGION \
  --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
  --output text)

echo "Latest AMI ID: $AMI_ID"
echo "Update your .env file with: AMI_ID=$AMI_ID"