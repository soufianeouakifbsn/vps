#!/usr/bin/env bash
set -euo pipefail

#############################################
# Postiz + Docker Compose + ngrok installer #
#############################################

# ===[ إعدادات قابلة للتعديل ]===
NGROK_DOMAIN="jaybird-normal-publicly.ngrok-free.app"
NGROK_TOKEN="30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9"
POSTIZ_DIR="/opt/postiz"
POSTIZ_IMAGE="ghcr.io/gitroomhq/postiz-app:latest"
POSTIZ_JWT_SECRET="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 64 || true)"
POSTIZ_PORT="5000"

echo "🚀 بدء تثبيت Postiz..."

# ---------------------------------
# 1) تثبيت Docker + Compose
# ---------------------------------
if ! command -v docker &>/dev/null; then
  echo "📦 تثبيت Docker بالطريقة الرسمية..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm get-docker.sh
  sudo usermod -aG docker "$USER"
  newgrp docker <<EONG
echo "✅ تم تفعيل مجموعة docker للمستخدم الحالي."
EONG
fi

if ! docker compose version &>/dev/null; then
  echo "🔧 تثبيت Docker Compose يدويًا..."
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose || true
fi

# ---------------------------------
# 2) تثبيت ngrok (إن لم يكن موجودًا)
# ---------------------------------
if ! command -v ngrok &>/dev/null; then
  echo "⬇️ تثبيت ngrok..."
  wget -O /tmp/ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf /tmp/ngrok.tgz -C /usr/local/bin
fi

ngrok config add-authtoken "$NGROK_TOKEN"

# ---------------------------------
# 3) تجهيز مجلد Postiz
# ---------------------------------
sudo mkdir -p "$POSTIZ_DIR"
sudo chown -R "$USER:$USER" "$POSTIZ_DIR"
cd "$POSTIZ_DIR"

# ---------------------------------
# 4) إنشاء ملف docker-compose.yml
# ---------------------------------
cat > docker-compose.yml <<'YAML'
services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    environment:
      MAIN_URL: "${MAIN_URL}"
      FRONTEND_URL: "${FRONTEND_URL}"
      NEXT_PUBLIC_BACKEND_URL: "${NEXT_PUBLIC_BACKEND_URL}"
      JWT_SECRET: "${JWT_SECRET}"
      DATABASE_URL: "${DATABASE_URL}"
      REDIS_URL: "${REDIS_URL}"
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
      - ${POSTIZ_PORT}:5000
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
YAML

# ---------------------------------
# 5) إعداد ملف .env
# ---------------------------------
cat > .env <<ENV
MAIN_URL="https://${NGROK_DOMAIN}"
FRONTEND_URL="https://${NGROK_DOMAIN}"
NEXT_PUBLIC_BACKEND_URL="https://${NGROK_DOMAIN}/api"
JWT_SECRET="${POSTIZ_JWT_SECRET}"
DATABASE_URL="postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local"
REDIS_URL="redis://postiz-redis:6379"
POSTIZ_PORT="${POSTIZ_PORT}"
ENV

# ---------------------------------
# 6) إعداد systemd لـ ngrok
# ---------------------------------
sudo bash -c "cat > /etc/systemd/system/ngrok-postiz.service" <<EOF
[Unit]
Description=Ngrok Tunnel for Postiz
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=${NGROK_DOMAIN} ${POSTIZ_PORT}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ngrok-postiz.service
sudo systemctl start ngrok-postiz.service

# ---------------------------------
# 7) تشغيل Postiz
# ---------------------------------
echo "🐳 تشغيل Postiz باستخدام docker-compose..."
docker-compose pull
docker-compose up -d

echo ""
echo "✅ تم التثبيت بنجاح!"
echo "🌐 افتح الآن: https://${NGROK_DOMAIN}"
