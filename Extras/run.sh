#!/bin/bash

# ===================== COLORS =====================
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
GRAY="\e[90m"
NC="\e[0m"
URL="https://raw.githubusercontent.com/nobita329/The-Coding-Hub/main/srv/External/"
# ===================== PAUSE =====================
pause() {
  read -rp "Press Enter to continue..."
}

# ===================== INFRA MENU =====================
infra_menu() {
  while true; do
    clear
    echo -e "${GRAY}────────────── INFRA MENU ──────────────${NC}"
    echo -e "${CYAN} 1) KVM + Cockpit"
    echo -e " 2) CasaOS"
    echo -e " 3) 1Panel"
    echo -e " 4) LXC/LXD"
    echo -e " 5) Docker"
    echo -e " 6) Back${NC}"
    echo -e "${GRAY}────────────────────────────────────────${NC}"
    read -rp "Select → " im

    case "$im" in
      1)
        clear
        echo -e "${CYAN}Installing KVM + Cockpit...${NC}"
        bash <(curl -fsSL https://raw.githubusercontent.com/nobita329/The-Coding-Hub/main/srv/External/Cockpit.sh)
        echo -e "${GREEN}Access: https://SERVER_IP:9090${NC}"
        pause
        ;;
      2)
        clear
        echo -e "${CYAN}Installing CasaOS...${NC}"
        bash <(curl -fsSL https://raw.githubusercontent.com/nobita329/The-Coding-Hub/main/srv/External/casaos.sh)
        pause
        ;;
      3)
        clear
        echo -e "${CYAN}Installing 1Panel...${NC}"
        bash <(curl -fsSL https://raw.githubusercontent.com/nobita329/The-Coding-Hub/main/srv/External/1panel.sh)
        pause
        ;;
      4)
        clear
        echo -e "${CYAN}Installing  LXC/LXD...${NC}"
        sudo usermod -aG lxd root
        bash <(curl -fsSL https://raw.githubusercontent.com/nobita329/The-Coding-Hub/main/srv/External/lxc.sh)
        pause
        ;;
      5)
        clear
        echo -e "${CYAN}Installing  LXC/LXD...${NC}"
        bash <(curl -fsSL https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/External/doc.sh)
        pause
        ;;
      6)
        clear
        exit 0
        ;;
      *)
        echo -e "${RED}Invalid option!${NC}"
        pause
        ;;
    esac
  done
}

# ===================== START =====================
infra_menu
