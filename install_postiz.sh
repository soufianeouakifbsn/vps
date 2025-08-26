#!/bin/bash

# -----------------------------
# 🚀 Install Postiz on Ubuntu 24.04 (Self-contained in /opt/postiz)
# Soufiane Automation
# -----------------------------

# 📌 Variables
DOMAIN="postiz2.soufianeautomation.space"
EMAIL="soufianeouakifbsn@gmail.com"
BASE_DIR="/opt/postiz"
JWT_SECRET=$(openssl rand -hex 32)

# -----------------------------
# System Update
# -----------------------------
echo "📦 Updating system..."
apt update -y && apt upgrade -y

# -----------------------------
# Install Docker & Docker Compose
# -----------------------------
echo "🐳 Installing Docker & Docker Compose..."
apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update -y
  apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

systemctl enable docker
systemctl start docker

# -----------------------------
# Prepare Directories
# -----------------------------
echo "📂 Creating Postiz directory..."
mkdir -p $BASE_DIR/{nginx,certbot,uploads,config,db,redis}
cd $BASE_DIR

# -----------------------------
# Create docker-compose.yml
# -----------------------------
echo "📝 Creating docker-compose.yml..."
cat > docker-compose.yml <<EOL
version: "3.9"

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
      BACKEND_INTERNAL_URL: "http://postiz:5000"
      IS_GENERAL: "true"
      DISABLE_REGISTRATION: "false"
      STORAGE_PROVIDER: "local"
      UPLOAD_DIRECTORY: "/uploads"
      NEXT_PUBLIC_UPLOAD_DIRECTORY: "/uploads"

      # ------------------------
      # Social App Credentials (replace with your values)
      # ------------------------
      GOOGLE_CLIENT_ID: "replace-with-google-client-id"
      GOOGLE_CLIENT_SECRET: "replace-with-google-secret"
      YOUTUBE_CLIENT_ID: "replace-with-youtube-client-id"
      YOUTUBE_CLIENT_SECRET: "replace-with-youtube-secret"
      FACEBOOK_CLIENT_ID: "replace-with-facebook-client-id"
      FACEBOOK_CLIENT_SECRET: "replace-with-facebook-secret"
      INSTAGRAM_CLIENT_ID: "replace-with-instagram-client-id"
      INSTAGRAM_CLIENT_SECRET: "replace-with-instagram-secret"
      LINKEDIN_CLIENT_ID: "78qccyidpxe68g"
      LINKEDIN_CLIENT_SECRET: "WPL_AP1.gxtCHrFFVAdgp2IT.4Bjirw=="
      TWITTER_CLIENT_ID: "replace-with-twitter-client-id"
      TWITTER_CLIENT_SECRET: "replace-with-twitter-secret"
      TIKTOK_CLIENT_ID: "replace-with-tiktok-client-id"
      TIKTOK_CLIENT_SECRET: "replace-with-tiktok-client-secret"
      OPENAI_API_KEY: "replace-with-openai-api-key"

    volumes:
      - ./config:/config
      - ./uploads:/uploads
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
      - ./db:/var/lib/postgresql/data
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
      - ./redis:/data
    networks:
      - postiz-network

networks:
  postiz-network:
EOL

# -----------------------------
# Nginx & SSL
# -----------------------------
echo "🌐 Installing Nginx & Certbot..."
apt install -y nginx certbot python3-certbot-nginx

echo "⚙️ Configuring Nginx reverse proxy..."
cat > $BASE_DIR/nginx/postiz.conf <<EOF
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

ln -sf $BASE_DIR/nginx/postiz.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "🔐 Installing SSL certificate..."
certbot --nginx -d $DOMAIN -m $EMAIL --agree-tos --non-interactive

# -----------------------------
# Start Postiz
# -----------------------------
echo "🚀 Starting Postiz with Docker Compose..."
docker compose up -d

echo "✅ Installation finished!"
echo "🌍 Access Postiz at: https://$DOMAIN"
echo "⚠️ Reminder: Edit docker-compose.yml and replace all 'replace-with-...' values with your actual API keys before using social integrations."
