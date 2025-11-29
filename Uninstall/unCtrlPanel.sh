#!/bin/bash

while true; do
    clear
    echo "============================"
    echo "       CTRL PANEL MANAGER   "
    echo "============================"
    echo "1) Install   (Blank)"
    echo "2) Uninstall CTRL Panel"
    echo "3) Update CTRL Panel"
    echo "4) Exit"
    echo "----------------------------"
    read -p "Select Option [1-4] : " option

    case $option in

        1)
            echo "Install Block Empty — bol de toh main likh du."
            bash <(curl -s https://raw.githubusercontent.com/nobita54/-150/refs/heads/main/panel/CtrlPanel.sh)
            ;;

        2)
            echo "⚠ Uninstall Starting — CTRL Panel will be removed completely."
            cd /var/www/ctrlpanel
            sudo php artisan down

            sudo systemctl stop ctrlpanel
            sudo systemctl disable ctrlpanel
            sudo rm /etc/systemd/system/ctrlpanel.service
            sudo systemctl daemon-reload
            sudo systemctl reset-failed

            # Remove Cron
            sudo crontab -l | grep -v 'php /var/www/ctrlpanel/artisan schedule:run' | sudo crontab - || true

            # Remove Nginx Config
            sudo unlink /etc/nginx/sites-enabled/ctrlpanel.conf
            sudo rm /etc/nginx/sites-available/ctrlpanel.conf
            sudo systemctl reload nginx

            # Database Removal
            echo "MariaDB Login Required to Drop Database & User"
            mariadb -u root -p <<EOF
DROP DATABASE ctrlpanel;
DROP USER 'ctrlpaneluser'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

            sudo rm -rf /var/www/ctrlpanel

            echo "✔ Uninstall Complete — system kahani khatam. 🧹"
            ;;

        3)
            echo "🔄 Updating CTRL Panel..."
            cd /var/www/ctrlpanel
            php artisan down

            git stash
            git pull
            chmod -R 755 /var/www/ctrlpanel

            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

            php artisan migrate --seed --force
            php artisan queue:restart
            php artisan up

            echo "✔ Update Done — code naya, panel taza. 🚀"
            ;;

        4)
            echo "Exit — terminal chup, raat geheri. 🌙"
            exit 0
            ;;

        *)
            echo "Galat number — 1 se 4 me se choose karo."
            ;;
    esac

    echo
    read -p "Press Enter to return to menu..."
done
