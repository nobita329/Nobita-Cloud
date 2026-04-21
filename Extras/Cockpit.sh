#!/bin/bash
set -e

# ===== Colors =====
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; W="\e[0m"

# ===== Detect Functions =====
svc_status() {
  systemctl is-active --quiet "$1" && echo -e "${G}RUNNING${W}" || echo -e "${R}STOPPED${W}"
}

detect_port() {
  ss -lntp 2>/dev/null | grep cockpit.socket | awk -F: '{print $NF}' | head -n1
}

COCKPIT_PORT=$(detect_port)
[[ -z "$COCKPIT_PORT" ]] && COCKPIT_PORT="9090"

# ===== UI =====
draw_header() {
clear
echo -e "${C}╔════════════════════════════════════════════╗${W}"
echo -e "${C}║${W}   🛠️  ${B}COCKPIT + KVM CONTROL PANEL${W}   ${C}║${W}"
echo -e "${C}╚════════════════════════════════════════════╝${W}"
echo ""
}

draw_status() {
echo -e "${Y}┌────────── SYSTEM STATUS ──────────┐${W}"
echo -e "${Y}│${W} Cockpit Socket : $(svc_status cockpit.socket)"
echo -e "${Y}│${W} Libvirt Daemon : $(svc_status libvirtd)"
echo -e "${Y}│${W} Cockpit Port  : ${C}$COCKPIT_PORT${W}"
echo -e "${Y}└───────────────────────────────────┘${W}"
echo ""
}

draw_menu() {
echo -e "${Y}┌──────────────── MENU ────────────────┐${W}"
echo -e "${Y}│${W} ${G}1${W}) Install"
echo -e "${Y}│${W} ${R}2${W}) Uninstall"
echo -e "${Y}│${W} ${C}3${W}) Change  Port"
echo -e "${Y}│${W} ${W}4${W}) Exit"
echo -e "${Y}└──────────────────────────────────────┘${W}"
echo ""
}

pause(){ read -rp "👉 Press Enter to continue..."; }

# ===== Actions =====
install_stack() {
echo -e "${G}🔥 Installing stack...${W}"

sudo apt update && sudo apt upgrade -y
sudo apt install -y cockpit
sudo systemctl enable --now cockpit.socket

sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
sudo systemctl enable --now libvirtd

sudo apt install -y cockpit-machines
sudo usermod -aG libvirt,kvm $USER

sudo rm -f /etc/cockpit/disallowed-users
sudo systemctl restart cockpit

echo -e "${G}✅ Install done.${W}"
pause
}

uninstall_stack() {
echo -e "${R}🧨 Removing stack...${W}"

sudo systemctl disable --now cockpit.socket || true
sudo systemctl disable --now libvirtd || true

sudo apt purge -y cockpit cockpit-machines virt-manager \
qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
sudo apt autoremove -y
sudo apt autoclean

echo -e "${R}❌ Removed.${W}"
pause
}

change_port() {
read -rp "🔢 New Cockpit port: " NEW_PORT
[[ ! "$NEW_PORT" =~ ^[0-9]+$ ]] && echo -e "${R}Invalid port${W}" && pause && return

sudo mkdir -p /etc/systemd/system/cockpit.socket.d
sudo tee /etc/systemd/system/cockpit.socket.d/listen.conf >/dev/null <<EOF
[Socket]
ListenStream=
ListenStream=$NEW_PORT
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart cockpit.socket

command -v ufw >/dev/null && sudo ufw allow $NEW_PORT/tcp && sudo ufw reload

echo -e "${G}✅ Port changed to $NEW_PORT${W}"
pause
}

# ===== Main Loop =====
while true; do
  COCKPIT_PORT=$(detect_port)
  [[ -z "$COCKPIT_PORT" ]] && COCKPIT_PORT="9090"

  draw_header
  draw_status
  draw_menu

  read -rp "Select [1-4]: " choice
  case "$choice" in
    1) install_stack ;;
    2) uninstall_stack ;;
    3) change_port ;;
    4) echo -e "${B}👋 Exit. System under control.${W}"; exit 0 ;;
    *) echo -e "${R}❌ Invalid choice${W}"; pause ;;
  esac
done
