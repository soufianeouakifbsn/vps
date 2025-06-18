#!/bin/bash

echo "🚨 بدء عملية التنظيف الكاملة لـ Docker و ngrok..."

# إيقاف كل الحاويات
echo "🛑 إيقاف كل الحاويات..."
sudo docker stop $(docker ps -aq) 2>/dev/null

# حذف كل الحاويات
echo "🗑️ حذف جميع الحاويات..."
sudo docker rm $(docker ps -aq) 2>/dev/null

# حذف كل الصور
echo "🧼 حذف جميع الصور (Images)..."
sudo docker rmi $(docker images -q) -f 2>/dev/null

# حذف الشبكات
echo "🔌 حذف الشبكات..."
sudo docker network prune -f

# حذف المجلدات المرتبطة بالحجم (Volumes)
echo "📂 حذف الأحجام..."
sudo docker volume prune -f

# حذف ملفات ngrok
echo "🧹 قتل عمليات ngrok النشطة..."
pkill -f "ngrok" || echo "⚠️ لم يتم العثور على ngrok شغال"

# حذف الملفات المتبقية
echo "🧽 حذف مجلد n8n والملفات المتعلقة..."
rm -rf ~/n8n_data ~/compose.yaml ~/ngrok.tgz ~/ngrok.yml

# تحقق
echo "✅ تم تنظيف كل شيء! جاهز للبدء من جديد 🎉"
