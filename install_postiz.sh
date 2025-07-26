#!/bin/bash

# 🎛️ سكريبت التحكم في Postiz

# تأكد من تشغيل السكربت كـ root
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ يجب تشغيل هذا السكربت باستخدام sudo أو كـ root"
  exit 1
fi

cd ~/postiz || { echo "❌ مجلد postiz غير موجود"; exit 1; }

if [[ ! -f docker-compose.yml ]]; then
  echo "❌ ملف docker-compose.yml غير موجود في ~/postiz"
  exit 1
fi

case "$1" in
  start)
    echo "🚀 بدء تشغيل Postiz..."
    systemctl start ngrok-postiz.service
    sleep 5
    docker-compose up -d
    echo "✅ تم تشغيل Postiz"
    ;;
  
  stop)
    echo "⏹️ إيقاف Postiz..."
    docker-compose down
    systemctl stop ngrok-postiz.service
    echo "✅ تم إيقاف Postiz"
    ;;
  
  restart)
    echo "🔄 إعادة تشغيل Postiz..."
    docker-compose down
    systemctl restart ngrok-postiz.service
    sleep 5
    docker-compose up -d
    echo "✅ تم إعادة التشغيل"
    ;;
  
  status)
    echo "📊 حالة خدمات Postiz:"
    echo ""
    echo "🌐 Ngrok Service:"
    systemctl status ngrok-postiz.service --no-pager -l
    echo ""
    echo "🐳 Docker Containers:"
    docker-compose ps
    echo ""
    echo "🌍 URL: https://jaybird-normal-publicly.ngrok-free.app"
    ;;
  
  logs)
    echo "📋 عرض آخر 50 سطر من اللوجز:"
    docker-compose logs --tail=50 -f
    ;;
  
  update)
    echo "📦 تحديث Postiz..."
    docker-compose pull
    docker-compose down
    docker-compose up -d
    echo "✅ تم التحديث"
    ;;
  
  backup)
    echo "💾 إنشاء نسخة احتياطية..."
    BACKUP_FILE="postiz_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czvf "$BACKUP_FILE" data/
    echo "✅ تم إنشاء النسخة: $BACKUP_FILE"
    ;;
  
  uninstall)
    echo "🧹 إزالة Postiz بالكامل..."
    docker-compose down
    systemctl stop ngrok-postiz.service
    systemctl disable ngrok-postiz.service
    rm /etc/systemd/system/ngrok-postiz.service
    systemctl daemon-reload
    echo "✅ تمت الإزالة بنجاح"
    ;;
  
  *)
    echo "🎛️ سكريبت التحكم في Postiz"
    echo ""
    echo "الاستخدام: $0 {start|stop|restart|status|logs|update|backup|uninstall}"
    echo ""
    echo "الأوامر المتاحة:"
    echo "  start     - تشغيل Postiz"
    echo "  stop      - إيقاف Postiz"
    echo "  restart   - إعادة التشغيل"
    echo "  status    - عرض الحالة"
    echo "  logs      - عرض اللوجز"
    echo "  update    - تحديث الحاوية"
    echo "  backup    - حفظ نسخة احتياطية"
    echo "  uninstall - إزالة الخدمة بالكامل"
    echo ""
    exit 1
    ;;
esac
