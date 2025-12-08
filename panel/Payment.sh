#!/usr/bin/env bash
set -euo pipefail

# Non-interactive apt
export DEBIAN_FRONTEND=noninteractive

# Colors for UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# UI Elements
BOLD='\033[1m'
UNDERLINE='\033[4m'

# Function to print header
print_header() {
    clear
    echo -e "${PURPLE}"
    echo -e "╔══════════════════════════════════════════════════════════════╗"
    echo -e "║${WHITE}           💰 Paymenter Auto-Installer${PURPLE}                     ║"
    echo -e "║                 ${WHITE}With Enhanced UI${PURPLE}                      ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to print status messages
print_status() {
    echo -e "${BLUE}${BOLD}[~]${NC} ${1}"
}

print_success() {
    echo -e "${GREEN}${BOLD}[✓]${NC} ${1}"
}

print_error() {
    echo -e "${RED}${BOLD}[✗]${NC} ${1}"
}

print_warning() {
    echo -e "${YELLOW}${BOLD}[!]${NC} ${1}"
}

print_info() {
    echo -e "${CYAN}${BOLD}[i]${NC} ${1}"
}

# Function to show progress bar
progress_bar() {
    local duration=$1
    local steps=20
    local step_delay=$(echo "scale=3; $duration/$steps" | bc -l 2>/dev/null || echo "0.1")
    
    echo -ne "${BLUE}["
    for ((i=0; i<steps; i++)); do
        echo -ne "█"
        sleep $step_delay
    done
    echo -e "]${NC}"
}

# Function to animate text
animate_text() {
    local text=$1
    echo -ne "${CYAN}"
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep 0.02
    done
    echo -e "${NC}"
}

# Start installation
print_header

# --- Preliminary checks ---
print_status "Running preliminary checks..."
if [ "$(id -u)" -ne 0 ]; then
  print_error "This script must be run as root. Exiting."
  exit 1
fi
print_success "Root privileges confirmed"

# --- Ask domain up-front ---
echo -e ""
echo -e "${CYAN}${BOLD}Domain Configuration:${NC}"
echo -e "${WHITE}Please enter your domain name for Paymenter${NC}"
read -rp "$(echo -e "${YELLOW}➤ Enter domain for Paymenter (e.g. paymenter.example.com): ${NC}")" DOMAIN

if [ -z "$DOMAIN" ]; then
  print_error "No domain entered. Exiting."
  exit 1
fi

echo -e "${GREEN}✓ Domain set to: ${WHITE}${DOMAIN}${NC}"
echo -e ""

# --- Variables (customize if needed) ---
WEB_ROOT="/var/www/paymenter"
SERVICE_PATH="/etc/systemd/system/paymenter.service"
NGINX_CONF="/etc/nginx/sites-available/paymenter.conf"
CERT_DIR="/etc/certs/paymenter"

DB_NAME="paymenter"
DB_USER="paymenteruser"
DB_PASS="yourPassword"   # change this after install or prompt earlier if desired

print_status "Starting Paymenter installation process..."
sleep 2

# --- OS detect ---
print_status "Detecting operating system..."
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID="${ID}"
  OS_VER="${VERSION_CODENAME:-unknown}"
  print_success "Detected: ${OS_ID} ${OS_VER}"
else
  print_error "/etc/os-release not found. Cannot detect distro. Exiting."
  exit 1
fi

if [[ "$OS_ID" != "ubuntu" && "$OS_ID" != "debian" ]]; then
  print_error "Only Ubuntu & Debian are supported by this installer. Detected: ${OS_ID}"
  exit 1
fi

# --- Update + install base deps ---
print_status "Updating system packages and installing dependencies..."
apt update &
progress_bar 3

apt -y install --no-install-recommends software-properties-common curl apt-transport-https ca-certificates gnupg lsb-release &
progress_bar 5

# Add Ondřej PPA for Ubuntu (Debian will use packaged PHP if available)
if [[ "$OS_ID" == "ubuntu" ]]; then
  print_status "Adding Ondřej PHP PPA for Ubuntu..."
  LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
  print_success "PHP PPA added"
fi

print_status "Refreshing package lists..."
apt update &
progress_bar 2

# Install packages
print_status "Installing required packages (PHP 8.3, MariaDB, Nginx, Redis)..."
animate_text "Installing: PHP 8.3, MariaDB, Nginx, Redis, and extensions..."

apt -y install --no-install-recommends \
  php8.3 php8.3-common php8.3-cli php8.3-gd php8.3-mysql php8.3-mbstring \
  php8.3-bcmath php8.3-xml php8.3-fpm php8.3-curl php8.3-zip php8.3-intl php8.3-redis \
  mariadb-server nginx tar unzip git redis-server cron openssl &
progress_bar 12

# Ensure services enabled
print_status "Enabling and starting core services..."
systemctl enable --now mariadb
systemctl enable --now nginx
systemctl enable --now php8.3-fpm
systemctl enable --now redis-server
systemctl enable --now cron
print_success "Core services enabled and started"

# --- Create web root and fetch Paymenter ---
print_status "Creating web root directory..."
mkdir -p "$WEB_ROOT"
cd "$WEB_ROOT"

print_status "Downloading Paymenter latest release..."
if ! curl -fsSL -o paymenter.tar.gz "https://github.com/paymenter/paymenter/releases/latest/download/paymenter.tar.gz"; then
  print_error "Failed to download Paymenter archive. Exiting."
  exit 1
fi
print_success "Paymenter downloaded successfully"

print_status "Extracting Paymenter files..."
tar -xzvf paymenter.tar.gz --strip-components=0
rm -f paymenter.tar.gz || true

# Permissions for storage & cache (temporary; final chown later)
if [ -d storage ]; then
  chmod -R 755 storage bootstrap/cache || true
fi
print_success "Files extracted and permissions set"

# --- MariaDB setup ---
print_status "Configuring MariaDB database..."
animate_text "Creating database and user..."

# Create DB user and DB (binds to 127.0.0.1)
mariadb -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
mariadb -e "CREATE DATABASE ${DB_NAME};"
mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
mariadb -e "FLUSH PRIVILEGES;"
print_success "Database '${DB_NAME}' created with user '${DB_USER}'"

# --- .env setup ---
print_status "Configuring environment variables..."
cp -n .env.example .env

# Replace common keys (only if patterns exist)
sed -i "s|^APP_URL=.*|APP_URL=https://${DOMAIN}|g" .env || true
sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|g" .env || true
sed -i "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USER}|g" .env || true
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env || true
print_success "Environment configuration completed"

# --- Composer (install if missing) and install PHP deps ---
if ! command -v composer >/dev/null 2>&1; then
  print_status "Installing Composer..."
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar /usr/local/bin/composer
  chmod +x /usr/local/bin/composer
  print_success "Composer installed"
fi

# Ensure owner is www-data for composer install
chown -R www-data:www-data "$WEB_ROOT"
cd "$WEB_ROOT"

print_status "Installing PHP dependencies via Composer..."
animate_text "This may take a few minutes depending on your system and internet speed..."
sudo -u www-data composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist &
progress_bar 15
print_success "PHP dependencies installed"

# --- Laravel artisan commands ---
print_status "Running Laravel artisan commands..."
animate_text "Setting up application key, storage, and database..."

# Generate app key
sudo -u www-data php artisan key:generate --force
print_success "Application key generated"

# Storage link
sudo -u www-data php artisan storage:link || true
print_success "Storage link created"

mysql -u root -p -e "
ALTER USER 'paymenter'@'localhost' IDENTIFIED BY 'yourPassword';
FLUSH PRIVILEGES;
" && \
php artisan config:clear && \
php artisan cache:clear && \
php artisan optimize:clear && \
php artisan migrate --force --seed

# Run migrations and seeds
print_status "Running database migrations and seeding..."
sudo -u www-data php artisan migrate --force --seed &
progress_bar 8
print_success "Database migrations completed"

# Run custom seeder if exists
if php -r "exit(file_exists('database/seeders/CustomPropertySeeder.php')?0:1);" >/dev/null 2>&1; then
  sudo -u www-data php artisan db:seed --class=CustomPropertySeeder || true
  print_success "Custom seeder executed"
fi

# --- Ownership & permissions ---
print_status "Setting up file permissions..."
chown -R www-data:www-data /var/www/paymenter
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
chmod -R 755 "$WEB_ROOT"/storage "$WEB_ROOT"/bootstrap/cache || true
chown -R www-data:www-data "$WEB_ROOT"/storage "$WEB_ROOT"/bootstrap/cache || true
print_success "File permissions configured"

# --- Cron: Laravel scheduler every minute ---
print_status "Setting up cron job for scheduler..."
( crontab -l 2>/dev/null | grep -v -F 'artisan schedule:run' || true ; echo "* * * * * php ${WEB_ROOT}/artisan schedule:run >> /dev/null 2>&1" ) | crontab -
print_success "Cron job installed"

# --- Systemd service for queue worker ---
print_status "Configuring systemd service for queue worker..."
cat > "$SERVICE_PATH" <<'EOF'
[Unit]
Description=Paymenter Queue Worker

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/paymenter/artisan queue:work --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now paymenter.service
print_success "Queue worker service configured and started"

# Ensure redis-server is enabled (already enabled earlier but ensure)
systemctl enable --now redis-server

# --- Self-signed SSL certificate (or use real certs later) ---
print_status "Generating SSL certificate..."
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"
openssl req \
  -new -newkey rsa:4096 -days 3650 -nodes -x509 \
  -subj "/C=NA/ST=NA/L=NA/O=NA/CN=${DOMAIN}" \
  -keyout privkey.pem -out fullchain.pem

chmod 640 "$CERT_DIR"/privkey.pem
chmod 644 "$CERT_DIR"/fullchain.pem
chown -R root:root "$CERT_DIR"
print_success "SSL certificate generated"

# --- Nginx site config ---
print_status "Configuring Nginx..."
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};
    root /var/www/paymenter/public;
    
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;
    charset utf-8;

    ssl_certificate ${CERT_DIR}/fullchain.pem;
    ssl_certificate_key ${CERT_DIR}/privkey.pem;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ \.php$ {
        return 404;
    }

    sendfile off;
    client_max_body_size 100m;
    keepalive_timeout 10;
}
EOF

# Disable adblock include to prevent nginx crash
sed -i 's|include /etc/nginx/adblock/blocked_sites.conf;|# include /etc/nginx/adblock/blocked_sites.conf;|g' /etc/nginx/conf.d/adblock.conf
rm -f /etc/nginx/conf.d/adblock.conf
rm -rf /etc/nginx/adblock

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/paymenter.conf

# Remove default site if exists to avoid conflicts
if [ -f /etc/nginx/sites-enabled/default ]; then
  rm -f /etc/nginx/sites-enabled/default || true
fi

print_status "Testing Nginx configuration..."
if nginx -t; then
  print_success "Nginx configuration test passed"
  systemctl restart nginx
  print_success "Nginx restarted successfully"
else
  print_error "Nginx configuration test failed"
  exit 1
fi

# Final setup steps
print_status "Running final setup commands..."
cd /var/www/paymenter
php artisan app:init
php artisan app:user:create

print_status "Finalizing installation..."
progress_bar 3

# Clear and show completion message
clear
echo -e "${PURPLE}"
echo -e "╔══════════════════════════════════════════════════════════════╗"
echo -e "║${WHITE}           💰 Paymenter Installation Complete${PURPLE}                 ║"
echo -e "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Animated completion message
echo -e "${GREEN}"
animate_text "🎉 Paymenter Installation Completed Successfully!"
echo -e "${NC}"

# Final information display
echo -e ""
echo -e "${PURPLE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}${BOLD}║                      📋 INSTALLATION SUMMARY                ║${NC}"
echo -e "${PURPLE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e ""

# Services status
print_status "Service Status:"
systemctl is-active --quiet nginx && echo -e "  ${GREEN}✓${NC} nginx: active" || echo -e "  ${RED}✗${NC} nginx: not active"
systemctl is-active --quiet php8.3-fpm && echo -e "  ${GREEN}✓${NC} php8.3-fpm: active" || echo -e "  ${RED}✗${NC} php8.3-fpm: not active"
systemctl is-active --quiet mariadb && echo -e "  ${GREEN}✓${NC} mariadb: active" || echo -e "  ${RED}✗${NC} mariadb: not active"
systemctl is-active --quiet redis-server && echo -e "  ${GREEN}✓${NC} redis-server: active" || echo -e "  ${RED}✗${NC} redis-server: not active"
systemctl is-active --quiet paymenter.service && echo -e "  ${GREEN}✓${NC} paymenter.service: active" || echo -e "  ${RED}✗${NC} paymenter.service: not active"

echo -e ""
echo -e "${CYAN}${BOLD}📊 Installation Details:${NC}"
echo -e "  ${WHITE}🌐 Panel URL:${NC} ${GREEN}https://${DOMAIN}${NC}"
echo -e "  ${WHITE}📁 Installation Directory:${NC} ${GREEN}${WEB_ROOT}${NC}"
echo -e "  ${WHITE}🗄️  Database Name:${NC} ${GREEN}${DB_NAME}${NC}"
echo -e "  ${WHITE}👤 Database User:${NC} ${GREEN}${DB_USER}${NC}"
echo -e "  ${WHITE}🔑 Database Password:${NC} ${GREEN}${DB_PASS}${NC}"

echo -e ""
echo -e "${YELLOW}${BOLD}⚠️  IMPORTANT SECURITY NOTES:${NC}"
echo -e "  ${WHITE}• Change the default database password immediately${NC}"
echo -e "  ${WHITE}• Replace self-signed SSL with valid certificate for production${NC}"
echo -e "  ${WHITE}• Configure your DNS to point to this server${NC}"

echo -e ""
echo -e "${GREEN}${BOLD}✅ Your Paymenter installation is ready!${NC}"
echo -e "${PURPLE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}${BOLD}║                    💳 Happy Processing!                     ║${NC}"
echo -e "${PURPLE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
