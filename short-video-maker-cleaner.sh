#!/bin/bash

set -e

echo "🚀 Starting deep cleanup for short-video-maker..."

# 1. قتل جميع العمليات المتعلقة بـ remotion و chrome
echo "🔪 Killing heavy rendering processes (remotion, chrome)..."
pkill -f remotion || true
pkill -f chrome || true

# 2. إيقاف وحذف الحاويات التي تحتوي على short-video-maker في اسمها
echo "🛑 Stopping and removing Docker containers with name 'short-video-maker'..."
CONTAINERS=$(docker ps -a --filter "name=short-video-maker" -q)
if [ -n "$CONTAINERS" ]; then
  docker stop $CONTAINERS
  docker rm $CONTAINERS
else
  echo "⚠️ No containers found with name 'short-video-maker'."
fi

# 3. حذف الصور الخاصة بـ short-video-maker
echo "🧹 Removing Docker images related to 'short-video-maker'..."
IMAGES=$(docker images --filter=reference='*short-video-maker*' -q)
if [ -n "$IMAGES" ]; then
  docker rmi -f $IMAGES
else
  echo "⚠️ No images found with name 'short-video-maker'."
fi

# 4. تنظيف ملفات عامة مؤقتة أقدم من يوم واحد
echo "🧼 Cleaning general temp files older than 1 day..."
find /tmp -type f -mtime +1 -exec rm -f {} \; 2>/dev/null
find /var/tmp -type f -mtime +1 -exec rm -f {} \; 2>/dev/null
find /dev/shm -type f -mtime +1 -exec rm -f {} \; 2>/dev/null

# 5. تنظيف الصور والحاويات غير المستخدمة (prune)
echo "🧹 Running Docker system prune..."
docker system prune -f

# 6. إعادة سحب أحدث صورة short-video-maker من الريبو الرسمي
IMAGE_NAME="gyoridavic/short-video-maker:latest"
echo "⬇️ Pulling latest Docker image: $IMAGE_NAME"
docker pull $IMAGE_NAME

# 7. تشغيل الحاوية من جديد (عدّل حسب حاجتك)
echo "▶️ Starting fresh short-video-maker container..."
docker run -d --name short-video-maker \
  -p 3123:3123 \
  $IMAGE_NAME

# 8. عرض استخدام الرام بعد التنظيف
echo "📊 RAM usage after cleanup:"
free -h | grep Mem

echo "✅ Deep cleanup complete. Your short-video-maker is fresh like new!"
