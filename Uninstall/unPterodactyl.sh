#!/bin/bash

# ====================================================
#          PTERODACTYL INSTALL / UNINSTALL MENU
# ====================================================

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
NC="\033[0m"

# ================== INSTALL FUNCTION ==================
install_ptero() {
    clear
    echo -e "${CYAN}"
    echo "┌──────────────────────────────────────────────┐"
    echo "│            Pterodactyl Installation          │"
    echo "└──────────────────────────────────────────────┘${NC}"

    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget git tar zip unzip software-properties-common

    bash <(curl -s https://pterodactyl-installer.se)

    echo -e "${GREEN}✔ Installation Complete${NC}"
    read -p "Press Enter to return..."
}

# ================= PANEL UNINSTALL =================
uninstall_panel() {
    echo ">>> Stopping Panel service..."
    sudo systemctl stop pteroq.service || true
    sudo systemctl disable pteroq.service || true
    sudo rm -f /etc/systemd/system/pteroq.service
    sudo systemctl daemon-reload

    echo ">>> Removing Panel cronjob..."
    sudo crontab -l | grep -v 'php /var/www/pterodactyl/artisan schedule:run' | sudo crontab - || true

    echo ">>> Removing Panel files..."
    sudo rm -rf /var/www/pterodactyl

    echo ">>> Removing Panel MySQL database & user..."
    sudo mysql -u root -e "DROP DATABASE IF EXISTS panel;"
    sudo mysql -u root -e "DROP USER IF EXISTS 'pterodactyl'@'127.0.0.1';"
    sudo mysql -u root -e "FLUSH PRIVILEGES;"

    echo ">>> Cleaning Nginx configs..."
    [ -f /etc/nginx/sites-enabled/pterodactyl.conf ] && sudo rm -f /etc/nginx/sites-enabled/pterodactyl.conf
    [ -f /etc/nginx/sites-available/pterodactyl.conf ] && sudo rm -f /etc/nginx/sites-available/pterodactyl.conf
    sudo systemctl reload nginx || true

    echo "✅ Panel uninstalled successfully!"
}

# ================= UNINSTALL PTERODACTYL =================
uninstall_ptero() {
    clear
    echo -e "${CYAN}"
    echo "┌──────────────────────────────────────────────┐"
    echo "│           Pterodactyl Uninstallation         │"
    echo "└──────────────────────────────────────────────┘${NC}"

    uninstall_panel

    echo -e "${GREEN}✔ Pterodactyl Panel Uninstalled (Wings Not Removed)${NC}"
    read -p "Press Enter to return..."
}

# ===================== UI MENU =====================
while true; do
    clear
    echo -e "${YELLOW}"
    echo "╔═══════════════════════════════════════════════╗"
    echo "║           PTERODACTYL CONTROL MENU            ║"
    echo "╠═══════════════════════════════════════════════╣"
    echo -e "║ ${GREEN}1) Install Pterodactyl${NC}                           ║"
    echo -e "║ ${RED}2) Uninstall Pterodactyl (Panel Only)${NC}            ║"
    echo -e "║ 3) Exit                                         ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo -ne "${CYAN}Select Option: ${NC}"
    read choice

    case $choice in
        1) install_ptero ;;
        2) uninstall_ptero ;;
        3) clear; exit ;;
        *) echo -e "${RED}Invalid option...${NC}"; sleep 1 ;;
    esac
done
