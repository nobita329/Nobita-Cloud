#!/usr/bin/env bash
# ==========================================================
# NOBITA CLOUD SYSTEM | BANE-ANMESH 3S UPLINK
# DATE: 2026-04-08 | UI-TYPE: SEMA-HYPER-VISUAL → VIP ELITE
# ==========================================================
set -euo pipefail

# --- VIP ELITE THEME ---
R='\033[1;38;5;196m'     # Crimson Red
G='\033[1;38;5;82m'      # Emerald Green
Y='\033[1;38;5;220m'     # Gold
C='\033[1;38;5;51m'      # Cyan
P='\033[1;38;5;201m'     # Hot Pink (VIP)
VIOLET='\033[1;38;5;135m' # Deep Violet
NEON='\033[1;38;5;198m'  # Neon Pink
W='\033[1;38;5;255m'     # Pure White
DG='\033[0;38;5;244m'    # Steel Gray
NC='\033[0m'             # Reset

# --- CONFIG ---
HOST="run.nobitahost.in"
URL="https://${HOST}"
NETRC="${HOME}/.netrc"
IP="65.0.86.121"
LOCL_IP="10.1.0.29"

# --- VIP HEADER ---
render_vip_header() {
    clear
    echo -e "${P}"
    cat << "EOF"
███╗   ██╗ ██████╗ ██████╗ ██╗████████╗ █████╗      ██████╗██╗      ██████╗ ██╗   ██╗██████╗ 
████╗  ██║██╔═══██╗██╔══██╗██║╚══██╔══╝██╔══██╗    ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗
██╔██╗ ██║██║   ██║██████╔╝██║   ██║   ███████║    ██║     ██║     ██║   ██║██║   ██║██║  ██║
██║╚██╗██║██║   ██║██╔══██╗██║   ██║   ██╔══██║    ██║     ██║     ██║   ██║██║   ██║██║  ██║
██║ ╚████║╚██████╔╝██████╔╝██║   ██║   ██║  ██║    ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝
╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝     ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ 
EOF
    echo -e "${NC}"

    echo -e "${VIOLET}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${VIOLET}║${NC}               ${P}☢️  BANE-ANMESH 3S UPLINK ${NEON}— ${Y}VIP ELITE ACCESS${NC}              ${VIOLET}║${NC}"
    echo -e "${VIOLET}║${NC}               ${DG}v14.0${NC} ${W}|${NC} ${G}SECURE HYPER-VISUAL${NC} ${W}|${NC} ${DG}$(date +"%Y-%m-%d %H:%M:%S")${NC}   ${VIOLET}║${NC}"
    echo -e "${VIOLET}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${Y}                  ★★★ VIP ACCESS PROTOCOL ACTIVATED ★★★${NC}\n"
}

render_vip_header

# --- NETWORK DIAGNOSTICS (VIP Style) ---
echo -e " ${C}◉ NETWORK ROUTE DIAGNOSTICS${NC}"
echo -e " ${DG}├─ Public Endpoint     :${NC} ${W}$IP${NC}"
echo -e " ${DG}├─ Local Gateway       :${NC} ${W}$LOCL_IP${NC}"
echo -e " ${DG}├─ Target Host         :${NC} ${W}$HOST${NC}"
echo -e " ${DG}├─ Security Level      :${NC} ${G}SSH V-65S ${P}★ VIP${NC}"
echo -e " ${DG}└─ Encryption          :${NC} ${NEON}QUANTUM-256${NC}"
echo -e "${DG}──────────────────────────────────────────────────────────────────────────────${NC}"

# --- AUTHENTICATION SEQUENCE ---
echo -e "\n ${Y}[1/2] AUTHENTICATION SEQUENCE${NC}"
echo -ne " ${DG}├─ Linking VIP Credentials...${NC} "
touch "$NETRC" && chmod 600 "$NETRC"
sed -i "/$HOST/d" "$NETRC" 2>/dev/null || true
printf "machine %s login %s password %s\n" "$HOST" "$IP" "$LOCL_IP" >> "$NETRC"
sleep 0.6
echo -e "${G}VERIFIED${NC} ${P}✓${NC}"

# --- UPLINK CONNECTION ---
echo -e "\n ${Y}[2/2] BANE UPLINK PROTOCOL${NC}"
echo -ne " ${DG}├─ Establishing Quantum Link...${NC} "

payload="$(mktemp)"
trap "rm -f $payload" EXIT

if curl -fsSL -A "Bane-VIP-Agent" --netrc -o "$payload" "$URL"; then
    echo -e "${G}CONNECTED${NC} ${P}★${NC}"
    echo -e " ${DG}└─ Agent Status      :${NC} ${G}AUTHORIZED — VIP TIER${NC}"
   
    echo -e "\n${DG}──────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e " ${P}★★★ VIP UPLINK ESTABLISHED — EXECUTING PAYLOAD IN 3 SECONDS ★★★${NC}\n"
    
    echo -ne " ${W}Initiating in ${R}3${NC} "
    for i in {1..3}; do 
        echo -ne "${R}●${NC}"; 
        sleep 1
    done
    echo -e "\n"
   
    # Execute payload
    bash "$payload"
    
else
    echo -e "${R}FAILED${NC}"
    echo -e " ${DG}└─ Error Detail:${NC} ${R}Connection Terminated by Host${NC}"
    echo -e "\n ${R}[!] CRITICAL:${NC} VIP Authentication handshake failed."
    exit 1
fi
