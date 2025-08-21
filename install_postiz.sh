#!/bin/bash

# ============================
# 📌 متغيرات أساسية
# ============================
DOMAIN="postiz.soufianeautomation.space"
EMAIL="soufianeouakifbsn@gmail.com"
POSTIZ_DIR=~/postiz

echo "🚀 بدء تثبيت Postiz على $DOMAIN ..."

# ============================
# ✅ تحديث النظام
# ============================
sudo apt update && sudo apt upgrade -y

# ============================
# ✅ تثبيت المتطلبات
# ============================
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw

# تفعيل Docker
sudo systemctl enable docker
sudo systemctl start docker

# ============================
# 🐳 تجهيز Postiz
# ============================
mkdir -p $POSTIZ_DIR
cd $POSTIZ_DIR

# ملف docker-compose.yml الرسمي لـ Postiz
sudo tee $POSTIZ_DIR/docker-compose.yml > /dev/null <<EOF
version: '3.9'

services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    environment:
      MAIN_URL: "https://$DOMAIN"
      FRONTEND_URL: "https://$DOMAIN"
      BACKEND_URL: "https://$DOMAIN/api"
      REDIS_URL: "redis://redis:6379"
      DATABASE_URL: "postgresql://postgres:postgres@postgres:5432/postiz"
      NODE_ENV: "production"
    depends_on:
      - redis
      - postgres
    ports:
      - "3210:3000"

  redis:
    image: redis:6.2
    container_name: postiz-redis
    restart: always

  postgres:
    image: postgres:13
    container_name: postiz-postgres
    restart: always
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postiz
    volumes:
      - postiz_pgdata:/var/lib/postgresql/data

volumes:
  postiz_pgdata:
EOF

# تشغيل Postiz
sudo docker-compose up -d

# ============================
# 🔧 إعداد Nginx كـ Reverse Proxy
# ============================
sudo tee /etc/nginx/sites-available/postiz.conf > /dev/null <<EOF
server {
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:3210;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/postiz.conf /etc/nginx/sites-enabled/ || true
sudo nginx -t && sudo systemctl restart nginx

# ============================
# 🔒 SSL من Let's Encrypt
# ============================
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# ============================
# 🔥 الجدار الناري UFW
# ============================
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo "✅ تم تثبيت Postiz على: https://$DOMAIN"
echo "🎉 يمكنك الدخول الآن وإنشاء الحساب الأول (Admin)."
