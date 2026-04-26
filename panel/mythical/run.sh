#!/bin/bash

# Colors for UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ASCII Art for MythicalDash
show_header() {
    clear
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}${CYAN}    __  __       _   _               _     _____   ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}${CYAN}   |  \/  |     | | | |             | |   |  __ \  ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}${CYAN}   | \  / |_   _| |_| |__   ___   __| |___| |  | | ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}${CYAN}   | |\/| | | | | __| '_ \ / _ \ / _\` / __| |  | | ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}${CYAN}   | |  | | |_| | |_| | | | (_) | (_| \__ \ |__| | ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}${CYAN}   |_|  |_|\__,_|\__|_| |_|\___/ \__,_|___/_____/  ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${MAGENTA}║${NC}${BOLD}            D A S H B O A R D   M A N A G E R        ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

while true; do
    show_header
    
    # Menu Options
    echo -e "${PURPLE}┌────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC} ${GREEN}🚀${NC} ${BOLD}1.${NC} Install                 ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC} ${YELLOW}🔄${NC} ${BOLD}2.${NC} Update                  ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC} ${RED}🗑️${NC} ${BOLD}3.${NC} Uninstall                ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC} ${BLUE}🚪${NC} ${BOLD}4.${NC} Exit                                 ${PURPLE}│${NC}"
    echo -e "${PURPLE}├────────────────────────────────────────────────┤${NC}"
    echo -e "${PURPLE}│${NC} ${CYAN}📊${NC} Version: 3.2.3 | By: MythicalLTD            ${PURPLE}│${NC}"
    echo -e "${PURPLE}└────────────────────────────────────────────────┘${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}🎯 Select option [1-4]:${NC} ")" option

    case $option in
        1)
            echo -e "\n${GREEN}══════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}           🚀 INSTALLATION STARTING                ${NC}"
            echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
            echo -e "${CYAN}Initializing MythicalDash installation...${NC}"
            echo -e "${YELLOW}This will set up the complete dashboard environment.${NC}"
            echo -e "${CYAN}Please wait while we download and configure...${NC}\n"
            
            echo -e "${BLUE}[1/4]${NC} ${CYAN}Downloading installer...${NC}"
            bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/panel/Dashboard-v3.sh)
            
            echo -e "\n${GREEN}✅ Installation process initiated!${NC}"
            echo -e "${CYAN}Follow the on-screen instructions to complete setup.${NC}"
            ;;
            
        2)
            echo -e "\n${YELLOW}══════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}           🔄 UPDATE IN PROGRESS                   ${NC}"
            echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
            
            # Check if MythicalDash is installed
            if [ ! -d "/var/www/mythicaldash" ]; then
                echo -e "${RED}❌ MythicalDash directory not found!${NC}"
                echo -e "${YELLOW}Please install MythicalDash first using option 1.${NC}"
                read -p "Press Enter to continue..."
                continue
            fi
            
            cd /var/www/mythicaldash
            
            echo -e "${BLUE}[1/6]${NC} ${CYAN}Downloading latest version...${NC}"
            curl -Lo MythicalDash.zip https://github.com/MythicalLTD/MythicalDash/releases/download/3.2.3/MythicalDash.zip
            
            echo -e "${BLUE}[2/6]${NC} ${CYAN}Extracting files...${NC}"
            unzip -o MythicalDash.zip -d /var/www/mythicaldash
            
            echo -e "${BLUE}[3/6]${NC} ${CYAN}Converting file formats...${NC}"
            dos2unix arch.bash
            
            echo -e "${BLUE}[4/6]${NC} ${CYAN}Running installation script...${NC}"
            sudo bash arch.bash
            
            echo -e "${BLUE}[5/6]${NC} ${CYAN}Installing dependencies...${NC}"
            composer install --no-dev --optimize-autoloader
            
            echo -e "${BLUE}[6/6]${NC} ${CYAN}Running migrations...${NC}"
            ./MythicalDash -migrate
            
            echo -e "${CYAN}Setting permissions...${NC}"
            chown -R www-data:www-data /var/www/mythicaldash/*
            
            echo -e "\n${GREEN}══════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}           ✅ UPDATE COMPLETED!                    ${NC}"
            echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
            echo -e "${CYAN}MythicalDash has been successfully updated to version 3.2.3!${NC}"
            echo -e "${GREEN}Dashboard is now running the latest version.${NC}"
            ;;
            
        3)
            echo -e "\n${RED}══════════════════════════════════════════════════${NC}"
            echo -e "${RED}           ⚠️  UNINSTALL WARNING!                  ${NC}"
            echo -e "${RED}══════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}This will completely remove MythicalDash from your system.${NC}"
            echo -e "${RED}All data including database will be permanently deleted!${NC}\n"
            
            read -p "$(echo -e "${RED}Are you absolutely sure? (y/N):${NC} ")" confirm
            
            if [[ $confirm == "y" || $confirm == "Y" ]]; then
                echo -e "\n${RED}🗑️  Starting uninstall process...${NC}"
                
                echo -e "${BLUE}[1/5]${NC} ${CYAN}Removing database...${NC}"
                mariadb -u root -p <<EOF
DROP DATABASE IF EXISTS mythicaldash;
DROP USER IF EXISTS 'mythicaldash'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
                
                echo -e "${BLUE}[2/5]${NC} ${CYAN}Removing files...${NC}"
                rm -rf /var/www/mythicaldash
                
                echo -e "${BLUE}[3/5]${NC} ${CYAN}Cleaning up cron jobs...${NC}"
                sudo crontab -l | grep -v 'php /var/www/mythicaldash/crons/server.php' | sudo crontab - || true
                
                echo -e "${BLUE}[4/5]${NC} ${CYAN}Removing nginx configuration...${NC}"
                rm /etc/nginx/sites-available/MythicalDash.conf 2>/dev/null
                rm /etc/nginx/sites-enabled/MythicalDash.conf 2>/dev/null
                
                echo -e "${BLUE}[5/5]${NC} ${CYAN}Restarting nginx...${NC}"
                systemctl restart nginx --now
                
                echo -e "\n${GREEN}══════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}           ✅ UNINSTALL COMPLETE!                  ${NC}"
                echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}MythicalDash has been completely removed from your system.${NC}"
                echo -e "${GREEN}All files, database entries, and configurations have been cleaned.${NC}"
            else
                echo -e "${YELLOW}❌ Uninstall cancelled. MythicalDash remains intact.${NC}"
            fi
            ;;
            
        4)
            echo -e "\n${BLUE}══════════════════════════════════════════════════${NC}"
            echo -e "${BLUE}           👋 FAREWELL!                           ${NC}"
            echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
            echo -e "${CYAN}Thank you for using MythicalDash Manager${NC}"
            echo -e "${MAGENTA}May your servers always stay online! ✨${NC}"
            echo -e "${BLUE}Exiting gracefully...${NC}\n"
            exit 0
            ;;
            
        *)
            echo -e "\n${RED}══════════════════════════════════════════════════${NC}"
            echo -e "${RED}           ❌ INVALID SELECTION!                   ${NC}"
            echo -e "${RED}══════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}Please enter a valid option between 1 and 4.${NC}"
            echo -e "${CYAN}Valid options: 1 (Install), 2 (Update), 3 (Uninstall), 4 (Exit)${NC}"
            ;;
    esac

    echo ""
    read -p "$(echo -e "${CYAN}Press ${BOLD}Enter${NC}${CYAN} to return to menu...${NC}")" dummy
done
