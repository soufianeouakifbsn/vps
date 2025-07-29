#!/usr/bin/env bash
set -euo pipefail

#############################################
# Postiz + Docker Compose + ngrok installer #
# النسخة المحسنة والمصححة                    #
#############################################

# ألوان للتنسيق
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# دالة للطباعة الملونة
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# ===[ إعدادات قابلة للتعديل ]===
NGROK_DOMAIN="jaybird-normal-publicly.ngrok-free.app"
NGROK_TOKEN="30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiSPJN9"
POSTIZ_DIR="/opt/postiz"
POSTIZ_IMAGE="ghcr.io/gitroomhq/postiz-app:latest"
POSTIZ_JWT_SECRET="$(openssl rand -hex 32 2>/dev/null || tr -dc A-Za-z0-9 </dev/urandom | head -c 64)"
POSTIZ_PORT="5000"

# بيانات حساب المسؤول
ADMIN_EMAIL="admin@example.com"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="admin123"

print_info "🚀 بدء تثبيت Postiz..."

# دالة للتحقق من نجاح الأوامر
check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# دالة انتظار الخدمة
wait_for_service() {
    local service_name="$1"
    local max_attempts=30
    local attempt=1
    
    print_info "انتظار تشغيل $service_name..."
    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps "$service_name" | grep -q "Up"; then
            print_success "$service_name يعمل الآن"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "فشل في انتظار $service_name"
    return 1
}

# ---------------------------------
# 1) تثبيت المتطلبات الأساسية
# ---------------------------------
print_info "تحديث النظام وتثبيت المتطلبات..."

# تحديث النظام
sudo apt update && sudo apt upgrade -y

# تثبيت المتطلبات الأساسية
sudo apt install -y curl wget jq openssl net-tools

# ---------------------------------
# 2) تثبيت Docker + Compose
# ---------------------------------
if ! check_command docker; then
    print_info "📦 تثبيت Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker "$USER"
    print_success "تم تثبيت Docker"
else
    print_success "Docker موجود مسبقاً"
fi

# التحقق من Docker Compose
if ! docker compose version &>/dev/null; then
    print_info "🔧 تثبيت Docker Compose..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    print_success "تم تثبيت Docker Compose"
else
    print_success "Docker Compose موجود مسبقاً"
fi

# ---------------------------------
# 3) تثبيت ngrok
# ---------------------------------
if ! check_command ngrok; then
    print_info "⬇️ تثبيت ngrok..."
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
    sudo apt update && sudo apt install -y ngrok
    print_success "تم تثبيت ngrok"
else
    print_success "ngrok موجود مسبقاً"
fi

# إعداد ngrok token
ngrok config add-authtoken "$NGROK_TOKEN"

# ---------------------------------
# 4) تنظيف التثبيت السابق (إن وُجد)
# ---------------------------------
if [ -d "$POSTIZ_DIR" ]; then
    print_warning "تنظيف التثبيت السابق..."
    cd "$POSTIZ_DIR"
    docker-compose down -v 2>/dev/null || true
    cd /
    sudo rm -rf "$POSTIZ_DIR"
fi

# إيقاف ngrok إن كان يعمل
sudo systemctl stop ngrok-postiz.service 2>/dev/null || true
sudo systemctl disable ngrok-postiz.service 2>/dev/null || true

# ---------------------------------
# 5) تجهيز مجلد Postiz
# ---------------------------------
print_info "تجهيز مجلد التثبيت..."
sudo mkdir -p "$POSTIZ_DIR"
sudo chown -R "$USER:$USER" "$POSTIZ_DIR"
cd "$POSTIZ_DIR"

# ---------------------------------
# 6) إنشاء ملف docker-compose.yml
# ---------------------------------
print_info "إنشاء ملف docker-compose.yml..."

cat > docker-compose.yml <<'YAML'
version: '3.8'

services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: unless-stopped
    environment:
      MAIN_URL: "${MAIN_URL}"
      FRONTEND_URL: "${FRONTEND_URL}"
      NEXT_PUBLIC_BACKEND_URL: "${NEXT_PUBLIC_BACKEND_URL}"
      JWT_SECRET: "${JWT_SECRET}"
      DATABASE_URL: "${DATABASE_URL}"
      REDIS_URL: "${REDIS_URL}"
      BACKEND_INTERNAL_URL: "http://localhost:3000"
      IS_GENERAL: "true"
      DISABLE_REGISTRATION: "false"
      STORAGE_PROVIDER: "local"
      UPLOAD_DIRECTORY: "/uploads"
      NEXT_PUBLIC_UPLOAD_DIRECTORY: "/uploads"
      NODE_ENV: "production"
    volumes:
      - postiz-config:/config/
      - postiz-uploads:/uploads/
    ports:
      - "${POSTIZ_PORT}:5000"
    networks:
      - postiz-network
    depends_on:
      postiz-postgres:
        condition: service_healthy
      postiz-redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  postiz-postgres:
    image: postgres:16-alpine
    container_name: postiz-postgres
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: "postiz-password-2024"
      POSTGRES_USER: "postiz-user"
      POSTGRES_DB: "postiz-db-local"
      PGDATA: "/var/lib/postgresql/data/pgdata"
    volumes:
      - postgres-volume:/var/lib/postgresql/data
    networks:
      - postiz-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postiz-user -d postiz-db-local"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  postiz-redis:
    image: redis:7.2-alpine
    container_name: postiz-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --replica-read-only no
    volumes:
      - postiz-redis-data:/data
    networks:
      - postiz-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

volumes:
  postgres-volume:
    driver: local
  postiz-redis-data:
    driver: local
  postiz-config:
    driver: local
  postiz-uploads:
    driver: local

networks:
  postiz-network:
    driver: bridge
YAML

# ---------------------------------
# 7) إعداد ملف .env
# ---------------------------------
print_info "إنشاء ملف .env..."

cat > .env <<ENV
MAIN_URL="https://${NGROK_DOMAIN}"
FRONTEND_URL="https://${NGROK_DOMAIN}"
NEXT_PUBLIC_BACKEND_URL="https://${NGROK_DOMAIN}/api"
JWT_SECRET="${POSTIZ_JWT_SECRET}"
DATABASE_URL="postgresql://postiz-user:postiz-password-2024@postiz-postgres:5432/postiz-db-local"
REDIS_URL="redis://postiz-redis:6379"
POSTIZ_PORT="${POSTIZ_PORT}"
ENV

# ---------------------------------
# 8) إعداد systemd لـ ngrok
# ---------------------------------
print_info "إعداد خدمة ngrok..."

sudo tee /etc/systemd/system/ngrok-postiz.service > /dev/null <<EOF
[Unit]
Description=Ngrok Tunnel for Postiz
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/postiz
ExecStart=/usr/bin/ngrok http --domain=${NGROK_DOMAIN} ${POSTIZ_PORT}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ngrok-postiz.service

# ---------------------------------
# 9) تشغيل قاعدة البيانات و Redis أولاً
# ---------------------------------
print_info "🐳 تشغيل قاعدة البيانات..."

# سحب الصور
docker-compose pull

# تشغيل قاعدة البيانات و Redis فقط
docker-compose up -d postiz-postgres postiz-redis

# انتظار تشغيل قاعدة البيانات
wait_for_service "postiz-postgres"
wait_for_service "postiz-redis"

# ---------------------------------
# 10) تشغيل تطبيق Postiz
# ---------------------------------
print_info "تشغيل تطبيق Postiz..."
docker-compose up -d postiz

# انتظار تشغيل Postiz
wait_for_service "postiz"

# ---------------------------------
# 11) تشغيل ngrok
# ---------------------------------
print_info "تشغيل ngrok..."
sudo systemctl start ngrok-postiz.service

# انتظار تشغيل ngrok
sleep 10

# ---------------------------------
# 12) انتظار إضافي للتأكد من استقرار النظام
# ---------------------------------
print_info "انتظار استقرار النظام..."
sleep 30

# ---------------------------------
# 13) تشغيل migration وإعداد قاعدة البيانات
# ---------------------------------
print_info "إعداد قاعدة البيانات..."

# تشغيل migrations
docker-compose exec -T postiz sh -c "npm run db:migrate" || {
    print_warning "فشل في تشغيل migrations، جاري المحاولة مرة أخرى..."
    sleep 10
    docker-compose exec -T postiz sh -c "npm run db:migrate"
}

# ---------------------------------
# 14) إنشاء حساب المسؤول
# ---------------------------------
print_info "🔐 إنشاء حساب المسؤول..."

docker-compose exec -T postiz sh -c "
node -e \"
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');

(async () => {
  const prisma = new PrismaClient();
  
  try {
    console.log('🔍 البحث عن حساب المسؤول الموجود...');
    const existingUser = await prisma.user.findUnique({
      where: { email: '$ADMIN_EMAIL' }
    });
    
    if (existingUser) {
      console.log('ℹ️ حساب المسؤول موجود مسبقاً، جاري تحديث كلمة المرور...');
      const hashedPassword = await bcrypt.hash('$ADMIN_PASSWORD', 12);
      await prisma.user.update({
        where: { email: '$ADMIN_EMAIL' },
        data: { 
          password: hashedPassword,
          role: 'ADMIN'
        }
      });
      console.log('✅ تم تحديث حساب المسؤول');
    } else {
      console.log('🆕 إنشاء حساب مسؤول جديد...');
      const hashedPassword = await bcrypt.hash('$ADMIN_PASSWORD', 12);
      await prisma.user.create({
        data: {
          email: '$ADMIN_EMAIL',
          username: '$ADMIN_USERNAME',
          password: hashedPassword,
          role: 'ADMIN',
          verified: true
        }
      });
      console.log('✅ تم إنشاء حساب المسؤول بنجاح');
    }
  } catch (error) {
    console.error('❌ خطأ في إنشاء حساب المسؤول:', error.message);
    process.exit(1);
  } finally {
    await prisma.\$disconnect();
    process.exit(0);
  }
})();
\"
" || {
    print_error "فشل في إنشاء حساب المسؤول"
    print_info "جاري المحاولة مرة أخرى بعد إعادة تشغيل الحاوية..."
    docker-compose restart postiz
    sleep 30
    
    docker-compose exec -T postiz sh -c "
    node -e \"
    const { PrismaClient } = require('@prisma/client');
    const bcrypt = require('bcrypt');
    
    (async () => {
      const prisma = new PrismaClient();
      try {
        const hashedPassword = await bcrypt.hash('$ADMIN_PASSWORD', 12);
        await prisma.user.upsert({
          where: { email: '$ADMIN_EMAIL' },
          update: { password: hashedPassword, role: 'ADMIN' },
          create: {
            email: '$ADMIN_EMAIL',
            username: '$ADMIN_USERNAME', 
            password: hashedPassword,
            role: 'ADMIN',
            verified: true
          }
        });
        console.log('✅ تم إنشاء/تحديث حساب المسؤول');
      } catch (error) {
        console.error('❌ خطأ:', error.message);
      } finally {
        await prisma.\$disconnect();
      }
    })();
    \"
    "
}

# ---------------------------------
# 15) التحقق من حالة الخدمات
# ---------------------------------
print_info "التحقق من حالة الخدمات..."

echo ""
print_info "حالة Docker Containers:"
docker-compose ps

echo ""
print_info "حالة ngrok:"
sudo systemctl status ngrok-postiz.service --no-pager -l

echo ""
print_info "اختبار الاتصال المحلي:"
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$POSTIZ_PORT" | grep -q "200\|302\|401"; then
    print_success "Postiz يعمل محلياً"
else
    print_warning "قد تكون هناك مشكلة في الاتصال المحلي"
fi

# ---------------------------------
# 16) عرض معلومات التسجيل
# ---------------------------------
echo ""
echo "=================================================================="
print_success "🎉 تم اكتمال التثبيت بنجاح!"
echo "=================================================================="
echo ""
print_info "📱 معلومات الوصول:"
echo "🌐 الرابط الخارجي: https://${NGROK_DOMAIN}"
echo "🏠 الرابط المحلي: http://localhost:${POSTIZ_PORT}"
echo ""
print_info "🔐 بيانات تسجيل الدخول:"
echo "📧 البريد الإلكتروني: $ADMIN_EMAIL"
echo "🔑 كلمة المرور: $ADMIN_PASSWORD"
echo "👤 اسم المستخدم: $ADMIN_USERNAME"
echo ""
print_info "🛠️ أوامر مفيدة للإدارة:"
echo "• عرض حالة الخدمات: cd $POSTIZ_DIR && docker-compose ps"
echo "• عرض السجلات: cd $POSTIZ_DIR && docker-compose logs -f"
echo "• إعادة تشغيل: cd $POSTIZ_DIR && docker-compose restart"
echo "• إيقاف: cd $POSTIZ_DIR && docker-compose down"
echo "• تشغيل: cd $POSTIZ_DIR && docker-compose up -d"
echo ""
print_warning "📝 ملاحظات هامة:"
echo "• إذا لم يعمل الرابط فوراً، انتظر دقيقتين ثم جرب مرة أخرى"
echo "• يمكنك تغيير كلمة المرور من إعدادات الملف الشخصي بعد تسجيل الدخول"
echo "• للحصول على الدعم: تحقق من السجلات باستخدام docker-compose logs"
echo ""
echo "=================================================================="
