# 🛑 إيقاف وحذف كل الحاويات
sudo docker stop $(docker ps -aq)
sudo docker rm $(docker ps -aq)

# 🧼 حذف جميع الخدمات ngrok
sudo systemctl stop ngrok-svm.service 2>/dev/null
sudo systemctl disable ngrok-svm.service 2>/dev/null
sudo rm /etc/systemd/system/ngrok-svm.service 2>/dev/null

sudo systemctl stop ngrok-n8n.service 2>/dev/null
sudo systemctl disable ngrok-n8n.service 2>/dev/null
sudo rm /etc/systemd/system/ngrok-n8n.service 2>/dev/null

# 🔁 إعادة تحميل النظام
sudo systemctl daemon-reload

# ✅ حذف ملفات ngrok config إذا أردت البداية من الصفر
rm -rf ~/.config/ngrok

# ✅ تنظيف البيانات القديمة (اختياري)
sudo rm -rf ~/n8n_data
