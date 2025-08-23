#!/bin/bash

# -----------------------------
# ⚙️ Configure Postiz Applications Credentials
# Soufiane Automation
# -----------------------------

POSTIZ_DIR="/opt/postiz"
ENV_FILE="$POSTIZ_DIR/.env"

echo "📂 Checking Postiz installation at $POSTIZ_DIR ..."
if [ ! -d "$POSTIZ_DIR" ]; then
  echo "❌ Postiz directory not found! Install Postiz first."
  exit 1
fi

echo "📝 Creating/Updating $ENV_FILE with App Credentials..."

cat > $ENV_FILE <<EOL
# ==============================
# 🌍 General Configuration
# ==============================
MAIN_URL=https://postiz.soufianeautomation.space
FRONTEND_URL=https://postiz.soufianeautomation.space
NEXT_PUBLIC_BACKEND_URL=https://postiz.soufianeautomation.space/api

# 🔑 JWT Secret
JWT_SECRET=$(openssl rand -hex 32)

# ==============================
# 🗄️ Database & Cache
# ==============================
DATABASE_URL=postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local
REDIS_URL=redis://postiz-redis:6379
BACKEND_INTERNAL_URL=http://localhost:5000
IS_GENERAL=true
DISABLE_REGISTRATION=false
STORAGE_PROVIDER=local
UPLOAD_DIRECTORY=/uploads
NEXT_PUBLIC_UPLOAD_DIRECTORY=/uploads

# ==============================
# 📱 Application Credentials
# ==============================

# --- Facebook ---
FACEBOOK_CLIENT_ID=your_facebook_app_id
FACEBOOK_CLIENT_SECRET=your_facebook_app_secret

# --- Instagram ---
INSTAGRAM_CLIENT_ID=your_instagram_app_id
INSTAGRAM_CLIENT_SECRET=your_instagram_app_secret

# --- Twitter / X ---
TWITTER_CLIENT_ID=your_twitter_app_id
TWITTER_CLIENT_SECRET=your_twitter_app_secret

# --- LinkedIn ---
LINKEDIN_CLIENT_ID=your_linkedin_app_id
LINKEDIN_CLIENT_SECRET=your_linkedin_app_secret

# --- Google (YouTube, etc) ---
GOOGLE_CLIENT_ID=478210438973-sbmd1ir93kifi2r0u3chk3i18fg4sj6k.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=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

# --- TikTok ---
TIKTOK_CLIENT_ID=your_tiktok_app_id
TIKTOK_CLIENT_SECRET=your_tiktok_app_secret
EOL

echo "🔄 Restarting Postiz with new credentials..."
cd $POSTIZ_DIR
docker compose down
docker compose up -d

echo "✅ Credentials file created at $ENV_FILE"
echo "👉 Now edit the file with your real app keys before restarting if needed!"
