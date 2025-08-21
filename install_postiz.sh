#!/bin/bash
set -e

# ==========================
# 🔧 Variables (Edit these)
# ==========================
DOMAIN="postiz.soufianeautomation.space"
EMAIL="soufianeouakifbsn@gmail.com"

# ==========================
echo "🔄 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installing dependencies..."
sudo apt install -y docker.io docker-compose curl nginx certbot python3-certbot-nginx

# ==========================
echo "📂 Creating Postiz directory..."
mkdir -p /opt/postiz && cd /opt/postiz

# ==========================
echo "⚙️ Creating docker-compose.yml..."
cat > docker-compose.yml <<EOL
version: '3.9'
services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    environment:
      MAIN_URL: "https://${DOMAIN}"
      FRONTEND_URL: "https://${DOMAIN}"
      NEXT_PUBLIC_BACKEND_URL: "https://${DOMAIN}/api"
      JWT_SECRET: "$(openssl rand -hex 32)"
      DATABASE_URL: "postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local"
      REDIS_URL: "redis://postiz-redis:6379"
      BACKEND_INTERNAL_URL: "http://localhost:3000"
      IS_GENERAL: "true"
      STORAGE_PROVIDER: "local"
      UPLOAD_DIRECTORY: "/uploads"
      NEXT_PUBLIC_UPLOAD_DIRECTORY: "/uploads"
    volumes:
      - postiz-config:/config/
      - postiz-uploads:/uploads/
    ports:
      - "5000:5000"
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
EOL

# ==========================
echo "▶️ Starting Postiz..."
sudo docker compose up -d

# ==========================
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/postiz <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/postiz /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# ==========================
echo "🔒 Setting up SSL with Certbot..."
sudo certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL}

# ==========================
echo "✅ Installation finished!"
echo "👉 Visit: https://${DOMAIN}"
