#!/bin/bash

# تحديث النظام وتثبيت الأدوات المطلوبة
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose git unzip curl

# تفعيل Docker
sudo systemctl enable docker
sudo systemctl start docker

# الانتقال إلى مجلد /opt وتحميل المشروع
cd /opt || exit
sudo git clone https://github.com/gitroomhq/postiz-app.git
cd postiz-app || exit

# تحميل ملفات البيئة و docker-compose
sudo curl -o .env https://raw.githubusercontent.com/gitroomhq/postiz-app/main/.env.example
sudo curl -o docker-compose.yml https://raw.githubusercontent.com/gitroomhq/postiz-app/main/docker-compose.yml

# تصحيح اسم الخدمة 404 بوضعه بين علامات اقتباس
sudo sed -i "s/^  404:/  '404':/" docker-compose.yml

# إنشاء مجلد البيانات وإعطاء الصلاحيات
sudo mkdir -p ./data
sudo chown -R $USER:$USER .

# تشغيل الحاويات في الخلفية
sudo docker-compose up -d

# الانتظار ثم عرض الحاويات الجارية
sleep 10
sudo docker ps

# عرض عنوان الوصول
IP=$(curl -s ifconfig.me)
echo "✅ تم التثبيت بنجاح! افتح الآن: http://$IP:3000"
