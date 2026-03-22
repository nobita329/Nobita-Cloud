#!/bin/bash

# ====================================================
#       PTERODACTYL CONTROL CENTER v2.1
# ====================================================

# --- COLORS & STYLING ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m'

# --- UI HELPER FUNCTIONS ---

show_header() {
    clear
    echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}║${NC}         ${BOLD}${WHITE}PTERODACTYL SERVER MANAGEMENT SYSTEM${NC}             ${PURPLE}║${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Current Module: ${YELLOW}$1${NC}"
    echo -e "${PURPLE}────────────────────────────────────────────────────────────${NC}"
    echo ""
}

status_msg() {
    # $1 = Type (OK, ERR, INFO, WAIT), $2 = Message
    case $1 in
        "OK")   echo -e "  [${GREEN} ✔ ${NC}] $2" ;;
        "ERR")  echo -e "  [${RED} ✘ ${NC}] $2" ;;
        "INFO") echo -e "  [${CYAN} ➜ ${NC}] $2" ;;
        "WAIT") echo -e "  [${YELLOW} ⏳ ${NC}] $2" ;;
    esac
}

pause() {
    echo ""
    read -p "  Press [Enter] to return to main menu..."
}

# ================== INSTALL FUNCTION ==================
install_ptero() {
    show_header "PANEL INSTALLATION"
    
    status_msg "INFO" "Initiating installation script..."
    sleep 1
    
    # Run the external script
    bash <(curl -s https://raw.githubusercontent.com/nobita329/hub/refs/heads/main/Codinghub/panel/pterodactyl/install.sh)
    
    echo ""
    status_msg "OK" "Installation Sequence Complete."
    pause
}

# ================== CREATE USER ==================
create_user() {
    show_header "USER MANAGEMENT"

    if [ ! -d /var/www/pterodactyl ]; then
        status_msg "ERR" "Panel directory not found (/var/www/pterodactyl)."
        status_msg "ERR" "Please install the panel first."
        pause
        return
    fi

    status_msg "WAIT" "Launching Artisan User Maker..."
    echo ""
    cd /var/www/pterodactyl || exit
    php artisan p:user:make

    echo ""
    status_msg "OK" "User created successfully."
    pause
}

# ================= PANEL UNINSTALL =================
uninstall_logic() {
    status_msg "WAIT" "Stopping Panel services..."
    systemctl stop pteroq.service 2>/dev/null || true
    systemctl disable pteroq.service 2>/dev/null || true
    rm -f /etc/systemd/system/pteroq.service
    systemctl daemon-reload

    status_msg "WAIT" "Removing cronjobs..."
    crontab -l | grep -v 'php /var/www/pterodactyl/artisan schedule:run' | crontab - || true

    status_msg "WAIT" "Deleting panel files..."
    rm -rf /var/www/pterodactyl

    status_msg "WAIT" "Dropping database and users..."
    mysql -u root -e "DROP DATABASE IF EXISTS panel;"
    mysql -u root -e "DROP USER IF EXISTS 'pterodactyl'@'127.0.0.1';"
    mysql -u root -e "FLUSH PRIVILEGES;"

    status_msg "WAIT" "Cleaning Nginx configs..."
    rm -f /etc/nginx/sites-enabled/pterodactyl.conf
    rm -f /etc/nginx/sites-available/pterodactyl.conf
    systemctl reload nginx || true
}

uninstall_ptero() {
    show_header "UNINSTALLATION"
    
    echo -e "${RED}  WARNING: This will delete all panel data and databases!${NC}"
    read -p "  Are you sure you want to proceed? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        status_msg "INFO" "Uninstallation cancelled."
        pause
        return
    fi

    echo ""
    uninstall_logic
    
    echo ""
    status_msg "OK" "Panel removed successfully (Wings untouched)."
    pause
}

# ================= UPDATE FUNCTION =================
update_panel() {
    show_header "SYSTEM UPDATE"

    if [ ! -d /var/www/pterodactyl ]; then
        status_msg "ERR" "Panel not found in /var/www/pterodactyl"
        pause
        return
    fi

    status_msg "INFO" "Putting panel into Maintenance Mode..."
    cd /var/www/pterodactyl
    php artisan down
    sudo rm -rf /var/www/pterodactyl/*
    cd /var/www/pterodactyl
    status_msg "INFO" "Downloading latest release..."
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    status_msg "INFO" "Setting permissions..."
    chmod -R 755 storage/* bootstrap/cache/

    status_msg "INFO" "Updating Composer dependencies..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    
    status_msg "INFO" "Clearing cache and database migration..."
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --seed --force
    chown -R www-data:www-data /var/www/pterodactyl/*
    
    status_msg "INFO" "Restarting Queue Workers..."
    php artisan queue:restart
    php artisan up

    echo ""
    status_msg "OK" "Panel Updated Successfully."
    pause
}

# ===================== MAIN MENU =====================
while true; do
    clear
    
    # Banner
    echo -e "${PURPLE}  ____  _                     _            _         _ ${NC}"
    echo -e "${PURPLE} |  _ \| |_ ___ _ __ ___   __| | __ _  ___| |_ _   _| |${NC}"
    echo -e "${PURPLE} | |_) | __/ _ \ '__/ _ \ / _\` |/ _\` |/ __| __| | | | |${NC}"
    echo -e "${PURPLE} |  __/| ||  __/ | | (_) | (_| | (_| | (__| |_| |_| | |${NC}"
    echo -e "${PURPLE} |_|    \__\___|_|  \___/ \__,_|\__,_|\___|\__|\__, |_|${NC}"
    echo -e "${PURPLE}                                               |___/   ${NC}"
    echo -e ""
    
    echo -e "${CYAN} ┌───────────────────────────────────────────────────────┐${NC}"

    # --- CHECK INSTALL STATUS ---
    if [ -d "/var/www/pterodactyl" ]; then
        # Green "INSTALLED" message
        echo -e "${CYAN} │${NC} ${BOLD}${WHITE}PANEL STATUS:${NC} ${GREEN}INSTALLED ✔${NC}                                 ${CYAN}│${NC}"
    else
        # Red "NOT INSTALLED" message
        echo -e "${CYAN} │${NC} ${BOLD}${WHITE}PANEL STATUS:${NC} ${RED}NOT INSTALLED ✘${NC}                             ${CYAN}│${NC}"
    fi

    echo -e "${CYAN} ├───────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN} │${NC}                                                       ${CYAN}│${NC}"
    echo -e "${CYAN} │${NC}  ${GREEN}[1]${NC} Install       ${GRAY}:: (Fresh Install)${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN} │${NC}  ${GREEN}[2]${NC} User          ${GRAY}:: (Add Admin/User)${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN} │${NC}  ${YELLOW}[3]${NC} Update       ${GRAY}:: (Latest Release)${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN} │${NC}  ${RED}[4]${NC} Domin           ${GRAY}:: (Chang/domin/ssl)${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN} │${NC}  ${RED}[5]${NC} Uninstall       ${GRAY}:: (Remove Data)${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN} │${NC}                                                       ${CYAN}│${NC}"
    echo -e "${CYAN} │${NC}  ${WHITE}[6] Exit System${NC}                                   ${CYAN}│${NC}"
    echo -e "${CYAN} └───────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -ne "${BOLD}${WHITE}  root@ptero:~# ${NC}"
    read choice

    case $choice in
        1) install_ptero ;;
        2) create_user ;;
        3) update_panel ;;
        4) bash <(curl -fsSL https://raw.githubusercontent.com/nobita329/ptero/refs/heads/main/ptero/panel/pterodactyl/ssl.sh) ;;
        5) uninstall_ptero ;;
        6) clear; exit ;;
        *) echo -e "${RED}  Invalid option selected...${NC}"; sleep 1 ;;
    esac
done
