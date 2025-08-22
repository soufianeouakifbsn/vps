#!/bin/bash

# 📌 Variables
DOMAIN="postiz.soufianeautomation.space" # Replace with your domain
EMAIL="you@example.com"          # Replace with your email for SSL management

echo "🚀 Starting Postiz installation on $DOMAIN..."

# --- 1. System Prerequisites ---
echo "⚙️  Updating system packages and installing prerequisites..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# --- 2. Postiz Docker Compose Setup ---
echo "🐳 Configuring and running Postiz with Docker Compose..."

# Create a directory for Postiz files
mkdir -p ~/postiz_data
cd ~/postiz_data

# Create the docker-compose.yml file
sudo tee docker-compose.yml > /dev/null <<EOF
services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    environment:
      # You must change these. Replace your-server.com with your DNS name - this needs to be exactly the URL you're accessing Postiz on.
      MAIN_URL: "https://$DOMAIN"
      FRONTEND_URL: "https://$DOMAIN"
      NEXT_PUBLIC_BACKEND_URL: "https://$DOMAIN/api"
      JWT_SECRET: "random_string_that_is_unique_to_every_install_change_me"
 
      # These defaults are probably fine, but if you change your user/password, update it in the
      # postiz-postgres or postiz-redis services below.
      DATABASE_URL: "postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local"
      REDIS_URL: "redis://postiz-redis:6379"
      BACKEND_INTERNAL_URL: "http://localhost:3000"
      IS_GENERAL: "true" # Required for self-hosting.
      DISABLE_REGISTRATION: "false" # Only allow single registration, then disable signup
      # The container images are pre-configured to use /uploads for file storage.
      # You probably should not change this unless you have a really good reason!
      STORAGE_PROVIDER: "local"
      UPLOAD_DIRECTORY: "/uploads"
      NEXT_PUBLIC_UPLOAD_DIRECTORY: "/uploads"
    volumes:
      - postiz-config:/config/
      - postiz-uploads:/uploads/
    ports:
      - 5000:5000
    networks:
      - postiz-network
    depends_on:
      postiz-postgres:
        condition: service_healthy
      postiz-redis:
        condition: service_healthy
 
  postiz-postgres:
    image: postgres:17-alpine
    container_name: postiz-postgres
    restart: always
    environment:
      POSTGRES_PASSWORD: postiz-password
      POSTGRES_USER: postiz-user
      POSTGRES_DB: postiz-db-local
    volumes:
      - postgres-volume:/var/lib/postgresql/data
    networks:
      - postiz-network
    healthcheck:
      test: pg_isready -U postiz-user -d postiz-db-local
      interval: 10s
      timeout: 3s
      retries: 3
  postiz-redis:
    image: redis:7.2
    container_name: postiz-redis
    restart: always
    healthcheck:
      test: redis-cli ping
      interval: 10s
      timeout: 3s
      retries: 3
    volumes:
      - postiz-redis-data:/data
    networks:
      - postiz-network
 
 
volumes:
  postgres-volume:
    external: false
 
  postiz-redis-data:
    external: false
 
  postiz-config:
    external: false
 
  postiz-uploads:
    external: false
 
networks:
  postiz-network:
    external: false
EOF

# Start the services
sudo docker-compose up -d

# --- 3. Nginx Reverse Proxy & SSL Setup ---
echo "🌐 Setting up Nginx as a reverse proxy and obtaining SSL certificate..."

# Create Nginx configuration file
sudo tee /etc/nginx/sites-available/postiz.conf > /dev/null <<EOF
server {
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Enable the site and restart Nginx
sudo ln -s /etc/nginx/sites-available/postiz.conf /etc/nginx/sites-enabled/ || true
sudo nginx -t && sudo systemctl restart nginx

# Obtain SSL certificate
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# --- 4. Firewall Configuration ---
echo "🛡️  Configuring the UFW firewall..."
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo "✅ Postiz has been installed successfully!"
echo "🎉 You can now access the web interface at https://$DOMAIN"
echo "🔧 If you encounter issues, check the Docker logs with: sudo docker-compose logs"
