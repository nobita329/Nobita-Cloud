#!/bin/bash

# ==================================================
#  AUTO DATABASE SETUP | NEON TREE EDITION
# ==================================================

# --- COLORS & STYLES ---
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[1;34m'
C_PURPLE='\033[1;35m'
C_CYAN='\033[1;36m'
C_WHITE='\033[1;37m'
C_GRAY='\033[1;90m'

# --- UI HELPERS ---

# New Header Style
draw_header() {
    clear
    local host=$(hostname)
    local ip=$(hostname -I | awk '{print $1}')
    
    # Check DB Service Status
    local status="${C_RED}${C_BOLD}✖ OFFLINE${C_RESET}"
    if systemctl is-active --quiet mariadb || systemctl is-active --quiet mysql; then
        status="${C_GREEN}${C_BOLD}● ONLINE${C_RESET}"
    fi

    echo -e "${C_PURPLE}${C_BOLD} ⚡ ${C_WHITE}DATABASE AUTO-SETUP ${C_GRAY}:: ${C_CYAN}v2.0${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD} ├──${C_RESET} ${C_BLUE}${C_BOLD}SYSTEM INFO${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD} │   ├─${C_RESET} ${C_GRAY}Host :${C_RESET} ${C_WHITE}${C_BOLD}$host${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD} │   └─${C_RESET} ${C_GRAY}IP   :${C_RESET} ${C_WHITE}${C_BOLD}$ip${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD} ├──${C_RESET} ${C_BLUE}${C_BOLD}SERVICE STATUS${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD} │   └─${C_RESET} ${C_GRAY}SQL  :${C_RESET} $status"
    echo -e "${C_PURPLE}${C_BOLD} └──────────────────────────────────────────${C_RESET}"
    echo ""
}

# Spinner Animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

msg_step() { echo -e "${C_PURPLE} ├──${C_RESET} ${C_BOLD}${C_WHITE}$1${C_RESET}"; }
msg_sub()  { echo -e "${C_PURPLE} │   ├─${C_RESET} ${C_GRAY}$1${C_RESET}"; }
msg_ok()   { echo -e "${C_PURPLE} │   └─${C_RESET} ${C_GREEN}✔ $1${C_RESET}"; }
msg_err()  { echo -e "${C_PURPLE} │   └─${C_RESET} ${C_RED}✖ $1${C_RESET}"; }

get_input() {
    # $1 = Prompt, $2 = Default, $3 = VarRef
    echo -ne "${C_PURPLE} │   ├─${C_RESET} ${C_CYAN}$1${C_RESET} ${C_GRAY}[$2]${C_RESET}: "
    read input
    if [ -z "$input" ]; then
        eval $3="'$2'"
    else
        eval $3="'$input'"
    fi
}

# --- START SCRIPT ---
draw_header

# 1. Configuration Section
msg_step "CONFIGURATION"
get_input " Username" "root" DB_USER
get_input " Password" "root" DB_PASS
msg_ok "Credentials Saved"
echo ""

# 2. Installation Check
msg_step "SYSTEM REQUIREMENTS"
if ! command -v mysql >/dev/null 2>&1; then
    echo -ne "${C_PURPLE} │   ├─${C_RESET} ${C_YELLOW}Installing MariaDB Server...${C_RESET}"
    
    # Run install silently
    (apt update -y && apt install mariadb-server mariadb-client -y) >/dev/null 2>&1 &
    spinner $!
    
    echo -e "\r${C_PURPLE} │   ├─${C_RESET} ${C_GREEN}Installation Complete.      ${C_RESET}"
    systemctl enable mariadb >/dev/null 2>&1
    systemctl start mariadb >/dev/null 2>&1
    msg_ok "Service Started"
else
    msg_ok "MariaDB is already installed."
fi
echo ""

# 3. Database Operations
msg_step "DATABASE OPERATIONS"
msg_sub "Configuring Users & Privileges..."

# Run SQL logic
sudo mysql <<MYSQL_SCRIPT >/dev/null 2>&1
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

if [ $? -eq 0 ]; then
    msg_ok "User '${C_WHITE}$DB_USER${C_GREEN}' Configured Successfully."
else
    msg_err "Failed to configure database user."
fi
echo ""

# 4. Remote Access Logic
msg_step "NETWORK CONFIGURATION"

CONF_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"

if [ -f "$CONF_FILE" ]; then
    sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' "$CONF_FILE"
    msg_ok "Remote Access Enabled (0.0.0.0)"
else
    msg_sub "Config file not found. Skipping bind-address."
fi

# Restart Services
echo -ne "${C_PURPLE} │   ├─${C_RESET} ${C_YELLOW}Restarting Services...${C_RESET}"
systemctl restart mysql 2>/dev/null
systemctl restart mariadb 2>/dev/null
echo -e "\r${C_PURPLE} │   ├─${C_RESET} ${C_GREEN}Services Restarted.   ${C_RESET}"

# Firewall
if command -v ufw &>/dev/null; then
    ufw allow 3306/tcp >/dev/null 2>&1
    msg_ok "Firewall Port 3306 Opened"
else
    msg_sub "UFW Not Detected (Skipping Firewall)"
fi
echo ""

# 5. Final Summary
echo -e "${C_PURPLE}${C_BOLD} ⚡ ${C_WHITE}INSTALLATION COMPLETE${C_RESET}"
echo -e "${C_GRAY} ──────────────────────────────────────────${C_RESET}"
echo -e " ${C_GRAY}●${C_RESET} User      : ${C_WHITE}${C_BOLD}$DB_USER${C_RESET}"
echo -e " ${C_GRAY}●${C_RESET} Password  : ${C_WHITE}${C_BOLD}$DB_PASS${C_RESET}"
echo -e " ${C_GRAY}●${C_RESET} Remote IP : ${C_WHITE}${C_BOLD}0.0.0.0${C_RESET} ${C_GRAY}(Any)${C_RESET}"
echo -e " ${C_GRAY}●${C_RESET} Port      : ${C_WHITE}${C_BOLD}3306${C_RESET}"
echo -e "${C_GRAY} ──────────────────────────────────────────${C_RESET}"
echo ""
