#!/bin/bash
# ============================================
# Postiz Apps Credentials Installer
# soufianeautomation.space
# ============================================

ENV_FILE="/opt/postiz/.env"

echo "🚀 إعداد الكريدينشيلز للتطبيقات (Google, YouTube, Facebook, LinkedIn, Twitter) في Postiz"
echo "ملف البيئة المستهدف: $ENV_FILE"
echo

# إنشاء الملف إذا لم يكن موجود
if [ ! -f "$ENV_FILE" ]; then
  echo "⚠️ ملف $ENV_FILE غير موجود. سيتم إنشاؤه الآن..."
  touch $ENV_FILE
fi

# دالة لإضافة أو تحديث متغير
set_env_var() {
  VAR_NAME=$1
  VAR_VALUE=$2
  if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
    sed -i "s|^$VAR_NAME=.*|$VAR_NAME=$VAR_VALUE|" "$ENV_FILE"
  else
    echo "$VAR_NAME=$VAR_VALUE" >> "$ENV_FILE"
  fi
}

# ==========================
# Google Login (ثابت)
# ==========================
set_env_var "GOOGLE_CLIENT_ID" "478210438973-c22oehbp2gnj5kjatpd04jitjkqds40c.apps.googleusercontent.com"
set_env_var "GOOGLE_CLIENT_SECRET" "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"

# ==========================
# YouTube
# ==========================
read -p "👉 أدخل YOUTUBE_CLIENT_ID: " YOUTUBE_CLIENT_ID
read -p "👉 أدخل YOUTUBE_CLIENT_SECRET: " YOUTUBE_CLIENT_SECRET
set_env_var "YOUTUBE_CLIENT_ID" "$YOUTUBE_CLIENT_ID"
set_env_var "YOUTUBE_CLIENT_SECRET" "$YOUTUBE_CLIENT_SECRET"

# ==========================
# Facebook
# ==========================
read -p "👉 أدخل FACEBOOK_CLIENT_ID: " FACEBOOK_CLIENT_ID
read -p "👉 أدخل FACEBOOK_CLIENT_SECRET: " FACEBOOK_CLIENT_SECRET
set_env_var "FACEBOOK_CLIENT_ID" "$FACEBOOK_CLIENT_ID"
set_env_var "FACEBOOK_CLIENT_SECRET" "$FACEBOOK_CLIENT_SECRET"

# ==========================
# LinkedIn
# ==========================
read -p "👉 أدخل LINKEDIN_CLIENT_ID: " LINKEDIN_CLIENT_ID
read -p "👉 أدخل LINKEDIN_CLIENT_SECRET: " LINKEDIN_CLIENT_SECRET
set_env_var "LINKEDIN_CLIENT_ID" "$LINKEDIN_CLIENT_ID"
set_env_var "LINKEDIN_CLIENT_SECRET" "$LINKEDIN_CLIENT_SECRET"

# ==========================
# Twitter (X)
# ==========================
read -p "👉 أدخل TWITTER_CLIENT_ID: " TWITTER_CLIENT_ID
read -p "👉 أدخل TWITTER_CLIENT_SECRET: " TWITTER_CLIENT_SECRET
set_env_var "TWITTER_CLIENT_ID" "$TWITTER_CLIENT_ID"
set_env_var "TWITTER_CLIENT_SECRET" "$TWITTER_CLIENT_SECRET"

echo
echo "✅ تم حفظ الكريدينشيلز في $ENV_FILE"
echo "🔄 سيتم إعادة تشغيل Postiz الآن..."
cd /opt/postiz && docker compose down && docker compose up -d

# ==========================
# Print Redirect URIs
# ==========================
echo
echo "============================================"
echo "✅ انسخ والصق الـ Redirect URIs التالية حسب كل منصة"
echo "============================================"
echo
echo "👉 Google Login:"
echo "https://postiz.soufianeautomation.space/api/auth/callback/google"
echo
echo "👉 YouTube:"
echo "https://postiz.soufianeautomation.space/integrations/social/youtube"
echo
echo "👉 Facebook:"
echo "https://postiz.soufianeautomation.space/integrations/social/facebook"
echo
echo "👉 LinkedIn:"
echo "https://postiz.soufianeautomation.space/integrations/social/linkedin"
echo
echo "👉 Twitter (X):"
echo "https://postiz.soufianeautomation.space/integrations/social/twitter"
echo
echo "============================================"
echo "⚡️ انسخ هذه الروابط وضعها في صفحة إعداد OAuth لكل منصة."
echo "============================================"
