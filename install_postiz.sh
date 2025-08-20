#!/bin/bash

# 📌 المتغيرات
DOMAIN="postiz.soufianeautomation.space"   # غيّر حسب الدومين الخاص بك
EMAIL="soufianeouakifbsn@gmail.com"       # ضع بريدك هنا لإدارة SSL

echo "🚀 بدء تثبيت Postiz على $DOMAIN ..."

# تحديث النظام
sudo apt update && sudo apt upgrade -y

# تثبيت الأدوات الأساسية
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw

# تفعيل Docker
sudo systemctl enable docker
sudo systemctl start docker

# 🧹 حذف أي حاويات قديمة لـ Postiz
sudo docker stop postiz 2>/dev/null || true
sudo docker rm postiz 2>/dev/null || true

# إنشاء مجلد بيانات Postiz (لحفظ كل الداتا بشكل دائم)
mkdir -p ~/postiz_data
sudo chown -R 1000:1000 ~/postiz_data

# 🐳 تشغيل Postiz في Docker
sudo docker run -d --name postiz \
  -p 3000:3000 \
  -v ~/postiz_data:/app/data \
  -e MAIN_URL="https://$DOMAIN" \
  --restart unless-stopped \
  ghcr.io/gitroomhq/postiz-app:latest

# 🔧 إعداد Nginx كـ Reverse Proxy مع Timeout مناسب
sudo tee /etc/nginx/sites-available/postiz.conf > /dev/null <<EOF
server {
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:3000;

        # ✅ تمرير الهيدر بشكل صحيح
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # ✅ منع انقطاع الاتصال
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;
    }
}
EOF

# تفعيل الموقع
sudo ln -s /etc/nginx/sites-available/postiz.conf /etc/nginx/sites-enabled/ || true
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
  containrrr/watchtower postiz --cleanup --interval 3600

echo "✅ تم تثبيت Postiz على https://$DOMAIN"
echo "🎉 افتح الموقع لإنشاء حسابك وبدء الاستخدام."
echo "🔄 Watchtower سيتحقق كل ساعة من وجود تحديث جديد لـ Postiz ويطبقه تلقائيًا."
