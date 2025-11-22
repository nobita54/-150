#!/bin/bash

# Colors for UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display custom header
display_header() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}"
    echo "   ███╗   ██╗ ██████╗ ██████╗ ██╗████████╗ █████╗ "
    echo "   ████╗  ██║██╔═══██╗██╔══██╗██║╚══██╔══╝██╔══██╗"
    echo "   ██╔██╗ ██║██║   ██║██████╔╝██║   ██║   ███████║"
    echo "   ██║╚██╗██║██║   ██║██╔══██╗██║   ██║   ██╔══██║"
    echo "   ██║ ╚████║╚██████╔╝██║  ██║██║   ██║   ██║  ██║"
    echo "   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═╝   ╚═╝   ╚═╝  ╚═╝"
    echo -e "${NC}"$
    echo -e "${CYAN}           Thank you for using Nobita-hosting!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    sleep 2
}

# Function to display status messages
status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect existing installation
detect_existing_installation() {
    status "Scanning for existing Pterodactyl installation..."
    
    local detected_components=()
    
    # Check for panel directory
    if [ -d "/var/www/pterodactyl" ]; then
        detected_components+=("Panel Directory: /var/www/pterodactyl")
    fi
    
    # Check for database
    if command_exists mariadb; then
        DB_CHECK=$(mariadb -e "SHOW DATABASES LIKE 'panel';" 2>/dev/null | grep -c panel || true)
        if [ "$DB_CHECK" -eq 1 ]; then
            detected_components+=("Database: panel")
        fi
    fi
    
    # Check for nginx config
    if [ -f "/etc/nginx/sites-available/pterodactyl.conf" ] || [ -f "/etc/nginx/sites-enabled/pterodactyl.conf" ]; then
        detected_components+=("Nginx Configuration")
    fi
    
    # Check for pteroq service
    if systemctl list-unit-files | grep -q pteroq; then
        detected_components+=("Queue Worker Service")
    fi
    
    if [ ${#detected_components[@]} -gt 0 ]; then
        warning "Existing Pterodactyl components detected:"
        for component in "${detected_components[@]}"; do
            echo "  - $component"
        done
        return 0
    else
        success "No existing Pterodactyl installation detected."
        return 1
    fi
}

# Function to validate domain
validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to get server IP
get_server_ip() {
    # Try different methods to get public IP
    local pub_ip=$(curl -s -4 ifconfig.co || curl -s -4 icanhazip.com || curl -s -4 ipinfo.io/ip || echo "127.0.0.1")
    echo "$pub_ip"
}

# Function to generate random password
generate_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | head -c 16
}

# Function to install dependencies
install_dependencies() {
    status "Installing system dependencies..."
    
    apt update && apt install -y curl apt-transport-https ca-certificates gnupg unzip git tar sudo lsb-release
    
    # Detect OS
    OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    
    if [[ "$OS" == "ubuntu" ]]; then
        status "Detected Ubuntu. Adding PPA for PHP..."
        apt install -y software-properties-common
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
    elif [[ "$OS" == "debian" ]]; then
        status "Detected Debian. Adding SURY PHP repository..."
        curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
        echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/sury-php.list
    fi
    
    # Add Redis repository
    curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
    
    apt update
}

# Function to install PHP and services
install_php_services() {
    status "Installing PHP and required services..."
    
    apt install -y php8.3 php8.3-{cli,fpm,common,mysql,mbstring,bcmath,xml,zip,curl,gd,tokenizer,ctype,simplexml,dom} mariadb-server nginx redis-server
    
    # Install Composer
    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
}

# Function to setup database
setup_database() {
    local db_name=$1
    local db_user=$2
    local db_pass=$3
    
    status "Setting up MariaDB database..."
    
    # Start MariaDB if not running
    systemctl start mariadb 2>/dev/null || true
    systemctl enable mariadb 2>/dev/null || true
    
    # Secure installation (minimal)
    mariadb -e "DELETE FROM mysql.user WHERE User='';"
    mariadb -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mariadb -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    # Create database and user
    mariadb -e "CREATE DATABASE IF NOT EXISTS ${db_name};" 2>/dev/null || {
        error "Failed to create database. Please check MariaDB installation."
        return 1
    }
    
    mariadb -e "CREATE USER IF NOT EXISTS '${db_user}'@'127.0.0.1' IDENTIFIED BY '${db_pass}';" 2>/dev/null || {
        error "Failed to create database user."
        return 1
    }
    
    mariadb -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'127.0.0.1' WITH GRANT OPTION;" 2>/dev/null || {
        error "Failed to grant privileges."
        return 1
    }
    
    mariadb -e "FLUSH PRIVILEGES;"
    
    success "Database setup completed successfully!"
}

# Function to install panel
install_panel() {
    local host=$1
    local use_ssl=$2
    local db_name=$3
    local db_user=$4
    local db_pass=$5
    
    status "Installing Pterodactyl Panel..."
    
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    
    # Download panel
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    
    # Setup .env file
    if [ ! -f ".env.example" ]; then
        curl -Lo .env.example https://raw.githubusercontent.com/pterodactyl/panel/develop/.env.example
    fi
    
    cp .env.example .env
    
    # Configure .env based on SSL choice
    if [ "$use_ssl" == "yes" ]; then
        sed -i "s|APP_URL=.*|APP_URL=https://${host}|g" .env
    else
        sed -i "s|APP_URL=.*|APP_URL=http://${host}|g" .env
    fi
    
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=${db_name}|g" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=${db_user}|g" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${db_pass}|g" .env
    
    if ! grep -q "^APP_ENVIRONMENT_ONLY=" .env; then
        echo "APP_ENVIRONMENT_ONLY=false" >> .env
    fi
    
    # Install PHP dependencies
    status "Installing PHP dependencies..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    
    # Generate application key
    php artisan key:generate --force
    
    # Run migrations
    php artisan migrate --seed --force
    
    # Set permissions
    chown -R www-data:www-data /var/www/pterodactyl/*
}

# Function to setup SSL
setup_ssl() {
    local host=$1
    
    status "Setting up SSL certificates..."
    
    mkdir -p /etc/certs/panel
    cd /etc/certs/panel
    
    # Generate self-signed certificate
    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
        -subj "/C=US/ST=Auto/L=Auto/O=Auto/CN=${host}" \
        -keyout privkey.pem -out fullchain.pem 2>/dev/null
    
    success "SSL certificates generated!"
}

# Function to setup nginx with SSL choice
setup_nginx() {
    local host=$1
    local use_ssl=$2
    
    status "Configuring Nginx..."
    
    # Get PHP version dynamically
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    
    if [ "$use_ssl" == "yes" ]; then
        # Configuration with SSL
        tee /etc/nginx/sites-available/pterodactyl.conf > /dev/null << EOF
server {
    listen 80;
    server_name ${host};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${host};

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
    else
        # Configuration without SSL
        tee /etc/nginx/sites-available/pterodactyl.conf > /dev/null << EOF
server {
    listen 80;
    server_name ${host};

    root /var/www/pterodactyl/public;
    index index.php;

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
    fi

    # Enable site
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
    
    # Remove default nginx site
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and restart nginx
    nginx -t && systemctl restart nginx
    
    success "Nginx configuration completed!"
}

# Function to setup queue worker
setup_queue_worker() {
    status "Setting up queue worker..."
    
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
    
    success "Queue worker setup completed!"
}

# Function to setup cron
setup_cron() {
    status "Setting up cron job..."
    
    apt install -y cron
    systemctl enable --now cron
    
    # Add schedule runner
    (crontab -l 2>/dev/null | grep -v "artisan schedule:run"; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
    
    success "Cron job setup completed!"
}

# Function to show installation summary
show_summary() {
    local host=$1
    local use_ssl=$2
    local db_user=$3
    local db_pass=$4
    
    display_header
    echo -e "\n${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    INSTALLATION COMPLETE!                   ║"
    echo "╚══════════════════════════════════════════════════════════════╗"
    echo -e "${NC}"
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    
    if [ "$use_ssl" == "yes" ]; then
        echo -e "${CYAN}│ ${YELLOW}🌐 PANEL URL (HTTPS)${NC}${CYAN}                           │${NC}"
        echo -e "${CYAN}│   ${GREEN}https://${host}${NC}"
    else
        echo -e "${CYAN}│ ${YELLOW}🌐 PANEL URL (HTTP)${NC}${CYAN}                            │${NC}"
        echo -e "${CYAN}│   ${GREEN}http://${host}${NC}"
        echo -e "${CYAN}│   ${YELLOW}Note: Running without SSL${NC}"
    fi
    
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│ ${YELLOW}📁 INSTALLATION DIRECTORY${NC}${CYAN}                     │${NC}"
    echo -e "${CYAN}│   ${GREEN}/var/www/pterodactyl${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│ ${YELLOW}🗄️  DATABASE CREDENTIALS${NC}${CYAN}                      │${NC}"
    echo -e "${CYAN}│   ${GREEN}Database: panel${NC}"
    echo -e "${CYAN}│   ${GREEN}Username: ${db_user}${NC}"
    echo -e "${CYAN}│   ${GREEN}Password: ${db_pass}${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│ ${YELLOW}🔧 NEXT STEPS${NC}${CYAN}                                 │${NC}"
    echo -e "${CYAN}│   ${GREEN}1. Create admin user:${NC}"
    echo -e "${CYAN}│      cd /var/www/pterodactyl && php artisan p:user:make${NC}"
    echo -e "${CYAN}│   ${GREEN}2. Check services:${NC}"
    echo -e "${CYAN}│      systemctl status nginx pteroq${NC}"
    if [ "$use_ssl" == "no" ]; then
        echo -e "${CYAN}│   ${YELLOW}3. For production, consider:${NC}"
        echo -e "${CYAN}│      - Setting up proper SSL certificates${NC}"
    fi
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e "\n${PURPLE}🎉 Pterodactyl Panel has been successfully installed!${NC}\n"
}

# Function to get user input for domain and SSL
get_installation_config() {
    display_header
    
    # Get domain or IP
    while true; do
        echo -e "${CYAN}Enter your domain or IP address:${NC}"
        echo -e "  ${YELLOW}Examples:${NC}"
        echo -e "  - Domain: panel.example.com"
        echo -e "  - IP: 192.168.1.100"
        echo
        read -p "$(status 'Enter domain or IP: ')" HOST
        
        if validate_domain "$HOST" || validate_ip "$HOST"; then
            success "Valid host: $HOST"
            break
        else
            error "Invalid input. Please enter a valid domain or IP address."
        fi
    done
    
    echo
    
    # Get SSL choice
    while true; do
        echo -e "${CYAN}Do you want to enable SSL?${NC}"
        echo -e "  ${GREEN}yes${NC}) Enable SSL (HTTPS) - Recommended for domains"
        echo -e "  ${RED}no${NC})  Disable SSL (HTTP) - For testing or local IP"
        echo
        read -p "$(status 'Enable SSL? (yes/no): ')" SSL_CHOICE
        
        case $SSL_CHOICE in
            [Yy][Ee][Ss]|Y|y)
                USE_SSL="yes"
                success "SSL will be enabled"
                break
                ;;
            [Nn][Oo]|N|n)
                USE_SSL="no"
                warning "SSL will be disabled - using HTTP"
                break
                ;;
            *)
                error "Invalid choice. Please enter 'yes' or 'no'."
                ;;
        esac
    done
}

# Main installation function
main_installation() {
    display_header
    
    # Detect existing installation
    if detect_existing_installation; then
        echo
        read -p "$(warning 'Existing installation detected. Continue? (y/N): ')" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation aborted by user."
            exit 1
        fi
    fi
    
    # Get installation configuration
    get_installation_config
    
    # Generate credentials
    DB_NAME="panel"
    DB_USER="pterodactyl"
    DB_PASS=$(generate_password)
    
    echo
    status "Starting installation with the following configuration:"
    echo "  Host: $HOST"
    if [ "$USE_SSL" == "yes" ]; then
        echo "  SSL: Enabled (HTTPS)"
    else
        echo "  SSL: Disabled (HTTP)"
    fi
    echo "  Database: $DB_NAME"
    echo "  DB User: $DB_USER"
    echo "  DB Password: $DB_PASS"
    echo
    
    read -p "$(warning 'Proceed with installation? (y/N): ')" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation aborted by user."
        exit 1
    fi
    
    # Installation steps
    install_dependencies
    install_php_services
    setup_database "$DB_NAME" "$DB_USER" "$DB_PASS"
    install_panel "$HOST" "$USE_SSL" "$DB_NAME" "$DB_USER" "$DB_PASS"
    
    # Setup SSL only if enabled
    if [ "$USE_SSL" == "yes" ]; then
        setup_ssl "$HOST"
    fi
    
    setup_nginx "$HOST" "$USE_SSL"
    setup_queue_worker
    setup_cron
    
    # Final setup
    cd /var/www/pterodactyl
    sed -i '/^APP_ENVIRONMENT_ONLY=/d' .env
    echo "APP_ENVIRONMENT_ONLY=false" >> .env
    
    show_summary "$HOST" "$USE_SSL" "$DB_USER" "$DB_PASS"
}

# Menu system
show_menu() {
    display_header
    echo -e "${CYAN}Select an option:${NC}"
    echo -e "  ${GREEN}1${NC}) Fresh Installation"
    echo -e "  ${GREEN}2${NC}) Check Existing Installation"
    echo -e "  ${GREEN}3${NC}) Create Admin User"
    echo -e "  ${GREEN}4${NC}) Check Services Status"
    echo -e "  ${GREEN}5${NC}) Exit"
    echo
}

check_services() {
    display_header
    status "Checking service status..."
    echo
    
    services=("nginx" "mariadb" "redis-server" "pteroq")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo -e "  ${GREEN}✓${NC} $service: ${GREEN}Running${NC}"
        else
            echo -e "  ${RED}✗${NC} $service: ${RED}Not Running${NC}"
        fi
    done
    
    echo
    read -p "Press Enter to continue..."
}

create_admin_user() {
    display_header
    status "Creating admin user..."
    
    if [ -d "/var/www/pterodactyl" ]; then
        cd /var/www/pterodactyl
        php artisan p:user:make
    else
        error "Pterodactyl panel not found at /var/www/pterodactyl"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Main menu loop
while true; do
    show_menu
    read -p "$(status 'Enter your choice (1-5): ')" choice
    
    case $choice in
        1)
            main_installation
            break
            ;;
        2)
            display_header
            detect_existing_installation
            echo
            read -p "Press Enter to continue..."
            ;;
        3)
            create_admin_user
            ;;
        4)
            check_services
            ;;
        5)
            display_header
            echo
            status "Goodbye!"
            exit 0
            ;;
        *)
            error "Invalid option. Please try again."
            sleep 2
            ;;
    esac
done
