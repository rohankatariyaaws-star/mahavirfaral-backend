#!/bin/bash
set -e

DOMAIN=$1
if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <your-domain.com>"
    echo "Example: $0 api.mahavirfaral.com"
    exit 1
fi

echo "Setting up SSL certificate for domain: $DOMAIN"

# Install certbot
sudo yum update -y
sudo yum install -y certbot python3-certbot-nginx

# Create temporary nginx config for domain verification
sudo tee /etc/nginx/conf.d/default.conf > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        return 200 'Backend is running! API available at /api/';
        add_header Content-Type text/plain;
    }
}
EOF

# Create web root
sudo mkdir -p /var/www/html
sudo chown nginx:nginx /var/www/html

# Test nginx config
sudo nginx -t && sudo systemctl reload nginx

echo "Nginx configured for domain: $DOMAIN"
echo ""
echo "IMPORTANT: Before running certbot, make sure:"
echo "1. Domain $DOMAIN points to this server's IP: $(curl -s http://checkip.amazonaws.com)"
echo "2. DNS A record is propagated (check with: nslookup $DOMAIN)"
echo ""
echo "To get SSL certificate, run:"
echo "sudo certbot --nginx -d $DOMAIN --email your-email@example.com --agree-tos --non-interactive"
echo ""
echo "After SSL is installed, your API will be available at:"
echo "https://$DOMAIN/api/"