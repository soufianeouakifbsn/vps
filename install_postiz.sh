#!/bin/bash

# 📌 المتغيرات - قم بتعديلها حسب الحاجة
DOMAIN="postiz.soufianeautomation.space"
EMAIL="soufianeouakifbsn@gmail.com"
POSTGRES_PASSWORD="$(openssl rand -base64 32)"
JWT_SECRET="$(openssl rand -base64 64)"
POSTIZ_DIR="$HOME/postiz"

echo "🚀 بدء تثبيت Postiz على $DOMAIN ..."

# تحديث النظام
echo "🔄 تحديث النظام..."
sudo apt update && sudo apt upgrade -y

# تثبيت الأدوات الأساسية
echo "📦 تثبيت الأدوات الأساسية..."
sudo apt install -y docker.io docker-compose-plugin nginx certbot python3-certbot-nginx ufw openssl

# تفعيل Docker
echo "🐳 تفعيل وتشغيل Docker..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# 🧹 حذف postiz القديم إن وجد
echo "🧹 حذف أي تثبيت قديم لـ Postiz..."
sudo docker compose -f "$POSTIZ_DIR/docker-compose.yml" down 2>/dev/null || true
sudo rm -rf "$POSTIZ_DIR" 2>/dev/null || true

# إنشاء مجلد Postiz
echo "📁 إنشاء مجلد Postiz..."
mkdir -p "$POSTIZ_DIR"
cd "$POSTIZ_DIR"

# 📝 إنشاء ملف docker-compose.yml
echo "📝 إنشاء ملف docker-compose.yml..."
cat > docker-compose.yml <<EOF
services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    environment:
      # URLs Configuration
      MAIN_URL: "https://$DOMAIN"
      FRONTEND_URL: "https://$DOMAIN"
      NEXT_PUBLIC_BACKEND_URL: "https://$DOMAIN/api"
      
      # Security
      JWT_SECRET: "$JWT_SECRET"
      
      # Database Configuration
      DATABASE_URL: "postgresql://postiz-user:$POSTGRES_PASSWORD@postiz-postgres:5432/postiz-db-local"
      REDIS_URL: "redis://postiz-redis:6379"
      BACKEND_INTERNAL_URL: "http://localhost:3000"
      
      # General Settings
      IS_GENERAL: "true"
      DISABLE_REGISTRATION: "false"
      
      # File Storage
      STORAGE_PROVIDER: "local"
      UPLOAD_DIRECTORY: "/uploads"
      NEXT_PUBLIC_UPLOAD_DIRECTORY: "/uploads"
      
    volumes:
      - postiz-config:/config/
      - postiz-uploads:/uploads/
    ports:
      - "127.0.0.1:5000:5000"
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
    environment:
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
      POSTGRES_USER: postiz-user
      POSTGRES_DB: postiz-db-local
    volumes:
      - postgres-volume:/var/lib/postgresql/data
    networks:
      - postiz-network
    healthcheck:
      test: pg_isready -U postiz-user -d postiz-db-local
      interval: 10s
      timeout: 3s
      retries: 3

  postiz-redis:
    image: redis:7.2
    container_name: postiz-redis
    restart: always
    healthcheck:
      test: redis-cli ping
      interval: 10s
      timeout: 3s
      retries: 3
    volumes:
      - postiz-redis-data:/data
    networks:
      - postiz-network

volumes:
  postgres-volume:
    external: false
  postiz-redis-data:
    external: false
  postiz-config:
    external: false
  postiz-uploads:
    external: false

networks:
  postiz-network:
    external: false
EOF

# 💾 حفظ كلمات المرور في ملف آمن
echo "🔐 حفظ بيانات الاعتماد..."
cat > credentials.txt <<EOF
=== بيانات Postiz ===
Domain: $DOMAIN
Postgres Password: $POSTGRES_PASSWORD
JWT Secret: $JWT_SECRET
Generated: $(date)

⚠️  احتفظ بهذا الملف في مكان آمن!
EOF

chmod 600 credentials.txt

# 🔧 إعداد Nginx كـ Reverse Proxy
echo "🔧 إعداد Nginx Reverse Proxy..."
sudo tee /etc/nginx/sites-available/postiz.conf > /dev/null <<EOF
server {
    server_name $DOMAIN;

    # زيادة حجم الملفات المرفوعة
    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:5000;
        
        # ✅ دعم WebSocket
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # ✅ تمرير الهيدر بشكل صحيح
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # ✅ منع انقطاع الاتصال
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_connect_timeout 75s;
        
        # ✅ تحسينات إضافية
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # معالجة الملفات المرفوعة
    location /uploads/ {
        proxy_pass http://127.0.0.1:5000/uploads/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# حذف الرابط القديم إن وُجد وإنشاء رابط جديد
sudo rm -f /etc/nginx/sites-enabled/postiz.conf
sudo ln -s /etc/nginx/sites-available/postiz.conf /etc/nginx/sites-enabled/

# اختبار إعداد Nginx
if sudo nginx -t; then
    echo "✅ إعداد Nginx صحيح"
    sudo systemctl restart nginx
else
    echo "❌ خطأ في إعداد Nginx"
    exit 1
fi

# 🔒 الحصول على SSL من Let's Encrypt
echo "🔒 الحصول على شهادة SSL..."
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# 🔥 إعداد الجدار الناري
echo "🔥 إعداد الجدار الناري..."
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# 🐳 تشغيل Postiz
echo "🚀 تشغيل Postiz..."
docker compose up -d

# ⏳ انتظار تشغيل الخدمات
echo "⏳ انتظار تشغيل الخدمات..."
sleep 30

# 🔍 فحص حالة الخدمات
echo "🔍 فحص حالة الخدمات..."
docker compose ps

# 🧾 عرض السجلات للتأكد من عدم وجود أخطاء
echo "📋 فحص السجلات..."
docker compose logs --tail=20

# 🛡️ تثبيت Watchtower للتحديث التلقائي (اختياري)
echo "🛡️ تثبيت Watchtower للتحديث التلقائي..."
docker stop watchtower-postiz 2>/dev/null || true
docker rm watchtower-postiz 2>/dev/null || true
docker run -d \
  --name watchtower-postiz \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower postiz postiz-postgres postiz-redis --cleanup --interval 3600

# 📝 إنشاء سكريبت إدارة سريع
cat > manage_postiz.sh <<EOF
#!/bin/bash
# سكريبت إدارة Postiz

case \$1 in
  start)
    echo "🚀 تشغيل Postiz..."
    cd "$POSTIZ_DIR" && docker compose up -d
    ;;
  stop)
    echo "⏹️  إيقاف Postiz..."
    cd "$POSTIZ_DIR" && docker compose down
    ;;
  restart)
    echo "🔄 إعادة تشغيل Postiz..."
    cd "$POSTIZ_DIR" && docker compose down && docker compose up -d
    ;;
  logs)
    echo "📋 عرض السجلات..."
    cd "$POSTIZ_DIR" && docker compose logs -f
    ;;
  status)
    echo "📊 حالة الخدمات..."
    cd "$POSTIZ_DIR" && docker compose ps
    ;;
  update)
    echo "🔄 تحديث Postiz..."
    cd "$POSTIZ_DIR" && docker compose pull && docker compose up -d
    ;;
  backup)
    echo "💾 نسخ احتياطي من قاعدة البيانات..."
    docker exec postiz-postgres pg_dump -U postiz-user postiz-db-local > "postiz_backup_\$(date +%Y%m%d_%H%M%S).sql"
    ;;
  *)
    echo "الاستخدام: \$0 {start|stop|restart|logs|status|update|backup}"
    ;;
esac
EOF

chmod +x manage_postiz.sh

echo ""
echo "🎉🎉🎉 تم تثبيت Postiz بنجاح! 🎉🎉🎉"
echo ""
echo "📍 رابط الوصول: https://$DOMAIN"
echo "📁 مجلد التثبيت: $POSTIZ_DIR"
echo "📝 بيانات الاعتماد محفوظة في: $POSTIZ_DIR/credentials.txt"
echo ""
echo "🔧 أوامر الإدارة:"
echo "   cd $POSTIZ_DIR"
echo "   ./manage_postiz.sh start     # تشغيل"
echo "   ./manage_postiz.sh stop      # إيقاف"
echo "   ./manage_postiz.sh restart   # إعادة تشغيل"
echo "   ./manage_postiz.sh logs      # عرض السجلات"
echo "   ./manage_postiz.sh status    # حالة الخدمات"
echo "   ./manage_postiz.sh update    # تحديث"
echo "   ./manage_postiz.sh backup    # نسخ احتياطي"
echo ""
echo "⚡ أول مرة: ستحتاج للتسجيل في الموقع لإنشاء حساب المدير"
echo "🔄 Watchtower يتحقق كل ساعة من وجود تحديثات ويطبقها تلقائياً"
echo ""
echo "💡 للمساعدة أو الدعم، راجع السجلات: ./manage_postiz.sh logs"
