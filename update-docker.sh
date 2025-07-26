#!/bin/bash

set -e

echo "📦 Starting Docker update and backup process..."

# === 1. Update system ===
sudo apt update && sudo apt upgrade -y

# === 2. Backup current projects ===
echo "📂 Backing up projects..."
mkdir -p ~/docker-projects-backup
cp -r ~/n8n ~/docker-projects-backup/n8n-backup-$(date +%F-%H-%M)
cp -r ~/short-video-maker ~/docker-projects-backup/short-video-maker-backup-$(date +%F-%H-%M)

# === 3. Stop current Docker containers ===
echo "🛑 Stopping running Docker containers..."
docker compose -f ~/n8n/docker-compose.yml down || true
docker compose -f ~/short-video-maker/docker-compose.yml down || true

# === 4. Remove old Docker version ===
echo "🧹 Removing old Docker version..."
sudo apt remove docker docker-engine docker.io containerd runc -y || true

# === 5. Install latest Docker ===
echo "⬇️ Installing latest Docker version..."
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# === 6. Start Docker again ===
echo "🚀 Starting Docker containers again..."
docker compose -f ~/n8n/docker-compose.yml up -d
docker compose -f ~/short-video-maker/docker-compose.yml up -d

# === 7. Done ===
echo "✅ Docker updated and services restarted successfully!"
