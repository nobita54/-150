#!/bin/bash

###################################################
# 🟢 FIRST PRIORITY — DOMAIN INPUT BEFORE ANYTHING
###################################################
clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔰 MythicalDash Remastered Auto Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "📌 Enter your Domain (example: panel.example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo ""
    echo "⚠ Domain required — Install Aborted."
    echo "Run again and enter properly."
    exit 1
fi

echo ""
echo "✔ Domain Set To: $DOMAIN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 2

###################################################
# 🔍 AUTO OS DETECT
###################################################
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Failed to detect OS."
    exit 1
fi

if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
    echo "❌ Script works only on Ubuntu/Debian"
    exit 1
fi

###################################################
# 🔄 UPDATE & INSTALL DEPENDENCIES
###################################################
apt update && apt upgrade -y
apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

if [ "$OS" == "ubuntu" ]; then
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
    apt-add-repository universe
else
    curl -fsSL https://packages.sury.org/php/apt.gpg | sudo gpg --dearmor -o /usr/share/keyrings/php.gpg
    echo "deb [signed-by=/usr/share/keyrings/php.gpg] https://packages.sury.org/php/ $VERSION_CODENAME main" \
    | tee /etc/apt/sources.list.d/php.list
fi

apt update

apt -y install \
php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,redis} \
mariadb-server nginx tar unzip zip git redis-server make dos2unix cron openssl screen

systemctl enable --now cron

###################################################
# 🎼 COMPOSER
###################################################
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

###################################################
# ⚡ DOWNLOAD + INSTALL PANEL
###################################################
mkdir -p /var/www/mythicaldash-v3
cd /var/www/mythicaldash-v3

curl -Lo MythicalDash.zip https://github.com/MythicalLTD/MythicalDash/releases/latest/download/MythicalDash.zip
unzip -o MythicalDash.zip -d /var/www/mythicaldash-v3
chown -R www-data:www-data /var/www/mythicaldash-v3/*

cd backend
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

###################################################
# 🏦 DATABASE SETUP
###################################################
DB="mythicaldash_remastered"
USER="mythicaldash_remastered"
PASS="1234"

mariadb -e "CREATE DATABASE $DB;"
mariadb -e "CREATE USER '$USER'@'127.0.0.1' IDENTIFIED BY '$PASS';"
mariadb -e "GRANT ALL PRIVILEGES ON $DB.* TO '$USER'@'127.0.0.1';"
mariadb -e "FLUSH PRIVILEGES;"

###################################################
# 🔥 PRODUCTION BUILD
###################################################
cd /var/www/mythicaldash-v3
make set-prod

###################################################
# ⏱ CRON SETUP
###################################################
{ crontab -l 2>/dev/null | grep -v "/var/www/mythicaldash-v3/backend/storage/cron/runner.bash"; \
  crontab -l 2>/dev/null | grep -v "/var/www/mythicaldash-v3/backend/storage/cron/runner.php"; \
  echo "* * * * * bash /var/www/mythicaldash-v3/backend/storage/cron/runner.bash >> /dev/null 2>&1"; \
  echo "* * * * * php /var/www/mythicaldash-v3/backend/storage/cron/runner.php >> /dev/null 2>&1"; } | crontab -

php mythicaldash setup
php mythicaldash migrate
php mythicaldash pterodactyl configure
###################################################
# 🔐 SELF-SIGNED SSL
###################################################
mkdir -p /etc/certs/MythicalDash-4
cd /etc/certs/MythicalDash-4
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
-keyout privkey.pem -out fullchain.pem

###################################################
# 🏗 NGINX CONFIG AUTO BUILD
###################################################
CONF="/etc/nginx/sites-available/MythicalDashRemastered.conf"
cat <<EOF > $CONF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    root /var/www/mythicaldash-v3/frontend/dist;
    index index.html;

    ssl_certificate /etc/certs/MythicalDash-4/fullchain.pem;
    ssl_certificate_key /etc/certs/MythicalDash-4/privkey.pem;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
    location /api {
        proxy_pass http://localhost:6000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    location /i/ {
        proxy_pass http://localhost:6000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    location /attachments {
        alias /var/www/mythicaldash-v3/backend/public/attachments;
    }
}
server {
    listen 6000;
    server_name localhost;
    root /var/www/mythicaldash-v3/backend/public;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

ln -s $CONF /etc/nginx/sites-enabled/
systemctl restart nginx
cd /var/www/mythicaldash-v3
chown -R www-data:www-data /var/www/mythicaldash-v3/*
php mythicaldash makeAdmin

echo ""
echo "🚀 MythicalDash Installed Successfully!"
echo "🔗 URL: https://$DOMAIN"
echo "Login & enjoy the magic ✨"

