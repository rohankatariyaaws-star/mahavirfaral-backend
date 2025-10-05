#!/bin/bash

echo "🚀 Setting up Netlify deployment..."

# Find frontend directory
for dir in "../../../frontend" "../../frontend" "../frontend" "./frontend"; do
    if [ -d "$dir" ]; then
        cd "$dir"
        break
    fi
done

# Install Netlify CLI if needed
if ! command -v netlify &> /dev/null; then
    npm install -g netlify-cli
fi

# Get API URL from SSM parameter
API_URL=$(aws ssm get-parameter --name "ecommerce-api-url" --region ap-south-1 --query 'Parameter.Value' --output text 2>/dev/null || echo "http://localhost:8080")

# Create environment file
echo "REACT_APP_API_URL=$API_URL" > .env.production

echo "✅ Netlify configured with API URL: $API_URL"