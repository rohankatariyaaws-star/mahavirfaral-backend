#!/bin/bash
set -e

# Create SSL certificate
mkdir -p /tmp/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/ssl/selfsigned.key \
  -out /tmp/ssl/selfsigned.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Create nginx HTTPS config
cat > /tmp/ssl/nginx-https.conf << 'EOF'
server {
    listen 80;
    server_name _;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate /etc/ssl/certs/selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/selfsigned.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location /api/ {
        proxy_pass http://localhost:8080/;
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

echo "Files created in /tmp/ssl/"
ls -la /tmp/ssl/