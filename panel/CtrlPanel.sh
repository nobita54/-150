#!/usr/bin/env bash
set -euo pipefail

# ============================================
# CtrlPanel Full Auto Installer (Nobita Final)
# ============================================

DB_NAME="ctrlpanel"
DB_USER="ctrlpaneluser"
DB_PASS="USE_YOUR_OWN_PASSWORD"

echo ""
echo ">>> CtrlPanel Auto Installer Starting..."
echo ""

# Ask domain
read -p "Enter your domain (example: panel.yourdomain.com): " DOMAIN
echo "Using domain: $DOMAIN"
echo ""

# -----------------------------
# Detect OS
# -----------------------------
detect_os() {
    . /etc/os-release || { echo "Unsupported OS"; exit 1; }
    OS="$ID"
    VER="$VERSION_ID"
    CODENAME=$(lsb_release -sc)
}

check_supported() {
    case "$OS" in
        ubuntu) [[ "$VER" =~ ^(20.04|22.04|24.04)$ ]] || { echo "Ubuntu $VER unsupported"; exit 1; };;
        debian) [[ "$VER" =~ ^(10|11|12)$ ]] || { echo "Debian $VER unsupported"; exit 1; };;
        *) echo "Unsupported OS: $OS $VER"; exit 1;;
    esac
}

# -----------------------------
# Base dependencies
# -----------------------------
install_base_packages() {
    apt update -y
    apt install -y software-properties-common curl apt-transport-https \
        ca-certificates gnupg lsb-release wget sudo git mariadb-server
}

# -----------------------------
# Auto Detect PHP Repo (NOBLE FIX)
# -----------------------------
add_php_repo_auto() {
    SURY_SUPPORTED=("focal" "jammy" "bookworm" "bullseye" "buster")

    if printf "%s\n" "${SURY_SUPPORTED[@]}" | grep -q "^${CODENAME}$"; then
        echo ">>> Sury PHP repo supported for ${CODENAME}, enabling…"
        wget -qO /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
        echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ ${CODENAME} main" \
            > /etc/apt/sources.list.d/php.list
        SKIP_PHP_REPO=0
    else
        echo ">>> '${CODENAME}' is NOT supported by Sury (noble detected?)."
        echo ">>> Falling back to system PHP."
        SKIP_PHP_REPO=1
    fi
}

# -----------------------------
# Redis Repo
# -----------------------------
add_redis_repo() {
    curl -fsSL https://packages.redis.io/gpg \
        | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb ${CODENAME} main" \
        > /etc/apt/sources.list.d/redis.list
}

# -----------------------------
# PHP Install Auto Switch
# -----------------------------
install_php_auto() {
    apt update -y
    if [ "${SKIP_PHP_REPO:-1}" -eq 1 ]; then
        echo ">>> Installing default PHP from OS..."
        apt install -y php php-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl} nginx redis-server
    else
        echo ">>> Installing PHP 8.3 from Sury..."
        apt install -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl,redis} nginx redis-server
    fi
}

enable_redis() {
    systemctl enable --now redis-server
}

# -----------------------------
# Composer
# -----------------------------
install_composer() {
    curl -sS https://getcomposer.org/installer \
        | php -- --install-dir=/usr/local/bin --filename=composer
}

# -----------------------------
# CtrlPanel Clone + Laravel Build
# -----------------------------
clone_ctrlpanel() {
    mkdir -p /var/www/ctrlpanel
    cd /var/www/ctrlpanel
    git clone https://github.com/Ctrlpanel-gg/panel.git ./ || true
}

laravel_build() {
    cd /var/www/ctrlpanel
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    php artisan storage:link
}

# -----------------------------
# SSL Self-Signed
# -----------------------------
setup_ssl() {
    mkdir -p /etc/certs/ctrlpanel
    cd /etc/certs/ctrlpanel
    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
        -subj "/C=NA/ST=NA/L=NA/O=NA/CN=${DOMAIN}" \
        -keyout privkey.pem -out fullchain.pem
}

# -----------------------------
# Database Setup
# -----------------------------
setup_mariadb() {
    mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
    mariadb -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
    mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
    mariadb -e "FLUSH PRIVILEGES;"
}

# -----------------------------
# Nginx Setup
# -----------------------------
setup_nginx() {
cat >/etc/nginx/sites-available/ctrlpanel.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root /var/www/ctrlpanel/public;
    index index.php;

    ssl_certificate /etc/certs/ctrlpanel/fullchain.pem;
    ssl_certificate_key /etc/certs/ctrlpanel/privkey.pem;

    client_max_body_size 100m;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php*.fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/ctrlpanel.conf /etc/nginx/sites-enabled/ctrlpanel.conf
    nginx -t
    systemctl restart nginx
}

# -----------------------------
# Permissions + Cron
# -----------------------------
setup_permissions_and_cron() {
    chown -R www-data:www-data /var/www/ctrlpanel/
    chmod -R 755 /var/www/ctrlpanel/storage/* /var/www/ctrlpanel/bootstrap/cache/

    apt install -y cron
    systemctl enable --now cron

    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/ctrlpanel/artisan schedule:run >> /dev/null 2>&1") | crontab -
}

# -----------------------------
# Queue Worker
# -----------------------------
setup_queue_worker() {
cat >/etc/systemd/system/ctrlpanel.service <<EOF
[Unit]
Description=Ctrlpanel Queue Worker

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/ctrlpanel/artisan queue:work --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now ctrlpanel.service
}

# -----------------------------
# MAIN
# -----------------------------
main() {
    detect_os
    check_supported

    install_base_packages
    add_php_repo_auto
    add_redis_repo
    install_php_auto
    enable_redis
    install_composer
    clone_ctrlpanel
    laravel_build
    setup_ssl
    setup_mariadb
    setup_nginx
    setup_permissions_and_cron
    setup_queue_worker

    echo ""
    echo "==========================================="
    echo " CtrlPanel Installation Completed"
    echo "==========================================="
    echo " URL       : https://${DOMAIN}"
    echo " DB Name   : ${DB_NAME}"
    echo " DB User   : ${DB_USER}"
    echo " DB Pass   : ${DB_PASS}"
    echo "==========================================="
    echo ""
}

main "$@"
