#!/bin/bash

# ===== COLORS =====
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; W="\e[37m"; U="\e[4m"; N="\e[0m"

while true; do
clear
echo -e "${C}"
echo "╔════════════════════════════════════════════════╗"
echo "║                VPS ANALYZER PRO UI              ║"
echo "╚════════════════════════════════════════════════╝${N}"

echo -e "
 ${G}╔═══════════════╗    ${Y}╔═══════════════╗    ${B}╔═══════════════╗
 ${G}║ 1) System Info║    ${Y}║ 2) Disk+RAM   ║    ${B}║ 3) Network     ║
 ${G}╚═══════════════╝    ${Y}╚═══════════════╝    ${B}╚═══════════════╝

 ${R}╔═══════════════╗    ${C}╔════════════════╗    ${Y}╔═══════════════╗
 ${R}║ 4) Fake Check ║    ${C}║ 5) Live Traffic║    ${Y}║ 6) Exit       ║
 ${R}╚═══════════════╝    ${C}╚════════════════╝    ${Y}╚═══════════════╝
"

echo -ne "${W}Select Option → ${N}"
read op

case $op in

# 1) System Info
1)
clear; echo -e "${U}${G}📌 SYSTEM INFORMATION${N}\n"
echo "Hostname      : $(hostname)"
echo "OS            : $(lsb_release -d | awk -F':' '{print $2}')"
echo "Kernel        : $(uname -r)"
echo "Model         : $(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo)"
echo "Uptime        : $(uptime -p)"
echo ""; read -p "↩ Back to Menu..." ;;
  
# 2) Disk + RAM
2)
clear; echo -e "${U}${C}💽 RAM & DISK STATUS${N}\n"
free -h | awk 'NR==1{print "Type   Total   Used   Free"} NR==2{printf "RAM    %-7s %-7s %-7s\n",$2,$3,$4} NR==3{printf "SWAP   %-7s %-7s %-7s\n",$2,$3,$4}'
echo ""; df -h --output=source,size,used,avail,pcent | column -t
echo ""; read -p "↩ Back to Menu..." ;;

# 3) Network
3)
clear; echo -e "${U}${Y}🌐 NETWORK REPORT${N}\n"
echo "Local IP   : $(hostname -I | awk '{print $1}')"
echo "Public IP  : $(curl -s ifconfig.me)"
echo "Gateway    : $(ip route | awk '/default/ {print $3}')"
echo ""; read -p "↩ Back to Menu..." ;;
  
# 4 Fake Real Check
4)
clear; echo -e "${U}${R}🕵 VPS AUTHENTICITY CHECK${N}\n"
virt=$(systemd-detect-virt)
echo "Virtualization → $virt"

grep -E -o 'vmx|svm' /proc/cpuinfo >/dev/null \
&& echo -e "${G}✔ REAL CPU Virtualization Found${N}" \
|| echo -e "${R}❗ CPU Flag Missing — Fake/Weak VPS Likely${N}"

speed=$(dd if=/dev/zero of=test.img bs=1M count=256 oflag=direct 2>&1 | grep -o '[0-9.]\+ MB/s')
rm -f test.img
echo -e "\nDisk Speed → $speed"
echo ""; read -p "↩ Back to Menu..." ;;
  
# 5 Live Traffic
5)
sudo apt install iftop -y
clear; echo -e "${U}${B}📡 LIVE TRAFFIC (Ctrl+C exit)${N}\n"
iftop -n -P || echo -e "${R}Install: sudo apt install iftop -y${N}"
read -p "↩ Back to Menu..." ;;

# Exit
6)
exit ;;
*) echo "Invalid Option"; sleep 1 ;;
esac
done
