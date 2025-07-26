#!/usr/bin/env bash
set -euo pipefail

#############################################
# Postiz + Docker Compose + ngrok one-liner #
#############################################

# ===[ قابل للتعديل ]===
NGROK_DOMAIN="jaybird-normal-publicly.ngrok-free.app"
NGROK_TOKEN="30Pd47TWZRWjAwhfEhsW8cb2XwI_3beapEPSsBZuiuCiSPJN9"
POSTIZ_DIR="/opt/postiz"
POSTIZ_IMAGE="ghcr.io/gitroomhq/postiz-app:latest"
POSTIZ_JWT_SECRET="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 64 || true)"

# لا تغيّر البورت 5000 إن لم تكن تعرف ما تفعل (Postiz يوصي باستعمال منفذ موحّد 5000).
POSTIZ_PORT="5000"

echo "🚀 Starting Postiz installation ..."

# ---------------------------------
# 0) Basic tools
# ---------------------------------
if ! command -v curl &>/dev/null; then
  sudo apt update
  sudo apt install -y curl
fi

# ---------------------------------
# 1) Install Docker & docker compose plugin if needed
# ---------------------------------
if ! command -v docker &>/dev/null; then
  echo "📦 Installing Docker..."
  sudo apt update
  sudo apt install -y docker.io
  sudo systemctl enable --now docker
fi

if ! docker compose version &>/dev/null; then
  echo "🔧 Installing docker compose plugin..."
  sudo apt update
  sudo apt install -y docker-compose-plugin
fi

# ---------------------------------
# 2) Install ngrok (if missing)
# ---------------------------------
if ! command -v ngrok &>/dev/null; then
  echo "⬇️ Installing ngrok..."
  wget -O /tmp/ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  sudo tar xvzf /tmp/ngrok.tgz -C /usr/local/bin
fi

# Configure ngrok token
ngrok config add-authtoken "$NGROK_TOKEN"

# ---------------------------------
# 3) Prepare folders
# ---------------------------------
sudo mkdir -p "$POSTIZ_DIR"
sudo chown -R "$USER":"$USER" "$POSTIZ_DIR"
cd "$POSTIZ_DIR"

# ---------------------------------
# 4) Create docker-compose.yml (from official docs, adapted)
# ---------------------------------
cat > docker-compose.yml <<'YAML'
services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    environment:
      # سيتم حقن هذه القيم ديناميكياً بواسطة envsubst قبل التشغيل
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
    volumes:
      - postiz-config:/config/
      - postiz-uploads:/uploads/
    ports:
      - ${POSTIZ_PORT}:5000
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
      POSTGRES_PASSWORD: postiz-password
      POSTGRES_USER: postiz-user
      POSTGRES_DB: postiz-db-local
    volumes:
      - postgres-volume:/var/lib/postgresql/data
    networks:
      - postiz-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postiz-user -d postiz-db-local"]
      interval: 10s
      timeout: 3s
      retries: 3

  postiz-redis:
    image: redis:7.2
    container_name: postiz-redis
    restart: always
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
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
YAML

# ---------------------------------
# 5) Create .env file that docker compose will read
# ---------------------------------
cat > .env <<ENV
# ---- URLs (use your ngrok https domain) ----
MAIN_URL="https://${NGROK_DOMAIN}"
FRONTEND_URL="https://${NGROK_DOMAIN}"
NEXT_PUBLIC_BACKEND_URL="https://${NGROK_DOMAIN}/api"

# ---- Secrets & connections ----
JWT_SECRET="${POSTIZ_JWT_SECRET}"
DATABASE_URL="postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local"
REDIS_URL="redis://postiz-redis:6379"

# ---- Port mapping (host:container) ----
POSTIZ_PORT="${POSTIZ_PORT}"
ENV

# ---------------------------------
# 6) Create a systemd unit for ngrok (to expose :5000)
# ---------------------------------
sudo bash -c "cat > /etc/systemd/system/ngrok-postiz.service" <<EOF
[Unit]
Description=Ngrok Tunnel for Postiz
After=network.target docker.service

[Service]
ExecStart=/usr/local/bin/ngrok http --domain=${NGROK_DOMAIN} ${POSTIZ_PORT}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ngrok-postiz.service
sudo systemctl start ngrok-postiz.service

# ---------------------------------
# 7) Launch Postiz
# ---------------------------------
echo "🐳 Pulling & starting Postiz via docker compose..."
docker compose pull
docker compose up -d

echo ""
echo "✅ Done!"
echo "🌐 Access Postiz at: https://${NGROK_DOMAIN}"
echo "📦 Compose files in: ${POSTIZ_DIR}"
echo "🛠  To see logs: cd ${POSTIZ_DIR} && docker compose logs -f --tail=100"
