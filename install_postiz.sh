#!/bin/bash

echo "📦 بدء تثبيت Postiz وربطه بـ ngrok..."

# 🐋 تثبيت Docker إذا لم يكن مثبتًا
if ! command -v docker &> /dev/null; then
  echo "🔧 تثبيت Docker..."
  sudo apt update
  sudo apt install -y docker.io
fi

# 🧼 حذف الحاوية القديمة إن وُجدت
echo "🧹 التحقق من وجود حاوية Postiz قديمة..."
sudo docker stop postiz 2>/dev/null || true
sudo docker rm postiz 2>/dev/null || true

# 🚀 تشغيل حاوية Postiz
sudo docker run -d --name postiz \
  --restart unless-stopped \
  -p 8080:8080 \
  ghcr.io/soufianeouakifbsn/postiz:latest

# 🧰 تثبيت ngrok إذا لم يكن موجودًا
if ! command -v ngrok &> /dev/null; then
  echo "⬇️ تثبيت ngrok..."
  wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf ngrok.tgz -C /usr/local/bin
fi

# 🔐 إعداد ngrok بحساب postiz
ngrok config add-authtoken 30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9

# 🧾 إنشاء systemd service لـ ngrok الخاص بـ Postiz
sudo bash -c 'cat > /etc/systemd/system/ngrok-postiz.service <<EOF
[Unit]
Description=Ngrok Tunnel for Postiz
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=jaybird-normal-publicly.ngrok-free.app 8080
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

# ♻️ تفعيل الخدمة
sudo systemctl daemon-reload
sudo systemctl enable ngrok-postiz.service
sudo systemctl start ngrok-postiz.service

echo "✅ Postiz يعمل الآن على: https://jaybird-normal-publicly.ngrok-free.app"
