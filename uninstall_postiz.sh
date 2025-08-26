#!/bin/bash

# -----------------------------
# 🧹 Uninstall Postiz & Clean Server
# Soufiane Automation
# -----------------------------

echo "🚨 Starting Postiz removal process..."

# -----------------------------
# Stop and remove Docker containers
# -----------------------------
if [ -f /opt/postiz/docker-compose.yml ]; then
    echo "🐳 Stopping and removing Docker containers..."
    cd /opt/postiz
    docker compose down --volumes --remove-orphans
else
    echo "⚠️ docker-compose.yml not found. Skipping Docker removal."
fi

# -----------------------------
# Remove Docker images related to Postiz
# -----------------------------
echo "🖼️ Removing Docker images for Postiz, Redis, and Postgres..."
docker images -a | grep -E 'postiz-app|redis|postgres' | awk '{print $3}' | xargs -r docker rmi -f

# -----------------------------
# Remove Postiz directory
# -----------------------------
if [ -d /opt/postiz ]; then
    echo "📂 Removing Postiz directory..."
    sudo rm -rf /opt/postiz
fi

# -----------------------------
# Remove Nginx configuration & SSL
# -----------------------------
DOMAIN="postiz2.soufianeautomation.space"
if [ -f /etc/nginx/sites-available/postiz ]; then
    echo "🌐 Removing Nginx configuration..."
    sudo rm -f /etc/nginx/sites-available/postiz
    sudo rm -f /etc/nginx/sites-enabled/postiz
    sudo nginx -t && sudo systemctl reload nginx
fi

echo "🔐 Removing SSL certificate..."
sudo certbot delete --cert-name $DOMAIN --non-interactive || echo "No cert found for $DOMAIN"

# -----------------------------
# Optional cleanup
# -----------------------------
echo "🧹 Cleaning up unused Docker volumes..."
docker volume prune -f

echo "✅ Postiz and all related services have been removed!"
echo "⚠️ System basic packages remain intact."
echo "🔹 Update system and essentials commands preserved:"
echo "sudo apt update && sudo apt upgrade -y"
echo "sudo apt install wget -y && sudo apt-get update"
echo "sudo apt-get upgrade -y && sudo apt install git -y"
echo "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release"
