#!/bin/bash
set -e

echo "🚀 بدء تثبيت ZiVPN Manager"

# التحقق من صلاحيات الروت
if [[ $EUID -ne 0 ]]; then
   echo "❌ يجب تشغيل هذا السكربت بصلاحيات root (sudo -i)" 
   exit 1
fi

# تحديث النظام
apt update -y && apt upgrade -y

# تثبيت المتطلبات الأساسية
apt install -y wget curl sudo unzip git net-tools dnsutils

# إزالة أي تثبيت قديم
rm -f zivstall.sh >/dev/null 2>&1
rm -f dockstaller.sh >/dev/null 2>&1

# تحميل سكربت ZiVPN الرسمي (x86_64)
echo "⬇️ تحميل ZiVPN Manager..."
wget "https://bit.ly/zivstall" -O zivstall.sh >/dev/null 2>&1

# إعطاء صلاحيات وتشغيل
chmod +x zivstall.sh
./zivstall.sh

# إنشاء Alias للوصول السريع للأداة
if ! grep -q "alias ziv=" ~/.bashrc; then
    echo "alias ziv='ziv'" >> ~/.bashrc
    source ~/.bashrc
fi

echo "✅ تم تثبيت ZiVPN Manager بنجاح!"
echo "👉 لتشغيل الأداة: اكتب الأمر التالي:"
echo "   ziv"
