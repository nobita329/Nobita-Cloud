#!/bin/bash

# ==================================================
#  MACK CONTROL PANEL v3.0 | Auto-Detect System
# ==================================================

# --- COLORS & STYLES ---
R="\e[31m"
G="\e[32m"
Y="\e[33m"
B="\e[34m"
M="\e[35m"
C="\e[36m"
W="\e[97m"
GR="\e[90m"
N="\e[0m"
BOLD="\e[1m"

# --- SYSTEM AUTO-DETECT VARIABLES ---
detect_system() {
    # 1. OS Detection
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$PRETTY_NAME
    else
        OS_NAME=$(uname -s)
    fi

    # 2. IP Detection (Fast with timeout)
    PUBLIC_IP=$(curl -s --max-time 2 https://ipinfo.io/ip || echo "Unknown")
    LOCAL_IP=$(hostname -I | awk '{print $1}')

    # 3. RAM Usage
    if command -v free >/dev/null 2>&1; then
        RAM_USED=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
    else
        RAM_USED="N/A"
    fi
}

# --- UI DRAWING FUNCTIONS ---

draw_line() {
    echo -e "${B}╠════════════════════════════════════════════════════════════╣${N}"
}

draw_top() {
    echo -e "${B}╔════════════════════════════════════════════════════════════╗${N}"
}

draw_bottom() {
    echo -e "${B}╚════════════════════════════════════════════════════════════╝${N}"
}

# --- NEW HEADER UI ---
header() {
    clear
    # Top Border
    echo -e "${B} ╔════════════════════════════════════════════════════════════╗${N}"
    
    # Title Section
    echo -e "${B} ║${W}${BOLD}   ⚡ MACK CONTROL PANEL v3.5 ${GR}::${C} SERVER AUTOMATION      ${B}║${N}"
    
    # Separator
    echo -e "${B} ╠════════════════════════════════════════════════════════════╣${N}"
    
    # Stats Dashboard (Formatted with printf for perfect alignment)
    # Row 1: OS and Public IP
    printf "${B} ║${GR}  OS   :${W} %-23s ${GR}WAN:${W} %-15s ${B}║${N}\n" "${OS_NAME:0:20}" "${PUBLIC_IP}"
    
    # Row 2: RAM and Local IP
    printf "${B} ║${GR}  RAM  :${W} %-23s ${GR}LAN:${W} %-15s ${B}║${N}\n" "${RAM_USED}" "${LOCAL_IP}"
    
    # Bottom Border
    echo -e "${B} ╚════════════════════════════════════════════════════════════╝${N}"
    echo ""
}

# --- NEW MENU UI ---
show_menu() {
    echo -e "${W}  AVAILABLE MODULES:${N}"
    echo -e "${GR}  ──────────────────────────────────────────────────────────${N}"
    
    # Menu Items
    echo -e "  ${B}[1]${N} ${C}SSL Configuration    ${GR}:: (Certbot/Nginx)${N}"
    echo -e "  ${B}[2]${N} ${G}Install Wings        ${GR}:: (Nobita Script)${N}"
    echo -e "  ${B}[3]${N} ${Y}Auto-Setup           ${GR}:: (One-Click)${N}"
    echo -e "  ${B}[4]${N} ${Y}Manager              ${GR}:: (Wings Manager)${N}"
    echo -e "  ${B}[5]${N} ${M}Database Manager     ${GR}:: (MySQL/MariaDB)${N}"
    echo -e "  ${B}[6]${N} ${R}Uninstall            ${GR}:: (Remove Wings)${N}"
    
    echo -e "${GR}  ──────────────────────────────────────────────────────────${N}"
    echo -e "  ${B}[0]${N} ${W}Exit System${N}"
    echo ""
}

# --- ACTIONS ---

ssl_setup() {
    header
    echo -e "${C}┌─[ ${W}SSL CONFIGURATION ${C}]${N}"
    
    # Auto-fill domain if possible or ask
    echo -e "${C}│${N} Auto-detected IP: ${G}$PUBLIC_IP${N}"
    echo -ne "${C}└─╼ ${W}Enter Domain (e.g., Node.host.com): ${N}"
    read DOMAIN

    if [[ -z "$DOMAIN" ]]; then
        echo -e "\n${R}✖ Setup aborted.${N}"
        sleep 1
        return
    fi

    echo -e "\n${Y}➜ Installing Dependencies...${N}"
    apt update -y >/dev/null 2>&1
    apt install -y certbot python3-certbot-nginx > /dev/null 2>&1
    

    echo -e "${Y}➜ Requesting Certificate for ${W}$DOMAIN${Y}...${N}"
    rm -rf /etc/letsencrypt/live/$DOMAIN
    rm -rf /etc/letsencrypt/archive/$DOMAIN
    rm -rf /etc/letsencrypt/renewal/$DOMAIN.conf
    certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "ssl$(tr -dc a-z0-9 </dev/urandom | head -c6)@$DOMAIN"
    
    echo -e "\n${G}✔ SSL Setup Complete.${N}"
    read -p "Press Enter to return..."
}

uninstall_menu() {
    clear
    echo -e "${R}╔════════════════════════════════════════════════════════════╗${N}"
    echo -e "${R}║              ⚠️  DANGER ZONE: UNINSTALL                   ║${N}"
    echo -e "${R}╚════════════════════════════════════════════════════════════╝${N}"
    echo -e "${W} This will remove Wings, Docker, and Configs.${N}"
    echo -e "${W} Panel files will remain safe.${N}\n"
    
    echo -ne "${R}Are you sure? [y/N]: ${N}"
    read CONFIRM
    [[ "$CONFIRM" != "y" ]] && return

    echo -e "\n${Y}➜ Stopping Wings...${N}"
    systemctl disable --now wings 2>/dev/null
    rm -f /etc/systemd/system/wings.service
    rm -rf /etc/pterodactyl /var/lib/pterodactyl /usr/local/bin/wings
    systemctl disable --now wings 2>/dev/null
    rm -f /etc/systemd/system/wings.service
    rm -rf /etc/pterodactyl
    rm -f /usr/local/bin/wings
    rm -rf /var/lib/pterodactyl
    
    echo -e "${Y}➜ Pruning Docker...${N}"
    docker system prune -a -f 2>/dev/null

    echo -ne "\n${C}Delete Database? [y/N]: ${N}"
    read DEL_DB
    if [[ "$DEL_DB" == "y" ]]; then
        echo -ne "${W}DB Name: ${N}"; read DBN
        echo -ne "${W}DB User: ${N}"; read DBU
        mysql -e "DROP DATABASE IF EXISTS $DBN; DROP USER IF EXISTS '$DBU'@'127.0.0.1';" 2>/dev/null
        echo -e "${G}✔ Database cleared.${N}"
    fi

    echo -e "\n${G}✔ Uninstallation Finished.${N}"
    sleep 2
}

# --- MAIN LOOP ---

# 1. Detect System Info ONCE at startup
echo -e "${C}Please wait, detecting system info...${N}"
detect_system

while true; do
    header
    show_menu
    
    echo -ne "${C}root@mack-panel:~# ${N}"
    read opt
    
    case $opt in
        1) ssl_setup ;;
        2) bash <(curl -fsSL https://raw.githubusercontent.com/nobita329/ptero/refs/heads/main/ptero/wings/install.sh) ;;
        3) bash <(curl -fsSL https://raw.githubusercontent.com/nobita329/ptero/refs/heads/main/ptero/wings/setup.sh) ;;
        4) bash <(curl -fsSL https://raw.githubusercontent.com/nobita329/Nobita-Cloud/refs/heads/main/wings/mang.sh) ;;
        5) bash <(curl -fsSL https://raw.githubusercontent.com/nobita329/ptero/refs/heads/main/ptero/wings/db.sh) ;;
        6) uninstall_menu ;;
        0) 
           echo -e "\n${G}👋 Goodbye!${N}"
           exit 0 
           ;;
        *) 
           echo -e "${R}Invalid Option.${N}"
           sleep 1 
           ;;
    esac
done
