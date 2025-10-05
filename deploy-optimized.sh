#!/bin/bash

# Optimized deployment script for AWS

echo "Building optimized frontend..."
cd frontend
npm run build
aws s3 sync build/ s3://your-bucket-name --delete
aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"

echo "Building backend..."
cd ../backend
./mvnw clean package -DskipTests

echo "Deploying to EC2..."
# Copy jar to EC2 and restart service
scp target/ecommerce-0.0.1-SNAPSHOT.jar ec2-user@your-ec2-ip:/home/ec2-user/
ssh ec2-user@your-ec2-ip "sudo systemctl restart ecommerce"

echo "Running database optimizations..."
psql -h your-rds-endpoint -U postgres -d ecommerce_db -f ../database-indexes.sql

echo "Deployment complete!"