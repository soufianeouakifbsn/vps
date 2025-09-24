#!/bin/bash

set -e

DOMAIN="n8n.soufianeautomation.space"

echo "🚀 بدء تحديث n8n على $DOMAIN ..."

# 🛑 إيقاف وحذف الكونتينر القديم
sudo docker stop n8n 2>/dev/null || true
sudo docker rm n8n 2>/dev/null || true

# 📥 سحب آخر نسخة من n8n
sudo docker pull n8nio/n8n:next

# ▶️ تشغيل n8n من جديد باستخدام المجلد الدائم للبيانات
sudo docker run -d --name n8n \
  -p 5678:5678 \
  -v ~/n8n_data:/home/node/.n8n \
  -e N8N_HOST="$DOMAIN" \
  -e N8N_PORT=5678 \
  -e N8N_PROTOCOL=https \
  -e WEBHOOK_URL="https://$DOMAIN" \
  --restart unless-stopped \
  n8nio/n8n:next

echo "✅ تم التحديث بنجاح! اذهب إلى: https://$DOMAIN"
