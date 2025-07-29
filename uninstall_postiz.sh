#!/bin/bash

echo "🚨 بدء إزالة كل ما يتعلق بـ Postiz..."

# إيقاف الحاويات التي تحتوي على اسم postiz
POSTIZ_CONTAINERS=$(sudo docker ps -a --filter "name=postiz" --format "{{.ID}}")
if [ -n "$POSTIZ_CONTAINERS" ]; then
  echo "🛑 إيقاف وحذف الحاويات:"
  echo "$POSTIZ_CONTAINERS"
  sudo docker stop $POSTIZ_CONTAINERS
  sudo docker rm -f $POSTIZ_CONTAINERS
else
  echo "✅ لا توجد حاويات باسم postiz قيد التشغيل."
fi

# حذف الصور التي تحتوي على postiz
POSTIZ_IMAGES=$(sudo docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep postiz | awk '{print $2}')
if [ -n "$POSTIZ_IMAGES" ]; then
  echo "🗑️ حذف الصور:"
  echo "$POSTIZ_IMAGES"
  sudo docker rmi -f $POSTIZ_IMAGES
else
  echo "✅ لا توجد صور postiz."
fi

# حذف مجلد postiz-app
if [ -d "/opt/postiz-app" ]; then
  echo "🗂️ حذف مجلد /opt/postiz-app"
  sudo rm -rf /opt/postiz-app
else
  echo "✅ لا يوجد مجلد /opt/postiz-app"
fi

# حذف ملفات postiz المحتملة في أي مكان
echo "🧹 البحث عن ملفات postiz في النظام..."
sudo find / -type f \( -iname "*postiz*" -o -iname "docker-compose.yml" -o -iname ".env" \) -exec rm -f {} \; 2>/dev/null

# تنظيف Docker
echo "🧼 تنظيف Docker..."
sudo docker volume prune -f
sudo docker network prune -f
sudo docker system prune -f --volumes

echo "✅ تم مسح كل شيء متعلق بـ Postiz بنجاح!"
