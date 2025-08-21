#!/bin/bash

DOMAIN="postiz.soufianeautomation.space"
EMAIL="soufianeouakifbsn@gmail.com"
POSTIZ_DATA="$HOME/postiz_data"

echo "🚀 Starting Postiz installation on $DOMAIN ..."

# تحديث النظام
# -----------------------------
# تحديث النظام + تثبيت الأدوات
# -----------------------------
sudo apt update && sudo apt upgrade -y

# تثبيت الأدوات
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw git

# تفعيل Docker
sudo systemctl enable docker
sudo systemctl start docker

# إنشاء مجلد البيانات
mkdir -p $POSTIZ_DATA
cd $POSTIZ_DATA

# إنشاء ملف docker-compose.yml
tee docker-compose.yml > /dev/null <<EOF
version: '3.9'
sudo apt install -y curl git unzip nginx certbot python3-certbot-nginx docker.io docker-compose

# -----------------------------
# تحميل Postiz
# -----------------------------
cd /opt
sudo git clone https://github.com/gitroomhq/postiz.git
cd postiz

# -----------------------------
# إنشاء ملف البيئة (backend + frontend)
# -----------------------------
cat > .env <<EOL
# Postgres
POSTGRES_USER=postiz
POSTGRES_PASSWORD=postizpass
POSTGRES_DB=postiz

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# Backend
PORT=3000
BACKEND_URL=https://postiz-api.soufianeautomation.space

# Frontend
FRONTEND_PORT=4200
FRONTEND_URL=https://postiz.soufianeautomation.space
EOL

# -----------------------------
# docker-compose.yml (تحديث البورتات)
# -----------------------------
cat > docker-compose.override.yml <<EOL
version: "3.8"

services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
  backend:
    environment:
      MAIN_URL: "https://$DOMAIN"
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
      - PORT=3000
    ports:
      - 5000:5000
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
      - "3000:3000"

  frontend:
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
      - PORT=4200
    ports:
      - "4200:4200"

# تشغيل الخدمات
sudo docker-compose up -d
  postgres:
    ports:
      - "5432:5432"

# إعداد Nginx كـ Reverse Proxy
sudo tee /etc/nginx/sites-available/postiz.conf > /dev/null <<EOF
  redis:
    ports:
      - "6379:6379"
EOL

# -----------------------------
# تشغيل الكونتينرات
# -----------------------------
sudo docker-compose up -d --build

# -----------------------------
# إعداد Nginx للـ frontend
# -----------------------------
sudo tee /etc/nginx/sites-available/postiz-frontend <<'EOF'
server {
    server_name $DOMAIN;
    server_name postiz.soufianeautomation.space;

    location / {
        proxy_pass http://127.0.0.1:5000;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:4200;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/postiz.conf /etc/nginx/sites-enabled/ || true
sudo nginx -t && sudo systemctl restart nginx

# SSL
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
# إعداد Nginx للـ backend API
sudo tee /etc/nginx/sites-available/postiz-backend <<'EOF'
server {
    server_name postiz-api.soufianeautomation.space;

# Firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

echo "✅ Postiz installed successfully on https://$DOMAIN"
# -----------------------------
# تفعيل الكونفيغ
# -----------------------------
sudo ln -s /etc/nginx/sites-available/postiz-frontend /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/postiz-backend /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# -----------------------------
# شهادة SSL
# -----------------------------
sudo certbot --nginx -d postiz.soufianeautomation.space -d postiz-api.soufianeautomation.space --non-interactive --agree-tos -m admin@soufianeautomation.space

echo "✅ تم تثبيت Postiz بنجاح!"
echo "Frontend: https://postiz.soufianeautomation.space"
echo "Backend API: https://postiz-api.soufianeautomation.space"
