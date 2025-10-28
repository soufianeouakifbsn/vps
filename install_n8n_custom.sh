#!/bin/bash

set -e

# 📌 المتغيرات
DOMAIN="n8n.soufianeautomation.space"   # غيّر حسب الدومين الخاص بك
EMAIL="soufianeouakifbsn@gmail.com"     # البريد لإصدار SSL

echo "🚀 بدء تثبيت n8n مخصص على $DOMAIN ..."

# تحديث النظام
sudo apt update && sudo apt upgrade -y

# تثبيت الأدوات الأساسية
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw git build-essential

# 🔐 إعداد الجدار الناري
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# تفعيل Docker
sudo systemctl enable docker
sudo systemctl start docker

# 🐳 حذف n8n القديم إذا وجد
sudo docker stop n8n 2>/dev/null || true
sudo docker rm n8n 2>/dev/null || true

# إنشاء مجلد بيانات n8n دائم
mkdir -p ~/n8n_data
sudo chown -R 1000:1000 ~/n8n_data

# ✅ إنشاء مجلد مؤقت لبناء Dockerfile
BUILD_DIR=~/n8n_docker_build
mkdir -p $BUILD_DIR
cd $BUILD_DIR

# 🔧 إنشاء Dockerfile
cat > Dockerfile <<EOF
FROM n8nio/n8n:next

USER root
RUN apt update && apt install -y pdftk zip
USER node
EOF

# بناء الصورة المخصصة
docker build -t n8n-custom:latest .

# تشغيل الحاوية المخصصة
sudo docker run -d --name n8n \
  -p 5678:5678 \
  -v ~/n8n_data:/home/node/.n8n \
  -e N8N_HOST="$DOMAIN" \
  -e N8N_PORT=5678 \
  -e N8N_PROTOCOL=https \
  -e WEBHOOK_URL="https://$DOMAIN" \
  --restart unless-stopped \
  n8n-custom:latest

# إعداد Nginx كـ Reverse Proxy
sudo tee /etc/nginx/sites-available/n8n.conf > /dev/null <<NGINXCONF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    client_max_body_size 50m;

    location / {
        proxy_pass http://127.0.0.1:5678;
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
        proxy_buffering off;
    }
}
NGINXCONF

sudo ln -sf /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/n8n.conf
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
sudo nginx -t
sudo systemctl reload nginx

# إصدار SSL تلقائي
sudo certbot --nginx -d "$DOMAIN" --redirect --non-interactive --agree-tos -m "$EMAIL"

# تثبيت Watchtower للتحديث التلقائي
sudo docker stop watchtower 2>/dev/null || true
sudo docker rm watchtower 2>/dev/null || true
sudo docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower n8n --cleanup --interval 3600

echo "✅ تم تثبيت n8n مخصص على https://$DOMAIN"
echo "🎉 الآن يمكنك الوصول للواجهة وتثبيت أي Workflow PDF splitter."
