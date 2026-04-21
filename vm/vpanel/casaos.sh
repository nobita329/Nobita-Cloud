#!/bin/bash

# ===================== COLORS =====================
RED="\e[31m"
C_MAIN="\e[36m"
C_SEC="\e[32m"
C_LINE="\e[90m"
NC="\e[0m"

# ===================== PAUSE =====================
pause() {
  read -rp "Press Enter to continue..."
}

# ===================== CASAOS MENU =====================
casaos_menu() {
  while true; do
    clear
    echo -e "${C_LINE}────────────── CASAOS MENU ──────────────${NC}"
    echo -e "${C_MAIN} 1) Install CasaOS"
    echo -e " 2) Uninstall CasaOS"
    echo -e " 3) Exit${NC}"
    echo -e "${C_LINE}────────────────────────────────────────${NC}"
    read -rp "Select → " cs

    case "$cs" in
      1)
        clear
        echo -e "${C_MAIN}🚀 Installing CasaOS...${NC}"
        curl -fsSL https://get.casaos.io | bash
        echo
        echo -e "${C_SEC}✅ CasaOS Installed Successfully${NC}"
        echo -e "${C_SEC}🌐 Access: http://SERVER_IP${NC}"
        pause
        ;;
      2)
        clear
        echo -e "${C_MAIN}🧹 Uninstalling CasaOS...${NC}"

        if command -v casaos-uninstall >/dev/null 2>&1; then
          casaos-uninstall
        fi

        systemctl stop casaos.service 2>/dev/null
        systemctl disable casaos.service 2>/dev/null

        rm -rf \
          /casaos \
          /usr/lib/casaos \
          /etc/casaos \
          /var/lib/casaos \
          /usr/bin/casaos \
          /usr/local/bin/casaos

        echo
        echo -e "${C_SEC}✅ CasaOS Completely Removed${NC}"
        pause
        ;;
      3)
        clear
        exit 0
        ;;
      *)
        echo -e "${RED}Invalid Option${NC}"
        pause
        ;;
    esac
  done
}

# ===================== START =====================
casaos_menu
