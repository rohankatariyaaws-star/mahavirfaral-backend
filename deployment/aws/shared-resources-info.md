# Shared Resources Across Deployments

This document explains which resources are shared across Lambda, ECS Fargate, and EC2 deployments to optimize costs and avoid duplication.

## 🔄 **Shared Resources**

### **1. RDS Database**
- **Resource Names**: `ecommerce-lambda-db`, `ecommerce-fargate-db`, `ecommerce-ec2-db`
- **Sharing Logic**: Scripts automatically detect and reuse existing database from any deployment
- **Cost Savings**: ~$12-15/month per avoided duplicate
- **Data**: All deployments share the same database and data

### **2. Vercel Frontend Deployment**
- **Resource**: Single Vercel app deployment
- **Parameter**: `ecommerce-vercel-url` (shared SSM parameter)
- **Sharing Logic**: All backend deployments update the same frontend with their API URL
- **Cost Savings**: Free (Vercel free tier)
- **Behavior**: Frontend automatically connects to the most recently deployed backend

### **3. SSM Parameters (Shared)**
- **`ecommerce-vercel-url`**: Frontend URL (shared across all deployments)
- **`ecommerce-db-endpoint`**: Database endpoint (if using shared DB)
- **`ecommerce-db-password`**: Database password (if using shared DB)

### **4. SSM Parameters (Deployment-Specific)**
- **`ecommerce-api-url`**: Backend API URL (overwritten by each deployment)
- **`ecommerce-jwt-secret`**: JWT secret (deployment-specific for security)

## 🏗️ **Deployment-Specific Resources**

### **Lambda Deployment**
- Lambda function: `ecommerce-lambda-function`
- API Gateway: `ecommerce-lambda-api`
- IAM Role: `ecommerce-lambda-lambda-role`
- WAF: `ecommerce-lambda-waf`

### **ECS Fargate Deployment**
- ECS Cluster: `ecommerce-fargate-cluster`
- ECS Service: `ecommerce-fargate-service`
- Task Definition: `ecommerce-fargate-task`
- ECR Repository: `ecommerce-fargate`
- Security Group: `ecommerce-fargate-sg`
- IAM Role: `ecommerce-fargate-execution-role`

### **EC2 Deployment**
- EC2 Instance: Tagged with `ecommerce-ec2`
- Security Group: `ecommerce-ec2-sg`
- Key Pair: `ecommerce-ec2-key`

## 💰 **Cost Optimization Strategy**

### **What Gets Shared (Cost Savings)**
1. **RDS Database**: Only one instance needed (~$12-15/month saved per duplicate)
2. **Vercel Frontend**: Free tier covers all deployments
3. **Data Storage**: Single database for all backends

### **What Stays Separate (Necessary)**
1. **Backend Infrastructure**: Each deployment type needs its own compute resources
2. **Security Groups**: Different networking requirements
3. **IAM Roles**: Different permission requirements
4. **API URLs**: Each backend has its own endpoint

## 🔄 **Switching Between Deployments**

### **To Switch from Lambda to ECS Fargate:**
1. Run ECS deployment script
2. Frontend automatically connects to ECS backend
3. Database and data remain unchanged
4. Clean up Lambda resources when ready

### **To Switch from ECS to EC2:**
1. Run EC2 deployment script
2. Frontend automatically connects to EC2 backend
3. Database and data remain unchanged
4. Clean up ECS resources when ready

## 🧹 **Resource Cleanup**

### **Safe to Delete (Deployment-Specific)**
- Lambda: Function, API Gateway, IAM roles, WAF
- ECS: Cluster, services, task definitions, ECR images
- EC2: Instances, security groups, key pairs

### **Shared Resources (Keep)**
- RDS Database (unless switching to different database)
- Vercel Frontend (unless changing frontend)
- Shared SSM parameters

## 📋 **Resource Inventory Commands**

```bash
# Check existing databases
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output table

# Check SSM parameters
aws ssm describe-parameters --query 'Parameters[?starts_with(Name, `ecommerce`)].Name' --output table

# Check Vercel URL
aws ssm get-parameter --name "ecommerce-vercel-url" --query 'Parameter.Value' --output text

# Check current API URL
aws ssm get-parameter --name "ecommerce-api-url" --query 'Parameter.Value' --output text
```

This approach ensures **maximum cost efficiency** while maintaining **deployment flexibility**.