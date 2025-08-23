#!/bin/bash

# -----------------------------
# 🚀 Update Postiz Credentials Script
# -----------------------------

POSTIZ_DIR="/opt/postiz"
COMPOSE_FILE="$POSTIZ_DIR/docker-compose.yml"

# 🟢 Function to update a key in docker-compose.yml
update_credential() {
    local key="$1"
    local value="$2"
    if grep -q "$key:" "$COMPOSE_FILE"; then
        sed -i "s|^\(\s*$key:\).*|\1 \"$value\"|" "$COMPOSE_FILE"
        echo "✅ Updated $key"
    else
        echo "⚠️ $key not found in docker-compose.yml"
    fi
}

echo "📂 Changing to Postiz directory..."
cd $POSTIZ_DIR || { echo "❌ Directory $POSTIZ_DIR not found"; exit 1; }

# -----------------------------
# Example usage: update your credentials here
# -----------------------------
# Replace these with your new credentials
update_credential "LINKEDIN_CLIENT_ID" "new-linkedin-client-id"
update_credential "LINKEDIN_CLIENT_SECRET" "new-linkedin-client-secret"
update_credential "REDDIT_CLIENT_ID" "g-gI1XviVk5DukK1IdgjOw"
update_credential "REDDIT_CLIENT_SECRET" "QlVucNLveKoLSKjPwKBNymQicZREsA"
update_credential "TELEGRAM_TOKEN" "new-telegram-token"

# -----------------------------
# Restart Docker Compose
# -----------------------------
echo "⚙️ Restarting Postiz..."
docker compose down
docker compose up -d

echo "✅ All credentials updated and Postiz restarted successfully!"
