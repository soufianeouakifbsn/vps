#!/bin/bash

echo "🚀 بدء تثبيت Postiz وربطه بـ ngrok..."

# 🐳 تثبيت Docker إذا لم يكن مثبتًا
if ! command -v docker &> /dev/null; then
  echo "📦 تثبيت Docker..."
  sudo apt update
  sudo apt install -y docker.io
fi

# 🌐 تثبيت ngrok إذا لم يكن مثبتًا
if ! command -v ngrok &> /dev/null; then
  echo "⬇️ تثبيت ngrok..."
  wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf ngrok.tgz -C /usr/local/bin
fi

# 🔐 إعداد ngrok بالتوكن الخاص بـ Postiz
ngrok config add-authtoken 30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9

# 🛠️ إنشاء خدمة ngrok للنطاق الثابت
sudo bash -c 'cat > /etc/systemd/system/ngrok-postiz.service <<EOF
[Unit]
Description=Ngrok Tunnel for Postiz
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=jaybird-normal-publicly.ngrok-free.app 5000
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable ngrok-postiz.service
sudo systemctl start ngrok-postiz.service

# ⏱️ انتظار ngrok ليشتغل
echo "⌛️ انتظار ngrok..."
sleep 8

# 🌍 جلب رابط ngrok من الـ API
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
echo "🌐 رابط ngrok المكتشف: $NGROK_URL"

# 📁 إنشاء مجلد العمل
mkdir -p ~/postiz && cd ~/postiz

# 🧾 إنشاء ملف docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    environment:
      MAIN_URL: "$NGROK_URL"
      FRONTEND_URL: "$NGROK_URL"
      NEXT_PUBLIC_BACKEND_URL: "$NGROK_URL/api"
      JWT_SECRET: "$(openssl rand -hex 32)"
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
    volumes:
      - postiz-redis-data:/data
    networks:
      - postiz-network
    healthcheck:
      test: redis-cli ping
      interval: 10s
      timeout: 3s
      retries: 3

volumes:
  postgres-volume:
  postiz-redis-data:
  postiz-config:
  postiz-uploads:

networks:
  postiz-network:
EOF

# 🚀 تشغيل Postiz
docker compose up -d

echo "✅ تم تشغيل Postiz على: $NGROK_URL"
