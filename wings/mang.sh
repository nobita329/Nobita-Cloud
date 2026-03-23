#!/bin/bash

# --- CONFIG & SEMA UI COLORS ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;214m'
NC='\033[0m'

SERVICE="wings"

# --- HELPER FUNCTIONS ---
get_status() {
    if systemctl is-active --quiet $SERVICE; then
        echo -e "${GREEN}ACTIVE${NC}"
    else
        echo -e "${RED}INACTIVE${NC}"
    fi
}

show_header() {
    clear
    STATUS=$(get_status)
    UPTIME=$(systemctl show -p ActiveEnterTimestamp $SERVICE | cut -d'=' -f2)
    
    echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${CYAN}🪽  WINGS CONTROL CENTER${NC} ${GRAY}v17.0${NC}          ${GRAY}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e "  ${CYAN}NODE DIAGNOSTICS${NC}"
    echo -e "  ${GRAY}├─ Service :${NC} ${WHITE}$SERVICE${NC}   ${GRAY}Status :${NC} $STATUS"
    echo -e "  ${GRAY}└─ Active  :${NC} ${GRAY}${UPTIME:-N/A}${NC}"
    echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
}
# -----------crate node ---
node() {
    while true; do
        clear
        echo "==== 🚀 NODE SETUP PROTOCOLS ===="
        echo "  [1] Public Domain (Auto SSL)"
        echo "  [2] Local IP (Manual)"
        echo "  [3] Finalize Deployment (Start Wings)"
        echo "  [0] Back"
        echo ""
        read -p "Setup-Action: " s_choice

        case $s_choice in

        1)
            echo ""
            read -p "Enter Domain (example: node.domain.com): " DOMAIN

            read -p "Create Node? (y/n) [y]: " CREATE
            CREATE=${CREATE:-y}

            if [ "$CREATE" = "y" ]; then

                # ==== AUTO NUMBER ====
                LAST_NUM=$(php artisan p:node:list 2>/dev/null | grep -oP 'Node - \K[0-9]+' | sort -n | tail -1)
                [ -z "$LAST_NUM" ] && NEXT_NUM=1 || NEXT_NUM=$((LAST_NUM+1))
                NODE_NAME="Node - $NEXT_NUM"

                echo "Creating Node..."

                printf "$NODE_NAME\nVPS: $(hostname)\n1\nhttps\n$DOMAIN\ny\nn\nn\n99999\n0\n99999\n0\n1024\n8080\n2022\n/var/lib/pterodactyl/volumes\n" | php artisan p:node:make > /dev/null 2>&1

                # ==== GET NODE ID ====
                NODE_ID=$(php artisan p:node:list | awk -F'|' 'NR>3 && $2+0 {gsub(/ /,"",$2); print $2}' | tail -1)

                # ==== CONFIG ====
                mkdir -p /etc/pterodactyl
                php artisan p:node:configuration $NODE_ID > /etc/pterodactyl/config.yml

                # ==== AUTO SSL FIX ====
                sed -i "s|ssl:.*|ssl:\n    enabled: true\n    cert: /etc/certs/wing/fullchain.pem\n    key: /etc/certs/wing/privkey.pem|g" /etc/pterodactyl/config.yml

                echo "✅ Node Created with SSL"

            else
                echo "Skipped Node Creation"
            fi
            sleep 2
        ;;

        2)
            echo ""
            read -p "Enter Local IP: " IP

            read -p "Create Node? (y/n) [y]: " CREATE
            CREATE=${CREATE:-y}

            if [ "$CREATE" = "y" ]; then

                LAST_NUM=$(php artisan p:node:list 2>/dev/null | grep -oP 'Node - \K[0-9]+' | sort -n | tail -1)
                [ -z "$LAST_NUM" ] && NEXT_NUM=1 || NEXT_NUM=$((LAST_NUM+1))
                NODE_NAME="Node - $NEXT_NUM"

                printf "$NODE_NAME\nLocal VPS\n1\nhttp\n$IP\ny\nn\nn\n99999\n0\n99999\n0\n1024\n8080\n2022\n/var/lib/pterodactyl/volumes\n" | php artisan p:node:make > /dev/null 2>&1

                NODE_ID=$(php artisan p:node:list | awk -F'|' 'NR>3 && $2+0 {gsub(/ /,"",$2); print $2}' | tail -1)

                mkdir -p /etc/pterodactyl
                php artisan p:node:configuration $NODE_ID > /etc/pterodactyl/config.yml

                echo "✅ Local Node Created"
            fi
            sleep 2
        ;;

        3)
            echo ""
            echo "🚀 Starting Wings..."

            pkill wings 2>/dev/null
            systemctl enable --now wings 2>/dev/null || wings > /dev/null 2>&1 &

            echo "✅ Wings Running"
            sleep 2
        ;;

        0)
            break
        ;;

        *)
            echo "Invalid option ❌"
            sleep 1
        ;;
        esac
    done
}
# --- AUTO SETUP SUB-MENU ---
auto_setup() {
    while true; do
        show_header
        echo -e "  ${GOLD}🚀 AUTO-SETUP PROTOCOLS${NC}"
        echo -e "  ${GRAY}├─ [1]${NC} Configure Node 01 ${GRAY}(Auto-Fetch)${NC}"
        echo -e "  ${GRAY}├─ [2]${NC} Configure Node 02 ${GRAY}(Manual Paste)${NC}"
        echo -e "  ${GRAY}├─ [3]${NC} Finalize Deployment ${GRAY}(Start Node)${NC}"
        echo -e "  ${GRAY}└─ [0]${NC} Back to Master Menu"
        echo ""
        echo -ne "  ${CYAN}λ${NC} ${WHITE}Setup-Action:${NC} "
        read -r s_choice

        case $s_choice in
            1) echo -e "\n  ${CYAN}➜ Running Config-01 Logic...${NC}"; sleep 2 ;;
            2) echo -e "\n  ${CYAN}➜ Running Config-02 Logic...${NC}"; sleep 2 ;;
            3) echo -e "\n  ${GREEN}➜ Deploying Wings Node...${NC}"; systemctl enable --now wings; sleep 2 ;;
            0) break ;;
        esac
    done
}

# --- MAIN CONTROLLER ---
while true; do
    show_header
    echo -e "  ${CYAN}SERVICE MANAGEMENT${NC}"
    echo -e "  ${GRAY}├─ [1]${NC} Start       ${GRAY}[4]${NC} Status"
    echo -e "  ${GRAY}├─ [2]${NC} Restart     ${GRAY}[5]${NC} Live  Logs"
    echo -e "  ${GRAY}└─ [3]${NC} Stop        ${GRAY}[6]${NC} Debug Mode ${GOLD}(Manual)${NC}"
    echo ""
    echo -e "  ${PURPLE}ADVANCED TOOLS${NC}"
    echo -e "  ${GRAY}├─ [A]${NC} ${WHITE}Auto-Setup Wizard${NC}  ${GRAY}(New)${NC}"
    echo -e "  ${GRAY}└─ [0]${NC} ${RED}Exit Manager${NC}"
    echo ""
    echo -ne "  ${CYAN}λ${NC} ${WHITE}Master Command:${NC} "
    read -r choice

    case $choice in
        1) sudo systemctl start $SERVICE; echo -e "  ${GREEN}✔ Started${NC}"; sleep 1 ;;
        2) sudo systemctl restart $SERVICE; echo -e "  ${CYAN}✔ Restarted${NC}"; sleep 1 ;;
        3) sudo systemctl stop $SERVICE; echo -e "  ${RED}✔ Stopped${NC}"; sleep 1 ;;
        4) echo -e "\n${WHITE}--- FULL SYSTEMCTL OUTPUT ---${NC}"; systemctl status $SERVICE --no-pager; read -p "Enter to return..." ;;
        5) echo -e "\n${GOLD}--- STREAMING LOGS (Ctrl+C to stop) ---${NC}"; journalctl -u $SERVICE -f ;;
        6) echo -e "\n${RED}⚠️  DEBUG MODE ACTIVATED${NC}"; sudo systemctl stop $SERVICE; sudo wings; read -p "Enter to return..." ;;
        [Aa]) node ;;
        0) echo -e "\n  ${GRAY}Closing Uplink... Goodbye.${NC}"; exit 0 ;;
        *) echo -e "  ${RED}⚠ Invalid Selection${NC}"; sleep 1 ;;
    esac
done
