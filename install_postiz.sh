#!/bin/bash

# 📌 المتغيرات
DOMAIN="postiz.soufianeautomation.space           # غيّر حسب الدومين الخاص بك
EMAIL="soufianeouakifbsn@gmail.com"             # ضع بريدك هنا لإدارة SSL
JWT_SECRET="$(openssl rand -base64 32)"  # توليد JWT secret عشوائي

echo "🚀 بدء تثبيت Postiz على $DOMAIN ..."

# تحديث النظام
sudo apt update && sudo apt upgrade -y

# تثبيت الأدوات الأساسية
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw openssl

# تفعيل Docker
sudo systemctl enable docker
sudo systemctl start docker

# إضافة المستخدم الحالي لمجموعة docker
sudo usermod -aG docker $USER

# 🧹 حذف Postiz القديم إن وجد
sudo docker stop postiz postiz-postgres postiz-redis 2>/dev/null || true
sudo docker rm postiz postiz-postgres postiz-redis 2>/dev/null || true
sudo docker network rm postiz-network 2>/dev/null || true

# إنشاء مجلد للمشروع
mkdir -p ~/postiz
cd ~/postiz

# 🐳 إنشاء ملف docker-compose.yml
cat > docker-compose.yml <<EOF
services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    environment:
      # URLs - يجب تغيير هذه القيم
      MAIN_URL: "https://$DOMAIN"
      FRONTEND_URL: "https://$DOMAIN"
      NEXT_PUBLIC_BACKEND_URL: "https://$DOMAIN/api"
      JWT_SECRET: "$JWT_SECRET"
 
      # قاعدة البيانات والـ Redis
      DATABASE_URL: "postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local"
      REDIS_URL: "redis://postiz-redis:6379"
      BACKEND_INTERNAL_URL: "http://localhost:3000"
      IS_GENERAL: "true"
      DISABLE_REGISTRATION: "false"
      
      # إعدادات التخزين
      STORAGE_PROVIDER: "local"
      UPLOAD_DIRECTORY: "/uploads"
      NEXT_PUBLIC_UPLOAD_DIRECTORY: "/uploads"
      
      # إعداد عدم الأمان للـ HTTP (إذا لم تكن تستخدم HTTPS)
      # NOT_SECURED: "true"
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
      test: pg_isready -U postiz-user -d postiz-db-local
      interval: 10s
      timeout: 3s
      retries: 3
      
  postiz-redis:
    image: redis:7.2
    container_name: postiz-redis
    restart: always
    healthcheck:
      test: redis-cli ping
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

echo "📝 تم إنشاء ملف docker-compose.yml"

# 🔧 إعداد Nginx كـ Reverse Proxy
sudo tee /etc/nginx/sites-available/postiz.conf > /dev/null <<EOF
server {
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:5000;

        # ✅ دعم WebSocket
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # ✅ تمرير الهيدر بشكل صحيح
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # ✅ منع انقطاع الاتصال
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;
        
        # ✅ زيادة حجم الملفات المسموح برفعها
        client_max_body_size 100M;
    }
}
EOF

# تفعيل الموقع
sudo ln -s /etc/nginx/sites-available/postiz.conf /etc/nginx/sites-enabled/ || true
sudo nginx -t && sudo systemctl restart nginx

# 🐳 تشغيل Postiz
echo "🐳 تشغيل Postiz..."
sudo docker compose up -d

# انتظار بدء الخدمات
echo "⏳ انتظار بدء الخدمات..."
sleep 30

# 🔒 الحصول على SSL من Let's Encrypt
echo "🔒 الحصول على شهادة SSL..."
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# فتح الجدار الناري (UFW)
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# 🛡️ تثبيت Watchtower للتحديث التلقائي
echo "🛡️ تثبيت Watchtower للتحديث التلقائي..."
sudo docker stop watchtower 2>/dev/null || true
sudo docker rm watchtower 2>/dev/null || true
sudo docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower postiz postiz-postgres postiz-redis --cleanup --interval 3600

# إعادة تشغيل الخدمات للتأكد من عملها مع SSL
echo "🔄 إعادة تشغيل الخدمات..."
sudo docker compose restart

echo ""
echo "✅ تم تثبيت Postiz بنجاح!"
echo "🌐 الرابط: https://$DOMAIN"
echo "🔑 JWT Secret: $JWT_SECRET"
echo "📝 ملف التكوين: ~/postiz/docker-compose.yml"
echo ""
echo "📋 الخطوات التالية:"
echo "1. انتظر 2-3 دقائق لبدء جميع الخدمات"
echo "2. اذهب إلى https://$DOMAIN"
echo "3. أنشئ حسابك الأول"
echo "4. يمكنك تعطيل التسجيل لاحقاً بتغيير DISABLE_REGISTRATION إلى true"
echo ""
echo "🔧 أوامر مفيدة:"
echo "   - عرض السجلات: cd ~/postiz && sudo docker compose logs -f"
echo "   - إعادة التشغيل: cd ~/postiz && sudo docker compose restart"
echo "   - إيقاف الخدمة: cd ~/postiz && sudo docker compose down"
echo "   - تحديث: cd ~/postiz && sudo docker compose pull && sudo docker compose up -d"
echo ""
echo "🛡️ Watchtower سيتحقق كل ساعة من وجود تحديثات ويطبقها تلقائياً"

# التحقق من حالة الخدمات
echo "📊 حالة الخدمات:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
