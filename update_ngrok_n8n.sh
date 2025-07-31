#!/bin/bash

echo "🔄 تحديث إعدادات ngrok و n8n تلقائيًا..."

# ⚙️ المتغيرات الجديدة (قم بتعديلها فقط)
NEW_DOMAIN="jaybird-normal-publicly.ngrok-free.app"
NEW_TOKEN="30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9"

# 🛑 إيقاف خدمة ngrok القديمة
echo "🛑 إيقاف خدمة ngrok القديمة..."
sudo systemctl stop ngrok-n8n.service

# 🔑 تحديث توكن ngrok
echo "🔐 تحديث توكن ngrok..."
ngrok config add-authtoken "$NEW_TOKEN"

# 📝 تعديل ملف systemd بخدمة ngrok
echo "📝 تعديل ملف ngrok-n8n.service بالدومين الجديد..."
sudo sed -i "s|--domain=.* 5678|--domain=$NEW_DOMAIN 5678|" /etc/systemd/system/ngrok-n8n.service

# ♻️ إعادة تشغيل خدمة ngrok
echo "♻️ إعادة تشغيل خدمة ngrok..."
sudo systemctl daemon-reload
sudo systemctl restart ngrok-n8n.service

# ⏳ الانتظار لتشغيل ngrok
echo "⌛️ انتظار ngrok لتشغيل النفق..."
sleep 8

# 📥 جلب رابط ngrok الجديد من API
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')

echo "🌍 تم اكتشاف رابط ngrok الجديد: $NGROK_URL"

# 🐳 تحديث حاوية n8n
echo "🧱 تحديث حاوية n8n بالدومين الجديد..."

sudo docker stop n8n
sudo docker rm n8n

sudo docker run -d --name n8n \
  -p 5678:5678 \
  -v ~/n8n_data:/home/node/.n8n \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=admin@gmail.com \
  -e N8N_BASIC_AUTH_PASSWORD=admin123 \
  -e N8N_HOST=$NEW_DOMAIN \
  -e N8N_PROTOCOL=https \
  -e WEBHOOK_URL=$NGROK_URL \
  --restart unless-stopped \
  n8nio/n8n

echo "✅ تم التحديث بنجاح! n8n يعمل الآن على: $NGROK_URL"
