#!/bin/bash

# 📌 إعداد المتغيرات
DOMAIN="postiz.soufianeautomation.space"
EMAIL="your@email.com"   # بريدك من أجل SSL Let's Encrypt
POSTGRES_PASSWORD="SuperSecretPass123"
JWT_SECRET="ChangeThisToLongRandomString"

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

# ✍️ إنشاء ملف docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  database:
    image: postgres:15
    restart: unless-stopped
    environment:
      POSTGRES_USER: postiz
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
      POSTGRES_DB: postiz
    volumes:
      - ./postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7
    restart: unless-stopped
    volumes:
      - ./redis_data:/data

  postiz:
    image: gitroomhq/postiz-app:latest
    restart: unless-stopped
    depends_on:
      - database
      - redis
    environment:
      DATABASE_URL: "postgresql://postiz:$POSTGRES_PASSWORD@database:5432/postiz"
      REDIS_URL: "redis://redis:6379"
      JWT_SECRET: "$JWT_SECRET"
      FRONTEND_URL: "https://$DOMAIN"
      NEXT_PUBLIC_BACKEND_URL: "https://$DOMAIN"
      BACKEND_INTERNAL_URL: "http://postiz:3000"
    expose:
      - "3000"
      - "5000"
EOF

# ▶️ تشغيل Postiz لأول مرة
sudo docker compose up -d

# 🌐 تثبيت Nginx و Certbot
sudo apt install -y nginx certbot python3-certbot-nginx

# ✍️ إعداد Nginx Reverse Proxy
sudo bash -c "cat > /etc/nginx/sites-available/postiz <<NGINX_CONF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX_CONF"

# 🔗 تفعيل الموقع
sudo ln -s /etc/nginx/sites-available/postiz /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# 🔒 إعداد SSL
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

echo "✅ تم التثبيت بنجاح! الآن افتح: https://$DOMAIN"
