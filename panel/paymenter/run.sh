#!/bin/bash

# ——————————————————————————————————————————————————
# PAYMENTER CONTROL PANEL - 2026 EDITION
# High-Contrast UI • Modular • Performance Optimized
# ——————————————————————————————————————————————————

# Color definitions (High Intensity & 256-bit)
NC='\033[0m'
BOLD='\033[1m'
BLACK='\033[0;30m'
RED='\033[38;5;196m'
GREEN='\033[38;5;82m'
YELLOW='\033[38;5;226m'
BLUE='\033[38;5;75m'
MAGENTA='\033[38;5;170m'
CYAN='\033[38;5;51m'
WHITE='\033[38;5;255m'
GRAY='\033[38;5;244m'

# UI Elements
SEP="${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
CHECK="${GREEN}✔${NC}"
INFO="${BLUE}ℹ${NC}"
WARN="${YELLOW}⚠${NC}"
ERR="${RED}✖${NC}"

show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}${WHITE}🚀 PAYMENTER CONTROL PANEL${NC}                     ${GRAY}v2.0${NC}  ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${GRAY}Managed by:${NC} ${MAGENTA}The Coding Hub${NC}      ${GRAY}Status:${NC} ${GREEN}System Online${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

show_menu() {
    echo -e "  ${BOLD}${WHITE}MAIN NAVIGATION${NC}"
    echo -e "  ${GRAY}Select an operation to continue:${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} ${WHITE}📥 Install ${NC}       ${GRAY}(New Instance)${NC}"
    echo -e "  ${CYAN}2.${NC} ${WHITE}🔄 Update ${NC}        ${GRAY}(Patch System)${NC}"
    echo -e "  ${CYAN}3.${NC} ${WHITE}🗑️ Uninstall${NC}      ${RED}(Destructive)${NC}"
    echo -e "  ${CYAN}4.${NC} ${WHITE}❌ Exit${NC}"
    echo ""
    echo -e "${SEP}"
}

install_paymenter() {
    echo -e "\n  ${BLUE}${BOLD}[ DEPLOYMENT STARTED ]${NC}"
    echo -e "  ${SEP}"
    echo -e "  ${INFO} Starting environment check..."
    echo -e "  ${INFO} Configuring ad-blocker filters..."
    echo -e "  ${INFO} Pulling latest Paymenter build..."
    echo ""
    
    # Run the Paymenter install script
    bash <(curl -s https://raw.githubusercontent.com/nobita329/hub/refs/heads/main/Codinghub/panel/paymenter/install.sh)
    
    echo -e "\n  ${CHECK} ${SUCCESS}Deployment sequence finished successfully."
    echo -e "  ${SEP}"
}

uninstall_paymenter() {
    echo -e "\n  ${RED}${BOLD}[ REMOVAL IN PROGRESS ]${NC}"
    echo -e "  ${SEP}"
    
    echo -en "  ${WARN} Cleaning files... "
    sudo rm -rf /var/www/paymenter && echo -e "${CHECK}"
    
    echo -en "  ${WARN} Dropping databases... "
    sudo mysql -u root -e "DROP DATABASE IF EXISTS paymenter; DROP USER IF EXISTS 'paymenteruser'@'127.0.0.1'; FLUSH PRIVILEGES;" 2>/dev/null && echo -e "${CHECK}"
    
    echo -en "  ${WARN} Clearing Cron & Services... "
    sudo crontab -l | grep -v 'artisan schedule:run' | sudo crontab - 2>/dev/null
    sudo rm -f /etc/systemd/system/paymenter.service && echo -e "${CHECK}"
    
    echo -en "  ${WARN} Removing Nginx Configs... "
    sudo rm -f /etc/nginx/sites-enabled/paymenter.conf /etc/nginx/sites-available/paymenter.conf
    sudo rm -rf /etc/nginx/adblock /etc/nginx/conf.d/adblock.conf
    sudo systemctl reload nginx || true
    echo -e "${CHECK}"
    
    echo -e "\n  ${CHECK} ${RED}System has been purged.${NC}"
    echo -e "  ${SEP}"
}

update_paymenter() {
    echo -e "\n  ${YELLOW}${BOLD}[ SYSTEM UPDATE ]${NC}"
    echo -e "  ${SEP}"
    
    if [ ! -d "/var/www/paymenter" ]; then
        echo -e "  ${ERR} ${RED}Error: Paymenter directory not found!${NC}"
        return
    fi
    
    echo -e "  ${INFO} Accessing /var/www/paymenter..."
    cd /var/www/paymenter
    echo -e "  ${INFO} Running artisan upgrade..."
    php artisan app:upgrade
    
    echo -e "\n  ${CHECK} ${GREEN}Update completed successfully.${NC}"
    echo -e "  ${SEP}"
}

# Main Loop Execution
while true; do
    show_header
    show_menu
    
    echo -en "  ${BOLD}${BLUE}➤ Option:${NC} "
    read option
    
    case $option in
        1) install_paymenter ;;
        2) update_paymenter ;;
        3) 
            echo -en "  ${RED}${BOLD}ARE YOU SURE? (y/n):${NC} "
            read confirm
            [[ "$confirm" == [yY] ]] && uninstall_paymenter || echo -e "  ${INFO} Cancelled."
            ;;
        4)
            echo -e "\n  ${BLUE}Connection closed. Goodbye!${NC}\n"
            exit 0
            ;;
        *)
            echo -e "  ${ERR} ${RED}Invalid selection. Try 1-4.${NC}"
            sleep 1
            continue
            ;;
    esac
    
    echo ""
    echo -en "  ${GRAY}Press [ENTER] to return to menu...${NC}"
    read
done
