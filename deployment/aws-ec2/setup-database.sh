#!/bin/bash
set -e

# Install PostgreSQL
sudo amazon-linux-extras install -y postgresql13
sudo yum install -y postgresql-server postgresql-contrib

# Initialize database
sudo postgresql-setup initdb

# Start and enable PostgreSQL
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE ecommerce_db;
CREATE USER ecommerce WITH PASSWORD 'ecommerce123';
GRANT ALL PRIVILEGES ON DATABASE ecommerce_db TO ecommerce;
ALTER USER ecommerce CREATEDB;
\q
EOF

# Configure PostgreSQL to allow connections
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf
echo "host all all 127.0.0.1/32 md5" | sudo tee -a /var/lib/pgsql/data/pg_hba.conf

# Restart PostgreSQL
sudo systemctl restart postgresql

echo "PostgreSQL setup complete!"
echo "Database: ecommerce_db"
echo "User: ecommerce"
echo "Password: ecommerce123"