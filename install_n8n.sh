#!/bin/bash

# 📌 المتغيرات
DOMAIN="n8n.soufianeautomation.space"
EMAIL="your@email.com"   # ضع بريدك هنا لإدارة SSL من Let's Encrypt

echo "🚀 بدء تثبيت n8n على $DOMAIN ..."

# تحديث النظام
sudo apt update && sudo apt upgrade -y

# تثبيت الأدوات الأساسية
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw

# تفعيل Docker
sudo systemctl enable docker
sudo systemctl start docker

# 🧹 حذف n8n القديم إن وجد
sudo docker stop n8n 2>/dev/null || true
sudo docker rm n8n 2>/dev/null || true
sudo rm -rf ~/n8n_data

# إنشاء مجلد بيانات n8n (لحفظ كل الداتا بشكل دائم)
mkdir -p ~/n8n_data
sudo chown -R 1000:1000 ~/n8n_data

# 🐳 تشغيل n8n في Docker (مع ربط البيانات)
sudo docker run -d --name n8n \
  -p 5678:5678 \
  -v ~/n8n_data:/home/node/.n8n \
  -e N8N_HOST="$DOMAIN" \
  -e N8N_PROTOCOL=https \
  -e WEBHOOK_URL="https://$DOMAIN" \
  --restart unless-stopped \
  n8nio/n8n:latest

# 🔧 إعداد Nginx كـ Reverse Proxy
sudo tee /etc/nginx/sites-available/n8n.conf > /dev/null <<EOF
server {
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# تفعيل الموقع
sudo ln -s /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/ || true
sudo nginx -t && sudo systemctl restart nginx

# 🔒 الحصول على SSL من Let's Encrypt
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# فتح الجدار الناري (UFW)
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# 🛡️ تثبيت Watchtower للتحديث التلقائي
sudo docker stop watchtower 2>/dev/null || true
sudo docker rm watchtower 2>/dev/null || true
sudo docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower n8n --cleanup --interval 3600

echo "✅ تم تثبيت n8n مع التحديث التلقائي!"
echo "🌍 افتح الرابط: https://$DOMAIN"
echo "🎉 أول مرة سيظهر لك صفحة التسجيل (Register)."
echo "🔄 Watchtower سيتحقق كل ساعة من وجود تحديث جديد لـ n8n ويطبقه تلقائيًا."
