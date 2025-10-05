#!/bin/bash

# Update Vercel with correct API URL

AWS_REGION=$(aws configure get region || echo "ap-south-1")

# Get the correct API URL from parameter store
API_URL=$(aws ssm get-parameter --name "ecommerce-api-url" --region $AWS_REGION --query 'Parameter.Value' --output text 2>/dev/null || echo "")

echo "Current API URL in parameter store: $API_URL"

# Test the correct endpoint
if [ -n "$API_URL" ]; then
    echo "Testing: $API_URL/api/products/all"
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/products/all" --max-time 30 || echo "000")
    echo "API Test Result: HTTP $HTTP_STATUS"
fi

# Find frontend directory and update environment
for dir in "../../../frontend" "../../frontend" "../frontend" "./frontend" "frontend"; do
    if [ -d "$dir" ]; then
        cd "$dir"
        echo "✅ Frontend directory found: $(pwd)"
        
        # Update environment files
        echo "REACT_APP_API_URL=$API_URL" > .env.production
        echo "REACT_APP_API_URL=$API_URL" > .env.production.local
        
        echo "✅ Updated frontend environment with: $API_URL"
        
        # Force rebuild by removing build cache
        rm -f .build-hash
        rm -rf build
        
        echo "✅ Cleared build cache to force rebuild"
        break
    fi
done

echo "Now run the deployment script with option 4 (Frontend deploy) to update Vercel"