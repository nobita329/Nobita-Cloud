#!/bin/bash

# --- CONFIG & COLORS ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;214m'
NC='\033[0m'

# --- INSTALLER UI HEADER ---
show_header() {
    clear
    echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${CYAN}🚀 CONVOY PANEL AUTO-INSTALLER${NC} ${GRAY}v1.0${NC}             ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
}

# --- CHECK PRE-EXISTING ---
check_status() {
    local name=$1
    local cmd=$2
    if command -v "$cmd" &> /dev/null || [ -d "$cmd" ]; then
        echo -e "  ${GRAY}├─ $name :${NC} ${GREEN}ALREADY INSTALLED (Skipping)${NC}"
        return 0
    else
        echo -e "  ${GRAY}├─ $name :${NC} ${RED}MISSING (Will Install)${NC}"
        return 1
    fi
}

# --- START INSTALLATION ---
show_header
echo -e "  ${CYAN}PRE-INSTALLATION CHECK${NC}"
check_status "MariaDB" "mariadb"
HAS_DB=$?
check_status "Docker" "docker"
HAS_DOCKER=$?
check_status "Convoy Files" "/var/www/convoy"
HAS_FILES=$?
echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"

# Ask for Domain first
echo -ne "\n  ${CYAN}λ${NC} ${WHITE}Enter Domain/IP (e.g. example.com):${NC} "
read DOMAIN

if [[ -z "$DOMAIN" ]]; then
    echo -e "  ${RED}✘ Error: Domain is required!${NC}"
    exit 1
fi
systemctl stop apache2 && systemctl disable apache2 && apt purge -y apache2 apache2-* && apt autoremove -y && rm -rf /etc/apache2 /var/www/html
# 1. Update System
echo -e "\n  ${PURPLE}[1/5]${NC} ${WHITE}Updating System Repositories...${NC}"
apt update && apt upgrade -y > /dev/null 2>&1

# 2. Database Setup
if [ $HAS_DB -eq 1 ]; then
    echo -e "  ${PURPLE}[2/5]${NC} ${WHITE}Installing & Configuring MariaDB...${NC}"
    apt install mariadb-server -y > /dev/null 2>&1
    systemctl start mariadb && systemctl enable mariadb
    
    DB_NAME="convoy"
    DB_USER="convoy_user"
    DB_PASS=$(openssl rand -base64 12) # Auto-generated secure pass
    
    mariadb -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
    mariadb -e "CREATE DATABASE ${DB_NAME};"
    mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
    mariadb -e "FLUSH PRIVILEGES;"
    echo -e "  ${GRAY}└─ DB Credentials saved to .env later.${NC}"
else
    # If DB exists, ask for existing creds or use defaults
    DB_NAME="convoy"; DB_USER="convoy_user"; DB_PASS="yourPassword"
fi

# 3. Docker Installation
if [ $HAS_DOCKER -eq 1 ]; then
    echo -e "  ${PURPLE}[3/5]${NC} ${WHITE}Installing Docker Engine...${NC}"
    curl -fsSL https://get.docker.com/ | sh > /dev/null 2>&1
else
    echo -e "  ${PURPLE}[3/5]${NC} ${WHITE}Docker detected. Skipping install.${NC}"
fi

# 4. Convoy Core Setup
if [ $HAS_FILES -eq 1 ]; then
    echo -e "  ${PURPLE}[4/5]${NC} ${WHITE}Downloading Convoy Panel files...${NC}"
    mkdir -p /var/www/convoy
    cd /var/www/convoy
    curl -Lo panel.tar.gz https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz > /dev/null
    chmod -R o+w storage/* bootstrap/cache/
    cp .env.example .env

    # Configure .env
    sed -i "s|APP_URL=.*|APP_URL=http://${DOMAIN}|g" .env
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|g" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|g" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env
    sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$(openssl rand -base64 10)|g" .env
    sed -i "s|APP_ENV=.*|APP_ENV=production|g" .env
    sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" .env
else
    cd /var/www/convoy
    echo -e "  ${PURPLE}[4/5]${NC} ${WHITE}Convoy directory exists. Updating config...${NC}"
    sed -i "s|APP_URL=.*|APP_URL=http://${DOMAIN}|g" .env
fi
sed -i "s|MAIL_MAILER=.*|MAIL_MAILER=smtp|g" .env
sed -i "s|MAIL_HOST=.*|MAIL_HOST=smtp.zoho.in|g" .env
sed -i "s|MAIL_PORT=.*|MAIL_PORT=587|g" .env
sed -i "s|MAIL_USERNAME=.*|MAIL_USERNAME=free.mell@aiomarket.online|g" .env
sed -i "s|MAIL_PASSWORD=.*|MAIL_PASSWORD=58@S5wZuWtpdDDX|g" .env
sed -i "s|MAIL_ENCRYPTION=.*|MAIL_ENCRYPTION=tls|g" .env
sed -i "s|MAIL_FROM_ADDRESS=.*|MAIL_FROM_ADDRESS=free.mell@aiomarket.online|g" .env
sed -i 's|MAIL_FROM_NAME=.*|MAIL_FROM_NAME="Nobita Cloud"|g' .env
# 5. Finalizing with Docker Compose
echo -e "  ${PURPLE}[5/5]${NC} ${WHITE}Building Containers & Migrating Database...${NC}"
docker compose up -d
docker compose exec workspace bash -c "composer install --no-dev --optimize-autoloader"
docker compose exec workspace bash -c "php artisan key:generate --force && php artisan optimize"
docker compose exec workspace php artisan migrate --force
echo -e "  ${GOLD}Creating Admin User...${NC}"
docker compose exec workspace php artisan c:user:make
echo -e "\n${GREEN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│${NC}  ${WHITE}INSTALLATION COMPLETE!${NC}                                  ${GREEN}│${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────┘${NC}"
echo -e "  ${CYAN}URL      :${NC} ${WHITE}http://${DOMAIN}${NC}"
echo -e "  ${CYAN}Database :${NC} ${WHITE}${DB_NAME}${NC}"
echo -e "  ${CYAN}DB User  :${NC} ${WHITE}${DB_USER}${NC}"
echo -e "  ${CYAN}DB Pass  :${NC} ${WHITE}${DB_PASS}${NC}"
echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
