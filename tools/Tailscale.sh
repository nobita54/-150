#!/bin/bash

while true; do
    clear
    echo "============================"
    echo "        Tailscale Menu      "
    echo "============================"
    echo "1) Install Tailscale"
    echo "2) Uninstall Tailscale"
    echo "3) Exit"
    echo "----------------------------"
    read -p "Choose Option [1-3] : " option

    case $option in

        1)
            echo "🔥 Installing Tailscale..."
            curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up
            echo "✔ Tailscale Installed & Connected!"
            ;;

        2)
            echo "⚠ Removing Tailscale completely..."
            sudo apt purge tailscale -y && sudo apt autoremove -y
            sudo systemctl stop tailscaled && sudo systemctl disable tailscaled \
            && sudo apt purge tailscale -y && sudo apt autoremove -y \
            && sudo rm -rf /var/lib/tailscale /etc/tailscale

            echo "🧹 Cleanup complete."
            echo "✔ Tailscale fully uninstalled from system!"
            ;;

        3)
            echo "Exit — script closed."
            exit 0
            ;;

        *)
            echo "Invalid Option — select 1 to 3."
            ;;
    esac

    echo
    read -p "Press Enter to return..."
done
