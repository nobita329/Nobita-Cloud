#!/bin/bash

# ==================================================
#  OMNI-ADMIN v201 | TITAN EDITION (AUTO-FIXED)
# ==================================================

# --- THEME & COLORS ---
R="\e[1;31m"; G="\e[1;32m"; Y="\e[1;33m"; B="\e[1;34m"; M="\e[1;35m"; C="\e[1;36m"; W="\e[1;37m"; GR="\e[1;90m"; N="\e[0m"

# --- CONFIG ---
LOG_FILE="$HOME/omni_titan.log"
BACKUP_DIR="$HOME/omni_backups"
mkdir -p "$BACKUP_DIR"

# --- SMART AUTO-FIX INSTALLER ---
auto_install() {
    local PKG=$1
    if ! command -v "$PKG" &>/dev/null; then
        echo -ne "${Y} [AUTO-FIX] Missing tool: $PKG. Installing... ${N}"
        if [ -f /etc/debian_version ]; then
            sudo apt-get update -qq >/dev/null 2>&1
            sudo apt-get install -y -qq "$PKG" >/dev/null 2>&1
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y -q "$PKG" >/dev/null 2>&1
        elif [ -f /etc/arch-release ]; then
            sudo pacman -S --noconfirm "$PKG" >/dev/null 2>&1
        fi
    fi
}

pause() { 
    echo -e "\n${GR}────────────────────────────────────────${N}"
    read -p " ↩ Press Enter to return..." _ 
}

# --- HEADER UI ---
draw_header() {
    clear
    CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    RAM=$(free -m | awk '/Mem/ {printf "%.1f", $3/$2*100}')
    
    echo -e "${C} ╔═════════════════════════════════════════════════════════════╗${N}"
    echo -e "${C} ║${W}  OMNI-ADMIN v201 ${GR}|${Y} TITAN EDITION ${GR}|${M} $(whoami)@$(hostname) ${C}║${N}"
    echo -e "${C} ╠═════════════════════════════════════════════════════════════╣${N}"
    echo -e "${C} ║${GR}  CPU: ${G}${CPU}%${GR}  │  RAM: ${G}${RAM}%${GR}  │  KERNEL: ${B}$(uname -r)${C}  ║${N}"
    echo -e "${C} ╚═════════════════════════════════════════════════════════════╝${N}"
    echo ""
}

# ==================================================
#  CATEGORY 1: SYSTEM & HARDWARE
# ==================================================
menu_sys() {
    while true; do
        draw_header
        echo -e "${M} [ CATEGORY 1: SYSTEM & HARDWARE ]${N}"
        printf "${GR} 0.${W} %-25s ${GR}11.${W} %-25s\n" "All Info" "All Devices"
        printf "${GR} 1.${W} %-25s ${GR}11.${W} %-25s\n" "OS Release Info" "PCI Devices"
        printf "${GR} 2.${W} %-25s ${GR}12.${W} %-25s\n" "Kernel Version" "USB Devices"
        printf "${GR} 3.${W} %-25s ${GR}13.${W} %-25s\n" "CPU Architecture" "Block Devices (lsblk)"
        printf "${GR} 4.${W} %-25s ${GR}14.${W} %-25s\n" "CPU Cores/Threads" "Disk Space (df)"
        printf "${GR} 5.${W} %-25s ${GR}15.${W} %-25s\n" "RAM Utilization" "Disk Inodes"
        printf "${GR} 6.${W} %-25s ${GR}16.${W} %-25s\n" "Uptime Detail" "Mount Points"
        printf "${GR} 7.${W} %-25s ${GR}17.${W} %-25s\n" "Load Average" "Hardware List (lshw)"
        printf "${GR} 8.${W} %-25s ${GR}18.${W} %-25s\n" "Hostname Info" "BIOS/Firmware Info"
        printf "${GR} 9.${W} %-25s ${GR}19.${W} %-25s\n" "System Date/Time" "Sensor Temps"
        printf "${GR}10.${W} %-25s ${GR}20.${W} %-25s\n" "Last Reboot Log" "Battery Status"
        echo -e "${R} 0. Back to Main Menu${N}"
        read -p " Select Tool > " opt
        
        case $opt in
            0) curl -sL yabs.sh | bash ;;
            1) cat /etc/*release ;;
            2) uname -a ;;
            3) lscpu | grep Architecture ;;
            4) lscpu | grep -E '^Thread|^Core|^Socket' ;;
            5) free -h ;;
            6) uptime -p ;;
            7) uptime ;;
            8) hostnamectl ;;
            9) date ;;
            10) last reboot | head -5 ;;
            11) command -v lspci >/dev/null || apt install pciutils -y >/dev/null 2>&1; lspci; pause ;;
            12) command -v lspci >/dev/null || apt install pciutils -y >/dev/null 2>&1; lspci; pause ;;
            13) command -v lsblk >/dev/null || apt install util-linux -y >/dev/null 2>&1; lsblk; pause ;;
            14) df -hT --exclude-type=tmpfs ;;
            15) df -i ;;
            16) mount | column -t ;;
            17) auto_install lshw; sudo lshw -short ;;
            18) [ -d /sys/firmware/efi ] && echo "UEFI Boot" || echo "Legacy BIOS" ;;
            19) auto_install lm-sensors; sensors ;;
            20) acpi -bi 2>/dev/null || echo "No battery detected" ;;
            0) return ;; # Breaks loop, returns to main menu
            *) echo "Invalid option"; sleep 1; continue ;;
        esac
        pause
    done
}

# ==================================================
#  CATEGORY 2: NETWORK
# ==================================================
menu_net() {
    while true; do
        draw_header
        echo -e "${B} [ CATEGORY 2: NETWORK & INTERNET ]${N}"
        printf "${GR}21.${W} %-25s ${GR}31.${W} %-25s\n" "IP Address (All)" "Ping Google"
        printf "${GR}22.${W} %-25s ${GR}32.${W} %-25s\n" "Public IP (Curl)" "Ping Custom"
        printf "${GR}23.${W} %-25s ${GR}33.${W} %-25s\n" "DNS Lookup (Dig)" "Traceroute"
        printf "${GR}24.${W} %-25s ${GR}34.${W} %-25s\n" "Whois Domain" "MTR (Live Trace)"
        printf "${GR}25.${W} %-25s ${GR}35.${W} %-25s\n" "Netstat Listening" "Speedtest CLI"
        printf "${GR}26.${W} %-25s ${GR}36.${W} %-25s\n" "SS Active Conns" "Download File (Wget)"
        printf "${GR}27.${W} %-25s ${GR}37.${W} %-25s\n" "Route Table" "HTTP Headers (Curl)"
        printf "${GR}28.${W} %-25s ${GR}38.${W} %-25s\n" "ARP Table" "Scan Local Network"
        printf "${GR}29.${W} %-25s ${GR}39.${W} %-25s\n" "Interface Stats" "Bandwidth (nload)"
        printf "${GR}30.${W} %-25s ${GR}40.${W} %-25s\n" "Flush DNS Cache" "Wifi Signal (Linux)"
        echo -e "${R} 0. Back to Main Menu${N}"
        read -p " Select Tool > " opt
        
        case $opt in
            21) ip a ;;
            22) curl -s ifconfig.me ;;
            23) read -p "Domain: " d; auto_install dnsutils; dig "$d" +short ;;
            24) read -p "Domain: " d; auto_install whois; whois "$d" | head -20 ;;
            25) netstat -tulpn ;;
            26) ss -tuna ;;
            27) ip route ;;
            28) ip neigh ;;
            29) ip -s link ;;
            30) sudo systemd-resolve --flush-caches && echo "Flushed." ;;
            31) ping -c 4 google.com ;;
            32) read -p "Host: " h; ping -c 4 "$h" ;;
            33) read -p "Host: " h; traceroute "$h" ;;
            34) read -p "Host: " h; auto_install mtr; mtr "$h" ;;
            35) auto_install speedtest-cli; speedtest-cli --simple ;;
            36) read -p "URL: " u; wget "$u" ;;
            37) read -p "URL: " u; curl -I "$u" ;;
            38) auto_install nmap; nmap -sn 192.168.1.0/24 ;;
            39) auto_install nload; nload ;;
            40) nmcli dev wifi ;;
            0) return ;;
            *) echo "Invalid option"; sleep 1; continue ;;
        esac
        pause
    done
}

# ==================================================
#  CATEGORY 3: SECURITY
# ==================================================
menu_sec() {
    while true; do
        draw_header
        echo -e "${R} [ CATEGORY 3: SECURITY OPS ]${N}"
        printf "${GR}41.${W} %-25s ${GR}51.${W} %-25s\n" "Firewall Status" "Check Rootkits"
        printf "${GR}42.${W} %-25s ${GR}52.${W} %-25s\n" "Fail2Ban Status" "Audit SSH Config"
        printf "${GR}43.${W} %-25s ${GR}53.${W} %-25s\n" "Last Logins" "Check Sudo Users"
        printf "${GR}44.${W} %-25s ${GR}54.${W} %-25s\n" "Failed Auth Logs" "Passwd File Check"
        printf "${GR}45.${W} %-25s ${GR}55.${W} %-25s\n" "Current Users" "Open Ports (Nmap)"
        printf "${GR}46.${W} %-25s ${GR}56.${W} %-25s\n" "Password Expiry" "File Permissions"
        printf "${GR}47.${W} %-25s ${GR}57.${W} %-25s\n" "Lock User" "Lynis Audit"
        printf "${GR}48.${W} %-25s ${GR}58.${W} %-25s\n" "Unlock User" "SELinux Status"
        printf "${GR}49.${W} %-25s ${GR}59.${W} %-25s\n" "Kick User" "AppArmor Status"
        printf "${GR}50.${W} %-25s ${GR}60.${W} %-25s\n" "Kill User Procs" "History Cleaner"
        echo -e "${R} 0. Back to Main Menu${N}"
        read -p " Select Tool > " opt
        
        case $opt in
            41) sudo ufw status 2>/dev/null || echo "UFW not found" ;;
            42) sudo fail2ban-client status 2>/dev/null || echo "Fail2ban not found" ;;
            43) last -n 10 ;;
            44) sudo grep "Failed" /var/log/auth.log | tail -10 ;;
            45) w ;;
            46) read -p "User: " u; sudo chage -l "$u" ;;
            47) read -p "User: " u; sudo passwd -l "$u" ;;
            48) read -p "User: " u; sudo passwd -u "$u" ;;
            49) read -p "User: " u; sudo pkill -u "$u" ;;
            50) read -p "User: " u; sudo killall -u "$u" ;;
            51) auto_install rkhunter; sudo rkhunter --check --sk ;;
            52) grep "^PermitRoot" /etc/ssh/sshd_config ;;
            53) grep sudo /etc/group ;;
            54) cat /etc/passwd ;;
            55) auto_install nmap; nmap -sT localhost ;;
            56) read -p "File: " f; ls -la "$f" ;;
            57) auto_install lynis; sudo lynis audit system --quick ;;
            58) sestatus 2>/dev/null || echo "Not SELinux system" ;;
            59) aa-status 2>/dev/null || echo "Not AppArmor system" ;;
            60) history -c; echo "History cleared in RAM" ;;
            0) return ;;
            *) echo "Invalid option"; sleep 1; continue ;;
        esac
        pause
    done
}

# ==================================================
#  CATEGORY 4: MAINTENANCE
# ==================================================
menu_maint() {
    while true; do
        draw_header
        echo -e "${Y} [ CATEGORY 4: MAINTENANCE ]${N}"
        printf "${GR}61.${W} %-25s ${GR}71.${W} %-25s\n" "Update System" "Edit Crontab"
        printf "${GR}62.${W} %-25s ${GR}72.${W} %-25s\n" "Upgrade System" "List Crons"
        printf "${GR}63.${W} %-25s ${GR}73.${W} %-25s\n" "Clean Packages" "Systemd Failed"
        printf "${GR}64.${W} %-25s ${GR}74.${W} %-25s\n" "Empty Trash" "Journal Vacuum"
        printf "${GR}65.${W} %-25s ${GR}75.${W} %-25s\n" "Clear Thumbnails" "List Services"
        printf "${GR}66.${W} %-25s ${GR}76.${W} %-25s\n" "Restart Network" "Restart SSH"
        printf "${GR}67.${W} %-25s ${GR}77.${W} %-25s\n" "Sync Time (NTP)" "Stop Service"
        printf "${GR}68.${W} %-25s ${GR}78.${W} %-25s\n" "Backup Home" "Start Service"
        printf "${GR}69.${W} %-25s ${GR}79.${W} %-25s\n" "Find Large Files" "Enable Service"
        printf "${GR}70.${W} %-25s ${GR}80.${W} %-25s\n" "Memory Cache Drop" "Disable Service"
        echo -e "${R} 0. Back to Main Menu${N}"
        read -p " Select Tool > " opt
        
        case $opt in
            61) sudo apt update || sudo yum check-update ;;
            62) sudo apt upgrade -y || sudo yum update -y ;;
            63) sudo apt autoremove -y || sudo yum autoremove ;;
            64) rm -rf ~/.local/share/Trash/* ;;
            65) rm -rf ~/.cache/thumbnails/* ;;
            66) sudo systemctl restart networking ;;
            67) sudo timedatectl set-ntp on ;;
            68) tar -czf "$BACKUP_DIR/home_bkp.tar.gz" /home/ ;;
            69) sudo find / -type f -size +100M ;;
            70) sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' ;;
            71) crontab -e ;;
            72) crontab -l ;;
            73) systemctl --failed ;;
            74) sudo journalctl --vacuum-time=2d ;;
            75) systemctl list-units --type=service ;;
            76) sudo systemctl restart ssh ;;
            77) read -p "Svc: " s; sudo systemctl stop "$s" ;;
            78) read -p "Svc: " s; sudo systemctl start "$s" ;;
            79) read -p "Svc: " s; sudo systemctl enable "$s" ;;
            80) read -p "Svc: " s; sudo systemctl disable "$s" ;;
            0) return ;;
            *) echo "Invalid option"; sleep 1; continue ;;
        esac
        pause
    done
}

# ==================================================
#  CATEGORY 5: DOCKER & WEB
# ==================================================
menu_web() {
    while true; do
        draw_header
        echo -e "${C} [ CATEGORY 5: DOCKER & WEB OPS ]${N}"
        printf "${GR}81.${W} %-25s ${GR}91.${W} %-25s\n" "Docker Version" "Nginx Status"
        printf "${GR}82.${W} %-25s ${GR}92.${W} %-25s\n" "List Containers" "Apache Status"
        printf "${GR}83.${W} %-25s ${GR}93.${W} %-25s\n" "Running Cont." "MySQL Status"
        printf "${GR}84.${W} %-25s ${GR}94.${W} %-25s\n" "Docker Images" "PHP Version"
        printf "${GR}85.${W} %-25s ${GR}95.${W} %-25s\n" "System Prune" "NodeJS Version"
        printf "${GR}86.${W} %-25s ${GR}96.${W} %-25s\n" "Stop All Cont." "Python Version"
        printf "${GR}87.${W} %-25s ${GR}97.${W} %-25s\n" "Kill All Cont." "Check Site SSL"
        printf "${GR}88.${W} %-25s ${GR}98.${W} %-25s\n" "Container Logs" "Access Logs"
        printf "${GR}89.${W} %-25s ${GR}99.${W} %-25s\n" "Docker Stats" "Error Logs"
        printf "${GR}90.${W} %-25s ${GR}100.${W} %-25s\n" "Docker Compose Up" "Certbot Renew"
        echo -e "${R} 0. Back to Main Menu${N}"
        read -p " Select Tool > " opt
        
        case $opt in
            81) docker --version ;;
            82) docker ps -a ;;
            83) docker ps ;;
            84) docker images ;;
            85) docker system prune -f ;;
            86) docker stop $(docker ps -a -q) ;;
            87) docker kill $(docker ps -a -q) ;;
            88) read -p "ID: " i; docker logs "$i" ;;
            89) docker stats --no-stream ;;
            90) docker-compose up -d ;;
            91) systemctl status nginx --no-pager ;;
            92) systemctl status apache2 --no-pager ;;
            93) systemctl status mysql --no-pager ;;
            94) php -v ;;
            95) node -v ;;
            96) python3 --version ;;
            97) read -p "Domain: " d; curl -vI https://"$d" 2>&1 | grep "expire" ;;
            98) tail -n 20 /var/log/nginx/access.log 2>/dev/null || echo "No Nginx Log" ;;
            99) tail -n 20 /var/log/nginx/error.log 2>/dev/null || echo "No Nginx Log" ;;
            100) sudo certbot renew --dry-run ;;
            0) return ;;
            *) echo "Invalid option"; sleep 1; continue ;;
        esac
        pause
    done
}

# ==================================================
#  MAIN MENU LOOP
# ==================================================
while true; do
    draw_header
    echo -e "${W} SELECT A MODULE (20 Tools Per Module):${N}"
    echo ""
    echo -e "  ${M}[1]${W} System & Hardware   ${GR}(Tools 1-20)${N}   ${GR}:: CPU, RAM, Disk, Info${N}"
    echo -e "  ${B}[2]${W} Network & Internet  ${GR}(Tools 21-40)${N}  ${GR}:: IP, DNS, Speed, Scan${N}"
    echo -e "  ${R}[3]${W} Security & Audit    ${GR}(Tools 41-60)${N}  ${GR}:: Firewall, Users, Perms${N}"
    echo -e "  ${Y}[4]${W} Maintenance & Ops   ${GR}(Tools 61-80)${N}  ${GR}:: Updates, Clean, Services${N}"
    echo -e "  ${C}[5]${W} Docker & Web Stack  ${GR}(Tools 81-100)${N} ${GR}:: Containers, Nginx, Logs${N}"
    echo ""
    echo -e "  ${R}[0]${W} EXIT TITAN PANEL${N}"
    echo ""
    echo -ne "${C}  root@info:~# ${N}"
    read main_opt

    case $main_opt in
        1) menu_sys ;;
        2) menu_net ;;
        3) menu_sec ;;
        4) menu_maint ;;
        5) menu_web ;;
        0) clear; echo "System Halted."; exit 0 ;;
        *) echo "Invalid"; sleep 1 ;;
    esac
done
