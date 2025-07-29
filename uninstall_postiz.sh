#!/bin/bash

echo "🔄 جاري إيقاف وإزالة Postiz..."

# التحقق من وجود مجلد المشروع
if [ -d "/opt/postiz-app" ]; then
  cd /opt/postiz-app || exit

  echo "🛑 إيقاف وتشغيل الحاويات..."
  sudo docker-compose down

  echo "🗑️ إزالة الحاويات والصور المتعلقة بـ postiz..."
  # إزالة الحاويات والصور الخاصة بـ postiz
  sudo docker container prune -f
  sudo docker image prune -a -f
fi

echo "🗂️ حذف ملفات المشروع من /opt/postiz-app"
sudo rm -rf /opt/postiz-app

echo "✅ تم إزالة Postiz بالكامل من هذا السيرفر."
