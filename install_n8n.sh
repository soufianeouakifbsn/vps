#!/bin/bash

set -e

# 📌 المتغيرات
DOMAIN="n8n.soufianeautomation.space"   # غيّر حسب الدومين الخاص بك
EMAIL="soufianeouakifbsn@gmail.com"     # ضع بريدك هنا لإدارة SSL

echo "🚀 بدء تثبيت n8n على $DOMAIN ..."

# تحديث النظام
sudo apt update && sudo apt upgrade -y

# تثبيت الأدوات الأساسية
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw

# 🔐 فتح الجدار الناري قبل إصدار الشهادة
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# تفعيل Docker
sudo systemctl enable docker
sudo systemctl start docker

# 🧹 حذف n8n القديم إن وجد
sudo docker stop n8n 2>/dev/null || true
sudo docker rm n8n 2>/dev/null || true

# إنشاء مجلد بيانات n8n (لحفظ كل الداتا بشكل دائم)
mkdir -p ~/n8n_data
sudo chown -R 1000:1000 ~/n8n_data

# 🐳 تشغيل n8n في Docker (مع ربط البيانات)
# ملاحظة: N8N_PROTOCOL=https + WEBHOOK_URL يضمنوا روابط صحيحة خلف الـ Proxy
sudo docker run -d --name n8n \
  -p 5678:5678 \
  -v ~/n8n_data:/home/node/.n8n \
  -e N8N_HOST="$DOMAIN" \
  -e N8N_PORT=5678 \
  -e N8N_PROTOCOL=https \
  -e WEBHOOK_URL="https://$DOMAIN" \
  --restart unless-stopped \
  n8nio/n8n:next

# 🔧 إعداد Nginx كـ Reverse Proxy مع WebSocket + Timeout
# ✅ أضفنا listen 80 و IPv6 عشان Certbot يتعرف على البلوك
sudo tee /etc/nginx/sites-available/n8n.conf > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    # زيادة حجم الرفع (اختياري)
    client_max_body_size 50m;

    location / {
        proxy_pass http://127.0.0.1:5678;

        # ✅ دعم WebSocket
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # ✅ تمرير الهيدر بشكل صحيح
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # ✅ منع انقطاع الاتصال (Connection lost)
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;

        # تحسينات اختيارية
        proxy_buffering off;
    }
}
EOF

# تفعيل الموقع (وحذف الديفولت اختياريًا لتفادي التضارب)
sudo ln -sf /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/n8n.conf
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# اختبار وإعادة تحميل Nginx
sudo nginx -t
sudo systemctl reload nginx

# 🔒 الحصول على SSL من Let's Encrypt + تفعيل التحويل التلقائي إلى HTTPS
sudo certbot --nginx -d "$DOMAIN" --redirect --non-interactive --agree-tos -m "$EMAIL"

# 🛡️ تثبيت Watchtower للتحديث التلقائي
sudo docker stop watchtower 2>/dev/null || true
sudo docker rm watchtower 2>/dev/null || true
sudo docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower n8n --cleanup --interval 3600

echo "✅ تم تثبيت n8n على https://$DOMAIN"
echo "🎉 أول مرة سيظهر لك صفحة التسجيل (Register)."
echo "🔄 Watchtower سيتحقق كل ساعة من وجود تحديث جديد لـ n8n ويطبقه تلقائيًا."
echo "🔧 تم إصلاح مشكلة Certbot عبر إضافة listen 80 + ضبط UFW قبل الإصدار."
