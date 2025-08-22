#!/bin/bash

# -----------------------------
# تحديث النظام + تثبيت الأدوات
# -----------------------------
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git unzip nginx certbot python3-certbot-nginx docker.io docker-compose

# -----------------------------
# تحميل Postiz
# -----------------------------
cd /opt
if [ -d "postiz" ]; then
  sudo rm -rf postiz
fi
sudo git clone https://github.com/gitroomhq/postiz-app postiz
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
PORT=5000
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
  backend:
    environment:
      - PORT=5000
    ports:
      - "5000:5000"

  frontend:
    environment:
      - PORT=4200
    ports:
      - "4200:4200"

  postgres:
    ports:
      - "5432:5432"

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
    server_name postiz.soufianeautomation.space;

    location / {
        proxy_pass http://127.0.0.1:4200;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# إعداد Nginx للـ backend API
sudo tee /etc/nginx/sites-available/postiz-backend <<'EOF'
server {
    server_name postiz-api.soufianeautomation.space;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# -----------------------------
# تفعيل الكونفيغ (مع تنظيف القديم)
# -----------------------------
sudo rm -f /etc/nginx/sites-enabled/postiz-frontend
sudo rm -f /etc/nginx/sites-enabled/postiz-backend
sudo ln -s /etc/nginx/sites-available/postiz-frontend /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/postiz-backend /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# -----------------------------
# شهادة SSL (مع التوسيع لو فيه قديم)
# -----------------------------
sudo certbot --nginx -d postiz.soufianeautomation.space -d postiz-api.soufianeautomation.space --expand --non-interactive --agree-tos -m admin@soufianeautomation.space

echo "✅ تم تثبيت Postiz بنجاح!"
echo "Frontend: https://postiz.soufianeautomation.space"
echo "Backend API: https://postiz-api.soufianeautomation.space"
