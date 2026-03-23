#!/bin/bash
set -e

# ==================================================
#  WINGS CONFIGURATOR v3.2 | CYBER-NODE EDITION
# ==================================================

# --- COLORS & STYLES ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[1;90m'
NC='\033[0m' # No Color

# --- HELPER FUNCTIONS ---

msg_info() { echo -e "  ${BLUE}➜${NC} $1"; }
msg_ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
msg_err()  { echo -e "  ${RED}✖${NC} $1"; }
msg_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
msg_input() { echo -ne "  ${PURPLE}➤${NC} $1: "; }

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

# --- HEADER UI ---
# --- COLORS & STYLES (Make sure these are at the top) ---
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

# --- NEW HEADER FUNCTION ---
draw_header() {
    clear
    local host=$(hostname)
    local ip=$(hostname -I | awk '{print $1}')
    
    # Status Logic with Bold Colors
    local status="${C_RED}${C_BOLD}✖ OFFLINE${C_RESET}"
    if systemctl is-active --quiet wings; then
        status="${C_GREEN}${C_BOLD}● ONLINE${C_RESET}"
    fi

    echo -e "${C_PURPLE}${C_BOLD} ⚡ ${C_WHITE}WINGS CONFIGURATOR ${C_GRAY}:: ${C_CYAN}v4.5${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD} ├──${C_RESET} ${C_BLUE}${C_BOLD}SYSTEM INFORMATION${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD} │   ├─${C_RESET} ${C_GRAY}Hostname :${C_RESET} ${C_WHITE}${C_BOLD}$host${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD} │   └─${C_RESET} ${C_GRAY}IP Addr  :${C_RESET} ${C_WHITE}${C_BOLD}$ip${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD} ├──${C_RESET} ${C_BLUE}${C_BOLD}SERVICE STATUS${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD} │   └─${C_RESET} ${C_GRAY}Daemon   :${C_RESET} $status"
    echo -e "${C_PURPLE}${C_BOLD} └──────────────────────────────────────────${C_RESET}"
    echo ""
}

# --- MAIN LOGIC ---

draw_header

echo -e "${WHITE}  CONFIGURATION WIZARD${NC}"
echo -e "${GRAY}  Enter credentials. Type ${WHITE}'back'${GRAY} to go to previous step.${NC}"
echo -e "${GRAY}  ──────────────────────────────────────────${NC}"

# VARIABLES
STEP=1
UUID=""
TOKEN_ID=""
TOKEN=""
API_PORT="8080" # Default Port
REMOTE=""

# WIZARD LOOP
while [ $STEP -le 6 ]; do
    case $STEP in
        1) # STEP 1: UUID
            echo ""
            if [ -n "$UUID" ]; then echo -e "  ${GRAY}(Current: $UUID)${NC}"; fi
            msg_input "Node UUID"
            read INPUT
            
            if [ "$INPUT" == "back" ]; then
                msg_warn "Exiting Configurator..."
                exit 0
            elif [ -z "$INPUT" ] && [ -n "$UUID" ]; then
                ((STEP++)) # Keep existing value if just Enter pressed
            elif [ -z "$INPUT" ]; then 
                msg_err "UUID is required."; continue
            else
                UUID="$INPUT"
                ((STEP++))
            fi
            ;;
            
        2) # STEP 2: TOKEN ID
            echo ""
            if [ -n "$TOKEN_ID" ]; then echo -e "  ${GRAY}(Current: $TOKEN_ID)${NC}"; fi
            msg_input "Token ID"
            read INPUT
            
            if [ "$INPUT" == "back" ]; then
                ((STEP--))
            elif [ -z "$INPUT" ] && [ -n "$TOKEN_ID" ]; then
                ((STEP++))
            elif [ -z "$INPUT" ]; then 
                msg_err "Token ID is required."; continue
            else
                TOKEN_ID="$INPUT"
                ((STEP++))
            fi
            ;;
            
        3) # STEP 3: TOKEN KEY
            echo ""
            # Don't show full token for security, just indicator
            if [ -n "$TOKEN" ]; then echo -e "  ${GRAY}(Current: ************)${NC}"; fi
            msg_input "Token Key"
            read INPUT
            
            if [ "$INPUT" == "back" ]; then
                ((STEP--))
            elif [ -z "$INPUT" ] && [ -n "$TOKEN" ]; then
                ((STEP++))
            elif [ -z "$INPUT" ]; then 
                msg_err "Token Key is required."; continue
            else
                TOKEN="$INPUT"
                ((STEP++))
            fi
            ;;

        4) # STEP 4: API PORT (NEW)
            echo ""
            echo -e "  ${GRAY}(Default: 8080) ENTER${NC}"
            if [ "$API_PORT" != "8080" ]; then echo -e "  ${GRAY}(Current: $API_PORT)${NC}"; fi
            
            msg_input "API Port"
            read INPUT
            
            if [ "$INPUT" == "back" ]; then
                ((STEP--))
            elif [ -z "$INPUT" ]; then
                # Keep default or previous
                msg_warn "Using Port: $API_PORT"
                ((STEP++))
            elif [[ ! "$INPUT" =~ ^[0-9]+$ ]]; then
                msg_err "Invalid Port. Must be a number."; continue
            else
                API_PORT="$INPUT"
                ((STEP++))
            fi
            ;;
            
        5) # STEP 5: REMOTE URL
            echo ""
            echo -e "  ${GRAY}(Default: https://panel.example.com)${NC}"
            if [ -n "$REMOTE" ]; then echo -e "  ${GRAY}(Current: $REMOTE)${NC}"; fi
            
            msg_input "Panel URL"
            read INPUT
            
            if [ "$INPUT" == "back" ]; then
                ((STEP--))
            elif [ -z "$INPUT" ] && [ -n "$REMOTE" ]; then
                 ((STEP++))
            elif [ -z "$INPUT" ]; then
                msg_warn "Using Default URL."
                REMOTE="https://panel.example.com"
                ((STEP++))
            elif [[ ! "$INPUT" =~ ^https?:// ]]; then
                msg_err "Invalid URL. Use http:// or https://"; continue
            else
                REMOTE="$INPUT"
                ((STEP++))
            fi
            ;;

        6) # STEP 6: REVIEW & CONFIRM
            echo ""
            echo -e "${CYAN}  REVIEW SETTINGS:${NC}"
            echo -e "${GRAY}  ──────────────────────────────────────────${NC}"
            echo -e "  ${GRAY}●${NC} UUID      : ${WHITE}$UUID${NC}"
            echo -e "  ${GRAY}●${NC} Token ID  : ${WHITE}$TOKEN_ID${NC}"
            echo -e "  ${GRAY}●${NC} Token Key : ${WHITE}****************${NC}"
            echo -e "  ${GRAY}●${NC} API Port  : ${WHITE}$API_PORT${NC}"
            echo -e "  ${GRAY}●${NC} Remote    : ${WHITE}$REMOTE${NC}"
            echo -e "${GRAY}  ──────────────────────────────────────────${NC}"
            echo ""

            read -p "  Apply Configuration? (Y/n/back): " CONFIRM
            
            if [ "$CONFIRM" == "back" ]; then
                ((STEP--))
            elif [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
                echo ""
                msg_err "Setup Cancelled."
                exit 0
            else
                # BREAK LOOP TO PROCEED
                break 
            fi
            ;;
    esac
done

# --- EXECUTION ---
echo ""
msg_info "Generating Configuration File..."

# Create Directory
rm -f /etc/pterodactyl/config.yml
mkdir -p /etc/pterodactyl

# Write Config
cat <<CFG > /etc/pterodactyl/config.yml
debug: false
uuid: ${UUID}
token_id: ${TOKEN_ID}
token: ${TOKEN}
api:
  host: 0.0.0.0
  port: ${API_PORT}
  ssl:
    enabled: true
    cert: /etc/certs/wing/fullchain.pem
    key: /etc/certs/wing/privkey.pem
  upload_limit: 100
system:
  data: /var/lib/pterodactyl/volumes
  sftp:
    bind_port: 2022
allowed_mounts: []
remote: '${REMOTE}'
CFG

if [ $? -eq 0 ]; then
    msg_ok "Config Written: /etc/pterodactyl/config.yml"
else
    msg_err "Failed to write config file!"
    exit 1
fi

# --- SERVICE RESTART ---
echo ""
msg_info "Restarting Wings Service..."
systemctl enable wings >/dev/null 2>&1

# Start in background to show spinner
(systemctl restart wings) &
spinner $!

# Check Status
sleep 2
if systemctl is-active --quiet wings; then
    msg_ok "Wings is Active & Running."
    echo ""
    echo -e "${GRAY}  ──────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}DEBUG COMMANDS:${NC}"
    echo -e "  ${WHITE}systemctl status wings${NC}"
    echo -e "  ${WHITE}journalctl -u wings -f${NC}"
    echo ""
else
    msg_err "Service failed to start."
    echo -e "  ${RED}Check logs: journalctl -u wings -n 20${NC}"
    exit 1
fi
