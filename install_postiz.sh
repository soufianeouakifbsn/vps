#!/bin/bash

echo "🚨 بدء تثبيت Postiz مع Docker و ngrok..."

# 1. التأكد من وجود Docker، وإذا لم يكن مثبتًا يتم تثبيته
if ! command -v docker &> /dev/null; then
  echo "📦 تثبيت Docker..."
  sudo apt update
  sudo apt install -y docker.io
  sudo systemctl enable docker
  sudo systemctl start docker
else
  echo "✅ Docker مثبت بالفعل"
fi

# 2. التأكد من وجود Docker Compose، وإذا لم يكن مثبتًا يتم تثبيته
if ! command -v docker-compose &> /dev/null; then
  echo "📦 تثبيت Docker Compose..."
  sudo apt update
  sudo apt install -y docker-compose
else
  echo "✅ Docker Compose مثبت بالفعل"
fi

# 3. تثبيت ngrok إذا لم يكن مثبتًا
if ! command -v ngrok &> /dev/null; then
  echo "⬇️ تثبيت ngrok..."
  wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf ngrok.tgz -C /usr/local/bin
  rm ngrok.tgz
else
  echo "✅ ngrok مثبت بالفعل"
fi

# 4. إعداد ngrok بالتوكن الخاص بـ Postiz
NGROK_TOKEN="30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9"
ngrok config add-authtoken $NGROK_TOKEN

# 5. إنشاء ملف خدمة systemd لتشغيل ngrok على النطاق الثابت
NGROK_DOMAIN="jaybird-normal-publicly.ngrok-free.app"
NGROK_PORT=3000  # رقم بورت Postiz حسب التوثيق (تأكد من الرقم الصحيح، غالبًا 3000 أو 8080)

sudo bash -c "cat > /etc/systemd/system/ngrok-postiz.service <<EOF
[Unit]
Description=Ngrok Tunnel for Postiz
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=${NGROK_DOMAIN} ${NGROK_PORT}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl enable ngrok-postiz.service
sudo systemctl start ngrok-postiz.service

# 6. انتظار ngrok ليشتغل
echo "⌛️ انتظار ngrok للعمل..."
sleep 8

# 7. جلب رابط ngrok من الـ API
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
echo "🌐 رابط ngrok المكتشف: $NGROK_URL"

# 8. إنشاء مجلد بيانات Postiz في الـ HOME إذا لم يكن موجودًا
mkdir -p ~/postiz_data

# 9. إنشاء ملف docker-compose.yml لـ Postiz في مجلد العمل الحالي
cat > docker-compose.yml <<EOF
version: "3"

services:
  postiz:
    image: postiz/postiz:latest
    container_name: postiz
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - ./postiz_data:/app/data
    environment:
      - NODE_ENV=production
      - BASE_URL=https://${NGROK_DOMAIN}
EOF

# 10. تشغيل Postiz باستخدام Docker Compose
docker-compose down 2>/dev/null || true
docker-compose up -d

echo "✅ تم تشغيل Postiz بنجاح على: $NGROK_URL"
echo "🚀 يمكنك الدخول إلى لوحة Postiz عبر الرابط أعلاه"

