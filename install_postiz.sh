#!/bin/bash

# 📌 Variables
DOMAIN="postiz.soufianeautomation.space"  # Your domain
EMAIL="soufianeouakifbsn@gmail.com"     # Your email for Let's Encrypt
JWT_SECRET=$(openssl rand -base64 32)   # Generate a random JWT secret
POSTIZ_PORT="5000"                      # Exposed port for Postiz

echo "🚀 Starting Postiz installation on $DOMAIN ..."

# 🔄 Update system and install required tools
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw

# 🐳 Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# 🧹 Clean up any existing Postiz containers
sudo docker stop postiz postiz-postgres postiz-redis 2>/dev/null || true
sudo docker rm postiz postiz-postgres postiz-redis 2>/dev/null || true

# 📂 Create directories for Postiz volumes
mkdir -p ~/postiz/config ~/postiz/uploads
sudo chown -R 1000:1000 ~/postiz

# 📝 Create Docker Compose file for Postiz
cat <<EOF > ~/postiz/docker-compose.yml
version: '3.8'

services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    environment:
      MAIN_URL: "https://$DOMAIN"
      FRONTEND_URL: "https://$DOMAIN"
      NEXT_PUBLIC_BACKEND_URL: "https://$DOMAIN/api"
      JWT_SECRET: "$JWT_SECRET"
      DATABASE_URL: "postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local"
      REDIS_URL: "redis://postiz-redis:6379"
      BACKEND_INTERNAL_URL: "http://localhost:3000"
      IS_GENERAL: "true"
      DISABLE_REGISTRATION: "false"
      STORAGE_PROVIDER: "local"
      UPLOAD_DIRECTORY: "/uploads"
      NEXT_PUBLIC_UPLOAD_DIRECTORY: "/uploads"
    volumes:
      - ~/postiz/config:/config/
      - ~/postiz/uploads:/uploads/
    ports:
      - $POSTIZ_PORT:5000
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
      - ~/postiz/postgres-data:/var/lib/postgresql/data
    networks:
      - postiz-network
    healthcheck:
      test: pg_isready -U postiz-user -d postiz-db-local
      interval: 10s
      timeout: 3s
      retries: 3

  postiz-redis:
    image: redis:7.2
    container_name: postiz-redis
    restart: always
    healthcheck:
      test: redis-cli ping
      interval: 10s
      timeout: 3s
      retries: 3
    volumes:
      - ~/postiz/redis-data:/data
    networks:
      - postiz-network

volumes:
  postgres-volume:
  postiz-redis-data:
  postiz-config:
  postiz-uploads:

networks:
  postiz-network:
EOF

# 🚀 Start Postiz services
cd ~/postiz
sudo docker-compose up -d

# 🔧 Configure Nginx as Reverse Proxy
sudo tee /etc/nginx/sites-available/postiz.conf > /dev/null <<EOF
server {
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$POSTIZ_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;
    }
}
EOF

# 🔗 Enable Nginx configuration
sudo ln -s /etc/nginx/sites-available/postiz.conf /etc/nginx/sites-enabled/ || true
sudo nginx -t && sudo systemctl restart nginx

# 🔒 Obtain SSL certificate from Let's Encrypt
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# 🛡️ Configure firewall (UFW)
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# 🛠️ Install Watchtower for automatic updates
sudo docker stop watchtower 2>/dev/null || true
sudo docker rm watchtower 2>/dev/null || true
sudo docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower postiz --cleanup --interval 3600

echo "✅ Postiz installed successfully at https://$DOMAIN"
echo "🎉 Access the Postiz web interface to complete setup."
echo "🔄 Watchtower will check for Postiz updates every hour."
