#!/bin/bash

while true; do
    clear
    echo "============================"
    echo "      MythicalDash Menu     "
    echo "============================"
    echo "1) Install (NO COMMAND)"
    echo "2) Update MythicalDash"
    echo "3) Uninstall MythicalDash"
    echo "4) Exit"
    echo "----------------------------"
    read -p "Select Option [1-4]: " option

    case $option in

        1)
            echo "Install Selected — but no commands exist here."
            ;;

        2)
            echo "🔄 Updating MythicalDash..."
            cd /var/www/mythicaldash
            curl -Lo MythicalDash.zip https://github.com/MythicalLTD/MythicalDash/releases/download/3.2.3/MythicalDash.zip
            unzip -o MythicalDash.zip -d /var/www/mythicaldash
            dos2unix arch.bash
            sudo bash arch.bash
            composer install --no-dev --optimize-autoloader
            ./MythicalDash -migrate
            chown -R www-data:www-data /var/www/mythicaldash/*

            echo "✔ Update Completed — MythicalDash refreshed. 🚀"
            ;;

        3)
            echo "⚠ Uninstalling MythicalDash... Database removal required login"
            mariadb -u root -p <<EOF
DROP DATABASE mythicaldash;
DROP USER 'mythicaldash'@'127.0.0.1';
EOF

            rm -rf /var/www/mythicaldash
            sudo crontab -l | grep -v 'php /var/www/mythicaldash/crons/server.php' | sudo crontab - || true

            rm /etc/nginx/sites-available/MythicalDash.conf
            rm /etc/nginx/sites-enabled/MythicalDash.conf
            systemctl restart nginx --now

            echo "✔ Uninstalled Successfully — files, cron, config all removed."
            ;;

        4)
            echo "Exiting — program closed."
            exit 0
            ;;

        *)
            echo "Invalid choice — select 1 to 4 only."
            ;;
    esac

    echo
    read -p "Press Enter to return to menu..."
done
