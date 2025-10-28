#!/bin/bash
set -e
DOMAIN="n8n.soufianeautomation.space"
EMAIL="soufianeouakifbsn@gmail.com"
echo "🚀 بدء تثبيت n8n على $DOMAIN ..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx ufw pdftk zip
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
sudo systemctl enable docker
sudo systemctl start docker
sudo docker stop n8n 2>/dev/null || true
sudo docker rm n8n 2>/dev/null || true
mkdir -p ~/n8n_data
sudo chown -R 1000:1000 ~/n8n_data
sudo docker run -d --name n8n \
 -p 5678:5678 \
 -v ~/n8n_data:/home/node/.n8n \
 -e N8N_HOST="$DOMAIN" \
 -e N8N_PORT=5678 \
 -e N8N_PROTOCOL=https \
 -e WEBHOOK_URL="https://$DOMAIN" \
 --restart unless-stopped \
 n8nio/n8n:next
sudo tee /etc/nginx/sites-available/n8n.conf > /dev/null <<EOF
server {
 listen 80;
 listen [::]:80;
 server_name $DOMAIN;
 client_max_body_size 50m;
 location / {
  proxy_pass http://127.0.0.1:5678;
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
  proxy_buffering off;
 }
}
EOF
sudo ln -sf /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/n8n.conf
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
sudo nginx -t
sudo systemctl reload nginx
sudo certbot --nginx -d "$DOMAIN" --redirect --non-interactive --agree-tos -m "$EMAIL"
sudo docker stop watchtower 2>/dev/null || true
sudo docker rm watchtower 2>/dev/null || true
sudo docker run -d \
 --name watchtower \
 -v /var/run/docker.sock:/var/run/docker.sock \
 containrrr/watchtower n8n --cleanup --interval 3600
echo "✅ تم تثبيت n8n على https://$DOMAIN"
echo "🎉 أول مرة سيظهر لك صفحة التسجيل (Register)."
echo "🔄 Watchtower سيتحقق كل ساعة من وجود تحديث جديد لـ n8n ويطبقه تلقائيًا."
