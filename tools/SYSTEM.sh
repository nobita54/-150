#!/bin/bash

# =============== COLORS ===============
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; N="\e[0m"

# =============== HELPERS ===============
pause() {
    echo
    read -p "↩ Press Enter to return to menu..." _
}

# =============== SPEEDTEST ===============
speedtest_run() {
    clear
    echo -e "${Y}🚀 INTERNET SPEEDTEST${N}"
    if ! command -v speedtest-cli &>/dev/null; then
        echo -e "${R}speedtest-cli missing → installing...${N}"
        sudo apt update -y && sudo apt install -y speedtest-cli
    fi
    speedtest-cli --simple
    pause
}

# =============== LOG VIEWER ===============
logs_view() {
    clear
    echo -e "${C}📜 System Logs (last 50 lines)${N}"
    journalctl -n 50 --no-pager | sed 's/^/   /'
    pause
}

# =============== TEMPERATURE MONITOR ===============
temp_monitor() {
    clear
    echo -e "${Y}🌡 TEMPERATURE MONITOR${N}"
    if ! command -v sensors &>/dev/null; then
        echo -e "${G}Installing lm-sensors...${N}"
        sudo apt update -y && sudo apt install -y lm-sensors
        sudo sensors-detect --auto
    fi
    echo -e "${C}Live temperatures (refresh 1s) — CTRL+C to exit${N}"
    sleep 1
    watch -n 1 sensors
}

# =============== DDOS / ABUSE CHECK ===============
ddos_check() {
    clear
    while true; do
        clear
        echo -e "${R}⚠ LIVE ATTACK / CONNECTION WATCH${N}"
        echo
        echo -e "${C}Top IPs by connection count:${N}"
        ss -tuna | awk 'NR>1{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head
        echo
        echo -e "${Y}CPU Load:${N} $(uptime | awk -F'load average:' '{print $2}')"
        echo -e "\n⏳ Refreshing every 2s...   CTRL+C to exit"
        sleep 2
    done
}

# =============== BTOP-LIKE DRAW BAR ===============
draw_bar() {
    local used=$1
    local total=$2
    (( total == 0 )) && total=1
    local p=$(( used * 100 / total ))
    local filled=$(( p / 2 ))
    local empty=$(( 50 - filled ))
    printf "${G}%3s%% ${R}[" "$p"
    printf "${Y}%0.s█" $(seq 1 $filled)
    printf "%0.s░" $(seq 1 $empty)
    printf "${R}]${N}"
}

# =============== BTOP-LIKE LIVE DASHBOARD ===============
btop_live() {
    while true; do
        clear
        echo -e "${C}══════════  VPS BTOP LIVE MONITOR  ══════════${N}"

        # CPU per core (requires mpstat from sysstat)
        if command -v mpstat >/dev/null 2>&1; then
            echo -e "${Y}CPU Per-Core Usage:${N}"
            mpstat -P ALL 1 1 | awk '/Average/ && $2 ~ /[0-9]/ {printf "Core %-2s : %3s%%\n",$2,100-$12}'
        else
            echo -e "${R}mpstat not installed.${N} Install: ${Y}sudo apt install sysstat -y${N}"
        fi

        # RAM
        mem_used=$(free -m | awk '/Mem/ {print $3}')
        mem_total=$(free -m | awk '/Mem/ {print $2}')
        echo -e "\n${Y}RAM:${N}"
        draw_bar "$mem_used" "$mem_total"
        echo -e "  (${mem_used}MB / ${mem_total}MB)"

        # DISK (/)
        disk_used=$(df / | awk 'NR==2 {print $3}')
        disk_total=$(df / | awk 'NR==2 {print $2}')
        echo -e "\n${Y}DISK (/):${N}"
        draw_bar "$disk_used" "$disk_total"
        echo -e "  (${disk_used}MB / ${disk_total}MB)"

        # TOP PROCESSES
        echo -e "\n${B}🔥 Top CPU Processes:${N}"
        ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -10

        # NETWORK SPEED
        rx1=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | paste -sd+)
        tx1=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | paste -sd+)
        sleep 1
        rx2=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | paste -sd+)
        tx2=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | paste -sd+)

        rx_kb=$(( (rx2 - rx1) / 1024 ))
        tx_kb=$(( (tx2 - tx1) / 1024 ))
        echo -e "\n${G}NET:${N} ⬇ ${rx_kb} KB/s   ⬆ ${tx_kb} KB/s"

        echo -e "\n${C}Press CTRL+C to exit BTOP mode...${N}"
    done
}

# =============== MAIN MENU (OLD UI) ===============
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
 ${R}║ 4) Fake Check ║    ${C}║ 5) Live Traffic║    ${Y}║ 6) BTOP Mode  ║
 ${R}╚═══════════════╝    ${C}╚════════════════╝    ${Y}╚═══════════════╝

 ${B}╔═══════════════╗    ${G}╔════════════════╗    ${R}╔═══════════════╗
 ${B}║ 7) SpeedTest  ║    ${G}║ 8) Logs Viewer ║    ${R}║ 9) Temp Monitor║
 ${B}╚═══════════════╝    ${G}╚════════════════╝    ${R}╚═══════════════╝

                    ${Y}╔═════════════════════╗
                    ${Y}║10) DDOS/Abuse Check ║
                    ${Y}╚═════════════════════╝

                     ${R}╔══════════════╗
                     ${R}║ 11) Exit     ║
                     ${R}╚══════════════╝${N}
"

    read -p "Option → " x

    case "$x" in
        1)
            clear
            echo -e "${G}📌 SYSTEM INFO${N}"
            hostnamectl
            pause
            ;;
        2)
            clear
            echo -e "${Y}🧠 RAM:${N}"
            free -h
            echo
            echo -e "${Y}💽 DISK:${N}"
            df -h
            pause
            ;;
        3)
            clear
            echo -e "${C}🌐 NETWORK INFO${N}"
            ip a
            pause
            ;;
        4)
            clear
            echo -e "${R}🕵 VPS FAKE / REAL CHECK${N}"
            echo -e "${Y}Virtualization:${N}"
            systemd-detect-virt
            echo
            echo -e "${Y}CPU VMX/SVM Flags:${N}"
            if grep -E -o "vmx|svm" /proc/cpuinfo >/dev/null; then
                echo -e "${G}✔ Hardware virtualization flags present${N}"
            else
                echo -e "${R}❗ VMX/SVM NOT found — may be weak/fake VPS${N}"
            fi
            pause
            ;;
        5)
            clear
            echo -e "${C}📡 LIVE TRAFFIC (iftop)${N}"
            if command -v iftop >/dev/null 2>&1; then
                echo -e "${Y}Ctrl+C to exit, then Enter to return to menu.${N}"
                sleep 1
                iftop -n -P
            else
                echo -e "${R}iftop not installed.${N}"
                echo -e "Install with: ${Y}sudo apt install iftop -y${N}"
            fi
            pause
            ;;
        6)
            btop_live
            ;;
        7)
            speedtest_run
            ;;
        8)
            logs_view
            ;;
        9)
            temp_monitor
            ;;
        10)
            ddos_check
            ;;
        11)
            clear
            echo -e "${Y}Exiting VPS Analyzer Pro. Bye!${N}"
            exit 0
            ;;
        *)
            echo "Invalid option"; sleep 1 ;;
    esac
done
