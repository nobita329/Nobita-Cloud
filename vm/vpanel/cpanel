#!/bin/bash
set -e

# ====================== Colors & UI ======================
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; W="\e[0m"
BOLD="\e[1m"; BRIGHT_C="\e[96m"; GEAR="⚙"; WARNING="⚠️"

# ====================== Detection Engine ======================
OS_NAME=$(grep -P '^ID=' /etc/os-release | cut -d'=' -f2 | sed 's/"//g')
OS_VER=$(grep -P '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | sed 's/"//g')

check_compat() {
    # cPanel Compatibility Logic
    case "$OS_NAME" in
        almalinux|rocky|cloudlinux)
            if [[ "$OS_VER" =~ ^(8|9) ]]; then echo -e "${G}COMPATIBLE (v$OS_VER)${W}"; else echo -e "${R}UNSUPPORTED v$OS_VER${W}"; fi
            ;;
        ubuntu)
            if [[ "$OS_VER" == "20.04" || "$OS_VER" == "22.04" ]]; then echo -e "${G}COMPATIBLE (v$OS_VER)${W}"; else echo -e "${R}UNSUPPORTED v$OS_VER${W}"; fi
            ;;
        *)
            echo -e "${R}INCOMPATIBLE OS ($OS_NAME)${W}"
            ;;
    esac
}

get_ip() { hostname -I | awk '{print $1}'; }
st_cpanel() { [ -d "/usr/local/cpanel" ] && echo -e "${G}INSTALLED${W}" || echo -e "${R}NOT DETECTED${W}"; }

# ====================== The UI ======================
draw_ui() {
    clear
    echo -e "${BRIGHT_C}${BOLD}╭──────────────────────────────────────────────────────────╮"
    echo -e "│            cPANEL AUTOMATIC DEPLOYMENT SYSTEM            │"
    echo -e "╰──────────────────────────────────────────────────────────╯${W}"
    
    echo -e "  ${BOLD}DETECTION LOGIC:${W}"
    echo -e "  Detected OS : ${C}$OS_NAME $OS_VER${W}"
    echo -e "  Status      : $(check_compat)"
    echo -e "  cPanel      : $(st_cpanel)"
    echo -e "${BRIGHT_C}────────────────────────────────────────────────────────────${W}"
    
    echo -e "  ${G}1)${W} ${BOLD}Auto-Install cPanel/WHM${W}"
    echo -e "  ${C}2)${W} Show Access Information"
    echo -e "  ${Y}3)${W} View Real-time Install Logs"
    echo -e "  ${R}4)${W} Exit"
    echo ""
}

# ====================== Actions ======================
auto_install() {
    # Final check before firing
    if [[ $(check_compat) == *"INCOMPATIBLE"* || $(check_compat) == *"UNSUPPORTED"* ]]; then
        echo -e "${R}${WARNING} ERROR: cPanel cannot be installed on this OS version.${W}"
        echo -e "Please use AlmaLinux 8/9, Rocky 8/9, or Ubuntu 20/22 LTS."
        sleep 5
        return
    fi

    echo -e "${Y}${WARNING} FINAL WARNING: This script will take over the server.${W}"
    read -rp "👉 Type 'INSTALL' to begin: " confirm
    
    if [ "$confirm" == "INSTALL" ]; then
        echo -e "${G}${GEAR} Environment Validated. Fetching latest cPanel installer...${W}"
        cd /home && curl -o latest -L https://securedownloads.cpanel.net/latest && sh latest
    else
        echo -e "${R}Aborted.${W}"
        sleep 2
    fi
}

show_info() {
    clear
    local IP=$(get_ip)
    echo -e "${C}${BOLD}cPANEL ENDPOINTS${W}"
    echo -e "${C}──────────────────────────────────────────────────${W}"
    echo -e "  Admin WHM:  ${G}https://$IP:2087${W}"
    echo -e "  User Panel: ${G}https://$IP:2083${W}"
    echo -e "  Webmail:    ${G}https://$IP:2096${W}"
    echo -e "${C}──────────────────────────────────────────────────${W}"
    read -rp "Press Enter..."
}

# ====================== Controller ======================
while true; do
    draw_ui
    read -p "Select [1-4]: " opt
    case $opt in
        1) auto_install ;;
        2) show_info ;;
        3) [ -f "/var/log/cpanel-install.log" ] && tail -f /var/log/cpanel-install.log || echo "No logs."; sleep 2 ;;
        4) clear; exit 0 ;;
        *) echo -e "${R}Invalid${W}"; sleep 1 ;;
    esac
done
