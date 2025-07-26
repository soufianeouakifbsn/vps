#!/bin/bash

echo "⛔️ بدء إزالة Postiz من Docker..."

# 1. إيقاف الحاويات
echo "🛑 إيقاف جميع الحاويات المرتبطة بـ Postiz..."
docker compose -f postiz-docker/docker-compose.yml down || true

# 2. إزالة الحاويات والصور والشبكات
echo "🧹 حذف الصور، الحاويات، والشبكات..."
docker system prune -af --volumes

# 3. حذف مجلد postiz
echo "🗑️ حذف مجلد postiz-docker إن وُجد..."
rm -rf postiz-docker

# 4. التحقق من إزالة Docker Compose plugin
echo "❌ التحقق من إزالة docker compose plugin ليس ضرورياً إذا كنت ستعيد تثبيته لاحقاً."

echo "✅ تم إزالة Postiz بالكامل من النظام."
