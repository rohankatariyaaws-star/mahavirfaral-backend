# EC2 Single-Instance Deployment (Free Tier friendly)

This folder contains a small helper to deploy both backend and frontend onto a single EC2 instance (t2.micro) suitable for development and testing on AWS Free Tier.

What it does

- Packages backend JAR (runs `mvn package` if needed)
- Builds frontend (`npm install && npm run build`) and syncs build to S3
- Uploads artifacts to an S3 bucket and creates presigned URLs
- Creates a keypair (if missing) and a security group allowing SSH/HTTP/HTTPS/8080
- Launches an Amazon Linux 2 `t2.micro` instance with HTTPS-enabled nginx and systemd service for backend
- Configures self-signed SSL certificate for HTTPS
- Sets up API proxy at `/api/` endpoint
- Prints a free-accessible host via nip.io (https://<public-ip>.nip.io/) — no DNS purchase required for testing

Usage

1. Copy `.env.example` to `.env` and edit the variables (APP_NAME, AWS_REGION, KEY_NAME, etc.)
2. Make the scripts executable:
   ```bash
   chmod +x deploy-ec2.sh setup-letsencrypt.sh
   ```
3. Run the deployment:
   ```bash
   ./deploy-ec2.sh
   ```
4. Access your application at the provided HTTPS URL
5. (Optional) Setup Let's Encrypt if you have a domain

SSL Certificate Options

1. **Self-signed certificate** (default): Automatically created during deployment
2. **Let's Encrypt certificate**: Use `setup-letsencrypt.sh` script after deployment if you have a domain

For Let's Encrypt:
```bash
# SSH into your instance
ssh -i your-key.pem ec2-user@<public-ip>
# Run the setup script
./setup-letsencrypt.sh your-domain.com
```

Notes & caveats

- This is a minimal, development-friendly setup with HTTPS support
- Uses self-signed SSL certificate by default (browsers will show security warning)
- Backend runs as systemd service for better reliability
- API endpoints available at `/api/` path
- The instance uses public IP and nip.io for a free developer-friendly hostname
- Clean up resources (EC2, S3 bucket, keypair, security group) when done to avoid charges
- AMI ID is region-specific; replace `AMI_ID` in `.env` if necessary
