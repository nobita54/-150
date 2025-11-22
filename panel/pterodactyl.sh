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

# UI Functions
print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   PTERODACTYL PANEL INSTALLER               ║"
    echo "║                     Automated Installation                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${YELLOW}▶ ${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

progress_bar() {
    local duration=$1
    local steps=20
    local step_delay=$(echo "scale=3; $duration/$steps" | bc)
    
    echo -ne "${PURPLE}["
    for ((i=0; i<steps; i++)); do
        echo -ne "█"
        sleep $step_delay
    done
    echo -e "]${NC}"
}

spinner() {
    local pid=$1
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

confirm_installation() {
    print_header
    echo -e "${WHITE}This script will install Pterodactyl Panel with the following components:${NC}"
    echo -e "${CYAN}"
    echo "  • Nginx Web Server"
    echo "  • PHP 8.3 with required extensions"
    echo "  • MariaDB Database"
    echo "  • Redis Server"
    echo "  • Composer Package Manager"
    echo -e "${NC}"
    echo -e "${YELLOW}Domain: ${WHITE}$DOMAIN${NC}"
    echo -e "${YELLOW}Database: ${WHITE}panel${NC}"
    echo -e "${YELLOW}Database User: ${WHITE}pterodactyl${NC}"
    
    echo -e "\n${RED}Warning: This will modify system configuration and install packages.${NC}"
    read -p "$(echo -e ${YELLOW}"Do you want to continue? (y/N): "${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Installation cancelled.${NC}"
        exit 1
    fi
}

get_user_input() {
    print_header
    echo -e "${WHITE}Please provide the following information:${NC}\n"
    
    while true; do
        read -p "$(echo -e ${YELLOW}"Enter your domain (e.g., panel.example.com): "${NC})" DOMAIN
        if [[ -n "$DOMAIN" ]]; then
            break
        else
            print_error "Domain cannot be empty. Please try again."
        fi
    done
    
    echo
    read -p "$(echo -e ${YELLOW}"Enter database password for pterodactyl user (press enter for random): "${NC})" DB_PASS
    if [[ -z "$DB_PASS" ]]; then
        DB_PASS=$(openssl rand -base64 16)
        print_info "Generated random database password"
    fi
}

show_progress() {
    local task_name="$1"
    local task_command="$2"
    
    print_step "$task_name"
    eval "$task_command" &
    local pid=$!
    spinner $pid
    wait $pid
    if [ $? -eq 0 ]; then
        print_success "$task_name completed"
    else
        print_error "$task_name failed"
        exit 1
    fi
}

# Main installation function
install_pterodactyl() {
    get_user_input
    confirm_installation
    
    print_header
    echo -e "${WHITE}Starting installation process...${NC}"
    
    # --- Dependencies ---
    show_progress "Updating package list" "apt update && apt install -y curl apt-transport-https ca-certificates gnupg unzip git tar sudo lsb-release"
    
    # Detect OS and setup PHP
    print_step "Detecting OS and configuring PHP repositories"
    OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    
    if [[ "$OS" == "ubuntu" ]]; then
        print_info "Detected Ubuntu. Adding PPA for PHP..."
        apt install -y software-properties-common
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
    elif [[ "$OS" == "debian" ]]; then
        print_info "Detected Debian. Adding SURY PHP repository..."
        curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
        echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/sury-php.list
    fi
    
    # Add Redis repository
    print_step "Adding Redis repository"
    curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
    
    show_progress "Updating repositories" "apt update"
    
    # --- Install PHP + extensions ---
    show_progress "Installing PHP 8.3 and extensions" "apt install -y php8.3 php8.3-{cli,fpm,common,mysql,mbstring,bcmath,xml,zip,curl,gd,tokenizer,ctype,simplexml,dom} mariadb-server nginx redis-server"
    
    # --- Install Composer ---
    show_progress "Installing Composer" "curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer"
    
    # --- Download Pterodactyl Panel ---
    print_step "Downloading Pterodactyl Panel"
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    print_success "Pterodactyl Panel downloaded and extracted"
    
    # --- MariaDB Setup ---
    print_step "Setting up MariaDB database"
    DB_NAME=panel
    DB_USER=pterodactyl
    
    mariadb -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
    mariadb -e "CREATE DATABASE ${DB_NAME};"
    mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
    mariadb -e "FLUSH PRIVILEGES;"
    print_success "Database setup completed"
    
    # --- .env Setup ---
    print_step "Configuring environment file"
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
    show_progress "Installing PHP dependencies" "COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"
    
    # --- Generate Application Key ---
    show_progress "Generating application key" "php artisan key:generate --force"
    
    # --- Run Migrations ---
    show_progress "Running database migrations" "php artisan migrate --seed --force"
    
    # --- Permissions ---
    print_step "Setting up permissions and cron job"
    chown -R www-data:www-data /var/www/pterodactyl/*
    apt install -y cron
    systemctl enable --now cron
    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
    print_success "Permissions and cron setup completed"
    
    # --- SSL Certificate ---
    print_step "Generating SSL certificate"
    mkdir -p /etc/certs/panel
    cd /etc/certs/panel
    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
        -subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
        -keyout privkey.pem -out fullchain.pem 2>/dev/null
    print_success "SSL certificate generated"
    
    # --- Nginx Setup ---
    print_step "Configuring Nginx"
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
    nginx -t && systemctl restart nginx
    print_success "Nginx configuration completed"
    
    # --- Queue Worker ---
    print_step "Setting up queue worker service"
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
    print_success "Queue worker service setup completed"
    
    # Final setup
    print_step "Finalizing installation"
    cd /var/www/pterodactyl
    sed -i '/^APP_ENVIRONMENT_ONLY=/d' .env
    echo "APP_ENVIRONMENT_ONLY=false" >> .env
    
    progress_bar 3
    print_success "Final configuration completed"
    
    show_final_summary
}

show_final_summary() {
    print_header
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   INSTALLATION COMPLETE!                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "\n${WHITE}Your Pterodactyl Panel has been successfully installed!${NC}\n"
    
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│                     ${WHITE}PANEL DETAILS${CYAN}                     │${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│  ${YELLOW}🌐 Panel URL:${WHITE} https://${DOMAIN}${CYAN}                   │${NC}"
    echo -e "${CYAN}│  ${YELLOW}📂 Installation:${WHITE} /var/www/pterodactyl${CYAN}            │${NC}"
    echo -e "${CYAN}│  ${YELLOW}🔧 Database:${WHITE} panel${CYAN}                               │${NC}"
    echo -e "${CYAN}│  ${YELLOW}👤 DB User:${WHITE} pterodactyl${CYAN}                          │${NC}"
    echo -e "${CYAN}│  ${YELLOW}🔑 DB Password:${WHITE} ${DB_PASS}${CYAN}           │${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    
    echo -e "\n${WHITE}Next steps:${NC}"
    echo -e "  ${GREEN}1.${NC} Run: ${CYAN}cd /var/www/pterodactyl && php artisan p:user:make${NC}"
    echo -e "  ${GREEN}2.${NC} Create your admin account when prompted"
    echo -e "  ${GREEN}3.${NC} Access your panel at ${CYAN}https://${DOMAIN}${NC}"
    echo -e "  ${GREEN}4.${NC} Consider setting up a proper SSL certificate"
    
    echo -e "\n${YELLOW}Services running:${NC}"
    echo -e "  ${GREEN}✓${NC} Nginx"
    echo -e "  ${GREEN}✓${NC} PHP-FPM 8.3"
    echo -e "  ${GREEN}✓${NC} MariaDB"
    echo -e "  ${GREEN}✓${NC} Redis"
    echo -e "  ${GREEN}✓${NC} Pterodactyl Queue Worker"
    
    echo -e "\n${GREEN}Thank you for using Pterodactyl! 🦖${NC}\n"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root. Use sudo or switch to root user."
    exit 1
fi

# Start installation
install_pterodactyl
