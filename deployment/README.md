# Deployment Options

This directory contains deployment configurations for different cloud platforms and architectures.

## 📁 Directory Structure

```
deployment/
├── vercel/          # Vercel + Fly.io + Supabase
├── aws/
│   ├── ec2-rds/     # S3 + EC2 + RDS
│   └── lambda-rds/  # S3 + Lambda + RDS
└── README.md
```

## 🚀 Deployment Options

### 1. Vercel + Fly.io + Supabase
**Best for:** Rapid prototyping, small to medium applications
- **Frontend:** Vercel (React hosting)
- **Backend:** Fly.io (Docker containers)
- **Database:** Supabase (Managed PostgreSQL)

```bash
cd vercel
chmod +x deploy.sh
./deploy.sh
```

### 2. AWS EC2 + RDS + S3
**Best for:** Traditional server-based applications, full control
- **Frontend:** S3 Static Website
- **Backend:** EC2 Instance (Spring Boot)
- **Database:** RDS PostgreSQL

```bash
cd aws/ec2-rds
chmod +x deploy-ec2-rds.sh
./deploy-ec2-rds.sh
```

### 3. AWS Lambda + RDS + S3
**Best for:** Serverless applications, cost optimization
- **Frontend:** S3 Static Website
- **Backend:** Lambda Functions (Serverless Spring Boot)
- **Database:** RDS PostgreSQL

```bash
cd aws/lambda-rds
chmod +x deploy-lambda-rds.sh
./deploy-lambda-rds.sh
```

## 📊 Comparison

| Feature | Vercel+Fly+Supabase | AWS EC2+RDS | AWS Lambda+RDS |
|---------|---------------------|-------------|----------------|
| **Setup Time** | ⭐⭐⭐⭐⭐ Fast | ⭐⭐⭐ Medium | ⭐⭐ Complex |
| **Cost (Small)** | ⭐⭐⭐⭐ Low | ⭐⭐⭐ Medium | ⭐⭐⭐⭐⭐ Very Low |
| **Scalability** | ⭐⭐⭐⭐ Auto | ⭐⭐ Manual | ⭐⭐⭐⭐⭐ Auto |
| **Control** | ⭐⭐ Limited | ⭐⭐⭐⭐⭐ Full | ⭐⭐⭐ Medium |
| **Maintenance** | ⭐⭐⭐⭐⭐ Minimal | ⭐⭐ High | ⭐⭐⭐⭐ Low |

## 🛠️ Prerequisites

### All Deployments
- Git repository with your code
- Node.js 16+
- Java 17+

### Vercel + Fly.io + Supabase
- Vercel account
- Fly.io account
- Supabase account

### AWS Deployments
- AWS account with CLI configured
- Appropriate IAM permissions
- For Lambda: SAM CLI installed

## 🔧 Configuration

Each deployment option includes:
- Automated setup scripts
- Environment configuration
- Database migrations
- Security configurations
- Monitoring setup

## 📝 Post-Deployment

After deployment:
1. Update DNS settings (if using custom domain)
2. Configure SSL certificates
3. Set up monitoring and alerts
4. Test all application features
5. Update environment variables as needed

## 🆘 Troubleshooting

Common issues and solutions are documented in each deployment folder's README file.

## 🔒 Security Notes

- All deployments include HTTPS/SSL
- Database credentials are securely stored
- CORS is properly configured
- JWT secrets are generated automatically