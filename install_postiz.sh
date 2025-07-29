@@ -3,6 +3,7 @@ set -euo pipefail

#############################################
# Postiz + Docker Compose + ngrok installer #
# + إنشاء حساب مسؤول تلقائي بعد التشغيل #
#############################################

# ===[ إعدادات قابلة للتعديل ]===
@@ -13,6 +14,11 @@ POSTIZ_IMAGE="ghcr.io/gitroomhq/postiz-app:latest"
POSTIZ_JWT_SECRET="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 64 || true)"
POSTIZ_PORT="5000"

# بيانات حساب المسؤول (غيرها حسب رغبتك)
ADMIN_EMAIL="admin@example.com"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="admin123"

echo "🚀 بدء تثبيت Postiz..."

# ---------------------------------
@@ -29,7 +35,7 @@ echo "✅ تم تفعيل مجموعة docker للمستخدم الحالي."
EONG
fi

if ! docker compose version &>/dev/null; then
if ! docker compose version &>/dev/null && ! docker-compose version &>/dev/null; then
  echo "🔧 تثبيت Docker Compose يدويًا..."
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
@@ -172,6 +178,36 @@ echo "🐳 تشغيل Postiz باستخدام docker-compose..."
docker-compose pull
docker-compose up -d

# ---------------------------------
# 8) انتظار ثواني حتى تبدأ الحاويات
# ---------------------------------
echo "⌛️ انتظر 20 ثانية حتى تشتغل الحاويات..."
sleep 20

# ---------------------------------
# 9) إنشاء حساب المسؤول تلقائيًا داخل الحاوية
# ---------------------------------
echo "🔐 إنشاء حساب مسؤول تلقائيًا..."

docker exec -i postiz /bin/sh -c " \
  node -e \"(async () => { \
    const { prisma } = require('@prisma/client'); \
    const bcrypt = require('bcrypt'); \
    const prismaClient = new prisma.PrismaClient(); \
    const exists = await prismaClient.user.findFirst({ where: { email: '$ADMIN_EMAIL' } }); \
    if (!exists) { \
      const hashedPassword = await bcrypt.hash('$ADMIN_PASSWORD', 10); \
      await prismaClient.user.create({ data: { email: '$ADMIN_EMAIL', username: '$ADMIN_USERNAME', password: hashedPassword, role: 'ADMIN' } }); \
      console.log('✅ حساب المسؤول تم إنشاؤه'); \
    } else { \
      console.log('ℹ️ حساب المسؤول موجود مسبقًا'); \
    } \
    process.exit(0); \
  })().catch(e => { console.error(e); process.exit(1); });\" \
"

echo ""
echo "✅ تم التثبيت بنجاح!"
echo "✅ التثبيت والانشاء اكتمل!"
echo "🌐 افتح الآن: https://${NGROK_DOMAIN}"
echo "📧 حساب المسؤول: $ADMIN_EMAIL"
echo "🔑 كلمة المرور: $ADMIN_PASSWORD"
