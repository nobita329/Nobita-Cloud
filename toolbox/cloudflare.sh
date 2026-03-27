#!/bin/bash

# ==================================================
#  CLOUDFLARE COMMANDER v3.0
# ==================================================

# --- THEME & COLORS ---
# Using distinct neon colors for a modern terminal look
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# --- ICONS ---
ICON_RUN="${GREEN}●${NC}"
ICON_STOP="${RED}●${NC}"
ICON_WAIT="${YELLOW}◌${NC}"
ICON_CHECK="${GREEN}✔${NC}"
ICON_ERR="${RED}✖${NC}"
ICON_ARROW="${PURPLE}➜${NC}"

# --- HELPER FUNCTIONS ---

# Draw a centered header with dynamic status
show_header() {
    clear
    # System & Service Checks
    local s_status="${GRAY}NOT INSTALLED${NC}"
    local s_pid="${GRAY}---${NC}"
    local s_uptime="${GRAY}---${NC}"
    local arch=$(dpkg --print-architecture 2>/dev/null || uname -m)

    if command -v cloudflared &>/dev/null; then
        if systemctl is-active --quiet cloudflared; then
            s_status="${GREEN}ACTIVE (RUNNING)${NC}"
            s_pid="${WHITE}$(pgrep -x cloudflared)${NC}"
            s_uptime="$(systemctl show -p ActiveEnterTimestamp cloudflared | cut -d'=' -f2 | cut -d' ' -f2-3)"
        else
            s_status="${RED}INACTIVE (STOPPED)${NC}"
        fi
    fi

    # UI Banner
    echo -e "${PURPLE} ┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE} │${NC}              ${WHITE}CLOUDFLARED TUNNEL MANAGER${NC}                  ${PURPLE}│${NC}"
    echo -e "${PURPLE} │${NC}                 ${GRAY}v3.0 | Premium Edition${NC}                   ${PURPLE}│${NC}"
    echo -e "${PURPLE} └────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    # Dashboard Card
    echo -e "${CYAN}  SYSTEM STATUS ${GRAY}───────────────────────────────────────────${NC}"
    echo -e "  ${GRAY}●${NC} Architecture : ${WHITE}$arch${NC}"
    echo -e "  ${GRAY}●${NC} Service Stat : $s_status"
    echo -e "  ${GRAY}●${NC} Process ID   : $s_pid"
    echo -e "  ${GRAY}●${NC} Last Started : ${CYAN}$s_uptime${NC}"
    echo -e "${GRAY} ────────────────────────────────────────────────────────────${NC}"
    echo ""
}

# Pretty print step messages
step_msg() {
    echo -e "  ${CYAN}[INFO]${NC} $1..."
}

success_msg() {
    echo -e "  ${GREEN}[DONE]${NC} $1"
}

error_msg() {
    echo -e "  ${RED}[FAIL]${NC} $1"
}

# --- CORE LOGIC ---

install_cf() {
    show_header
    echo -e "${WHITE}  STARTING INSTALLATION SEQUENCE${NC}"
    echo -e "${GRAY}  ────────────────────────────────${NC}"
    sleep 1

    # 1. Setup Repo
    step_msg "Configuring Cloudflare Repository"
    sudo mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
    success_msg "Repository Added"

    # 2. Install Package
    step_msg "Updating APT & Installing Binary"
    sudo apt-get update -qq >/dev/null
    sudo apt-get install -y cloudflared -qq >/dev/null 2>&1
    
    if command -v cloudflared &>/dev/null; then
        success_msg "Cloudflared Binary Installed"
    else
        error_msg "Binary Installation Failed"
        read -p "Press Enter to return..."
        return
    fi

    # 3. Clean Old Service
    if systemctl list-units --type=service | grep -q cloudflared; then
        step_msg "Removing conflicting services"
        sudo cloudflared service uninstall >/dev/null 2>&1
        success_msg "Cleaned old service"
    fi

    # 4. Token Input UI
    echo ""
    echo -e "${YELLOW}  ┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}  │                    ACTION REQUIRED                     │${NC}"
    echo -e "${YELLOW}  │${NC} Paste your Tunnel Token below.${NC}                         ${YELLOW}│${NC}"
    echo -e "${YELLOW}  │${NC} ${GRAY}(You can paste the whole 'sudo cloudflared...' cmd)${NC}    ${YELLOW}│${NC}"
    echo -e "${YELLOW}  └────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -ne "${PURPLE}  ➤ INPUT TOKEN:${NC} " 
    read USER_TOKEN

    # Logic to clean token (removes command if pasted)
    CLEAN_TOKEN=$(echo "$USER_TOKEN" | sed 's/sudo cloudflared service install //g' | sed 's/cloudflared service install //g' | xargs)

    if [[ -z "$CLEAN_TOKEN" ]]; then
        error_msg "Token cannot be empty!"
        read -p "Press Enter to return..."
        return
    fi

    # 5. Register & Start
    step_msg "Registering Tunnel Service"
    sudo cloudflared service uninstall >/dev/null 2>&1
    sudo cloudflared service install "$CLEAN_TOKEN"
    
    echo ""
    echo -e "${CYAN}  Waiting for service to initialize...${NC}"
    
    # Progress Bar Animation
    for i in {1..20}; do echo -ne "▓"; sleep 0.1; done
    echo ""
    
    if systemctl is-active --quiet cloudflared; then
        echo ""
        echo -e "${GREEN}  SUCCESS: Tunnel is Online & Stable!${NC}"
    else
        echo ""
        echo -e "${RED}  ERROR: Service failed to start.${NC}"
        echo -e "${GRAY}  Debug command: sudo journalctl -u cloudflared -f${NC}"
    fi

    echo ""
    read -p "  Press [Enter] to return to menu..."
}

uninstall_cf() {
    show_header
    echo -e "${RED}  WARNING: DESTRUCTIVE ACTION${NC}"
    echo -e "${GRAY}  This will remove the tunnel service and the binary.${NC}"
    echo ""
    echo -ne "${RED}  Are you sure you want to proceed? (y/N): ${NC}"
    read confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        step_msg "Stopping Service"
        sudo cloudflared service uninstall >/dev/null 2>&1
        
        step_msg "Removing Binary"
        sudo apt-get remove -y cloudflared -qq >/dev/null 2>&1
        
        step_msg "Cleaning Configuration"
        sudo rm -f /etc/apt/sources.list.d/cloudflared.list
        sudo rm -f /usr/share/keyrings/cloudflare-main.gpg
        
        echo ""
        success_msg "Cloudflared Completely Removed."
    else
        echo -e "\n  ${GRAY}Operation Cancelled.${NC}"
    fi
    sleep 2
}

# --- MAIN MENU LOOP ---

while true; do
    show_header
    
    echo -e "  ${WHITE}AVAILABLE OPERATIONS:${NC}"
    echo -e "  ${GREEN}[1]${NC} Install        ${GRAY}(Auto-Fix)${NC}"
    echo -e "  ${RED}[2]${NC} Uninstall         ${GRAY}(Remove All)${NC}"
    echo -e "  ${GRAY}[0]${NC} Exit"
    echo ""
    echo -ne "${PURPLE}  root@cloudflared:~# ${NC}"
    read choice

    case $choice in
        1) install_cf ;;
        2) uninstall_cf ;;
        0) clear; exit ;;
        *) echo -e "  ${RED}Invalid Option${NC}"; sleep 1 ;;
    esac
done
