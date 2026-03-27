#!/bin/bash

# Define modern colors
B='\033[1;34m'   # Blue
C='\033[1;36m'   # Cyan
G='\033[1;32m'   # Green
R='\033[1;31m'   # Red
Y='\033[1;33m'   # Yellow
W='\033[1;37m'   # White
NC='\033[0m'     # No Color

# Ensure cursor comes back if user presses Ctrl+C
trap "tput cnorm; exit" SIGINT SIGTERM

while true; do
    # Hide cursor while drawing menu
    tput civis
    clear

    # Check if zerotier is installed
    if command -v zerotier-cli &> /dev/null; then
        STATUS="${G}● ACTIVE & INSTALLED${NC}"
    else
        STATUS="${R}○ OFFLINE & MISSING${NC}"
    fi

    # Draw the Dashboard Header
    echo -e ""
    echo -e "  ${B}╓──────────────────────────────────────────────╖${NC}"
    echo -e "  ${B}║${NC}           ${C}ZEROTIER CONTROL PANEL${NC}             ${B}║${NC}"
    echo -e "  ${B}╟──────────────────────────────────────────────╢${NC}"
    echo -e "  ${B}║${NC}  System Status: $STATUS" 
    echo -e "  ${B}╙──────────────────────────────────────────────╜${NC}"
    echo -e ""
    
    # Draw the Numbered Options
    echo -e "       ${Y}[ 1 ]${NC} ${W}Join ${NC}"
    echo -e "       ${Y}[ 2 ]${NC} ${W}Remove ${NC}"
    echo -e "       ${Y}[ 3 ]${NC} ${W}Close ${NC}"
    echo -e ""
    
    # Show cursor for input
    tput cnorm 
    
    # Modern input prompt
    echo -e -n "  ${C}╰─❯ Select an option (1-3): ${NC}"
    read choice

    # Hide cursor again while processing
    tput civis 

    case $choice in
    1)
        echo -e "\n  ${C}▶ Downloading and Installing ZeroTier...${NC}"
        curl -s https://install.zerotier.com | sudo bash > /dev/null 2>&1

        echo -e -n "  ${C}▶ Enter NETWORK_ID: ${NC}"
        tput cnorm
        read NETWORK_ID
        tput civis
        
        if [ -n "$NETWORK_ID" ]; then
            sudo zerotier-cli join "$NETWORK_ID" > /dev/null 2>&1
            echo -e "  ${G}✔ Successfully joined network!${NC}"
        else
            echo -e "  ${R}✖ No ID provided. Skipping join.${NC}"
        fi
        sleep 2
        ;;

    2)
        echo -e "\n  ${R}▶ Purging ZeroTier from system...${NC}"
        sudo apt remove zerotier-one -y > /dev/null 2>&1
        sudo apt purge zerotier-one -y > /dev/null 2>&1
        sudo rm -rf /var/lib/zerotier-one > /dev/null 2>&1

        echo -e "  ${G}✔ ZeroTier completely removed.${NC}"
        sleep 2
        ;;

    3)
        echo -e "\n  ${W}Goodbye! 👋${NC}\n"
        tput cnorm # Show cursor back before exiting
        exit 0
        ;;

    *)
        echo -e "\n  ${R}✖ Invalid selection. Please type 1, 2, or 3.${NC}"
        sleep 1.5
        ;;
    esac
done
