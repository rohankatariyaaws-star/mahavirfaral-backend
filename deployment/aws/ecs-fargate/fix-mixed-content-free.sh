#!/bin/bash

# Free solutions for mixed content issues without ALB
# Uses Vercel serverless functions as HTTPS proxy

set -e

echo "🔒 Setting up FREE mixed content solutions..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

AWS_REGION=$(aws configure get region || echo "ap-south-1")

echo "🎯 Free Mixed Content Solutions:"
echo "1. Vercel API proxy (Recommended - completely free)"
echo "2. Cloudflare tunnel (Free tier available)"
echo "3. ngrok tunnel (Free tier with limitations)"

read -p "Choice (1-3): " choice

setup_vercel_proxy() {
    echo "🚀 Setting up Vercel API proxy..."
    
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
    
    # Create API directory for Vercel serverless functions
    mkdir -p api
    
    # Create catch-all proxy function
    cat > api/[...path].js << 'EOF'
export default async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  try {
    // Get the API URL from environment or SSM
    const API_URL = process.env.BACKEND_API_URL || 'http://localhost:8080';
    
    // Construct target URL
    const { path } = req.query;
    const pathString = Array.isArray(path) ? path.join('/') : (path || '');
    const targetUrl = `${API_URL}/${pathString}`;
    
    console.log(`Proxying ${req.method} ${targetUrl}`);
    
    // Prepare headers
    const headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Vercel-Proxy/1.0'
    };
    
    // Copy authorization header if present
    if (req.headers.authorization) {
      headers.Authorization = req.headers.authorization;
    }
    
    // Prepare fetch options
    const fetchOptions = {
      method: req.method,
      headers: headers
    };
    
    // Add body for non-GET requests
    if (req.method !== 'GET' && req.method !== 'HEAD' && req.body) {
      fetchOptions.body = JSON.stringify(req.body);
    }
    
    // Make request to backend
    const response = await fetch(targetUrl, fetchOptions);
    
    // Handle different content types
    const contentType = response.headers.get('content-type');
    let data;
    
    if (contentType && contentType.includes('application/json')) {
      data = await response.json();
    } else {
      data = await response.text();
    }
    
    // Return response
    return res.status(response.status).json(data);
    
  } catch (error) {
    console.error('Proxy error:', error);
    return res.status(500).json({ 
      error: 'Proxy error', 
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
}
EOF
    
    # Create API utility for frontend
    mkdir -p src/utils
    cat > src/utils/api.js << 'EOF'
// API utility that automatically uses proxy in production
const API_BASE_URL = process.env.NODE_ENV === 'production' 
  ? '/api'  // Use Vercel proxy in production
  : process.env.REACT_APP_API_URL || 'http://localhost:8080';

export const apiCall = async (endpoint, options = {}) => {
  const url = process.env.NODE_ENV === 'production'
    ? `${API_BASE_URL}/${endpoint.replace(/^\//, '')}`
    : `${API_BASE_URL}/${endpoint.replace(/^\//, '')}`;
  
  const defaultOptions = {
    headers: {
      'Content-Type': 'application/json',
    },
  };
  
  const mergedOptions = {
    ...defaultOptions,
    ...options,
    headers: {
      ...defaultOptions.headers,
      ...options.headers,
    },
  };
  
  try {
    const response = await fetch(url, mergedOptions);
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const contentType = response.headers.get('content-type');
    if (contentType && contentType.includes('application/json')) {
      return await response.json();
    }
    
    return await response.text();
  } catch (error) {
    console.error('API call failed:', error);
    throw error;
  }
};

// Convenience methods
export const api = {
  get: (endpoint) => apiCall(endpoint, { method: 'GET' }),
  post: (endpoint, data) => apiCall(endpoint, { 
    method: 'POST', 
    body: JSON.stringify(data) 
  }),
  put: (endpoint, data) => apiCall(endpoint, { 
    method: 'PUT', 
    body: JSON.stringify(data) 
  }),
  delete: (endpoint) => apiCall(endpoint, { method: 'DELETE' }),
};

export default api;
EOF
    
    # Update vercel.json for proper routing
    cat > vercel.json << 'EOF'
{
  "version": 2,
  "functions": {
    "api/[...path].js": {
      "maxDuration": 30
    }
  },
  "rewrites": [
    {
      "source": "/api/(.*)",
      "destination": "/api/[...path]"
    },
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        {
          "key": "Access-Control-Allow-Origin",
          "value": "*"
        },
        {
          "key": "Access-Control-Allow-Methods",
          "value": "GET, POST, PUT, DELETE, OPTIONS"
        },
        {
          "key": "Access-Control-Allow-Headers",
          "value": "Content-Type, Authorization"
        }
      ]
    }
  ]
}
EOF
    
    echo -e "${GREEN}✅ Vercel proxy setup completed${NC}"
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo "1. Replace all fetch() calls in your React components with api.get(), api.post(), etc."
    echo "2. Set BACKEND_API_URL environment variable in Vercel dashboard"
    echo "3. Redeploy your Vercel app"
    echo ""
    echo "Example usage in React:"
    echo "  import api from './utils/api';"
    echo "  const products = await api.get('api/products/all');"
}

setup_cloudflare_tunnel() {
    echo "🌐 Setting up Cloudflare Tunnel..."
    
    echo -e "${YELLOW}📋 Cloudflare Tunnel Setup Instructions:${NC}"
    echo ""
    echo "1. Install cloudflared:"
    echo "   wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    echo "   chmod +x cloudflared-linux-amd64"
    echo "   sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared"
    echo ""
    echo "2. Login to Cloudflare:"
    echo "   cloudflared tunnel login"
    echo ""
    echo "3. Create tunnel:"
    echo "   cloudflared tunnel create ecommerce-api"
    echo ""
    echo "4. Get your ECS IP:"
    
    # Get current ECS IP
    CLUSTER_NAME="ecommerce-fargate-cluster"
    SERVICE_NAME="ecommerce-fargate-service"
    
    TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text 2>/dev/null || echo "")
    
    if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
        ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text 2>/dev/null || echo "")
        if [ -n "$ENI_ID" ]; then
            PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $AWS_REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text 2>/dev/null || echo "")
            if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
                echo "   Current ECS IP: $PUBLIC_IP"
                echo ""
                echo "5. Run tunnel:"
                echo "   cloudflared tunnel run --url http://$PUBLIC_IP:8080 ecommerce-api"
            fi
        fi
    fi
    
    echo ""
    echo "6. Configure DNS in Cloudflare dashboard to point to your tunnel"
    echo ""
    echo -e "${GREEN}✅ Cloudflare tunnel provides free HTTPS for your HTTP backend${NC}"
}

setup_ngrok_tunnel() {
    echo "🚇 Setting up ngrok tunnel..."
    
    echo -e "${YELLOW}📋 ngrok Setup Instructions:${NC}"
    echo ""
    echo "1. Install ngrok:"
    echo "   curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null"
    echo "   echo 'deb https://ngrok-agent.s3.amazonaws.com buster main' | sudo tee /etc/apt/sources.list.d/ngrok.list"
    echo "   sudo apt update && sudo apt install ngrok"
    echo ""
    echo "2. Sign up at https://ngrok.com and get your auth token"
    echo ""
    echo "3. Configure ngrok:"
    echo "   ngrok config add-authtoken YOUR_AUTH_TOKEN"
    echo ""
    echo "4. Get your ECS IP and run tunnel:"
    
    # Get current ECS IP
    CLUSTER_NAME="ecommerce-fargate-cluster"
    SERVICE_NAME="ecommerce-fargate-service"
    
    TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text 2>/dev/null || echo "")
    
    if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
        ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text 2>/dev/null || echo "")
        if [ -n "$ENI_ID" ]; then
            PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $AWS_REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text 2>/dev/null || echo "")
            if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
                echo "   Current ECS IP: $PUBLIC_IP"
                echo "   ngrok http $PUBLIC_IP:8080"
            fi
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}⚠️  Free ngrok has limitations:${NC}"
    echo "   - Random URLs that change on restart"
    echo "   - 2 hour session limit"
    echo "   - Limited bandwidth"
    echo ""
    echo -e "${GREEN}✅ ngrok provides HTTPS tunnel to your HTTP backend${NC}"
}

update_vercel_env() {
    echo "🔧 Updating Vercel environment variables..."
    
    # Get current ECS IP
    CLUSTER_NAME="ecommerce-fargate-cluster"
    SERVICE_NAME="ecommerce-fargate-service"
    
    TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text 2>/dev/null || echo "")
    
    if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
        ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $AWS_REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text 2>/dev/null || echo "")
        if [ -n "$ENI_ID" ]; then
            PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $AWS_REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text 2>/dev/null || echo "")
            if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
                BACKEND_URL="http://$PUBLIC_IP:8080"
                echo -e "${GREEN}✅ Current ECS backend URL: $BACKEND_URL${NC}"
                echo ""
                echo -e "${YELLOW}📝 Add this environment variable in Vercel dashboard:${NC}"
                echo "   BACKEND_API_URL = $BACKEND_URL"
                echo ""
                echo "Or use Vercel CLI:"
                echo "   vercel env add BACKEND_API_URL"
                echo "   (Enter: $BACKEND_URL)"
            fi
        fi
    fi
}

main() {
    case $choice in
        1)
            setup_vercel_proxy
            update_vercel_env
            ;;
        2)
            setup_cloudflare_tunnel
            ;;
        3)
            setup_ngrok_tunnel
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}🎉 Mixed content solution setup completed!${NC}"
    echo -e "${YELLOW}💡 Recommendation: Use Vercel proxy (Option 1) as it's completely free and reliable${NC}"
}

main "$@"