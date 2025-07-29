#!/bin/bash

echo "🧹 بدء تنظيف كامل لكل ما يتعلق بـ Postiz..."

# 1. إيقاف أي حاويات قيد التشغيل مرتبطة بـ postiz
echo "🛑 إيقاف الحاويات..."
sudo docker ps -a --filter "name=postiz" --format "{{.ID}}" | xargs -r sudo docker stop
sudo docker ps -a --filter "name=postiz" --format "{{.ID}}" | xargs -r sudo docker rm

# 2. حذف الصور التي لها علاقة بـ postiz
echo "🗑️ حذف الصور..."
sudo docker images --filter=reference='*postiz*' --format "{{.ID}}" | xargs -r sudo docker rmi -f

# 3. حذف أي شبكة Docker مخصصة لـ Postiz
echo "🌐 حذف الشبكات..."
sudo docker network ls --filter name=postiz --format "{{.ID}}" | xargs -r sudo docker network rm

# 4. حذف أي volumes قد تكون مستخدمة من قبل Postiz
echo "💾 حذف الحجوم..."
sudo docker volume ls --filter name=postiz --format "{{.Name}}" | xargs -r sudo docker volume rm

# 5. حذف مجلد المشروع بالكامل
echo "🗂️ حذف مجلد /opt/postiz-app..."
sudo rm -rf /opt/postiz-app

# 6. التأكد من عدم وجود ملفات متبقية باسم postiz في النظام
echo "🔍 البحث عن أي ملفات postiz متبقية في /opt أو /var أو /etc..."
sudo find /opt /var /etc -type d -name "*postiz*" -exec rm -rf {} +
sudo find /opt /var /etc -type f -name "*postiz*" -exec rm -f {} +

echo "✅ تم تنظيف Postiz بالكامل من هذا السيرفر."
