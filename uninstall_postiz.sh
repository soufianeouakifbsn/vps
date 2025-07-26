#!/bin/bash

echo "⛔️ بدء إزالة Postiz من النظام..."

# 1. إيقاف الخدمة ngrok
echo "🛑 إيقاف خدمة ngrok-postiz.service إن وُجدت..."
sudo systemctl stop ngrok-postiz.service 2>/dev/null || true
sudo systemctl disable ngrok-postiz.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/ngrok-postiz.service
sudo systemctl daemon-reload

# 2. إيقاف الحاويات
echo "🛑 إيقاف وتشغيل docker-compose down..."
docker compose -f ~/postiz/docker-compose.yml down || true

# 3. إزالة الحاويات والصور والشبكات
echo "🧹 حذف الصور، الحاويات، الشبكات، والـ volumes..."
docker system prune -af --volumes

# 4. حذف مجلد postiz
echo "🗑️ حذف مجلد ~/postiz..."
rm -rf ~/postiz

echo "✅ تم إزالة Postiz وكل متعلقاته من النظام."
