#!/bin/bash
set -e

source .env

INSTANCE_IP="65.2.74.13"
JAR_FILE="../../backend/target/ecommerce-backend-1.0.0.jar"

echo "Uploading JAR to EC2..."
scp -i mahavirfaral-ec2-key.pem -o StrictHostKeyChecking=no "$JAR_FILE" ec2-user@$INSTANCE_IP:/home/ec2-user/app.jar

echo "Setting up backend service..."
ssh -i mahavirfaral-ec2-key.pem -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << 'EOF'
# Install Java 17 if not present
sudo yum update -y
sudo yum install -y java-17-amazon-corretto nginx

# Create systemd service
sudo tee /etc/systemd/system/ecommerce-backend.service > /dev/null << 'EOL'
[Unit]
Description=Ecommerce Backend
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user
ExecStart=/usr/bin/java -jar /home/ec2-user/app.jar
Restart=always
RestartSec=10
Environment=SPRING_PROFILES_ACTIVE=prod

[Install]
WantedBy=multi-user.target
EOL

# Start services
sudo systemctl daemon-reload
sudo systemctl enable ecommerce-backend
sudo systemctl start ecommerce-backend

# Configure nginx
sudo tee /etc/nginx/conf.d/default.conf > /dev/null << 'EOL'
server {
    listen 80;
    server_name _;

    location /api/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
    }
}
EOL

sudo systemctl enable nginx
sudo systemctl restart nginx

echo "Services status:"
sudo systemctl status ecommerce-backend --no-pager
sudo systemctl status nginx --no-pager
EOF

echo "Deployment fixed! Backend should be accessible at:"
echo "http://$INSTANCE_IP:8080 (direct)"
echo "http://$INSTANCE_IP/api/ (via nginx)"