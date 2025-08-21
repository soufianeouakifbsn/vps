#!/bin/bash
set -euo pipefail

# -----------------------------
# تحديث النظام + تثبيت الأدوات
# -----------------------------
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git unzip nginx certbot python3-certbot-nginx docker.io docker-compose

# -----------------------------
# تحميل Postiz (مع تنظيف المجلد القديم لو موجود)
# -----------------------------
cd /opt
if [ -d "postiz" ]; then
  sudo rm -rf postiz
fi
sudo git clone https://github.com/gitroomhq/postiz-app postiz
cd postiz

# -----------------------------
# إنشاء ملف البيئة (backend + frontend + منصات التواصل)
# -----------------------------
cat > .env <<EOL
# -----------------
# Postgres
# -----------------
POSTGRES_USER=postiz
POSTGRES_PASSWORD=postizpass
POSTGRES_DB=postiz

# -----------------
# Redis
# -----------------
REDIS_HOST=redis
REDIS_PORT=6379

# -----------------
# Backend
# -----------------
PORT=3000
BACKEND_URL=https://postiz-api.soufianeautomation.space

# -----------------
# Frontend
# -----------------
FRONTEND_PORT=4200
FRONTEND_URL=https://postiz.soufianeautomation.space

# -----------------
# Pinterest
# -----------------
PINTEREST_CLIENT_ID=xxxxx
PINTEREST_CLIENT_SECRET=xxxxx
PINTEREST_REDIRECT_URL=https://postiz-api.soufianeautomation.space/auth/pinterest/callback

# -----------------
# LinkedIn
# -----------------
LINKEDIN_CLIENT_ID=xxxxx
LINKEDIN_CLIENT_SECRET=xxxxx
LINKEDIN_REDIRECT_URL=https://postiz-api.soufianeautomation.space/auth/linkedin/callback

# -----------------
# Google / YouTube
# -----------------
GOOGLE_CLIENT_ID=xxxxx
GOOGLE_CLIENT_SECRET=xxxxx
GOOGLE_REDIRECT_URL=https://postiz-api.soufianeautomation.space/auth/google/callback

# -----------------
# Facebook
# -----------------
FACEBOOK_CLIENT_ID=xxxxx
FACEBOOK_CLIENT_SECRET=xxxxx
FACEBOOK_REDIRECT_URL=https://postiz-api.soufianeautomation.space/auth/facebook/callback

# -----------------
# Instagram
# -----------------
INSTAGRAM_CLIENT_ID=xxxxx
INSTAGRAM_CLIENT_SECRET=xxxxx
INSTAGRAM_REDIRECT_URL=https://postiz-api.soufianeautomation.space/auth/instagram/callback

# -----------------
# Twitter (X)
# -----------------
TWITTER_CLIENT_ID=xxxxx
TWITTER_CLIENT_SECRET=xxxxx
TWITTER_REDIRECT_URL=https://postiz-api.soufianeautomation.space/auth/twitter/callback

# -----------------
# TikTok
# -----------------
TIKTOK_CLIENT_ID=xxxxx
TIKTOK_CLIENT_SECRET=xxxxx
TIKTOK_REDIRECT_URL=https://postiz-api.soufianeautomation.space/auth/tiktok/callback

# -----------------
# Reddit
# -----------------
REDDIT_CLIENT_ID=xxxxx
REDDIT_CLIENT_SECRET=xxxxx
REDDIT_REDIRECT_URL=https://postiz-api.soufianeautomation.space/auth/reddit/callback
EOL

# -----------------------------
# docker-compose.override.yml
# -----------------------------
cat > docker-compose.override.yml <<EOL
version: "3.8"

services:
  backend:
    environment:
      - PORT=3000
    ports:
      - "3000:3000"

  frontend:
    environment:
      - PORT=4200
    ports:
      - "4200:4200"

  postgres:
    ports:
      - "5432:5432"

  redis:
    ports:
      - "6379:6379"
EOL

# -----------------------------
# تشغيل الكونتينرات
# -----------------------------
sudo docker-compose up -d --build

# -----------------------------
# إعداد Nginx للـ frontend
# -----------------------------
sudo tee /etc/nginx/sites-available/postiz-frontend <<'EOF'
server {
    server_name postiz.soufianeautomation.space;

    location / {
        proxy_pass http://127.0.0.1:4200;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# إعداد Nginx للـ backend API
sudo tee /etc/nginx/sites-available/postiz-backend <<'EOF'
server {
    server_name postiz-api.soufianeautomation.space;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# -----------------------------
# تنظيف أي روابط قديمة + تفعيل الجديدة
# -----------------------------
sudo rm -f /etc/nginx/sites-enabled/postiz-frontend
sudo rm -f /etc/nginx/sites-enabled/postiz-backend
sudo rm -f /etc/nginx/sites-enabled/default

sudo ln -s /etc/nginx/sites-available/postiz-frontend /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/postiz-backend /etc/nginx/sites-enabled/

sudo nginx -t && sudo systemctl reload nginx

# -----------------------------
# شهادة SSL
# -----------------------------
sudo certbot --nginx -d postiz.soufianeautomation.space -d postiz-api.soufianeautomation.space --expand --non-interactive --agree-tos -m admin@soufianeautomation.space

echo "✅ تم تثبيت Postiz بنجاح!"
echo "Frontend: https://postiz.soufianeautomation.space"
echo "Backend API: https://postiz-api.soufianeautomation.space"
