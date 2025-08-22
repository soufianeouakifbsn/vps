#!/bin/bash

# 📌 Configuration
DOMAIN="postiz.soufianeautomation.space"  # Change to your domain
EMAIL="your-email@gmail.com"     # Your email for SSL
JWT_SECRET=$(openssl rand -base64 32)  # Generate random JWT secret

echo "🚀 Starting Postiz installation on $DOMAIN..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Create Postiz directory
mkdir -p ~/postiz
cd ~/postiz

# Create docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    environment:
      MAIN_URL: "https://$DOMAIN"
      FRONTEND_URL: "https://$DOMAIN"
      NEXT_PUBLIC_BACKEND_URL: "https://$DOMAIN/api"
      JWT_SECRET: "$JWT_SECRET"
      DATABASE_URL: "postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local"
      REDIS_URL: "redis://postiz-redis:6379"
      BACKEND_INTERNAL_URL: "http://localhost:3000"
      IS_GENERAL: "true"
      DISABLE_REGISTRATION: "false"
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
  postiz-redis-data:
  postiz-config:
  postiz-uploads:

networks:
  postiz-network:
EOF

# Start Postiz containers
sudo docker-compose up -d

# Create Nginx configuration
sudo tee /etc/nginx/sites-available/postiz.conf > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/postiz.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# Obtain SSL certificate
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# Configure firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo "✅ Postiz installation completed!"
echo "📌 Access your instance at: https://$DOMAIN"
echo "🔑 JWT Secret: $JWT_SECRET"
echo "⚠️  Remember to:"
echo "   1. Update your DNS records to point to this server"
echo "   2. Keep your JWT secret secure"
echo "   3. Check logs with: docker-compose logs -f"
