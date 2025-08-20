#!/bin/bash

# 📌 Variables
DOMAIN="postiz.yourdomain.com"   # Replace with your actual domain
EMAIL="your_email@example.com"   # Replace with your email for Let's Encrypt SSL

echo "🚀 Starting Postiz installation on $DOMAIN ..."

# Update the system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw

# Enable and start Docker with status check
sudo systemctl enable docker
sudo systemctl start docker
if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to start Docker. Please check the status with 'sudo systemctl status docker'."
    exit 1
fi

# Verify Docker is working
sudo docker info > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Error: Docker daemon is not responding. Please troubleshoot Docker installation."
    exit 1
fi

# 🧹 Clean up any existing Postiz containers
sudo docker stop postiz 2>/dev/null || true
sudo docker rm postiz 2>/dev/null || true

# Pull the Postiz image explicitly to avoid runtime errors
echo "📥 Pulling Postiz Docker image..."
sudo docker pull ghcr.io/postiz-app/postiz:latest
if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to pull Postiz image. Check internet connection or image availability."
    exit 1
fi

# Create a directory for Postiz data (persistent storage)
mkdir -p ~/postiz_data
sudo chown -R 1000:1000 ~/postiz_data

# 🐳 Run Postiz in Docker
echo "🚀 Starting Postiz container..."
sudo docker run -d --name postiz \
  -p 5000:5000 \
  -v ~/postiz_data:/app/data \
  -e POSTIZ_HOST="$DOMAIN" \
  -e POSTIZ_PROTOCOL=https \
  -e WEBHOOK_URL="https://$DOMAIN" \
  --restart unless-stopped \
  ghcr.io/postiz-app/postiz:latest
if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to start Postiz container. Check logs with 'sudo docker logs postiz'."
    exit 1
fi

# 🔧 Set up Nginx as a Reverse Proxy with WebSocket support
sudo tee /etc/nginx/sites-available/postiz.conf > /dev/null <<EOF
server {
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:5000;

        # ✅ WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # ✅ Pass headers correctly
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # ✅ Prevent connection timeout issues
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;
    }
}
EOF

# Enable the Nginx site
sudo ln -s /etc/nginx/sites-available/postiz.conf /etc/nginx/sites-enabled/ || true
sudo nginx -t && sudo systemctl restart nginx

# 🔒 Obtain SSL certificate from Let's Encrypt
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# Open firewall (UFW)
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# 🛡️ Install Watchtower for automatic updates
sudo docker stop watchtower 2>/dev/null || true
sudo docker rm watchtower 2>/dev/null || true
sudo docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower postiz --cleanup --interval 3600

echo "✅ Postiz installed successfully at https://$DOMAIN"
echo "🎉 On first access, you may see a registration or setup page."
echo "🔄 Watchtower will check for Postiz updates every hour and apply them automatically."
echo "🔧 WebSocket and timeout issues are handled via Nginx configuration."
echo "📋 If issues persist, check logs with 'sudo docker logs postiz'."
