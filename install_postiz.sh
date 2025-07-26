#!/bin/bash

echo "🚀 بدء تثبيت Postiz وربطه بـ ngrok..."

# 🧰 تثبيت الأدوات اللازمة
sudo apt update
sudo apt install -y docker.io docker-compose curl

# ⬇️ تحميل ملفات Postiz الأصلية من GitHub
mkdir -p ~/postiz && cd ~/postiz
curl -o docker-compose.yml https://raw.githubusercontent.com/rammcodes/postiz/main/docker-compose.yml

# 🛠 إعداد ngrok
if ! command -v ngrok &> /dev/null; then
  echo "⬇️ تثبيت ngrok..."
  wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf ngrok.tgz -C /usr/local/bin
fi

# 🪪 إضافة التوكن
ngrok config add-authtoken 30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9

# ⚙️ إنشاء خدمة systemd للـ ngrok
sudo bash -c 'cat > /etc/systemd/system/ngrok-postiz.service <<EOF
[Unit]
Description=Ngrok Tunnel for Postiz
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=jaybird-normal-publicly.ngrok-free.app 3000
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable ngrok-postiz.service
sudo systemctl start ngrok-postiz.service

# 🔄 انتظار ngrok ليشتغل
sleep 8

# 📦 تشغيل Postiz
sudo docker compose up -d

echo "✅ تم تشغيل Postiz على: https://jaybird-normal-publicly.ngrok-free.app"
