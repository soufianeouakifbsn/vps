#!/bin/bash

# إعداد مبدئي
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose git unzip curl

# تفعيل Docker
sudo systemctl enable docker
sudo systemctl start docker

# إنشاء مجلد المشروع
cd /opt || exit
sudo git clone https://github.com/gitroomhq/postiz-app.git
cd postiz-app || exit

# تحميل أحدث نسخة من env وملف docker-compose
sudo curl -o .env https://raw.githubusercontent.com/gitroomhq/postiz-app/main/.env.example

# إنشاء مجلد التخزين للبوت
sudo mkdir -p ./data

# إعطاء الصلاحيات
sudo chown -R $USER:$USER .

# تشغيل الخدمة
sudo docker-compose up -d

# الانتظار قليلاً ثم التحقق من التشغيل
sleep 10
sudo docker ps

# طباعة رابط الوصول
IP=$(curl -s ifconfig.me)
echo "✅ تم التثبيت بنجاح! افتح الآن: http://$IP:3000"
