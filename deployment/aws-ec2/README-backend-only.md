# Backend-Only EC2 Deployment

Simple deployment script for Spring Boot backend API on EC2 t2.micro (Free Tier).

## What it does

- Builds backend JAR (`mvn package`)
- Embeds JAR in EC2 user-data (no S3 needed)
- Creates keypair and security group (ports 22, 8080)
- Launches t2.micro instance with systemd service
- Backend runs on port 8080

## Usage

1. Copy `.env.example` to `.env` and edit variables
2. Run: `./deploy-backend-only.sh`
3. Access API at: `http://<public-ip>:8080/`

## Resources Created

- **EC2 t2.micro**: Backend API server
- **EBS 8GB**: Root volume (required)
- **Security Group**: SSH + port 8080
- **Key Pair**: SSH access

## Free Tier Usage

- **EC2**: 750 hours/month (within limit)
- **EBS**: 8GB/30GB (within limit)
- **No S3**: Zero storage costs
- **Total services**: 2 (EC2 + EBS)

## API Endpoints

Your Spring Boot API will be available at:
- `http://<ip>:8080/api/auth/login`
- `http://<ip>:8080/api/products`
- `http://<ip>:8080/api/orders`
- etc.

## SSH Access

```bash
ssh -i your-key.pem ec2-user@<public-ip>
```

## Service Management

```bash
# Check status
sudo systemctl status ecommerce-backend

# View logs
sudo journalctl -u ecommerce-backend -f

# Restart
sudo systemctl restart ecommerce-backend
```