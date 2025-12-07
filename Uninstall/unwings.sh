#!/bin/bash

# Colors
Y="\e[33m"
G="\e[32m"
R="\e[31m"
C="\e[36m"
M="\e[35m"
B="\e[34m"
W="\e[97m"
N="\e[0m"

# Box Drawing Characters
TL="╔"  # Top Left
TR="╗"  # Top Right
BL="╚"  # Bottom Left
BR="╝"  # Bottom Right
HL="═"  # Horizontal Line
VL="║"  # Vertical Line
LT="╠"  # Left T
RT="╣"  # Right T

show_header() {
    clear
    echo -e "${M}${TL}════════════════════════════════════════════════════════════${TR}${N}"
    echo -e "${VL}${W}                🚀 MACK CONTROL PANEL                    ${M}${VL}${N}"
    echo -e "${LT}════════════════════════════════════════════════════════════${RT}${N}"
    echo -e "${VL}${Y}               Version 2.0 • Server Manager               ${M}${VL}${N}"
    echo -e "${BL}════════════════════════════════════════════════════════════${BR}${N}\n"
}

show_menu() {
    echo -e "${B}${TL}════════════════════════════════════════════════════════════${TR}${N}"
    echo -e "${VL}${W}                     📋 MAIN MENU                          ${B}${VL}${N}"
    echo -e "${LT}════════════════════════════════════════════════════════════${RT}${N}"
    echo -e "${VL}${G}   1. ${W}🌐 Public IP                 ${B}${VL}${N}"
    echo -e "${VL}${C}   2. ${W}🏠 Local IP                        ${B}${VL}${N}"
    echo -e "${VL}${R}   3. ${W}🗑️  Uninstall             ${B}${VL}${N}"
    echo -e "${VL}${Y}   0. ${W}🚪 Exit                                        ${B}${VL}${N}"
    echo -e "${BL}════════════════════════════════════════════════════════════${BR}${N}\n"
}

show_progress_bar() {
    local current=$1
    local total=$2
    local message=$3
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${C}["
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "] ${percent}%% ${W}${message}${N}"
}

public_ip_setup() {
    clear
    echo -e "${G}${TL}════════════════════════════════════════════════════════════${TR}${N}"
    echo -e "${VL}${W}            🌐 PUBLIC IP & NETWORK SETUP                 ${G}${VL}${N}"
    echo -e "${LT}════════════════════════════════════════════════════════════${RT}${N}\n"
    
    # Get public IP
    echo -e "${VL}${C}📍 Detecting Public IP...${N}"
    PUBLIC_IP=$(curl -s https://ipinfo.io/ip || echo "Unable to detect")
    echo -e "${VL}${G}✓ Public IP: ${W}$PUBLIC_IP${N}"
    
    # Ask Domain for SSL
    echo -e "\n${VL}${Y}🔗 DOMAIN SETUP FOR SSL${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    echo -ne "${VL}${W}Enter Domain for SSL (e.g., panel.example.com): ${N}"
    read DOMAIN
    
    if [[ -z "$DOMAIN" ]]; then
        echo -e "\n${VL}${R}❌ No domain entered. Setup aborted.${N}"
        echo -e "${BL}════════════════════════════════════════════════════════════${BR}${N}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "\n${VL}${G}✓ Using domain: ${W}$DOMAIN${N}"
    
    # ---------------------------
    # Step 1: Update & Install Dependencies
    # ---------------------------
    echo -e "\n${VL}${Y}📦 STEP 1: System Updates & Dependencies${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    
    show_progress_bar 1 10 "Updating package list..."
    apt update -y > /dev/null 2>&1
    
    show_progress_bar 2 10 "Installing MySQL & MariaDB..."
    apt install -y mysql-server mariadb-server > /dev/null 2>&1
    
    show_progress_bar 3 10 "Starting database services..."
    systemctl enable mysql > /dev/null 2>&1
    systemctl enable mariadb > /dev/null 2>&1
    systemctl start mysql > /dev/null 2>&1
    systemctl start mariadb > /dev/null 2>&1
    
    echo -e "\n\n${VL}${G}✓ System updates and database installation complete${N}"
    
    # ---------------------------
    # Step 2: SSL Certificate
    # ---------------------------
    echo -e "\n${VL}${Y}🔐 STEP 2: SSL Certificate Installation${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    
    show_progress_bar 4 10 "Installing Certbot..."
    apt install -y certbot python3-certbot-nginx > /dev/null 2>&1
    
    show_progress_bar 5 10 "Requesting SSL certificate..."
    certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@$DOMAIN > /dev/null 2>&1
    
    echo -e "\n\n${VL}${G}✓ SSL certificate installed for ${W}$DOMAIN${N}"
    
    # ---------------------------
    # Step 3: Database Configuration
    # ---------------------------
    echo -e "\n${VL}${Y}💾 STEP 3: Database Configuration${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    
    echo -e "${VL}${C}Enter MariaDB Details (Press Enter for defaults):${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    
    echo -ne "${VL}${W}Database Name [root]: ${N}"
    read DB_NAME
    DB_NAME=${DB_NAME:-root}
    
    echo -ne "${VL}${W}Database User [root]: ${N}"
    read DB_USER
    DB_USER=${DB_USER:-root}
    
    echo -ne "${VL}${W}Database Password [root]: ${N}"
    read DB_PASS
    DB_PASS=${DB_PASS:-root}
    
    echo -e "\n${VL}${Y}Using: DB=${W}$DB_NAME${Y}, USER=${W}$DB_USER${Y}, PASS=${W}$DB_PASS${N}"
    
    show_progress_bar 6 10 "Creating database and user..."
    mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';" > /dev/null 2>&1
    mariadb -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" > /dev/null 2>&1
    mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;" > /dev/null 2>&1
    mariadb -e "FLUSH PRIVILEGES;" > /dev/null 2>&1
    
    echo -e "\n\n${VL}${G}✓ MariaDB configured successfully!${N}"
    
    # ---------------------------
    # Step 4: Bind-address Fix
    # ---------------------------
    echo -e "\n${VL}${Y}⚙️  STEP 4: Network Configuration${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    
    show_progress_bar 7 10 "Configuring bind-address..."
    CONF_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"
    
    if [ -f "$CONF_FILE" ]; then
        sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' "$CONF_FILE"
        echo -e "\n${VL}${G}✓ Bind-address set to 0.0.0.0${N}"
    else
        echo -e "\n${VL}${Y}⚠ Config file not found, skipping bind-address update${N}"
    fi
    
    systemctl restart mysql 2>/dev/null
    systemctl restart mariadb 2>/dev/null
    
    # ---------------------------
    # Confirmation
    # ---------------------------
    echo -e "\n${VL}${Y}⚠️  INSTALLATION CONFIRMATION${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    echo -e "${VL}${W}Ready to install:${N}"
    echo -e "${VL}${W}  • Docker${N}"
    echo -e "${VL}${W}  • Pterodactyl Wings${N}"
    echo -e "${VL}${W}  • GRUB Configuration${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    
    echo -ne "${VL}${C}Proceed with Docker & Wings installation? (y/n): ${N}"
    read YES
    
    if [[ "$YES" != "y" ]] && [[ "$YES" != "Y" ]]; then
        echo -e "\n${VL}${R}❌ Installation cancelled by user.${N}"
        echo -e "${BL}════════════════════════════════════════════════════════════${BR}${N}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # ---------------------------
    # Step 5: Docker Install
    # ---------------------------
    echo -e "\n${VL}${Y}🐳 STEP 5: Docker Installation${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    
    show_progress_bar 8 10 "Installing Docker..."
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash > /dev/null 2>&1
    systemctl enable --now docker > /dev/null 2>&1
    
    # ---------------------------
    # Step 6: GRUB Fix
    # ---------------------------
    echo -e "\n${VL}${Y}⚙️  STEP 6: GRUB Configuration${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    
    show_progress_bar 9 10 "Updating GRUB..."
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' /etc/default/grub
    update-grub > /dev/null 2>&1
    
    # ---------------------------
    # Step 7: Wings Install
    # ---------------------------
    echo -e "\n${VL}${Y}🦅 STEP 7: Pterodactyl Wings Installation${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    
    show_progress_bar 10 10 "Installing Wings..."
    mkdir -p /etc/pterodactyl
    
    ARCH=$(uname -m)
    if [ "$ARCH" == "x86_64" ]; then 
        ARCH="amd64"
    else 
        ARCH="arm64"
    fi
    
    curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$ARCH" > /dev/null 2>&1
    chmod u+x /usr/local/bin/wings
    
    # Wings service
    cat <<EOF > /etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
ExecStart=/usr/local/bin/wings
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable wings > /dev/null 2>&1
    
    echo -e "\n\n${VL}${G}✅ INSTALLATION COMPLETE!${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    echo -e "${VL}${G}✓ Domain: ${W}$DOMAIN${N}"
    echo -e "${VL}${G}✓ Database: ${W}$DB_NAME${N}"
    echo -e "${VL}${G}✓ Public IP: ${W}$PUBLIC_IP${N}"
    echo -e "${VL}${G}✓ Docker: ${W}Installed & Running${N}"
    echo -e "${VL}${G}✓ Wings: ${W}Installed & Enabled${N}"
    echo -e "${VL}${G}✓ SSL Certificate: ${W}Installed${N}"
    echo -e "\n${VL}${Y}📋 Next Steps:${N}"
    echo -e "${VL}${W}1. Configure your panel to connect to this node${N}"
    echo -e "${VL}${W}2. Start Wings service: ${C}systemctl start wings${N}"
    echo -e "${VL}${W}3. Check status: ${C}systemctl status wings${N}"
    echo -e "${BL}════════════════════════════════════════════════════════════${BR}${N}\n"
    
    read -p "Press Enter to return to menu..."
}

show_local_ip() {
    clear
    echo -e "${C}${TL}════════════════════════════════════════════════════════════${TR}${N}"
    echo -e "${VL}${W}             🏠 LOCAL NETWORK INFORMATION                ${C}${VL}${N}"
    echo -e "${LT}════════════════════════════════════════════════════════════${RT}${N}\n"
    
    bash <(curl -s https://raw.githubusercontent.com/nobita54/-150/refs/heads/main/panel/wing.sh)
    
    echo -e "\n${BL}════════════════════════════════════════════════════════════${BR}${N}"
    read -p "Press Enter to continue..."
}

uninstall_wings() {
    clear
    echo -e "${R}${TL}════════════════════════════════════════════════════════════${TR}${N}"
    echo -e "${VL}${W}           🗑️  UNINSTALL WINGS (PANEL SAFE)              ${R}${VL}${N}"
    echo -e "${LT}════════════════════════════════════════════════════════════${RT}${N}\n"
    
    echo -e "${VL}${Y}⚠️  WARNING: This will remove Wings and Docker${N}"
    echo -e "${VL}${Y}   Your panel installation will remain intact.${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}\n"
    
    echo -ne "${VL}${C}Are you sure you want to uninstall Wings? (y/n): ${N}"
    read U
    
    if [[ "$U" != "y" ]] && [[ "$U" != "Y" ]]; then
        echo -e "\n${VL}${G}✓ Uninstallation cancelled.${N}"
        echo -e "${BL}════════════════════════════════════════════════════════════${BR}${N}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "\n${VL}${R}🔄 Stopping & removing Wings...${N}"
    systemctl disable --now wings 2>/dev/null
    rm -f /etc/systemd/system/wings.service
    rm -rf /etc/pterodactyl
    rm -f /usr/local/bin/wings
    rm -rf /var/lib/pterodactyl
    echo -e "${VL}${G}✓ Wings removed${N}"
    
    echo -e "\n${VL}${R}🔄 Cleaning Docker containers and images...${N}"
    docker system prune -a -f 2>/dev/null
    echo -e "${VL}${G}✓ Docker cleaned${N}"
    
    echo -e "\n${VL}${R}🔄 Database Removal (Optional)${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    echo -ne "${VL}${C}Delete MariaDB database & user? (y/n): ${N}"
    read DBDEL
    
    if [[ "$DBDEL" == "y" ]] || [[ "$DBDEL" == "Y" ]]; then
        echo -ne "${VL}${W}Database name to delete: ${N}"
        read DROPDB
        echo -ne "${VL}${W}Database user to delete: ${N}"
        read DROPUSER
        
        if [[ -n "$DROPDB" ]]; then
            mariadb -e "DROP DATABASE IF EXISTS $DROPDB;" 2>/dev/null
            echo -e "${VL}${G}✓ Database '$DROPDB' deleted${N}"
        fi
        
        if [[ -n "$DROPUSER" ]]; then
            mariadb -e "DROP USER IF EXISTS '$DROPUSER'@'127.0.0.1';" 2>/dev/null
            echo -e "${VL}${G}✓ User '$DROPUSER' deleted${N}"
        fi
        
        mariadb -e "FLUSH PRIVILEGES;" 2>/dev/null
    else
        echo -e "${VL}${Y}✓ Database kept intact${N}"
    fi
    
    echo -e "\n${VL}${G}✅ UNINSTALLATION COMPLETE!${N}"
    echo -e "${VL}${W}══════════════════════════════════════════════════════════${N}"
    echo -e "${VL}${W}Removed:${N}"
    echo -e "${VL}${W}  • Pterodactyl Wings${N}"
    echo -e "${VL}${W}  • Docker containers/images${N}"
    echo -e "${VL}${W}  • Wings configuration files${N}"
    echo -e "\n${VL}${Y}⚠️  Note: Panel files are preserved.${N}"
    echo -e "${BL}════════════════════════════════════════════════════════════${BR}${N}\n"
    
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_header
    show_menu
    
    echo -e "${C}┌─[${W}SELECT OPTION${C}]${N}"
    echo -ne "${C}└──╼${W} $ ${N}"
    read -p "" opt
    
    case $opt in
        1)
            public_ip_setup
            ;;
        2)
            show_local_ip
            ;;
        3)
            uninstall_wings
            ;;
        0)
            clear
            echo -e "${M}${TL}════════════════════════════════════════════════════════════${TR}${N}"
            echo -e "${VL}${W}                    👋 GOODBYE!                          ${M}${VL}${N}"
            echo -e "${VL}${Y}          Thank you for using Mack Control Panel         ${M}${VL}${N}"
            echo -e "${BL}════════════════════════════════════════════════════════════${BR}${N}\n"
            exit 0
            ;;
        *)
            echo -e "\n${R}❌ Invalid option! Please select 0-3${N}"
            sleep 1
            ;;
    esac
done
