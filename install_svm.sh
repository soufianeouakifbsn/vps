#!/bin/bash

echo "🎬 بدء تثبيت short-video-maker وربطه بـ ngrok..."

# تثبيت Docker إذا لم يكن مثبتًا
if ! command -v docker &> /dev/null; then
  echo "🔧 تثبيت Docker..."
  sudo apt update
  sudo apt install -y docker.io
fi

# تشغيل حاوية short-video-maker
sudo docker run -d --name short-video-maker \
  --restart unless-stopped \
  -p 3123:3123 \
  -e PEXELS_API_KEY=FDrZIasw3qXF6eOCc0dafpZ9cJnN2FfAWi3xEn1mcHy9lqmLqpuIebwC \
  gyoridavid/short-video-maker:latest-tiny

# إعداد ngrok
ngrok config add-authtoken 2ydu6xnFE745us2CHwUkj3AAjUe_7QBXqRsTdNKYh76JJZfK2

# تشغيل النفق في الخلفية وتخزين الـ log
nohup ngrok http --domain=talented-fleet-monkfish.ngrok-free.app 3123 > ~/ngrok_svm.log 2>&1 &

echo "✅ short-video-maker يعمل الآن على: https://talented-fleet-monkfish.ngrok-free.app"
