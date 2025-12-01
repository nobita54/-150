#!/bin/bash

# ===== COLORS =====
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; CYAN="\e[36m"; RESET="\e[0m"

clear
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════╗"
echo "║         VPS REAL-TIME DIAGNOSTIC TOOL      ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${RESET}"


# ================= SYSTEM INFORMATION =================
echo -e "${YELLOW}🖥 SYSTEM INFORMATION${RESET}"
echo -e "${GREEN}Hostname       :${RESET} $(hostname)"
echo -e "${GREEN}OS Version     :${RESET} $(lsb_release -d 2>/dev/null | awk -F':' '{print $2}')"
echo -e "${GREEN}Kernel         :${RESET} $(uname -r)"
echo -e "${GREEN}Architecture   :${RESET} $(uname -m)"
echo -e "${GREEN}Uptime         :${RESET} $(uptime -p)"
echo ""


# ================= RAM / MEMORY =================
echo -e "${YELLOW}🧠 MEMORY STATUS${RESET}"
free -h | awk '
NR==1{print "Type    Total    Used    Free"}
NR==2{printf "RAM     %-7s %-7s %-7s\n",$2,$3,$4}
NR==3{printf "SWAP    %-7s %-7s %-7s\n",$2,$3,$4}'
echo ""


# ================= DISK USAGE =================
echo -e "${YELLOW}💽 DISK STATUS${RESET}"
df -h --output=source,size,used,avail,pcent | grep -E '/|Filesystem' | column -t
echo ""


# ================= NETWORK INFO =================
echo -e "${YELLOW}🌐 NETWORK DETAILS${RESET}"
echo -e "${GREEN}Local IP  :${RESET} $(hostname -I | awk '{print $1}')"
echo -e "${GREEN}Public IP :${RESET} $(curl -s ifconfig.me)"
echo -e "${GREEN}Gateway   :${RESET} $(ip route | awk '/default/ {print $3}')"
echo ""


# ================= VPS FAKE / REAL TEST =================
echo -e "${YELLOW}🕵 CHECKING IF VPS IS REAL OR FAKE${RESET}"
virt=$(systemd-detect-virt)

echo -e "${BLUE}Virtualization Detected: ${RESET}$virt"

if [[ "$virt" == "kvm" ]]; then
    echo -e "${GREEN}✔ REAL VPS — KVM Detected (Legit Performance)${RESET}"
elif [[ "$virt" == "qemu" ]]; then
    echo -e "${GREEN}✔ REAL VPS — QEMU Virtualization${RESET}"
elif [[ "$virt" == "openvz" ]]; then
    echo -e "${RED}❗ Possible FAKE VPS — OpenVZ Oversold Common${RESET}"
elif [[ "$virt" == "lxc" ]]; then
    echo -e "${RED}❗ Container VPS (Shared Kernel) Not Full VPS${RESET}"
else
    echo -e "${YELLOW}❓ Unknown — Could Be Bare Metal / Nested VM${RESET}"
fi


echo ""
echo -e "${YELLOW}🧪 CPU REALITY TEST${RESET}"
if grep -E -o 'vmx|svm' /proc/cpuinfo >/dev/null; then
    echo -e "${GREEN}✔ Hardware Virtualization Flag Present (Strong CPU Core)${RESET}"
else
    echo -e "${RED}❗ VMX/SVM Missing → CPU Virtual, Might Be Low Quality VPS${RESET}"
fi


echo ""
echo -e "${YELLOW}💽 DISK SPEED (REALITY CHECK — 512MB)${RESET}"
speed=$(dd if=/dev/zero of=test.img bs=1M count=512 oflag=direct 2>&1 | grep -o '[0-9.]\+ MB/s')
rm -f test.img
echo -e "${CYAN}Disk Speed:${RESET} ${speed}"
[[ $(echo "$speed < 200" | bc) -eq 1 ]] && echo -e "${RED}❗ Slow IO = VPS likely Fake/Oversold${RESET}" || echo -e "${GREEN}✔ IO Speed Good${RESET}"


# ================= LIVE NETWORK TRAFFIC =================
echo ""
echo -e "${YELLOW}📡 LIVE NETWORK TRAFFIC MONITOR${RESET}"
echo -e "${CYAN}Press CTRL + C to exit monitoring${RESET}"
sleep 2
iftop -n -P || echo -e "${RED}iftop missing → install with: sudo apt install iftop -y${RESET}"
