#!/bin/bash

echo "🚀 بدء تثبيت Postiz وربطه بـ ngrok..."

# 🐳 التأكد من أن Docker مثبت
if ! command -v docker &> /dev/null; then
  echo "📦 تثبيت Docker..."
  sudo apt update
  sudo apt install -y docker.io docker-compose
else
  echo "✅ Docker موجود بالفعل"
fi

# 🌐 تثبيت ngrok إذا لم يكن مثبتًا
if ! command -v ngrok &> /dev/null; then
  echo "⬇️ تثبيت ngrok..."
  wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf ngrok.tgz -C /usr/local/bin
  rm ngrok.tgz
else
  echo "✅ ngrok موجود بالفعل"
fi

# 🔐 إعداد ngrok لحساب Postiz
ngrok config add-authtoken 30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9

# 📁 إنشاء مجلد Postiz
echo "📁 إنشاء مجلد ~/postiz..."
mkdir -p ~/postiz
cd ~/postiz
echo "📍 المجلد الحالي: $(pwd)"

# 📝 إنشاء ملف docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:v1.36.1-amd64
    container_name: postiz
    restart: always
    environment:
      # إعدادات URL الأساسية
      MAIN_URL: "https://jaybird-normal-publicly.ngrok-free.app"
      FRONTEND_URL: "https://jaybird-normal-publicly.ngrok-free.app"
      NEXT_PUBLIC_BACKEND_URL: "https://jaybird-normal-publicly.ngrok-free.app/api"
      
      # إعدادات الأمان
      JWT_SECRET: "postiz_jwt_secret_$(date +%s)_$(openssl rand -hex 16)"
      NOT_SECURED: "true"
      
      # إعدادات قاعدة البيانات
      DATABASE_URL: "postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local"
      REDIS_URL: "redis://postiz-redis:6379"
      BACKEND_INTERNAL_URL: "http://localhost:3000"
      
      # إعدادات عامة
      IS_GENERAL: "true"
      DISABLE_REGISTRATION: "false"
      
      # إعدادات التخزين
      STORAGE_PROVIDER: "local"
      UPLOAD_DIRECTORY: "/uploads"
      NEXT_PUBLIC_UPLOAD_DIRECTORY: "/uploads"
      
    volumes:
      - postiz-config:/config/
      - postiz-uploads:/uploads/
    ports:
      - "5000:5000"
    networks:
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
      - postgres-volume:/var/lib/postgresql/data
    networks:
      - postiz-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postiz-user -d postiz-db-local"]
      interval: 10s
      timeout: 3s
      retries: 3

  postiz-redis:
    image: redis:7.2-alpine
    container_name: postiz-redis
    restart: always
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3
    volumes:
      - postiz-redis-data:/data
    networks:
      - postiz-network

volumes:
  postgres-volume:
    external: false
  postiz-redis-data:
    external: false
  postiz-config:
    external: false
  postiz-uploads:
    external: false

networks:
  postiz-network:
    external: false
EOF

# 🧹 إيقاف وحذف الحاويات القديمة إن وُجدت
echo "🧹 تنظيف الحاويات القديمة..."
sudo docker stop postiz postiz-postgres postiz-redis 2>/dev/null || true
sudo docker rm postiz postiz-postgres postiz-redis 2>/dev/null || true
# محاولة إيقاف docker-compose إذا كان موجوداً
if [ -f docker-compose.yml ]; then
    sudo docker-compose down 2>/dev/null || true
fi

# 🔁 إنشاء خدمة ngrok للنطاق الثابت
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

# تفعيل وتشغيل خدمة ngrok
sudo systemctl daemon-reload
sudo systemctl enable ngrok-postiz.service
sudo systemctl start ngrok-postiz.service

# ⏱️ انتظار ngrok ليشتغل
echo "⌛️ انتظار ngrok..."
sleep 10

# 🐳 تشغيل Postiz
echo "🚀 تشغيل Postiz..."
echo "📁 التأكد من المجلد: $(pwd)"
ls -la
sudo docker-compose up -d

# ⏱️ انتظار تشغيل الخدمات
echo "⌛️ انتظار تشغيل جميع الخدمات..."
sleep 30

# 📊 عرض حالة الخدمات
echo "📊 حالة الخدمات:"
sudo docker-compose ps

# 🌍 التحقق من ngrok
NGROK_URL="https://jaybird-normal-publicly.ngrok-free.app"
echo "🌐 رابط Postiz: $NGROK_URL"

# 📋 عرض معلومات الدخول
echo ""
echo "✅ تم تثبيت Postiz بنجاح!"
echo "🌐 الرابط: $NGROK_URL"
echo "👤 يمكنك الآن إنشاء حساب جديد من خلال الواجهة"
echo ""
echo "📝 معلومات إضافية:"
echo "   - مجلد التثبيت: ~/postiz"
echo "   - لعرض اللوجز: cd ~/postiz && sudo docker-compose logs -f"
echo "   - لإعادة التشغيل: cd ~/postiz && sudo docker-compose restart"
echo "   - لإيقاف الخدمة: cd ~/postiz && sudo docker-compose down"
echo ""
echo "🔧 إذا واجهت مشاكل، تحقق من اللوجز باستخدام:"
echo "   cd ~/postiz && sudo docker-compose logs"
