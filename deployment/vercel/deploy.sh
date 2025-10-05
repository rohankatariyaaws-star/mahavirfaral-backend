#!/bin/bash

# Ecommerce App Deployment Script
# Deploys Frontend to Vercel, Backend to Fly.io, and Database to Supabase

set -e

echo "🚀 Starting Ecommerce App Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check dependencies based on deployment choice
check_dependencies() {
    echo "📋 Checking dependencies..."
    
    case $1 in
        1|4) # Full deployment or Frontend only
            if ! command -v npm &> /dev/null; then
                echo -e "${RED}❌ npm is not installed${NC}"
                exit 1
            fi
            
            if ! command -v vercel &> /dev/null; then
                echo -e "${YELLOW}⚠️  Vercel CLI not found. Installing...${NC}"
                npm install -g vercel
            fi
            ;;
    esac
    
    case $1 in
        1|2) # Full deployment or Database only
            if ! command -v supabase &> /dev/null; then
                echo -e "${YELLOW}⚠️  Supabase CLI not found. Installing...${NC}"
                npm install -g supabase
            fi
            ;;
    esac
    
    case $1 in
        1|3) # Full deployment or Backend only
            if ! command -v flyctl &> /dev/null; then
                echo -e "${RED}❌ Fly.io CLI not found. Please install: https://fly.io/docs/getting-started/installing-flyctl/${NC}"
                exit 1
            fi
            ;;
    esac
    
    echo -e "${GREEN}✅ Dependencies checked${NC}"
}

# Deploy database to Supabase
deploy_database() {
    echo "🗄️  Setting up Supabase database..."
    
    cd backend
    
    # Initialize Supabase project if not exists
    if [ ! -f "supabase/config.toml" ]; then
        supabase init
    fi
    
    # Start local Supabase (for migration testing)
    supabase start
    
    # Apply database migrations
    supabase db reset
    
    # Deploy to Supabase cloud
    echo "Please link your Supabase project:"
    supabase link
    supabase db push
    
    echo -e "${GREEN}✅ Database deployed to Supabase${NC}"
    cd ..
}

# Deploy backend to Fly.io
deploy_backend() {
    echo "🔧 Deploying backend to Fly.io..."
    
    cd backend
    
    # Build the application
    ./mvnw clean package -DskipTests
    
    # Initialize Fly app if not exists
    if [ ! -f "fly.toml" ]; then
        flyctl launch --no-deploy
    fi
    
    # Deploy to Fly.io
    flyctl deploy
    
    echo -e "${GREEN}✅ Backend deployed to Fly.io${NC}"
    cd ..
}

# Deploy frontend to Vercel
deploy_frontend() {
    echo "🎨 Deploying frontend to Vercel..."
    
    cd frontend
    
    # Install dependencies
    npm install
    
    # Build the application
    npm run build
    
    # Deploy to Vercel
    vercel --prod
    
    echo -e "${GREEN}✅ Frontend deployed to Vercel${NC}"
    cd ..
}

# Main deployment function
main() {
    echo "🎯 Choose deployment option:"
    echo "1. Full deployment (Database + Backend + Frontend)"
    echo "2. Database only (Supabase)"
    echo "3. Backend only (Fly.io)"
    echo "4. Frontend only (Vercel)"
    
    read -p "Enter your choice (1-4): " choice
    
    check_dependencies $choice
    
    case $choice in
        1)
            deploy_database
            deploy_backend
            deploy_frontend
            ;;
        2)
            deploy_database
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
    
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
}

main "$@"