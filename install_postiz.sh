#!/bin/bash

echo "🚀 بدء تثبيت Postiz مع ngrok..."

# ألوان للرسائل
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# دالة لطباعة الرسائل الملونة
print_message() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# دالة للتحقق من نجاح الأمر
check_command() {
    if [ $? -eq 0 ]; then
        print_message "$1"
    else
        print_error "فشل في: $1"
        exit 1
    fi
}

# 🧹 0. تنظيف كامل للتثبيت السابق
print_info "تنظيف التثبيت السابق..."
sudo systemctl stop ngrok-postiz.service 2>/dev/null || true
sudo systemctl disable ngrok-postiz.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/ngrok-postiz.service
docker-compose -f ~/postiz/docker-compose.yml down 2>/dev/null || true
docker stop postiz-app postiz-db postiz-redis 2>/dev/null || true
docker rm postiz-app postiz-db postiz-redis 2>/dev/null || true
docker volume rm postiz_postiz_db_data postiz_postiz_redis_data postiz_postiz_uploads 2>/dev/null || true
sudo systemctl daemon-reload

# 🔧 1. تحديث النظام
print_info "تحديث النظام..."
sudo apt update -y
check_command "تحديث قائمة الحزم"

# 🐳 2. التحقق من وجود Docker وتثبيته إذا لزم الأمر
if ! command -v docker &> /dev/null; then
    print_warning "Docker غير مثبت، جاري التثبيت..."
    sudo apt install -y docker.io
    check_command "تثبيت Docker"
    
    # إضافة المستخدم الحالي لمجموعة docker
    sudo usermod -aG docker $USER
    print_message "تم إضافة المستخدم لمجموعة Docker"
else
    print_message "Docker مثبت مسبقاً"
fi

# تشغيل خدمة Docker
sudo systemctl enable docker
sudo systemctl start docker
check_command "تشغيل خدمة Docker"

# 🔄 3. التحقق من وجود Docker Compose وتثبيته إذا لزم الأمر
if ! command -v docker-compose &> /dev/null; then
    print_warning "Docker Compose غير مثبت، جاري التثبيت..."
    sudo apt install -y docker-compose
    check_command "تثبيت Docker Compose"
else
    print_message "Docker Compose مثبت مسبقاً"
fi

# 📦 4. تثبيت الأدوات المساعدة
print_info "تثبيت الأدوات المساعدة..."
sudo apt install -y curl wget jq openssl
check_command "تثبيت الأدوات المساعدة"

# 🌐 5. تثبيت ngrok إذا لم يكن مثبتًا
if ! command -v ngrok &> /dev/null; then
    print_warning "ngrok غير مثبت، جاري التثبيت..."
    
    # تنظيف الملفات المؤقتة إن وجدت
    rm -f ngrok.tgz
    
    wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    check_command "تحميل ngrok"
    
    sudo tar xvzf ngrok.tgz -C /usr/local/bin
    check_command "استخراج ngrok"
    
    # حذف الملف المؤقت
    rm -f ngrok.tgz
    
    # التأكد من صلاحيات التشغيل
    sudo chmod +x /usr/local/bin/ngrok
else
    print_message "ngrok مثبت مسبقاً"
fi

# 🔐 6. إعداد ngrok token
print_info "إعداد ngrok..."
ngrok config add-authtoken 30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9
check_command "إعداد ngrok token"

# 📁 7. إنشاء مجلد العمل
WORK_DIR="$HOME/postiz"
rm -rf $WORK_DIR
mkdir -p $WORK_DIR
cd $WORK_DIR
print_message "إنشاء مجلد العمل: $WORK_DIR"

# 🔑 8. توليد مفاتيح آمنة
JWT_SECRET=$(openssl rand -hex 32)
ENCRYPT_KEY=$(openssl rand -hex 32)
DATABASE_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

print_message "تم توليد المفاتيح الآمنة"

# 📄 9. إنشاء ملف .env
cat > .env << EOF
# Database Configuration
POSTGRES_USER=postiz_user
POSTGRES_PASSWORD=${DATABASE_PASSWORD}
POSTGRES_DB=postiz_db

# Application Configuration
MAIN_URL=https://jaybird-normal-publicly.ngrok-free.app
FRONTEND_URL=https://jaybird-normal-publicly.ngrok-free.app
NEXT_PUBLIC_BACKEND_URL=https://jaybird-normal-publicly.ngrok-free.app/api
JWT_SECRET=${JWT_SECRET}
ENCRYPT_KEY=${ENCRYPT_KEY}
DATABASE_URL=postgresql://postiz_user:${DATABASE_PASSWORD}@db:5432/postiz_db?schema=public
REDIS_URL=redis://redis:6379
BACKEND_INTERNAL_URL=http://localhost:3000
IS_GENERAL=true
NEXT_PUBLIC_IS_GENERAL=true

# Optional Cloudflare (leave empty if not using)
CLOUDFLARE_ACCOUNT_ID=
CLOUDFLARE_API_TOKEN=
CLOUDFLARE_ZONE_ID=
EOF

print_message "تم إنشاء ملف .env"

# 📄 10. إنشاء ملف docker-compose.yml محسن
print_info "إنشاء ملف docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: postiz-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - postiz_db_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - postiz-network

  redis:
    image: redis:7-alpine
    container_name: postiz-redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - postiz_redis_data:/data
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - postiz-network

  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz-app
    restart: unless-stopped
    environment:
      MAIN_URL: ${MAIN_URL}
      FRONTEND_URL: ${FRONTEND_URL}
      NEXT_PUBLIC_BACKEND_URL: ${NEXT_PUBLIC_BACKEND_URL}
      JWT_SECRET: ${JWT_SECRET}
      ENCRYPT_KEY: ${ENCRYPT_KEY}
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
      BACKEND_INTERNAL_URL: ${BACKEND_INTERNAL_URL}
      IS_GENERAL: ${IS_GENERAL}
      NEXT_PUBLIC_IS_GENERAL: ${NEXT_PUBLIC_IS_GENERAL}
      CLOUDFLARE_ACCOUNT_ID: ${CLOUDFLARE_ACCOUNT_ID}
      CLOUDFLARE_API_TOKEN: ${CLOUDFLARE_API_TOKEN}
      CLOUDFLARE_ZONE_ID: ${CLOUDFLARE_ZONE_ID}
      NODE_ENV: production
    ports:
      - "3000:3000"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - postiz_uploads:/app/uploads
      - postiz_config:/app/.postiz
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - postiz-network

volumes:
  postiz_db_data:
    driver: local
  postiz_redis_data:
    driver: local
  postiz_uploads:
    driver: local
  postiz_config:
    driver: local

networks:
  postiz-network:
    driver: bridge
EOF

check_command "إنشاء ملف docker-compose.yml"

# 🔁 11. إنشاء خدمة ngrok systemd محسنة
print_info "إنشاء خدمة ngrok..."
sudo bash -c 'cat > /etc/systemd/system/ngrok-postiz.service <<EOF
[Unit]
Description=Ngrok Tunnel for Postiz
After=network.target docker.service
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ngrok http --domain=jaybird-normal-publicly.ngrok-free.app 3000
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF'

check_command "إنشاء ملف خدمة ngrok"

# تفعيل وتشغيل خدمة ngrok
sudo systemctl daemon-reload
sudo systemctl enable ngrok-postiz.service
sudo systemctl start ngrok-postiz.service
check_command "تشغيل خدمة ngrok"

# ⏱️ 12. انتظار ngrok ليبدأ العمل
print_info "انتظار بدء تشغيل ngrok..."
sleep 15

# التحقق من حالة ngrok
for i in {1..5}; do
    if sudo systemctl is-active --quiet ngrok-postiz.service; then
        print_message "خدمة ngrok تعمل بشكل صحيح"
        break
    else
        print_warning "محاولة $i: إعادة تشغيل ngrok..."
        sudo systemctl restart ngrok-postiz.service
        sleep 10
    fi
done

# 🐳 13. سحب صور Docker مسبقاً
print_info "سحب صور Docker..."
docker-compose pull
check_command "سحب صور Docker"

# 🐳 14. تشغيل قاعدة البيانات أولاً
print_info "تشغيل قاعدة البيانات..."
docker-compose up -d db redis
check_command "تشغيل قاعدة البيانات"

# انتظار قاعدة البيانات
print_info "انتظار جاهزية قاعدة البيانات..."
sleep 30

# التحقق من حالة قاعدة البيانات
for i in {1..10}; do
    if docker-compose exec -T db pg_isready -U postiz_user -d postiz_db >/dev/null 2>&1; then
        print_message "قاعدة البيانات جاهزة"
        break
    else
        print_info "انتظار قاعدة البيانات... محاولة $i/10"
        sleep 10
    fi
done

# 🐳 15. تشغيل Postiz
print_info "تشغيل Postiz..."
docker-compose up -d postiz
check_command "تشغيل Postiz"

# ⏱️ 16. انتظار بدء تشغيل Postiz
print_info "انتظار بدء تشغيل Postiz (قد يستغرق بضع دقائق)..."
sleep 60

# 🔍 17. التحقق من حالة جميع الخدمات
print_info "التحقق من حالة الخدمات..."
echo ""
echo "حالة الحاويات:"
docker-compose ps
echo ""
echo "حالة ngrok:"
sudo systemctl status ngrok-postiz.service --no-pager -l
echo ""

# 📊 18. عرض سجلات التطبيق للتشخيص
print_info "عرض آخر سجلات Postiz..."
docker-compose logs --tail=20 postiz

# 🌐 19. اختبار الاتصال
print_info "اختبار الاتصال..."
if curl -f http://localhost:3000 >/dev/null 2>&1; then
    print_message "Postiz يستجيب على المنفذ المحلي"
else
    print_warning "Postiz لا يستجيب على المنفذ المحلي بعد"
fi

# 📋 20. إنشاء سكربت إدارة
cat > postiz_manage.sh << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "🚀 بدء تشغيل جميع الخدمات..."
        sudo systemctl start ngrok-postiz.service
        cd ~/postiz && docker-compose up -d
        ;;
    stop)
        echo "⏹️ إيقاف جميع الخدمات..."
        sudo systemctl stop ngrok-postiz.service
        cd ~/postiz && docker-compose down
        ;;
    restart)
        echo "🔄 إعادة تشغيل جميع الخدمات..."
        sudo systemctl restart ngrok-postiz.service
        cd ~/postiz && docker-compose restart
        ;;
    status)
        echo "📊 حالة الخدمات:"
        echo "--- Ngrok ---"
        sudo systemctl status ngrok-postiz.service --no-pager -l
        echo ""
        echo "--- Docker Containers ---"
        cd ~/postiz && docker-compose ps
        ;;
    logs)
        echo "📋 سجلات Postiz:"
        cd ~/postiz && docker-compose logs -f postiz
        ;;
    update)
        echo "🔄 تحديث Postiz..."
        cd ~/postiz && docker-compose pull && docker-compose up -d
        ;;
    *)
        echo "الاستخدام: $0 {start|stop|restart|status|logs|update}"
        exit 1
        ;;
esac
EOF

chmod +x postiz_manage.sh
print_message "تم إنشاء سكربت الإدارة: ~/postiz/postiz_manage.sh"

# 🌐 21. عرض معلومات الوصول
echo ""
echo "=================================================="
print_message "تم تثبيت Postiz بنجاح! 🎉"
echo "=================================================="
echo ""
print_info "رابط الوصول: https://jaybird-normal-publicly.ngrok-free.app"
print_info "مجلد التثبيت: $WORK_DIR"
echo ""
print_info "أوامر الإدارة السريعة:"
echo "  ~/postiz/postiz_manage.sh start   - تشغيل الخدمات"
echo "  ~/postiz/postiz_manage.sh stop    - إيقاف الخدمات"
echo "  ~/postiz/postiz_manage.sh restart - إعادة تشغيل"
echo "  ~/postiz/postiz_manage.sh status  - حالة الخدمات"
echo "  ~/postiz/postiz_manage.sh logs    - عرض السجلات"
echo "  ~/postiz/postiz_manage.sh update  - تحديث التطبيق"
echo ""
print_warning "ملاحظات مهمة:"
echo "  • قد يحتاج التطبيق 2-3 دقائق إضافية ليصبح جاهزاً تماماً"
echo "  • إذا لم يعمل التطبيق، راجع السجلات: ~/postiz/postiz_manage.sh logs"
echo "  • تأكد من أن جميع الحاويات تعمل: ~/postiz/postiz_manage.sh status"
echo ""
print_info "بيانات قاعدة البيانات المُولدة:"
echo "  Database User: postiz_user"
echo "  Database Password: $DATABASE_PASSWORD"
echo "  (محفوظة في ملف .env)"
echo "=================================================="
