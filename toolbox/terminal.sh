#!/bin/bash

# ==================================================
#  TERMINAL SHARING HUB v4.1 | FIXED UNINSTALLER
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

# --- UTILS ---
has() { command -v "$1" >/dev/null 2>&1; }

get_status() {
    if has "$1"; then
        echo -e "${GREEN}[ INSTALLED ]${NC}"
    else
        echo -e "${GRAY}[  MISSING  ]${NC}"
    fi
}

msg_info() { echo -e "  ${BLUE}➜${NC} $1"; }
msg_ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
msg_err()  { echo -e "  ${RED}✖${NC} $1"; }

# --- HEADER UI ---
draw_header() {
    clear
    local host=$(hostname)
    local ip=$(hostname -I | awk '{print $1}')
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}║${NC}       ${WHITE}TERMINAL SHARING HUB${NC} ${GRAY}::${NC} ${PURPLE}REMOTE COLLABORATION SUITE${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}║${NC} ${GRAY}SYSTEM:${NC} ${WHITE}$host${NC}  ${GRAY}IP:${NC} ${WHITE}$ip${NC}   ${GRAY}VER:${NC} ${WHITE}4.1 (Stable)${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# --- INSTALL / UNINSTALL LOGIC ---

manage_tool() {
    TOOL=$1
    echo -e "${GRAY}  ──────────────────────────────────────────${NC}"
    
    if has "$TOOL"; then
        # === UNINSTALL LOGIC (FIXED) ===
        echo -e "${RED}  Detected '$TOOL' is installed.${NC}"
        read -p "  Uninstall it? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            msg_info "Removing $TOOL..."
            
            case $TOOL in
                sshx)  
                    # Remove binary and local config folder
                    rm -rf "$HOME/.sshx"
                    sudo rm -f $(which sshx) 2>/dev/null
                    ;;
                tmate) 
                    # Smart Package Manager Detection
                    if command -v apt &>/dev/null; then sudo apt remove -y tmate -qq
                    elif command -v dnf &>/dev/null; then sudo dnf remove -y tmate
                    elif command -v yum &>/dev/null; then sudo yum remove -y tmate
                    elif command -v pacman &>/dev/null; then sudo pacman -Rns --noconfirm tmate
                    fi 
                    ;;
                upterm) 
                     rm -f /usr/local/bin/upterm 
                     rm -f /usr/bin/upterm
                    ;;
                ttyd)   
                     rm -f /usr/local/bin/ttyd 
                    ;;
                gotty)  
                     rm -f /usr/local/bin/gotty 
                    ;;
                cloudflared) 
                     rm -f /usr/local/bin/cloudflared 
                    ;;
            esac
            
            # Verify Removal
            if ! has "$TOOL"; then
                msg_ok "Uninstallation Complete."
            else
                msg_err "Failed to remove completely. Try running as sudo."
            fi
        else
            msg_info "Cancelled."
        fi
    else
        # === INSTALL LOGIC ===
        echo -e "${GREEN}  Detected '$TOOL' is missing.${NC}"
        read -p "  Install it now? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            msg_info "Installing $TOOL..."
            
            case $TOOL in
                sshx) curl -sSf https://sshx.io/get | sh -s run ;;
                tmate) 
                    if command -v apt &>/dev/null; then sudo apt update -qq && sudo apt install -y tmate -qq
                    elif command -v yum &>/dev/null; then sudo yum install -y tmate
                    elif command -v pacman &>/dev/null; then sudo pacman -S --noconfirm tmate
                    fi 
                    ;;
                upterm) curl -fsSL https://upterm.sh/install | sh ;;
                ttyd) 
                    curl -L https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 -o ttyd
                    chmod +x ttyd && sudo mv ttyd /usr/local/bin/
                    ;;
                gotty)
                    wget -q https://github.com/yudai/gotty/releases/latest/download/gotty_linux_amd64.tar.gz
                    tar -xzf gotty_linux_amd64.tar.gz
                    chmod +x gotty && sudo mv gotty /usr/local/bin/
                    rm gotty_linux_amd64.tar.gz
                    ;;
                cloudflared)
                    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
                    chmod +x cloudflared-linux-amd64
                    sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
                    ;;
            esac
            
            msg_ok "Installation Complete."
        else
            msg_info "Cancelled."
        fi
    fi
    read -p "  Press Enter..."
}

package_manager_menu() {
    while true; do
        draw_header
        echo -e "  ${WHITE}PACKAGE MANAGER (INSTALL / UNINSTALL):${NC}"
        echo -e "  ${GRAY}Select a tool to toggle its installation state.${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} $(get_status sshx) sshx"
        echo -e "  ${CYAN}[2]${NC} $(get_status tmate) tmate"
        echo -e "  ${CYAN}[3]${NC} $(get_status upterm) upterm"
        echo -e "  ${CYAN}[4]${NC} $(get_status ttyd) ttyd"
        echo -e "  ${CYAN}[5]${NC} $(get_status gotty) gotty"
        echo -e "  ${CYAN}[6]${NC} $(get_status cloudflared) cloudflared"
        echo ""
        echo -e "  ${RED}[0] Back to Main Menu${NC}"
        echo ""
        echo -ne "${PURPLE}  root@manager:~# ${NC}"
        read pkg_opt
        
        case $pkg_opt in
            1) manage_tool "sshx" ;;
            2) manage_tool "tmate" ;;
            3) manage_tool "upterm" ;;
            4) manage_tool "ttyd" ;;
            5) manage_tool "gotty" ;;
            6) manage_tool "cloudflared" ;;
            0) return ;;
            *) msg_err "Invalid Option"; sleep 1 ;;
        esac
    done
}

# --- RUN TOOLS LOGIC ---

sshx_run() { [ ! -x "$(command -v sshx)" ] && manage_tool "sshx"; sshx; }
tmate_run() { [ ! -x "$(command -v tmate)" ] && manage_tool "tmate"; tmate; }
upterm_run() { [ ! -x "$(command -v upterm)" ] && manage_tool "upterm"; upterm host; }
ttyd_run() { 
    [ ! -x "$(command -v ttyd)" ] && manage_tool "ttyd"
    echo -ne "${PURPLE}  ➤ Select Port (Default 8080): ${NC}"
    read P
    P=${P:-8080}
    echo -e "${GREEN}  ▶ Web Terminal Active: http://$(hostname -I | awk '{print $1}'):$P${NC}"
    ttyd -p "$P" bash
}
gotty_run() { [ ! -x "$(command -v gotty)" ] && manage_tool "gotty"; gotty -w bash; }
cloudflared_run() { 
    [ ! -x "$(command -v cloudflared)" ] && manage_tool "cloudflared"
    echo -e "${GREEN}  ▶ Starting Quick Tunnel...${NC}"
    cloudflared tunnel --url ssh://localhost:22
}
serveo_run() {
    echo -ne "${PURPLE}  ➤ Custom Subdomain (Enter for random): ${NC}"
    read SUB
    if [ -z "$SUB" ]; then ssh -R 80:localhost:22 serveo.net
    else ssh -R "$SUB":80:localhost:22 serveo.net; fi
}
localhost_run() { ssh -R 80:localhost:22 nokey@localhost.run; }

# --- PRE-REQ CHECK ---
base_install() {
    if ! has curl || ! has wget; then
        echo -e "${YELLOW}  [SYSTEM] Installing base dependencies...${NC}"
        if command -v apt &>/dev/null; then
            sudo apt update -y -qq >/dev/null
            sudo apt install -y curl wget sudo screen tmux -qq >/dev/null
        elif command -v yum &>/dev/null; then
            sudo yum install -y curl wget sudo screen tmux -q
        fi
    fi
}

# --- MAIN MENU ---

base_install

while true; do
    draw_header
    
    echo -e "  ${WHITE}COLLABORATIVE SHELLS:${NC}"
    echo -e "  ${GREEN}[1]${NC} $(get_status sshx) sshx      ${GRAY}:: (Web-based, Multiplayer)${NC}"
    echo -e "  ${GREEN}[2]${NC} $(get_status tmate) tmate     ${GRAY}:: (Tmux Session Sharing)${NC}"
    echo -e "  ${GREEN}[3]${NC} $(get_status upterm) upterm    ${GRAY}:: (Secure SSH Sharing)${NC}"
    echo ""
    echo -e "  ${WHITE}WEB TERMINALS:${NC}"
    echo -e "  ${BLUE}[4]${NC} $(get_status ttyd) ttyd      ${GRAY}:: (C++ Backend)${NC}"
    echo -e "  ${BLUE}[5]${NC} $(get_status gotty) gotty     ${GRAY}:: (Go Backend)${NC}"
    echo ""
    echo -e "  ${WHITE}TUNNELS & UTILS:${NC}"
    echo -e "  ${PURPLE}[6]${NC} $(get_status ssh) Serveo    ${GRAY}:: (Clientless Tunnel)${NC}"
    echo -e "  ${PURPLE}[7]${NC} $(get_status ssh) Localhost ${GRAY}:: (Clientless Tunnel)${NC}"
    echo -e "  ${PURPLE}[8]${NC} $(get_status cloudflared) Cloudflare${GRAY}:: (Zero Trust Tunnel)${NC}"
    echo ""
    echo -e "  ${YELLOW}[9] PACKAGE MANAGER (Install/Uninstall)${NC}"
    echo -e "  ${GRAY}[0] Exit Hub${NC}"
    echo ""
    echo -ne "${CYAN}  root@hub:~# ${NC}"
    read option
    
    case $option in
        1) sshx_run ;;
        2) tmate_run ;;
        3) upterm_run ;;
        4) ttyd_run ;;
        5) gotty_run ;;
        6) serveo_run ;;
        7) localhost_run ;;
        8) cloudflared_run ;;
        9) package_manager_menu ;;
        0) clear; exit 0 ;;
        *) echo -e "  ${RED}Invalid Option${NC}"; sleep 1 ;;
    esac
done
