#!/bin/bash

# ---------------------------------------
# 🚀 Auto Install Hysteria 2 (QUIC + BBR)
# Soufiane Automation
# ---------------------------------------

DOMAIN="udp.soufianeautomation.space"   # ضع هنا دومين أو IP السيرفر
PORT=443
PASSWORD=$(openssl rand -hex 16)
CONFIG_DIR="/etc/hysteria"

# 1️⃣ تحديث النظام وتثبيت الأدوات
apt update -y && apt upgrade -y
apt install curl wget unzip -y

# 2️⃣ تفعيل BBR لتحسين الشبكة
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 3️⃣ تنزيل Hysteria v2
mkdir -p $CONFIG_DIR
HY_VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep tag_name | cut -d '"' -f 4)
wget -O /tmp/hysteria.tar.gz https://github.com/apernet/hysteria/releases/download/${HY_VERSION}/hysteria-linux-amd64.tar.gz
tar -xvzf /tmp/hysteria.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/hysteria

# 4️⃣ إنشاء ملف الإعداد
cat > $CONFIG_DIR/config.yaml <<EOF
listen: :$PORT
tls:
  insecure: true
auth:
  type: password
  password: "$PASSWORD"
masquerade: "https://www.bing.com"
bandwidth:
  up: 100 mbps
  down: 100 mbps
EOF

# 5️⃣ إضافة خدمة systemd
cat > /etc/systemd/system/hysteria.service <<EOF
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server -c $CONFIG_DIR/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6️⃣ تشغيل الخدمة
systemctl daemon-reexec
systemctl enable hysteria
systemctl restart hysteria

# ✅ معلومات الاتصال
echo -e "\n🎉 Hysteria2 Installed Successfully!\n"
echo "🔑 Import this into your client (Hysteria2 / Clash / NekoBox):"
echo "hysteria2://$PASSWORD@$DOMAIN:$PORT/?insecure=1&sni=$DOMAIN#Soufiane-Hysteria2"
