#!/bin/bash

echo "🎨 Building and Deploying to Netlify..."

# Find frontend directory
for dir in "../../../frontend" "../../frontend" "../frontend" "./frontend" "frontend"; do
    if [ -d "$dir" ]; then
        cd "$dir"
        echo "✅ Frontend directory found: $(pwd)"
        break
    fi
done

# Get API URL
API_URL=$(aws ssm get-parameter --name "ecommerce-api-url" --region ap-south-1 --query 'Parameter.Value' --output text 2>/dev/null || echo "http://localhost:8080")

# Set environment variables
echo "REACT_APP_API_URL=$API_URL" > .env.production.local
echo "NODE_ENV=production" >> .env.production.local

# Install dependencies
npm install --no-audit --no-fund

# Build
npm run build

# Deploy to existing Netlify site
read -p "Enter your Netlify site ID: " NETLIFY_SITE_ID

if [ -n "$NETLIFY_SITE_ID" ]; then
    netlify deploy --prod --dir=build --site=$NETLIFY_SITE_ID
    echo "✅ Deployed to existing Netlify site: $NETLIFY_SITE_ID"
else
    echo "❌ Site ID required for deployment"
fi