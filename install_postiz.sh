#!/bin/bash

# === إعداد أولي ===
set -e

echo "🔧 بدء تثبيت Postiz مع ngrok ثابت..."

# === تحديث النظام وتثبيت المتطلبات ===
apt update && apt install -y curl unzip docker.io docker-compose

# === إعداد ngrok ===
echo "🌐 إعداد ngrok..."
NGROK_DOMAIN="jaybird-normal-publicly.ngrok-free.app"
NGROK_TOKEN="30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9"

curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
apt update && apt install -y ngrok

ngrok config add-authtoken "$NGROK_TOKEN"

# === إعداد نفق ثابت من ngrok ===
mkdir -p ~/.config/ngrok
cat > ~/.config/ngrok/ngrok.yml <<EOF
authtoken: $NGROK_TOKEN
tunnels:
  postiz:
    proto: http
    addr: 3000
    domain: $NGROK_DOMAIN
EOF

# إنشاء خدمة systemd لتشغيل ngrok تلقائياً
cat > /etc/systemd/system/ngrok.service <<EOF
[Unit]
Description=Ngrok Tunnel
After=network.target

[Service]
ExecStart=/usr/bin/ngrok start --config /root/.config/ngrok/ngrok.yml --all
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl enable ngrok && systemctl start ngrok

# === تحميل ملفات Postiz ===
echo "📦 تحميل Postiz..."
mkdir -p /opt/postiz && cd /opt/postiz
git clone https://github.com/postiz/postiz.git .
cp .env.example .env

# تعديل .env لاستخدام الدومين الثابت
sed -i "s|^APP_URL=.*|APP_URL=https://$NGROK_DOMAIN|" .env
sed -i "s|^FRONTEND_URL=.*|FRONTEND_URL=https://$NGROK_DOMAIN|" .env

# إنشاء قاعدة بيانات وبدء الخدمات
docker-compose up -d --build

# تأكيد التشغيل
echo "✅ تم تثبيت Postiz بنجاح!"
echo "🌍 رابط الوصول: https://$NGROK_DOMAIN"
