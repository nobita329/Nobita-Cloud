#!/bin/bash
# ===========================================================
# CODING HUB - OBSIDIAN NEXT GEN (v12.0 - Nobita Edition)
# Style: Modern Glass / Segmented Neo UI / Full Redesign
# ===========================================================

# --- COLORS (Premium Palette) ---
B_BLUE='\033[1;38;5;33m'
B_CYAN='\033[1;38;5;51m'
B_PURPLE='\033[1;38;5;141m'
B_GREEN='\033[1;38;5;82m'
B_RED='\033[1;38;5;196m'
GOLD='\033[38;5;220m'
W='\033[1;38;5;255m'
G='\033[0;38;5;244m'
BG_SHADE='\033[48;5;236m'
NC='\033[0m'

# --- REAL-TIME METRICS ---
get_metrics() {
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.0f", $2+$4}' 2>/dev/null || echo "??")
    RAM=$(free | grep Mem | awk '{printf "%.0f", $3*100/$2}' 2>/dev/null || echo "??")
    UPT=$(uptime -p | sed 's/up //' 2>/dev/null || echo "Unknown")
    DISK=$(df -h / | awk 'NR==2 {print $5}' 2>/dev/null || echo "??")
    CURRENT_HOST=$(hostname)
}

# --- MAIN UI RENDERER (New Full Design) ---
render_ui() {
    clear
    get_metrics

    # Top Status Bar (Glass Pills)
    echo -e " ${B_BLUE}${NC}${BG_SHADE}${W}  $CURRENT_HOST ${NC}${B_BLUE}${NC}  ${B_PURPLE}${NC}${BG_SHADE}${W}  $UPT ${NC}${B_PURPLE}${NC}  ${B_GREEN}${NC}${BG_SHADE}${W}  $DISK ${NC}${B_GREEN}${NC}  ${B_CYAN}${NC}${BG_SHADE}${W}  ${CPU}% ${B_PURPLE}RAM ${RAM}%${NC}${B_CYAN}${NC}"
    echo -e ""

    # NEW BIG BANNER (Modern Gradient Style)
    echo -e "${B_CYAN}   ██████╗  ██████╗ ██████╗ ██╗███╗   ██╗ ██████╗     ██╗  ██╗██╗   ██╗██████╗ ${NC}"
    echo -e "${B_CYAN}  ██╔════╝ ██╔═══██╗██╔══██╗██║████╗  ██║██╔════╝     ██║  ██║██║   ██║██╔══██╗${NC}"
    echo -e "${B_PURPLE}  ██║  ███╗██║   ██║██║  ██║██║██╔██╗ ██║██║  ███╗    ███████║██║   ██║██████╔╝${NC}"
    echo -e "${B_PURPLE}  ██║   ██║██║   ██║██║  ██║██║██║╚██╗██║██║   ██║    ██╔══██║██║   ██║██╔══██╗${NC}"
    echo -e "${GOLD}  ╚██████╔╝╚██████╔╝██████╔╝██║██║ ╚████║╚██████╔╝    ██║  ██║╚██████╔╝██████╔╝${NC}"
    echo -e "${GOLD}   ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝     ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ${NC}"
    echo -e "                  ${G}NOBITA EDITION — OBSIDIAN NEXT GEN${NC}"

    echo -e " ${G}────────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e ""

    # System Health
    echo -e " ${W}◉ SYSTEM STATUS${NC}"
    printf "   ${G}CPU Usage:${NC} ${B_CYAN}%3s%%${NC}     ${G}RAM Usage:${NC} ${B_PURPLE}%3s%%${NC}     ${G}Network:${NC} ${B_GREEN}● CONNECTED${NC}\n" "$CPU" "$RAM"
    echo -e ""

    # Main Menu - Segmented Glass Style
    echo -e " ${B_CYAN} DEPLOYMENT & SERVICES${NC}"
    echo -e " ${G}├─${NC} ${W}[1]${NC} VPS           ${G}├─${NC} ${W}[5]${NC} Themes "
    echo -e " ${G}├─${NC} ${W}[2]${NC} Panel         ${G}├─${NC} ${W}[6]${NC} System "
    echo -e " ${G}├─${NC} ${W}[3]${NC} Wings         ${G}├─${NC} ${W}[7]${NC} Container"
    echo -e " ${G}└─${NC} ${W}[8]${NC} ${B_GREEN}New Module${NC}           ${G}   ${NC}"

    echo -e ""
    echo -e " ${B_PURPLE} MAINTENANCE & TOOLS${NC}"
    echo -e " ${G}├─${NC} ${W}[4]${NC} Toolbox              ${G}└─${NC} ${B_RED}${NC}${BG_SHADE}${W} [0] SHUTDOWN SYSTEM ${NC}${B_RED}${NC}"
    echo -e " ${G}└─${NC} ${W}[9]${NC} Extras"

    echo -e "\n ${G}────────────────────────────────────────────────────────────────────────────────${NC}"
    echo -ne " ${B_CYAN}➜${NC} ${W}Enter Option${NC} ${G}(0-9):${NC} "
}

# --- MAIN LOOP ---
while true; do
    render_ui
    read -r opt

    case $opt in
        1) bash <(curl -s https://raw.githubusercontent.com/nobita329/hub/refs/heads/main/Codinghub/VM/menu.sh) ;;
        2) bash <(curl -s https://raw.githubusercontent.com/nobita329/hub/refs/heads/main/Codinghub/panel/run.sh) ;;
        3) bash <(curl -s https://raw.githubusercontent.com/nobita329/Nobita-Cloud/refs/heads/main/wings/run.sh) ;;
        4) bash <(curl -s https://raw.githubusercontent.com/nobita329/ptero/refs/heads/main/ptero/tools/run.sh) ;;
        5) bash <(curl -s https://raw.githubusercontent.com/nobita329/hub/refs/heads/main/Codinghub/thames/run.sh) ;;
        6) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/menu/System1.sh) ;;
        7) bash <(curl -s https://raw.githubusercontent.com/nobita329/ptero/refs/heads/main/ptero/no-kvm/run.sh) ;;

        # New Options (Ready for you to fill)
        8) 
            echo -e "\n ${B_GREEN}▶ Launching New Module...${NC}"
            echo -e " ${G}(Add your new script/command here)${NC}"
            sleep 1.8
            ;;
        9) 
            echo -e "\n ${B_PURPLE}▶ Opening Extra Tools...${NC}"
            echo -e " ${G}More features coming in future updates.${NC}"
            sleep 1.5
            ;;

        0|exit|quit)
            echo -e "\n ${B_RED}● DISCONNECTED${NC}  Goodbye, Nobita."
            exit 0 
            ;;

        *)
            echo -e "\n ${B_RED}✘ Invalid Option! Please try again.${NC}"
            sleep 0.8
            ;;
    esac
done
