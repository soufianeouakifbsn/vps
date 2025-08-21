@@ -1,4 +1,5 @@
#!/bin/bash
set -euo pipefail

# -----------------------------
# تحديث النظام + تثبيت الأدوات
@@ -7,10 +8,13 @@ sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git unzip nginx certbot python3-certbot-nginx docker.io docker-compose

# -----------------------------
# تحميل Postiz
# تحميل Postiz (مع تنظيف المجلد القديم لو موجود)
# -----------------------------
cd /opt
sudo git clone https://github.com/gitroomhq/postiz-app
if [ -d "postiz" ]; then
  sudo rm -rf postiz
fi
sudo git clone https://github.com/gitroomhq/postiz-app postiz
cd postiz

# -----------------------------
@@ -101,16 +105,21 @@ server {
EOF

# -----------------------------
# تفعيل الكونفيغ
# تنظيف أي روابط قديمة + تفعيل الجديدة
# -----------------------------
sudo rm -f /etc/nginx/sites-enabled/postiz-frontend
sudo rm -f /etc/nginx/sites-enabled/postiz-backend
sudo rm -f /etc/nginx/sites-enabled/default

sudo ln -s /etc/nginx/sites-available/postiz-frontend /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/postiz-backend /etc/nginx/sites-enabled/

sudo nginx -t && sudo systemctl reload nginx

# -----------------------------
# شهادة SSL
# شهادة SSL (مع --expand لتفادي التعارض)
# -----------------------------
sudo certbot --nginx -d postiz.soufianeautomation.space -d postiz-api.soufianeautomation.space --non-interactive --agree-tos -m admin@soufianeautomation.space
sudo certbot --nginx -d postiz.soufianeautomation.space -d postiz-api.soufianeautomation.space --expand --non-interactive --agree-tos -m admin@soufianeautomation.space

echo "✅ تم تثبيت Postiz بنجاح!"
echo "Frontend: https://postiz.soufianeautomation.space"
