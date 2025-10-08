#!/bin/bash
set -e

DB_ENDPOINT="mahavirfaral-db.c3wm66u2mamb.ap-south-1.rds.amazonaws.com"
DB_USERNAME="ecommerceadmin"
DB_PASSWORD="MyPassword123"

# Create application.yml with RDS connection
sudo tee /home/ec2-user/application.yml > /dev/null << EOF
spring:
  datasource:
    url: jdbc:postgresql://$DB_ENDPOINT:5432/postgres
    username: $DB_USERNAME
    password: $DB_PASSWORD
    driver-class-name: org.postgresql.Driver
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: false
server:
  port: 8080
jwt:
  secret: myVerySecureSecretKeyThatIsLongEnoughForJWTHMACSHA256AlgorithmForTest
  expiration: 86400000
EOF

# Create systemd service for backend
sudo tee /etc/systemd/system/ecommerce-backend.service > /dev/null << EOF
[Unit]
Description=Ecommerce Backend
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user
ExecStart=/usr/bin/java -jar /home/ec2-user/app.jar --spring.config.location=/home/ec2-user/application.yml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create nginx config
sudo tee /etc/nginx/conf.d/default.conf > /dev/null << EOF
server {
    listen 80;
    server_name _;

    location /api/ {
        proxy_pass http://localhost:8080/;
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

# Start services
sudo systemctl daemon-reload
sudo systemctl enable ecommerce-backend
sudo systemctl start ecommerce-backend
sudo systemctl enable nginx
sudo systemctl start nginx

echo "Services started successfully!"
sudo systemctl status ecommerce-backend --no-pager
sudo systemctl status nginx --no-pager