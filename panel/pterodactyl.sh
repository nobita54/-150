#!/bin/bash

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
    echo -e "║${WHITE}           🦖 Pterodactyl Panel Auto-Installer${PURPLE}            ║"
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

# Function to show spinner animation
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to animate text
animate_text() {
    local text=$1
    echo -ne "${CYAN}"
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep 0.03
    done
    echo -e "${NC}"
}

# Function to draw progress bar
progress_bar() {
    local duration=$1
    local steps=20
    local step_delay=$(echo "scale=3; $duration/$steps" | bc -l)
    
    echo -ne "${BLUE}["
    for ((i=0; i<steps; i++)); do
        echo -ne "█"
        sleep $step_delay
    done
    echo -e "]${NC}"
}

# Start installation
print_header

echo -e "${WHITE}Welcome to Pterodactyl Panel Installation${NC}"
echo -e "${YELLOW}This script will install and configure your panel.${NC}"
echo -e ""

# Get domain input with styling
echo -e "${CYAN}${BOLD}Domain Configuration:${NC}"
echo -e "${WHITE}Please enter your domain name for the panel${NC}"
read -p "$(echo -e "${YELLOW}➤ Enter your domain (e.g., panel.example.com): ${NC}")" DOMAIN

echo -e ""
echo -e "${PURPLE}${BOLD}Starting installation process...${NC}"
sleep 2

# --- Dependencies ---
print_status "Updating system packages and installing dependencies..."
apt update && apt install -y curl apt-transport-https ca-certificates gnupg unzip git tar sudo lsb-release bc &
progress_bar 5

# Detect OS with animation
print_status "Detecting operating system..."
OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
sleep 1

if [[ "$OS" == "ubuntu" ]]; then
    print_success "Detected Ubuntu"
    print_status "Adding PPA for PHP..."
    apt install -y software-properties-common
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
elif [[ "$OS" == "debian" ]]; then
    print_success "Detected Debian"
    print_status "Adding SURY PHP repository..."
    curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/sury-php.list
fi

# Add Redis repository
print_status "Adding Redis repository..."
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

print_status "Finalizing package updates..."
apt update &
progress_bar 3

# --- Install PHP + extensions ---
print_status "Installing PHP 8.3 and required extensions..."
animate_text "Installing: PHP 8.3, MariaDB, Nginx, Redis..."
apt install -y php8.3 php8.3-{cli,fpm,common,mysql,mbstring,bcmath,xml,zip,curl,gd,tokenizer,ctype,simplexml,dom} mariadb-server nginx redis-server &
progress_bar 10

# --- Install Composer ---
print_status "Installing Composer..."
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer &
progress_bar 3
print_success "Composer installed successfully"

# --- Download Pterodactyl Panel ---
print_status "Downloading Pterodactyl Panel..."
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz &
progress_bar 5

print_status "Extracting panel files..."
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/
print_success "Panel files extracted and permissions set"

# --- MariaDB Setup ---
print_status "Setting up MariaDB database..."
DB_NAME=panel
DB_USER=pterodactyl
DB_PASS=$(openssl rand -base64 16)

# Start MariaDB if not running
systemctl start mariadb 2>/dev/null || systemctl start mysql 2>/dev/null

mariadb -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null
mariadb -e "CREATE DATABASE ${DB_NAME};" 2>/dev/null
mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;" 2>/dev/null
mariadb -e "FLUSH PRIVILEGES;" 2>/dev/null
print_success "Database '${DB_NAME}' created with user '${DB_USER}'"

# --- .env Setup ---
print_status "Configuring environment variables..."
if [ ! -f ".env.example" ]; then
    curl -Lo .env.example https://raw.githubusercontent.com/pterodactyl/panel/develop/.env.example
fi
cp .env.example .env

sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|g" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|g" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|g" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env

if ! grep -q "^APP_ENVIRONMENT_ONLY=" .env; then
    echo "APP_ENVIRONMENT_ONLY=false" >> .env
fi
print_success "Environment configuration completed"

# --- Install PHP dependencies ---
print_status "Installing PHP dependencies with Composer..."
animate_text "This may take a few minutes depending on your system..."
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader &
progress_bar 15

# --- Generate Application Key ---
print_status "Generating application key..."
php artisan key:generate --force &
progress_bar 2
print_success "Application key generated"

# --- Run Migrations ---
print_status "Running database migrations and seeding..."
animate_text "Setting up database structure..."
php artisan migrate --seed --force &
progress_bar 8
print_success "Database migrations completed"

# --- Permissions ---
print_status "Setting up permissions and cron jobs..."
chown -R www-data:www-data /var/www/pterodactyl/*
apt install -y cron
systemctl enable --now cron
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
print_success "Permissions and cron jobs configured"

# --- SSL Certificate Setup ---
print_status "Generating SSL certificate..."
mkdir -p /etc/certs/panel
cd /etc/certs/panel
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
    -subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
    -keyout privkey.pem -out fullchain.pem 2>/dev/null
print_success "SSL certificate generated"

# --- Nginx Setup ---
print_status "Configuring Nginx..."
PHP_VERSION="8.3"

tee /etc/nginx/sites-available/pterodactyl.conf > /dev/null << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root /var/www/pterodactyl/public;
    index index.php;

    ssl_certificate /etc/certs/panel/fullchain.pem;
    ssl_certificate_key /etc/certs/panel/privkey.pem;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        include /etc/nginx/fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize=100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf

print_status "Testing Nginx configuration..."
if nginx -t; then
    print_success "Nginx configuration test passed"
    systemctl restart nginx
    print_success "Nginx restarted successfully"
else
    print_error "Nginx configuration test failed"
    exit 1
fi

# --- Queue Worker ---
print_status "Setting up queue worker service..."
tee /etc/systemd/system/pteroq.service > /dev/null << 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now redis-server
systemctl enable --now pteroq.service
print_success "Queue worker service configured and started"

# Final setup
print_status "Finalizing installation..."
cd /var/www/pterodactyl
sed -i '/^APP_ENVIRONMENT_ONLY=/d' .env
echo "APP_ENVIRONMENT_ONLY=false" >> .env
cd /var/www/pterodactyl
php artisan p:user:make

# Clear and show completion message
clear
print_header

# Animated completion message
echo -e "${GREEN}"
animate_text "🎉 Pterodactyl Panel Installation Completed Successfully!"
echo -e "${NC}"

# Final information display
echo -e ""
echo -e "${PURPLE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}${BOLD}║                      📋 INSTALLATION SUMMARY                ║${NC}"
echo -e "${PURPLE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e ""
echo -e "${CYAN}${BOLD}🌐 Panel URL:${NC} ${WHITE}https://${DOMAIN}${NC}"
echo -e "${CYAN}${BOLD}📁 Installation Directory:${NC} ${WHITE}/var/www/pterodactyl${NC}"
echo -e "${CYAN}${BOLD}🗄️  Database Name:${NC} ${WHITE}${DB_NAME}${NC}"
echo -e "${CYAN}${BOLD}👤 Database User:${NC} ${WHITE}${DB_USER}${NC}"
echo -e "${CYAN}${BOLD}🔑 Database Password:${NC} ${WHITE}${DB_PASS}${NC}"
echo -e ""
echo -e "${YELLOW}${BOLD}⚠️  IMPORTANT NEXT STEPS:${NC}"
echo -e "${WHITE}1. Run: ${CYAN}cd /var/www/pterodactyl${NC}"
echo -e "${WHITE}2. Create admin user: ${CYAN}php artisan p:user:make${NC}"
echo -e "${WHITE}3. Configure your DNS to point to this server${NC}"
echo -e ""
echo -e "${GREEN}${BOLD}✅ Your Pterodactyl panel is ready!${NC}"
echo -e "${PURPLE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}${BOLD}║                    🚀 Happy Hosting!                        ║${NC}"
echo -e "${PURPLE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e ""
print_warning "Note: The panel uses a self-signed SSL certificate by default."
print_warning "For production use, replace it with a valid SSL certificate (Let's Encrypt)."
