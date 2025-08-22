#!/usr/bin/env bash
set -euo pipefail

# ===============================
# 🚀 Script Install Postiz (Ubuntu 24.04)
# ===============================

DOMAIN="postiz.soufianeautomation.space"
POSTGRES_PASSWORD="StrongPass123!"
ENV_FILE=".env"

echo "🚀 Starting Postiz installation..."

# 1) Update & Install dependencies
echo "📦 Installing dependencies..."
sudo apt-get remove docker docker-engine docker.io containerd runc -y || true
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release

# 2) Setup Docker official repo
echo "🐳 Setting up Docker repository..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker

# 3) Clean previous Postiz (if exists)
echo "🧹 Removing any old Postiz installation..."
docker compose down -v || true
rm -f docker-compose.yml "${ENV_FILE}" docker-compose.override.yml || true
docker system prune -af --volumes || true

# 4) Create .env file
echo "📝 Creating ${ENV_FILE}..."
cat > "${ENV_FILE}" <<EOF
# 🌐 Main URL
MAIN_URL=https://${DOMAIN}

# 🗄️ Database
POSTGRES_USER=postiz
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=postiz
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# 🔑 App secret
APP_SECRET=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)

# ☁️ Google OAuth (YouTube)
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_CALLBACK_URL=https://${DOMAIN}/auth/callback/google

# 📘 Facebook OAuth
FACEBOOK_CLIENT_ID=your-facebook-app-id
FACEBOOK_CLIENT_SECRET=your-facebook-app-secret
FACEBOOK_CALLBACK_URL=https://${DOMAIN}/auth/callback/facebook

# 🐦 Twitter/X OAuth
TWITTER_CLIENT_ID=your-twitter-client-id
TWITTER_CLIENT_SECRET=your-twitter-client-secret
TWITTER_CALLBACK_URL=https://${DOMAIN}/auth/callback/twitter

# 💼 LinkedIn OAuth
LINKEDIN_CLIENT_ID=your-linkedin-client-id
LINKEDIN_CLIENT_SECRET=your-linkedin-client-secret
LINKEDIN_CALLBACK_URL=https://${DOMAIN}/auth/callback/linkedin

# 📸 Instagram OAuth (عبر Facebook App)
INSTAGRAM_CLIENT_ID=your-instagram-client-id
INSTAGRAM_CLIENT_SECRET=your-instagram-client-secret
INSTAGRAM_CALLBACK_URL=https://${DOMAIN}/auth/callback/instagram
EOF

# 5) Create docker-compose.yml
echo "📝 Creating docker-compose.yml..."
cat > docker-compose.yml <<'YAML'
version: '3.9'

services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    ports:
      - "3000:3000"
    env_file:
      - .env
    depends_on:
      - postgres
      - redis

  postgres:
    image: postgres:15
    container_name: postiz_postgres
    restart: always
    environment:
      POSTGRES_USER: postiz
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: postiz
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7
    container_name: postiz_redis
    restart: always
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
YAML

# 6) Start Postiz
echo "🚀 Starting Postiz..."
docker compose up -d

echo
echo "✅ Postiz installed successfully!"
echo "➡️ Go to: https://${DOMAIN}"
echo "📌 Now edit the .env file and fill in your real OAuth App IDs & Secrets:"
echo "   nano .env"
echo "⚠️ After editing, restart with:"
echo "   docker compose down && docker compose up -d"
echo
