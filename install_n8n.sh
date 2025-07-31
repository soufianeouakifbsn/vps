#!/bin/bash

# 📌 المتغيرات (قم بتعديلهما حسب الحاجة)
NGROK_DOMAIN="jaybird-normal-publicly.ngrok-free.app"
NGROK_TOKEN="30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9"

echo "🚀 بدء تثبيت n8n وربطه بـ ngrok..."

# تحديث وترقية النظام وتثبيت الأدوات المطلوبة
echo "🔄 تحديث وترقية النظام وتثبيت wget, git, jq ..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget git jq

# 🧼 حذف الحاوية القديمة إن وُجدت
echo "🧹 التحقق من وجود حاوية n8n قديمة..."
sudo docker stop n8n 2>/dev/null || true
sudo docker rm n8n 2>/dev/null || true

# تثبيت Docker إذا لم يكن مثبتًا
if ! command -v docker &> /dev/null; then
  echo "🔧 تثبيت Docker..."
  sudo apt update
  sudo apt install -y docker.io
fi

# إنشاء مجلد بيانات n8n
mkdir -p ~/n8n_data
sudo chown -R 1000:1000 ~/n8n_data

# تثبيت ngrok إذا لم يكن موجودًا
if ! command -v ngrok &> /dev/null; then
  echo "⬇️ تثبيت ngrok..."
  wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf ngrok.tgz -C /usr/local/bin
fi

# إعداد ngrok بحسابك باستخدام المتغيرات
ngrok config add-authtoken "$NGROK_TOKEN"

# حذف أي خدمة ngrok-n8n قديمة
sudo systemctl stop ngrok-n8n.service 2>/dev/null || true
sudo systemctl disable ngrok-n8n.service 2>/dev/null || true
sudo rm /etc/systemd/system/ngrok-n8n.service 2>/dev/null || true

# إنشاء systemd service لـ ngrok
sudo bash -c "cat > /etc/systemd/system/ngrok-n8n.service <<EOF
[Unit]
Description=Ngrok Tunnel for N8N
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=$NGROK_DOMAIN 5678
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF"

# تفعيل خدمة ngrok
sudo systemctl daemon-reload
sudo systemctl enable ngrok-n8n.service
sudo systemctl start ngrok-n8n.service

# 🔁 انتظار ngrok ليشتغل
echo "⌛️ انتظار ngrok ليشتغل..."
sleep 8

# 📥 جلب رابط ngrok من الـ API المحلي
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')

echo "🌍 تم اكتشاف رابط ngrok: $NGROK_URL"

# 🐳 تشغيل n8n بالحاوية مع إعداد OAuth الصحيح
sudo docker run -d --name n8n \
  -p 5678:5678 \
  -v ~/n8n_data:/home/node/.n8n \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=admin \
  -e N8N_BASIC_AUTH_PASSWORD=admin123 \
  -e N8N_HOST="$NGROK_DOMAIN" \
  -e N8N_PROTOCOL=https \
  -e WEBHOOK_URL="$NGROK_URL" \
  --restart unless-stopped \
  n8nio/n8n

echo "✅ تم تشغيل n8n على: $NGROK_URL"
