#!/bin/bash

# Postiz installation script by Soufiane
# Ref: https://github.com/gitroomhq/postiz-app

echo "🔄 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "🐳 Installing Docker & Docker Compose..."
sudo apt install -y docker.io docker-compose

echo "🧰 Creating postiz-app directory..."
mkdir -p ~/postiz-app
cd ~/postiz-app

echo "📥 Downloading docker-compose.yml from GitHub..."
curl -o docker-compose.yml https://raw.githubusercontent.com/gitroomhq/postiz-app/main/docker-compose.yml

echo "🔐 Creating .env file..."
cat <<EOF > .env
POSTIZ_PORT=3000
POSTIZ_DB_USERNAME=postiz
POSTIZ_DB_PASSWORD=securepassword123
POSTIZ_DB_NAME=postizdb
POSTIZ_DB_PORT=5432
EOF

echo "✅ Launching Postiz containers..."
sudo docker-compose up -d

echo "✅ Postiz is now running on port 3000!"
