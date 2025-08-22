#!/usr/bin/env bash
set -euo pipefail

# ===============================
# 🚀 سكربت تسطيب Postiz من الصفر
# Ubuntu 24.04 + Docker + Compose
# ===============================
# - يمسح أي نسخة سابقة من Postiz
# - ينزل ويثبت Postiz مع PostgreSQL + Redis
# - ينشئ docker-compose.yml + .env
# - يضيف متغيرات Google OAuth placeholders
# ===============================

# 📌 إعداداتك
DOMAIN="postiz.example.com"    # غيّر هذا لدومينك
POSTGRES_PASSWORD="StrongPass123!"   # غيّر الباسوورد
ENV_FILE=".env"

echo "🚀 بدء التثبيت..."

# 1) تحديث النظام وتنزيل Docker + Compose
echo "📦 تثبيت المتطلبات (Docker & Compose)..."
sudo apt update -y
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker

# 2) إزالة أي نسخة قديمة من Postiz
echo "🧹 تنظيف أي نسخة سابقة من Postiz..."
if [ -f docker-compose.yml ]; then
    docker compose down -v || true
    rm -f docker-compose.yml
fi
rm -f "${ENV_FILE}" docker-compose.override.yml || true
docker system prune -af --volumes || true

# 3) إنشاء ملف البيئة (.env)
echo "📝 إنشاء ملف ${ENV_FILE}..."
cat > "${ENV_FILE}" <<EOF
# 🌐 الإعدادات العامة
MAIN_URL=https://${DOMAIN}

# 🗄️ إعدادات قاعدة البيانات PostgreSQL
POSTGRES_USER=postiz
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=postiz
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# 🔑 سر التطبيق (توليد عشوائي)
APP_SECRET=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)

# ☁️ Google OAuth (YouTube)
# ضع القيم بعد إنشائها من Google Cloud Console
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_CALLBACK_URL=https://${DOMAIN}/auth/callback/google
EOF

# 4) إنشاء ملف docker-compose.yml
echo "📝 إنشاء ملف docker-compose.yml..."
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

# 5) تشغيل Postiz
echo "🚀 تشغيل Postiz..."
docker compose up -d

echo "✅ تم تثبيت Postiz بنجاح!"
echo "➡️ افتح: https://${DOMAIN}"
echo
echo "📌 تذكير: لا تنسَ تعديل ملف .env ووضع القيم الصحيحة لمتغيرات Google OAuth:"
echo "   GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_CALLBACK_URL"
echo
