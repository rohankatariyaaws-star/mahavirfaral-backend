@echo off
echo Fixing HTTPS on current EC2 instance...

ssh -i mahavirfaral-ec2-key.pem -o StrictHostKeyChecking=no ec2-user@65.0.21.120 "sudo mkdir -p /etc/ssl/private && sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/selfsigned.key -out /etc/ssl/certs/selfsigned.crt -subj '/C=US/ST=State/L=City/O=Organization/CN=localhost' && sudo tee /etc/nginx/conf.d/default.conf > /dev/null << 'EOF'
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
sudo nginx -t && sudo systemctl reload nginx"

echo.
echo HTTPS setup complete!
echo Access your API at: https://65.0.21.120/api/
echo Note: Browser will show security warning due to self-signed certificate