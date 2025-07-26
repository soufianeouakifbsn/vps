#!/bin/bash

echo "🚨 بدء تنظيف النظام من تثبيت Postiz السابق..."

# 🧹 1. إيقاف وحذف الحاويات القديمة إن وُجدت
sudo docker stop postiz postiz-postgres postiz-redis 2>/dev/null || true
sudo docker rm postiz postiz-postgres postiz-redis 2>/dev/null || true

# 🧹 2. حذف الشبكة القديمة إن وُجدت
sudo docker network rm postiz-network 2>/dev/null || true

# 🧹 3. حذف مجلدات البيانات القديمة
rm -rf ~/postiz

# 🧹 4. حذف خدمة ngrok القديمة الخاصة بـ Postiz
sudo systemctl stop ngrok-postiz.service 2>/dev/null || true
sudo systemctl disable ngrok-postiz.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/ngrok-postiz.service
sudo systemctl daemon-reload

echo "✅ تم التنظيف بنجاح!"

echo "🔧 بدء التثبيت الجديد..."

# 📦 5. تثبيت Docker إذا لم يكن مثبتًا
if ! command -v docker &> /dev/null; then
  echo "📦 تثبيت Docker..."
  sudo apt update
  sudo apt install -y docker.io
  sudo systemctl start docker
  sudo systemctl enable docker
fi

# ⚙️ 6. تثبيت docker-compose إذا لم يكن موجودًا
if ! command -v docker-compose &> /dev/null; then
  echo "🔧 تثبيت docker-compose..."
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# 🌐 7. تثبيت ngrok إذا لم يكن موجودًا
if ! command -v ngrok &> /dev/null; then
  echo "⬇️ تثبيت ngrok..."
  wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf ngrok.tgz -C /usr/local/bin
fi

# 🔐 8. إعداد ngrok بالتوكن الخاص بك
ngrok config add-authtoken 30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9

# 📁 9. إنشاء مجلد للعمل
export WORKING_DIR=$HOME
mkdir -p $WORKING_DIR/postiz/{config,uploads,postgres,redis}

# ⚙️ 10. إعداد ملف البيئة .env
cat > $WORKING_DIR/postiz/.env <<EOF
DOMAIN=jaybird-normal-publicly.ngrok-free.app
WORKING_DIR=$WORKING_DIR
EOF

# 🐳 11. إنشاء ملف docker-compose.yml
cat > $WORKING_DIR/postiz/docker-compose.yml <<'EOF'
version: '3.9'
services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    env_file: 
      - .env
    environment:
      MAIN_URL: "https://postiz.${DOMAIN}"
      FRONTEND_URL: "https://postiz.${DOMAIN}"
      NEXT_PUBLIC_BACKEND_URL: "https://postiz.${DOMAIN}/api"
      JWT_SECRET: "sdfjhkj34sdkfhsdkfhsdkjfhsdf"
      DATABASE_URL: "postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local"
      REDIS_URL: "redis://postiz-redis:6379"
      BACKEND_INTERNAL_URL: "http://localhost:3000"
      IS_GENERAL: "true"
      STORAGE_PROVIDER: "local"
      UPLOAD_DIRECTORY: "/uploads"
      NEXT_PUBLIC_UPLOAD_DIRECTORY: "/uploads"
    volumes:
      - ${WORKING_DIR}/postiz/config:/config/
      - ${WORKING_DIR}/postiz/uploads:/uploads/
    networks:
      - proxy
      - postiz-network
    depends_on:
      postiz-postgres:
        condition: service_healthy
      postiz-redis:
        condition: service_healthy

  postiz-postgres:
    image: postgres:17-alpine
    container_name: postiz-postgres
    restart: always
    environment:
      POSTGRES_PASSWORD: postiz-password
      POSTGRES_USER: postiz-user
      POSTGRES_DB: postiz-db-local
    volumes:
      - ${WORKING_DIR}/postiz/postgres:/var/lib/postgresql/data
    networks:
      - postiz-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postiz-user -d postiz-db-local"]
      interval: 10s
      timeout: 3s
      retries: 3

  postiz-redis:
    image: redis:7.2
    container_name: postiz-redis
    restart: always
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3
    volumes:
      - ${WORKING_DIR}/postiz/redis:/data
    networks:
      - postiz-network

networks:
  proxy:
    external: true
  postiz-network:
    external: false
EOF

# 🌍 12. إعداد خدمة ngrok الخاصة بـ postiz
sudo bash -c 'cat > /etc/systemd/system/ngrok-postiz.service <<EOF
[Unit]
Description=Ngrok Tunnel for Postiz
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=jaybird-normal-publicly.ngrok-free.app 5000
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable ngrok-postiz.service
sudo systemctl start ngrok-postiz.service

# ⏳ 13. انتظار ngrok ليبدأ
echo "⌛️ انتظار ngrok ليشتغل..."
sleep 8

# 🚀 14. تشغيل postiz باستخدام docker-compose
cd $WORKING_DIR/postiz
docker-compose up -d

echo "✅ تم تشغيل postiz بنجاح على: https://jaybird-normal-publicly.ngrok-free.app"
