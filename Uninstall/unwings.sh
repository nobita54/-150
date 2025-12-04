#!/bin/bash

# Optional color vars
Y="\e[33m"
G="\e[32m"
R="\e[31m"
C="\e[36m"
N="\e[0m"

while true; do
    clear
    echo "======================="
    echo "       MACK MENU       "
    echo "======================="
    echo "1) Full Installer"
    echo "2) Local IP"
    echo "3) Uninstall"
    echo "0) Exit"
    echo "======================="
    read -p "Choose an option: " opt

    case $opt in

# ---------------------------------------------------------
# OPTION 1: FULL INSTALLER
# ---------------------------------------------------------
        1)
            clear
            echo -e "${Y}⚙ Starting Extended Installer...${N}"

            # ---------------------------
            # Ask Domain for SSL
            # ---------------------------
            read -p "Enter Domain for SSL: " DOMAIN

            echo -e "${C}Installing Certbot...${N}"
            apt update -y
            apt install -y certbot python3-certbot-nginx
            certbot certonly --nginx -d "$DOMAIN"


            # ---------------------------
            # Database Setup (Default + Custom)
            # ---------------------------
            echo -e "${C}Enter MariaDB Database Details (Press Enter for default root/root/root):${N}"

            read -p "DB Name [root]: " DB_NAME
            DB_NAME=${DB_NAME:-root}

            read -p "DB User [root]: " DB_USER
            DB_USER=${DB_USER:-root}

            read -p "DB Pass [root]: " DB_PASS
            DB_PASS=${DB_PASS:-root}

            echo -e "${Y}Using DB=${DB_NAME}, USER=${DB_USER}, PASS=${DB_PASS}${N}"

            mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
            mariadb -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
            mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
            mariadb -e "FLUSH PRIVILEGES;"

            echo -e "${G}✔ MariaDB configured successfully!${N}"


            # ---------------------------
            # Bind-address Fix
            # ---------------------------
            CONF_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"

            if [ -f "$CONF_FILE" ]; then
                echo -e "${Y}Updating bind-address...${N}"
                sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' "$CONF_FILE"
            else
                echo -e "${R}Config file NOT found: $CONF_FILE${N}"
            fi

            echo -e "${C}Restarting MySQL...${N}"
            systemctl restart mysql 2>/dev/null
            systemctl restart mariadb 2>/dev/null


            # ---------------------------
            # Confirmation (Y/N)
            # ---------------------------
            read -p "Proceed with Docker & Wings install? (y/n): " YES

            if [[ "$YES" != "y" ]]; then
                echo -e "${R}Installation aborted.${N}"
                read -p "↩ Press Enter..."
                break
            fi


            # ---------------------------
            # Docker Install
            # ---------------------------
            echo -e "${C}Installing Docker...${N}"
            curl -sSL https://get.docker.com/ | CHANNEL=stable bash

            echo -e "${C}Starting Docker service...${N}"
            systemctl enable --now docker


            # ---------------------------
            # GRUB Fix
            # ---------------------------
            echo -e "${C}Updating GRUB config...${N}"
            GRUB_FILE="/etc/default/grub"

            if [ -f "$GRUB_FILE" ]; then
                sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' $GRUB_FILE
                update-grub
            fi


            # ---------------------------
            # WINGS Install
            # ---------------------------
            echo -e "${C}Installing Wings...${N}"
            mkdir -p /etc/pterodactyl

            ARCH=$(uname -m)
            if [ "$ARCH" == "x86_64" ]; then 
                ARCH="amd64"
            else 
                ARCH="arm64"
            fi

            curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$ARCH"
            chmod u+x /usr/local/bin/wings


            # ---------------------------
            # Wings Service
            # ---------------------------
            echo -e "${C}Creating Wings Service...${N}"

            cat <<EOF > /etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

            systemctl daemon-reload
            systemctl enable wings

            echo -e "${G}✔ FULL Installation Completed Successfully!${N}"
            read -p "↩ Press Enter..."
        ;;


# ---------------------------------------------------------
# OPTION 2: LOCAL IP
# ---------------------------------------------------------
        2)
            echo "Local IPs:"
            hostname -I
            read -p "↩ Press Enter..."
        ;;


# ---------------------------------------------------------
# OPTION 3: UNINSTALL
# ---------------------------------------------------------
        3)
            echo -e "${R}Uninstall script not added yet.${N}"
            echo "Bol do kya uninstall karna hai, main add kar dunga."
            read -p "↩ Press Enter..."
        ;;


# ---------------------------------------------------------
# EXIT
# ---------------------------------------------------------
        0)
            echo "Goodbye!"
            exit 0
        ;;

        *)
            echo "Wrong option, nobita! Try again."
            sleep 1
        ;;
    esac
done
