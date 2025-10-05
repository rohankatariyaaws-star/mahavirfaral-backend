# EC2 Single-Instance Deployment (Free Tier friendly)

This folder contains a small helper to deploy both backend and frontend onto a single EC2 instance (t2.micro) suitable for development and testing on AWS Free Tier.

What it does

- Packages backend JAR (runs `mvn package` if needed)
- Builds frontend (`npm install && npm run build`) and syncs build to S3
- Uploads artifacts to an S3 bucket and creates presigned URLs
- Creates a keypair (if missing) and a security group allowing SSH/HTTP/8080
- Launches an Amazon Linux 2 `t2.micro` instance and uses user-data to download artifacts and run the backend + nginx for frontend
- Prints a free-accessible host via nip.io (http://<public-ip>.nip.io/) — no DNS purchase required for testing

Usage

1. Copy `.env.example` to `.env` and edit the variables (APP_NAME, AWS_REGION, KEY_NAME, etc.)
2. Make the script executable:
   chmod +x deploy-ec2.sh
3. Run:
   ./deploy-ec2.sh

Notes & caveats

- This is a minimal, development-friendly setup. It's not intended for production (no HTTPS, no scaling, no monitoring).
- The instance uses public IP and nip.io for a free developer-friendly hostname.
- Clean up resources (EC2, S3 bucket, keypair, security group) when done to avoid charges.
- AMI ID is region-specific; replace `AMI_ID` in `.env` if necessary.
