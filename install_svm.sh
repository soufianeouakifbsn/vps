#!/bin/bash

echo "🎬 بدء تثبيت short-video-maker وربطه بـ ngrok..."

# تثبيت Docker إذا لم يكن مثبتًا
if ! command -v docker &> /dev/null; then
  echo "🔧 تثبيت Docker..."
  sudo apt update
  sudo apt install -y docker.io
fi

# تشغيل الحاوية
sudo docker run -d --name short-video-maker \
  --restart unless-stopped \
  -p 3123:3123 \
  -e PEXELS_API_KEY=xxxxxxxxxxxxxxxxxxxxxx \
  gyoridavid/short-video-maker:latest-tiny

# تثبيت ngrok إذا لم يكن موجودًا
if ! command -v ngrok &> /dev/null; then
  echo "⬇️ تثبيت ngrok..."
  wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf ngrok.tgz -C /usr/local/bin
fi

# إعداد ngrok لحساب SVM
ngrok config add-authtoken xxxxxxxxxxxxxxxxx

# إنشاء systemd service ل ngrok SVM
sudo bash -c 'cat > /etc/systemd/system/ngrok-svm.service <<EOF
[Unit]
Description=Ngrok Tunnel for Short Video Maker
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=xxxxxxxxxx.ngrok-free.app 3123
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

# تفعيل الخدمة
sudo systemctl daemon-reload
sudo systemctl enable ngrok-svm.service
sudo systemctl start ngrok-svm.service

echo "✅ short-video-maker يعمل الآن على: https://xxxxxxxxxx.ngrok-free.app"
