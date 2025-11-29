#!/bin/bash

while true; do
    clear
    echo "============================"
    echo "         MAIN MENU          "
    echo "============================"
    echo "1) Install (empty block)"
    echo "2) Uninstall / Remove Jexactyl"
    echo "3) Update Jexactyl Panel"
    echo "4) Exit"
    echo "----------------------------"
    read -p "Choose an option [1-4]: " choice

    case "$choice" in

        1)
            echo ">> Install block empty hai — bole toh setup bhi likh du."
            bash <(curl -s https://raw.githubusercontent.com/nobita54/-150/refs/heads/main/panel/Jexpanel.sh)
            ;;

        2)
            echo ">> Uninstall starting... ⚠️ Everything will be removed."

            systemctl stop jxctl.service
            systemctl disable jxctl.service
            rm -f /etc/systemd/system/jxctl.service
            systemctl daemon-reload

            rm -f /etc/nginx/sites-available/jexactyl.conf
            rm -f /etc/nginx/sites-enabled/jexactyl.conf
            nginx -s reload

            mysql -u root -p -e "
            DROP DATABASE IF EXISTS jexactyldb;
            DROP USER IF EXISTS 'jexactyluser'@'127.0.0.1';
            FLUSH PRIVILEGES;
            "

            # NEW Line — Requested clean Cron Removal
            sudo crontab -l | grep -v 'php /var/www/jexactyl/artisan schedule:run' | sudo crontab - || true

            rm -rf /var/www/jexactyl

            echo ">> Removal Complete — server saaf, hawa me naya sukoon. 🧹🌙"
            ;;

        3)
            echo ">> Updating Jexactyl Panel..."
            cd /var/www/jexactyl
            php artisan down

            curl -Lo panel.tar.gz https://github.com/jexactyl/jexactyl/releases/download/v4.0.0-rc2/panel.tar.gz
            tar -xzvf panel.tar.gz
            chmod -R 755 storage/* bootstrap/cache/
            composer install --no-dev --optimize-autoloader
            php artisan optimize:clear
            php artisan migrate --seed --force
            chown -R www-data:www-data /var/www/jexactyl/
            php artisan up

            echo ">> Update complete — like a phoenix reborn. 🔥🚀"
            ;;

        4)
            echo "Shubh ratri — server chup, console khamosh. 🌑"
            exit 0
            ;;

        *)
            echo "Wrong option — 1 se 4 ke beech ghoomo mere bhai."
            ;;
    esac

    echo
    read -p "Press Enter to return to menu..."
done
