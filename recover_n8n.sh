#!/bin/bash

echo "🚨 بدء عملية استرجاع نظام العمل بعد حذف ~"

# 🧱 1. إعادة إنشاء مجلد HOME إذا لزم الأمر
sudo mkdir -p ~
sudo chown $USER:$USER ~

# 📂 2. إعادة إعداد مجلد بيانات n8n
mkdir -p ~/n8n_data
sudo chown -R 1000:1000 ~/n8n_data

# ⚙️ 3. إعادة ملفات .bashrc و .profile (بيئة الطرفية)
cp /etc/skel/.bashrc ~/
cp /etc/skel/.profile ~/
source ~/.bashrc

# 🐳 4. التأكد من أن Docker مثبت
if ! command -v docker &> /dev/null; then
  echo "📦 تثبيت Docker..."
  sudo apt update
  sudo apt install -y docker.io
fi

# 🌐 5. تثبيت ngrok إذا لم يكن مثبتًا
if ! command -v ngrok &> /dev/null; then
  echo "⬇️ تثبيت ngrok..."
  wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf ngrok.tgz -C /usr/local/bin
fi

# 🔐 6. إعداد ngrok لحساب n8n
ngrok config add-authtoken 2N7U2BmqSbPX5ibsRPhpuyD8b1b_6CsuZXHCnLCrgHvqKvRCE

# 🔁 7. إنشاء خدمة ngrok للنطاق الثابت
sudo bash -c 'cat > /etc/systemd/system/ngrok-n8n.service <<EOF
[Unit]
Description=Ngrok Tunnel for N8N
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=repeatedly-positive-deer.ngrok-free.app 5678
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable ngrok-n8n.service
sudo systemctl start ngrok-n8n.service

# ⏱️ 8. انتظار ngrok ليشتغل
echo "⌛️ انتظار ngrok..."
sleep 8

# 🌍 9. جلب رابط ngrok من الـ API
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
echo "🌐 رابط ngrok المكتشف: $NGROK_URL"

# 🧹 10. حذف الحاوية القديمة إن وُجدت
sudo docker stop n8n 2>/dev/null || true
sudo docker rm n8n 2>/dev/null || true

# 🐳 11. تشغيل n8n مع إعداد OAuth الصحيح
sudo docker run -d --name n8n \
  -p 5678:5678 \
  -v ~/n8n_data:/home/node/.n8n \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=admin \
  -e N8N_BASIC_AUTH_PASSWORD=admin123 \
  -e N8N_HOST=repeatedly-positive-deer.ngrok-free.app \
  -e N8N_PROTOCOL=https \
  -e WEBHOOK_URL=$NGROK_URL \
  --restart unless-stopped \
  n8nio/n8n

echo "✅ تم تشغيل n8n على: $NGROK_URL"
