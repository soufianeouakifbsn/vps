#!/bin/bash

# 📌 متغيراتك الأساسية
DOMAIN="postiz.soufianeautomation.space"
EMAIL="your@email.com"
JWT_SECRET="ChangeThisToSomethingRandom123"

echo "🚀 بدء تثبيت Postiz على $DOMAIN"

# 🔄 تحديث النظام
sudo apt update && sudo apt upgrade -y

# 🐳 تثبيت Docker و Docker Compose إذا لم يكن مثبتًا
if ! command -v docker &> /dev/null; then
  echo "🔧 تثبيت Docker..."
  sudo apt install -y docker.io
fi

if ! command -v docker compose &> /dev/null; then
  echo "🔧 تثبيت Docker Compose..."
  sudo apt install -y docker-compose-plugin
fi

# 📂 إنشاء مجلد للتطبيق
mkdir -p ~/postiz
cd ~/postiz

# ✍️ إنشاء ملف docker-compose.yml مع wait-for-it
cat > docker-compose.yml <<EOF
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
      BACKEND_INTERNAL_URL: "http://0.0.0.0:3000/"
      IS_GENERAL: "true"
    volumes:
      - postiz-config:/config/
    ports:
      - 3000:3000
    networks:
      - postiz-network
    depends_on:
      postiz-postgres:
        condition: service_healthy
      postiz-redis:
        condition: service_healthy

  postiz-postgres:
    image: postgres:14.5
    container_name: postiz-postgres
    restart: always
    environment:
      POSTGRES_PASSWORD: postiz-password
      POSTGRES_USER: postiz-user
      POSTGRES_DB: postiz-db-local
    volumes:
      - postgres-volume:/var/lib/postgresql/data
    ports:
      - 5432:5432
    networks:
      - postiz-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postiz-user -d postiz-db-local"]
      interval: 10s
      timeout: 3s
      retries: 10

  postiz-redis:
    image: redis:7.2
    container_name: postiz-redis
    restart: always
    ports:
      - 6379:6379
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 10
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

networks:
  postiz-network:
    external: false
EOF

# ▶️ تشغيل Postiz
sudo docker compose up -d

# ⏳ الانتظار حتى تكون Postiz جاهزة
echo "⏳ الانتظار حتى تشغيل Postiz..."
until sudo docker exec postiz curl -s http://0.0.0.0:3000 >/dev/null 2>&1; do
  echo "🚀 Postiz لا يزال يبدأ... الانتظار 5 ثواني"
  sleep 5
done
echo "✅ Postiz جاهز!"

# 🌐 تثبيت Nginx و Certbot
sudo apt install -y nginx certbot python3-certbot-nginx

# ✍️ إعداد Nginx Reverse Proxy
sudo bash -c "cat > /etc/nginx/sites-available/postiz <<NGINX_CONF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \\\$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
    }
}
NGINX_CONF"

# 🔗 تفعيل الموقع
sudo ln -s /etc/nginx/sites-available/postiz /etc/nginx/sites-enabled/ || true
sudo nginx -t && sudo systemctl restart nginx

# 🔒 إعداد SSL
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

echo "✅ تم التثبيت بنجاح! افتح: https://$DOMAIN"
