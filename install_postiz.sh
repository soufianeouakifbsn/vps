#!/bin/bash

# 📌 المتغيرات
DOMAIN="postiz.soufianeautomation.space"    # غيّر للدومين الخاص بك
EMAIL="soufianeouakifbsn@gmail.com"        # بريدك للحصول على SSL
POSTIZ_DATA="$HOME/postiz_data"

echo "🚀 بدء التثبيت التلقائي لـ Postiz على $DOMAIN ..."

# تحديث النظام
sudo apt update && sudo apt upgrade -y

# تثبيت الأدوات الأساسية
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw git

# تفعيل Docker
sudo systemctl enable docker
sudo systemctl start docker

# إنشاء مجلد البيانات
mkdir -p $POSTIZ_DATA
sudo chown -R 1000:1000 $POSTIZ_DATA

# إنشاء ملف Docker Compose
tee $POSTIZ_DATA/docker-compose.yml > /dev/null <<EOF
version: '3.9'

services:
  postgresql:
    image: postgres:15
    container_name: postiz_postgres
    environment:
      POSTGRES_USER: postiz
      POSTGRES_PASSWORD: postizpass
      POSTGRES_DB: postizdb
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  redis:
    image: redis:7
    container_name: postiz_redis
    volumes:
      - ./redis_data:/data
    restart: unless-stopped

  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    environment:
      MAIN_URL: "https://$DOMAIN"
      DATABASE_URL: "postgresql://postiz:postizpass@postgresql:5432/postizdb"
      REDIS_URL: "redis://redis:6379"
    ports:
      - "3000:3000"
    depends_on:
      - postgresql
      - redis
    restart: unless-stopped
EOF

# تشغيل Docker Compose
cd $POSTIZ_DATA
sudo docker-compose up -d

# ✅ التأكد من تشغيل الحاويات
sleep 15
echo "🔹 حالة الحاويات:"
sudo docker-compose ps

# إعداد Nginx كـ Reverse Proxy
sudo tee /etc/nginx/sites-available/postiz.conf > /dev/null <<EOF
server {
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:3000;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        send_timeout 600s;
    }
}
EOF

# تفعيل الموقع وإعادة تشغيل Nginx
sudo ln -s /etc/nginx/sites-available/postiz.conf /etc/nginx/sites-enabled/ || true
sudo nginx -t && sudo systemctl restart nginx

# الحصول على SSL من Let's Encrypt
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# فتح الجدار الناري
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# تثبيت Watchtower للتحديث التلقائي
sudo docker stop watchtower 2>/dev/null || true
sudo docker rm watchtower 2>/dev/null || true
sudo docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower postiz --cleanup --interval 3600

echo "✅ تم تثبيت Postiz بالكامل على https://$DOMAIN"
echo "🎉 افتح الموقع لإنشاء الحساب وبدء الاستخدام!"
