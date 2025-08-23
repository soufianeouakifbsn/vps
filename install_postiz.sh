#!/bin/bash

# -----------------------------
# 🚀 Install Postiz on Ubuntu 24.04
# Soufiane Automation
# -----------------------------

# 📌 Variables
DOMAIN="postiz.soufianeautomation.space"
EMAIL="soufianeouakifbsn@gmail.com"
POSTIZ_DIR="/opt/postiz"
JWT_SECRET=$(openssl rand -hex 32)

echo "📦 Updating system..."
apt update -y && apt upgrade -y

echo "🐳 Installing Docker & Docker Compose..."
apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

# Docker repo
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update -y
  apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

systemctl enable docker
systemctl start docker

echo "📂 Creating Postiz directory..."
mkdir -p $POSTIZ_DIR
cd $POSTIZ_DIR

echo "📝 Creating docker-compose.yml..."
cat > docker-compose.yml <<EOL
version: '3.9'

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
      test: ["CMD-SHELL", "pg_isready -U postiz-user -d postiz-db-local"]
      interval: 10s
      timeout: 3s
      retries: 3

  postiz-redis:
    image: redis:7.2
    container_name: postiz-redis
    restart: always
    command: ["redis-server", "--appendonly", "yes"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
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
EOL

echo "🌐 Installing Nginx & Certbot..."
apt install -y nginx certbot python3-certbot-nginx

echo "⚙️ Configuring Nginx reverse proxy..."
cat > /etc/nginx/sites-available/postiz <<EOF
server {
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/postiz /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "🔐 Installing SSL certificate..."
certbot --nginx -d $DOMAIN -m $EMAIL --agree-tos --non-interactive

echo "🚀 Starting Postiz with Docker Compose..."
docker compose up -d

echo "✅ Installation finished!"
echo "🌍 Access Postiz at: https://$DOMAIN"
