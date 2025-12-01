#!/bin/bash

while true; do
    clear
    echo "============================"
    echo "        Paymenter Menu      "
    echo "============================"
    echo "1) Install (Empty)"
    echo "2) Uninstall Paymenter"
    echo "3) Update Paymenter"
    echo "4) Exit"
    echo "----------------------------"
    read -p "Choose Option [1-4] : " option

    case $option in

        1)
            echo "Install Selected — no commands added yet."
            bash <(curl -s https://raw.githubusercontent.com/nobita54/-150/refs/heads/main/panel/Payment.sh) 
            ;;

        2)
            echo "⚠ Uninstalling & Removing Paymenter completely..."

            sudo rm -rf /var/www/paymenter
            sudo mysql -u root -e "DROP DATABASE IF EXISTS paymenter;"
            sudo mysql -u root -e "DROP USER IF EXISTS 'paymenteruser'@'127.0.0.1';"
            sudo mysql -u root -e "FLUSH PRIVILEGES;"

            sudo crontab -l | grep -v 'php /var/www/paymenter/artisan schedule:run' | sudo crontab - || true

            sudo rm -f /etc/systemd/system/paymenter.service

            [ -f /etc/nginx/sites-enabled/paymenter.conf ] && sudo rm -f /etc/nginx/sites-enabled/paymenter.conf
            [ -f /etc/nginx/sites-available/paymenter.conf ] && sudo rm -f /etc/nginx/sites-available/paymenter.conf

            sudo systemctl reload nginx || true

            echo "✔ Paymenter completely removed from the system!"
            ;;

        3)
            echo "🔄 Updating Paymenter..."
            cd /var/www/paymenter
            php artisan app:upgrade
            echo "✔ Paymenter Updated Successfully!"
            ;;

        4)
            echo "Exit — script closed."
            exit 0
            ;;

        *)
            echo "Invalid Option — select 1 to 4."
            ;;
    esac

    echo
    read -p "Press Enter to return..."
done
