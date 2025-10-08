#!/bin/bash
set -e

# Install certbot for Let's Encrypt
sudo yum update -y
sudo yum install -y certbot python3-certbot-nginx

# Get the public IP
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
echo "Public IP: $PUBLIC_IP"

# Create nginx config for HTTP challenge
sudo tee /etc/nginx/conf.d/default.conf > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        return 200 'Backend is running! API available at /api/';
        add_header Content-Type text/plain;
    }
}
EOF

# Create web root directory
sudo mkdir -p /var/www/html
sudo chown nginx:nginx /var/www/html

# Reload nginx
sudo nginx -t && sudo systemctl reload nginx

echo "Setup complete!"
echo "To get SSL certificate, you need a domain name pointing to: $PUBLIC_IP"
echo "Then run: sudo certbot --nginx -d yourdomain.com"