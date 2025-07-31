#!/bin/bash

# 📌 المتغيرات (قم بتعديلهما حسب الحاجة)
NGROK_DOMAIN="talented-fleet-monkfish.ngrok-free.app"
NGROK_TOKEN="2ydu6xnFE745us2CHwUkj3AAjUe_7QBXqRsTdNKYh76JJZfK2"

echo "🎬 بدء تثبيت short-video-maker وربطه بـ ngrok..."

# ✅ تحديث النظام وتثبيت الأدوات المطلوبة
echo "🔄 تحديث النظام وتثبيت الأدوات..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget jq docker.io

# 🔁 إيقاف وحذف أي حاوية قديمة بنفس الاسم
echo "🧹 التحقق من وجود حاوية قديمة لـ short-video-maker..."
sudo docker stop short-video-maker 2>/dev/null || true
sudo docker rm short-video-maker 2>/dev/null || true

# 🐳 تشغيل الحاوية
echo "🚀 تشغيل short-video-maker بالحاوية..."
sudo docker run -d --name short-video-maker \
  --restart unless-stopped \
  -p 3123:3123 \
  -e PEXELS_API_KEY=FDrZIasw3qXF6eOCc0dafpZ9cJnN2FfAWi3xEn1mcHy9lqmLqpuIebwC \
  gyoridavid/short-video-maker:latest-tiny

# 🧪 تثبيت ngrok إذا لم يكن مثبتًا
if ! command -v ngrok &> /dev/null; then
  echo "⬇️ ngrok غير مثبت، يتم تحميله وتثبيته الآن..."
  wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf ngrok.tgz -C /usr/local/bin
fi

# 🧾 إعداد ngrok بحسابك الشخصي
echo "🔑 ربط ngrok بالحساب باستخدام التوكن..."
ngrok config add-authtoken "$NGROK_TOKEN"

# 🧹 حذف الخدمة القديمة إن وُجدت
echo "🧯 حذف أي خدمة ngrok-svm قديمة..."
sudo systemctl stop ngrok-svm.service 2>/dev/null || true
sudo systemctl disable ngrok-svm.service 2>/dev/null || true
sudo rm /etc/systemd/system/ngrok-svm.service 2>/dev/null || true

# ⚙️ إنشاء خدمة systemd لـ ngrok
echo "🛠️ إنشاء خدمة systemd لـ ngrok..."
sudo bash -c "cat > /etc/systemd/system/ngrok-svm.service <<EOF
[Unit]
Description=Ngrok Tunnel for Short Video Maker
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=$NGROK_DOMAIN 3123
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF"

# ✅ تفعيل الخدمة
sudo systemctl daemon-reload
sudo systemctl enable ngrok-svm.service
sudo systemctl start ngrok-svm.service

# ⏳ انتظار ngrok ليشتغل
echo "⏳ انتظار ngrok ليشتغل..."
sleep 8

# 🌐 جلب رابط ngrok من الـ API المحلي (اختياري إذا كنت تستعمل النطاق الخاص)
NGROK_URL="https://$NGROK_DOMAIN"

echo "✅ short-video-maker يعمل الآن على: $NGROK_URL"
