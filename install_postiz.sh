#!/bin/bash

# تحديث النظام وتثبيت المتطلبات
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose git unzip curl

# تفعيل Docker
sudo systemctl enable docker
sudo systemctl start docker

# الدخول إلى /opt وتحميل المشروع
cd /opt || exit
sudo git clone https://github.com/gitroomhq/postiz-app.git
cd postiz-app || exit

# تحميل ملفات البيئة
sudo curl -o .env https://raw.githubusercontent.com/gitroomhq/postiz-app/main/.env.example
sudo curl -o docker-compose.yml https://raw.githubusercontent.com/gitroomhq/postiz-app/main/docker-compose.yml

# تصحيح مشكلة اسم الخدمة 404
sudo sed -i "s/^  404:/  '404':/" docker-compose.yml

# إنشاء مجلد البيانات
sudo mkdir -p ./data

# إعطاء الصلاحيات للمستخدم الحالي
sudo chown -R $USER:$USER .

# تشغيل الحاويات
sudo docker-compose up -d

# الانتظار ثم عرض الحاويات
sleep 10
sudo docker ps

# طباعة رابط الوصول
IP=$(curl -s ifconfig.me)
echo "✅ تم التثبيت بنجاح! افتح الآن: http://$IP:3000"
