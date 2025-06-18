#!/bin/bash

echo "🚀 بدء تثبيت n8n وربطه بـ ngrok..."

# تثبيت Docker إذا لم يكن مثبتًا
if ! command -v docker &> /dev/null; then
  echo "🔧 تثبيت Docker..."
  sudo apt update
  sudo apt install -y docker.io
fi

# إنشاء مجلد بيانات n8n
mkdir -p ~/n8n_data
sudo chown -R 1000:1000 ~/n8n_data

# تشغيل حاوية n8n
sudo docker run -d --name n8n \
  -p 5678:5678 \
  -v ~/n8n_data:/home/node/.n8n \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=admin \
  -e N8N_BASIC_AUTH_PASSWORD=admin123 \
  --restart unless-stopped \
  n8nio/n8n

# إعداد ngrok
ngrok config add-authtoken 2N7U2BmqSbPX5ibsRPhpuyD8b1b_6CsuZXHCnLCrgHvqKvRCE

# تشغيل النفق في الخلفية وتخزين الـ log
nohup ngrok http --domain=repeatedly-positive-deer.ngrok-free.app 5678 > ~/ngrok_n8n.log 2>&1 &

echo "✅ n8n يعمل الآن على: https://repeatedly-positive-deer.ngrok-free.app"
