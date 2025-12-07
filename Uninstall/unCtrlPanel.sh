#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${PURPLE}         ░█▀▀░█▀█░█▀▄░█▀▀░█░░        ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${PURPLE}         ░█▀▀░█▀█░█▀▄░█▀▀░█░░        ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${PURPLE}         ░▀░░░▀░▀░▀░▀░▀▀▀░▀▀▀        ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${YELLOW}           C T R L   P A N E L         ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}›${NC} ${BOLD}1)${NC} Install           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${RED}›${NC} ${BOLD}2)${NC} Uninstall       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}›${NC} ${BOLD}3)${NC} Update          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${BLUE}›${NC} ${BOLD}4)${NC} Exit                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e "${YELLOW}👉 Select an option [1-4]:${NC} ")" option

    case $option in
        1)
            echo -e "\n${GREEN}🚀 Installing CTRL Panel...${NC}"
            echo -e "${CYAN}Please wait while we set up everything...${NC}\n"
            bash <(curl -s https://raw.githubusercontent.com/nobita54/-150/refs/heads/main/panel/CtrlPanel.sh)
            ;;
        2)
            echo -e "\n${RED}⚠️  WARNING: This will remove CTRL Panel completely!${NC}"
            read -p "Are you sure? (y/N): " confirm
            if [[ $confirm == "y" || $confirm == "Y" ]]; then
                echo -e "${RED}🗑️  Uninstalling CTRL Panel...${NC}"
                
                cd /var/www/ctrlpanel 2>/dev/null
                sudo php artisan down 2>/dev/null

                sudo systemctl stop ctrlpanel 2>/dev/null
                sudo systemctl disable ctrlpanel 2>/dev/null
                sudo rm /etc/systemd/system/ctrlpanel.service 2>/dev/null
                sudo systemctl daemon-reload
                sudo systemctl reset-failed

                # Remove Cron
                sudo crontab -l | grep -v 'php /var/www/ctrlpanel/artisan schedule:run' | sudo crontab - || true

                # Remove Nginx Config
                sudo unlink /etc/nginx/sites-enabled/ctrlpanel.conf 2>/dev/null
                sudo rm /etc/nginx/sites-available/ctrlpanel.conf 2>/dev/null
                sudo systemctl reload nginx 2>/dev/null

                # Database Removal
                echo -e "${RED}🗃️  Removing database...${NC}"
                mariadb -u root -p <<EOF 2>/dev/null
DROP DATABASE IF EXISTS ctrlpanel;
DROP USER IF EXISTS 'ctrlpaneluser'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

                sudo rm -rf /var/www/ctrlpanel 2>/dev/null

                echo -e "${GREEN}✅ Uninstall complete! All files removed.${NC}"
            else
                echo -e "${YELLOW}❌ Uninstall cancelled.${NC}"
            fi
            ;;
        3)
            echo -e "\n${YELLOW}🔄 Updating CTRL Panel...${NC}"
            cd /var/www/ctrlpanel 2>/dev/null || {
                echo -e "${RED}❌ CTRL Panel directory not found!${NC}"
                echo -e "${YELLOW}Please install CTRL Panel first.${NC}"
                read -p "Press Enter to continue..."
                continue
            }
            
            php artisan down

            git stash
            git pull
            chmod -R 755 /var/www/ctrlpanel

            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

            php artisan migrate --seed --force
            php artisan queue:restart
            php artisan up

            echo -e "${GREEN}✅ Update complete! Panel is now up to date.${NC}"
            ;;
        4)
            echo -e "\n${BLUE}👋 Exiting... Have a great day!${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}❌ Invalid option! Please choose between 1-4.${NC}"
            ;;
    esac

    echo ""
    read -p "$(echo -e "${CYAN}Press ${BOLD}Enter${NC}${CYAN} to return to menu...${NC}")" dummy
done
