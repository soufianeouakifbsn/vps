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
sudo apt install -y curl wget jq
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
mkdir -p $WORK_DIR
cd $WORK_DIR
print_message "إنشاء مجلد العمل: $WORK_DIR"

# 📄 8. إنشاء ملف docker-compose.yml
print_info "إنشاء ملف docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz-app
    restart: unless-stopped
    environment:
      - MAIN_URL=https://jaybird-normal-publicly.ngrok-free.app
      - FRONTEND_URL=https://jaybird-normal-publicly.ngrok-free.app
      - NEXT_PUBLIC_BACKEND_URL=https://jaybird-normal-publicly.ngrok-free.app/api
      - JWT_SECRET=my-super-secret-jwt-key-change-this-in-production
      - DATABASE_URL=postgresql://postiz-user:postiz-password@db:5432/postiz-db?schema=public
      - REDIS_URL=redis://redis:6379
      - BACKEND_INTERNAL_URL=http://localhost:3000
      - IS_GENERAL=true
      - NEXT_PUBLIC_IS_GENERAL=true
      - CLOUDFLARE_ACCOUNT_ID=
      - CLOUDFLARE_API_TOKEN=
      - CLOUDFLARE_ZONE_ID=
      - ENCRYPT_KEY=12345678901234567890123456789012
    ports:
      - "3000:3000"
    depends_on:
      - db
      - redis
    volumes:
      - postiz_uploads:/app/uploads

  db:
    image: postgres:15
    container_name: postiz-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=postiz-user
      - POSTGRES_PASSWORD=postiz-password
      - POSTGRES_DB=postiz-db
    volumes:
      - postiz_db_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    container_name: postiz-redis
    restart: unless-stopped
    volumes:
      - postiz_redis_data:/data
    ports:
      - "6379:6379"

volumes:
  postiz_db_data:
  postiz_redis_data:
  postiz_uploads:
EOF

check_command "إنشاء ملف docker-compose.yml"

# 🔁 9. إنشاء خدمة ngrok systemd
print_info "إنشاء خدمة ngrok..."
sudo bash -c 'cat > /etc/systemd/system/ngrok-postiz.service <<EOF
[Unit]
Description=Ngrok Tunnel for Postiz
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=jaybird-normal-publicly.ngrok-free.app 3000
Restart=always
User=root
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

check_command "إنشاء ملف خدمة ngrok"

# تفعيل وتشغيل خدمة ngrok
sudo systemctl daemon-reload
sudo systemctl enable ngrok-postiz.service
sudo systemctl start ngrok-postiz.service
check_command "تشغيل خدمة ngrok"

# ⏱️ 10. انتظار ngrok ليبدأ العمل
print_info "انتظار بدء تشغيل ngrok..."
sleep 10

# التحقق من حالة ngrok
if sudo systemctl is-active --quiet ngrok-postiz.service; then
    print_message "خدمة ngrok تعمل بشكل صحيح"
else
    print_warning "مشكلة في خدمة ngrok، جاري إعادة المحاولة..."
    sudo systemctl restart ngrok-postiz.service
    sleep 5
fi

# 🧹 11. تنظيف الحاويات القديمة إن وجدت
print_info "تنظيف الحاويات القديمة..."
docker-compose down 2>/dev/null || true

# 🐳 12. تشغيل Postiz
print_info "تشغيل Postiz..."
docker-compose up -d
check_command "تشغيل حاويات Postiz"

# ⏱️ 13. انتظار بدء تشغيل الخدمات
print_info "انتظار بدء تشغيل جميع الخدمات..."
sleep 30

# 🔍 14. التحقق من حالة الحاويات
print_info "التحقق من حالة الحاويات..."
docker-compose ps

# 🌐 15. عرض معلومات الوصول
echo ""
echo "=================================================="
print_message "تم تثبيت Postiz بنجاح! 🎉"
echo "=================================================="
echo ""
print_info "رابط الوصول: https://jaybird-normal-publicly.ngrok-free.app"
print_info "مجلد التثبيت: $WORK_DIR"
echo ""
print_info "للتحقق من حالة الخدمات:"
echo "  - حالة ngrok: sudo systemctl status ngrok-postiz.service"
echo "  - حالة Postiz: cd $WORK_DIR && docker-compose ps"
echo ""
print_info "لإيقاف الخدمات:"
echo "  - إيقاف ngrok: sudo systemctl stop ngrok-postiz.service"  
echo "  - إيقاف Postiz: cd $WORK_DIR && docker-compose down"
echo ""
print_info "لإعادة تشغيل الخدمات:"
echo "  - إعادة تشغيل ngrok: sudo systemctl restart ngrok-postiz.service"
echo "  - إعادة تشغيل Postiz: cd $WORK_DIR && docker-compose restart"
echo ""
print_warning "ملاحظة: قد تحتاج إلى بضع دقائق إضافية حتى يصبح التطبيق جاهزاً تماماً"
echo "=================================================="
