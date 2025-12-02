#!/bin/bash

# COLORS
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; N="\e[0m"

center() {
    local term_width=$(tput cols)
    local text="$1"
    local text_width=${#text}
    local padding=$(( (term_width - text_width) / 2 ))
    printf "%*s%s\n" "$padding" "" "$text"
}

while true; do
clear
echo ""
center "${C}╔════════════════════════════════════════════════╗${N}"
center "${C}║                DEVELOPMENT MENU                 ║${N}"
center "${C}╚════════════════════════════════════════════════╝${N}"
echo ""

center "${G}╔═══════════════════════╗${N}"
center "${G}║ 1) GitHub / VM        ║${N}"
center "${G}╚═══════════════════════╝${N}"
echo ""

center "${Y}╔═══════════════════════╗${N}"
center "${Y}║ 2) IDX Tool           ║${N}"
center "${Y}╚═══════════════════════╝${N}"
echo ""

center "${B}╔═══════════════════════╗${N}"
center "${B}║ 3) IDX VM             ║${N}"
center "${B}╚═══════════════════════╝${N}"
echo ""

center "${R}╔═══════════════════════╗${N}"
center "${R}║ 4) Exit               ║${N}"
center "${R}╚═══════════════════════╝${N}"
echo ""

read -p "Select Option → " op

case $op in

# =========================================================
# (1) VM Launcher
# =========================================================
1)
    clear
    echo -e "${G}⚙ Starting VM Using Docker + KVM...${N}"

RAM=15000
CPU=4
DISK_SIZE=100G
CONTAINER_NAME=hopingboyz
IMAGE_NAME=hopingboyz/debain12
VMDATA_DIR="$PWD/vmdata"

echo -e "${Y}Creating VM data directory...${N}"
mkdir -p "$VMDATA_DIR"

echo -e "${C}Launching VM Container with:${N}"
echo "RAM        = $RAM MB"
echo "CPU        = $CPU"
echo "DISK SIZE  = $DISK_SIZE"
echo "NAME       = $CONTAINER_NAME"
echo "IMAGE      = $IMAGE_NAME"
echo ""

docker run -it --rm \
  --name "$CONTAINER_NAME" \
  --device /dev/kvm \
  -v "$VMDATA_DIR":/vmdata \
  -e RAM="$RAM" \
  -e CPU="$CPU" \
  -e DISK_SIZE="$DISK_SIZE" \
  "$IMAGE_NAME"

read -p "↩ Press Enter to return..."
    ;;

# =========================================================
# (2) IDX TOOL
# =========================================================
2)
    clear
    echo -e "${Y}⚙ Running IDX Tool Setup...${N}"

    cd
    rm -rf myapp
    rm -rf flutter

    cd vps123

    if [ ! -d ".idx" ]; then
      mkdir .idx
      cd .idx

cat <<EOF > dev.nix
{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = with pkgs; [
    unzip
    openssh
    git
    qemu_kvm
    sudo
    cdrkit
    cloud-utils
    qemu
  ];

  env = {
    EDITOR = "nano";
  };

  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];

    workspace = {
      onCreate = { };
      onStart = { };
    };

    previews = {
      enable = false;
    };
  };
}
EOF

      echo -e "${G}✔ IDX Tool setup complete!${N}"
    else
      echo -e "${R}Directory .idx already exists — skipping.${N}"
    fi

    read -p "↩ Press Enter..."
    ;;

# =========================================================
# (3) IDX VM — FULLY ADDED
# =========================================================
3)
    clear
    echo -e "${B}⚙ Starting IDX VM From Your GitHub Script...${N}"
    echo ""
    echo -e "${C}Running: bash <(curl -s https://raw.githubusercontent.com/nobita54/-150/refs/heads/main/tools/vm.sh)${N}"
    echo ""

    bash <(curl -s https://raw.githubusercontent.com/nobita54/-150/refs/heads/main/tools/vm.sh)

    read -p "↩ Press Enter..."
    ;;

# =========================================================
# EXIT
# =========================================================
4)
    clear
    echo -e "${R}Exiting...${N}"
    exit 0
    ;;

*)
    echo -e "${R}Invalid Option!${N}"
    sleep 1
    ;;
esac
done
