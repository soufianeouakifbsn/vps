@@ -1,16 +1,15 @@
#!/bin/bash

# 📌 المتغيرات
DOMAIN="postiz.soufianeautomation.space"    # غيّر للدومين الخاص بك
EMAIL="soufianeouakifbsn@gmail.com"        # بريدك للحصول على SSL
DOMAIN="postiz.soufianeautomation.space"
EMAIL="soufianeouakifbsn@gmail.com"
POSTIZ_DATA="$HOME/postiz_data"

echo "🚀 بدء التثبيت التلقائي لـ Postiz على $DOMAIN ..."
echo "🚀 Starting Postiz installation on $DOMAIN ..."

# تحديث النظام
sudo apt update && sudo apt upgrade -y

# تثبيت الأدوات الأساسية
# تثبيت الأدوات
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw git

# تفعيل Docker
@@ -19,123 +18,113 @@ sudo systemctl start docker

# إنشاء مجلد البيانات
mkdir -p $POSTIZ_DATA
sudo chown -R 1000:1000 $POSTIZ_DATA
cd $POSTIZ_DATA

# إنشاء ملف Docker Compose
tee $POSTIZ_DATA/docker-compose.yml > /dev/null <<EOF
# إنشاء ملف docker-compose.yml
tee docker-compose.yml > /dev/null <<EOF
version: '3.9'

services:
  postgresql:
    image: postgres:15
    container_name: postiz_postgres
    environment:
      POSTGRES_USER: postiz
      POSTGRES_PASSWORD: postizpass
      POSTGRES_DB: postizdb
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postiz -d postizdb"]
      interval: 5s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  redis:
    image: redis:7
    container_name: postiz_redis
    volumes:
      - ./redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  migrate:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz_migrate
    environment:
      DATABASE_URL: "postgresql://postiz:postizpass@postgresql:5432/postizdb"
      REDIS_URL: "redis://redis:6379"
    command: >
      sh -c "pnpm prisma db push --schema ./libraries/nestjs-libraries/src/database/prisma/schema.prisma"
    depends_on:
      postgresql:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: "on-failure"

  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    environment:
      MAIN_URL: "https://$DOMAIN"
      DATABASE_URL: "postgresql://postiz:postizpass@postgresql:5432/postizdb"
      REDIS_URL: "redis://redis:6379"
      FRONTEND_URL: "https://$DOMAIN"
      NEXT_PUBLIC_BACKEND_URL: "https://$DOMAIN/api"
      JWT_SECRET: "CHANGE_ME_RANDOM_SECRET_$(openssl rand -hex 16)"
      DATABASE_URL: "postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local"
      REDIS_URL: "redis://postiz-redis:6379"
      BACKEND_INTERNAL_URL: "http://localhost:3000"
      IS_GENERAL: "true"
      DISABLE_REGISTRATION: "false"
      STORAGE_PROVIDER: "local"
      UPLOAD_DIRECTORY: "/uploads"
      NEXT_PUBLIC_UPLOAD_DIRECTORY: "/uploads"
    volumes:
      - postiz-config:/config/
      - postiz-uploads:/uploads/
    ports:
      - "3000:3000"
      - 5000:5000
    networks:
      - postiz-network
    depends_on:
      postgresql:
      postiz-postgres:
        condition: service_healthy
      redis:
      postiz-redis:
        condition: service_healthy
      migrate:
        condition: service_completed_successfully
    restart: unless-stopped

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
      retries: 5

  postiz-redis:
    image: redis:7.2
    container_name: postiz-redis
    restart: always
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    volumes:
      - postiz-redis-data:/data
    networks:
      - postiz-network

volumes:
  postgres-volume:
  postiz-redis-data:
  postiz-config:
  postiz-uploads:

networks:
  postiz-network:
EOF

# تشغيل Docker Compose
cd $POSTIZ_DATA
# تشغيل الخدمات
sudo docker-compose up -d

# ✅ التأكد من تشغيل الحاويات
sleep 15
echo "🔹 حالة الحاويات:"
sudo docker-compose ps

# إعداد Nginx كـ Reverse Proxy
sudo tee /etc/nginx/sites-available/postiz.conf > /dev/null <<EOF
server {
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_pass http://127.0.0.1:5000;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        send_timeout 600s;
    }
}
EOF

# تفعيل الموقع وإعادة تشغيل Nginx
sudo ln -s /etc/nginx/sites-available/postiz.conf /etc/nginx/sites-enabled/ || true
sudo nginx -t && sudo systemctl restart nginx

# الحصول على SSL من Let's Encrypt
# SSL
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# فتح الجدار الناري
# Firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# تثبيت Watchtower للتحديث التلقائي
sudo docker stop watchtower 2>/dev/null || true
sudo docker rm watchtower 2>/dev/null || true
sudo docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower postiz --cleanup --interval 3600

echo "✅ تم تثبيت Postiz بالكامل على https://$DOMAIN"
echo "🎉 افتح الموقع لإنشاء الحساب وبدء الاستخدام!"
echo "✅ Postiz installed successfully on https://$DOMAIN"
