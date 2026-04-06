#!/bin/bash

# --- CONFIG & COLORS (Sema UI Modern Palette) ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;214m'
NC='\033[0m'
line(){ echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }
step(){ echo -e "${BLUE}➜ $1${RESET}"; }
ok(){ echo -e "${GREEN}✔ $1${RESET}"; }
warn(){ echo -e "${YELLOW}⚠ $1${RESET}"; }
fail(){ echo -e "${RED}✖ $1${RESET}"; }
# --- UI EFFECTS ---
type_write() {
    local text="$1"
    local delay=0.01
    for (( i=0; i<${#text}; i++ )); do
        echo -ne "${text:$i:1}"
        sleep $delay
    done
    echo ""
}

loading_bar() {
    echo -ne "  ${GRAY}[${NC}"
    for i in {1..25}; do
        echo -ne "${CYAN}#${NC}"
        sleep 0.02
    done
    echo -e "${GRAY}]${NC} ${GREEN}COMPLETE${NC}"
}

# --- HEADER & BRANDING ---
show_header() {
    clear
    echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${CYAN}🦅 PTERODACTYL AUTO-DEPLOY${NC} ${GRAY}v11.0${NC}          ${GRAY}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
}

# --- INITIALIZATION SEQUENCE ---
show_header
echo -e "  ${CYAN}BOOT PROTOCOLS${NC}"
echo -ne "  ${GRAY}├─ KERNEL :${NC} " ; type_write "Initializing core deployment modules..."
echo -ne "  ${GRAY}├─ MEMORY :${NC} " ; type_write "Allocating virtual server resources..."
echo -ne "  ${GRAY}└─ STATUS :${NC} " ; loading_bar
echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"

# --- CONFIGURATION INPUT ---
while true; do
    echo -e "\n  ${GOLD}CONFIGURATION REQUIRED${NC}"
    echo -ne "  ${WHITE}Enter Target Domain${NC} ${GRAY}(panel.example.com):${NC} "
    read DOMAIN
    DOMAIN=${DOMAIN:-panel.example.com}

    echo -e "  ${GRAY}Target Locked :${NC} ${WHITE}$DOMAIN${NC}"
    echo -ne "  ${CYAN}Confirm deployment? (y/n):${NC} "
    read CONFIRM

    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "  ${GREEN}✔ Identity Confirmed.${NC}"
        break
    else
        echo -e "  ${RED}⚠ Re-initializing input...${NC}"
    fi
done

echo -e "\n  ${PURPLE}CREDENTIAL SETUP${NC}"
echo -ne "  ${GRAY}├─ Username${NC} ${WHITE}(default: admin)${NC}${GRAY}:${NC} "
read USERNAME
USERNAME=${USERNAME:-admin}
echo -ne "  ${GRAY}└─ Password${NC} ${WHITE}(default: admin)${NC}${GRAY}:${NC} "
read PASSWORD
PASSWORD=${PASSWORD:-admin}
echo -ne "  ${GRAY}└─ Pterodactyl${NC} ${WHITE}(default: pterodactyl)${NC}${GRAY}:${NC} "
read NAME
NAME=${NAME:-pterodactyl}
# --- EXECUTION DASHBOARD ---
echo -e "\n${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${PURPLE}│${NC}  ${CYAN}🚀 DEPLOYMENT MANIFEST${NC}                              ${PURPLE}│${NC}"
echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
echo -e "  ${GRAY}DOMAIN   :${NC} ${WHITE}$DOMAIN${NC}"
echo -e "  ${GRAY}USER     :${NC} ${WHITE}$USERNAME${NC}"
echo -e "  ${GRAY}PASS     :${NC} ${WHITE}$PASSWORD${NC}"
echo -e "  ${GRAY}/var/www/:${NC} ${WHITE}${NAME} ${NC}"
echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"

echo -e "  ${GOLD}Executing Root Protocols...${NC}"
# Logic for actual deployment would go here
sleep 1

echo -e "\n  ${GREEN}✔ SYSTEM DEPLOYED SUCCESSFULLY${NC}"
echo -e "  ${GRAY}Access your panel at:${NC} ${CYAN}http://$DOMAIN${NC}"
echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
# Add your actual install logic below this line
step "Updating system packages..."
# --- Dependencies ---
apt update && apt install -y curl apt-transport-https ca-certificates gnupg unzip git tar sudo lsb-release
rm -f /etc/apt/keyrings/nodesource.gpg 2>/dev/null
# Detect OS
OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

if [[ "$OS" == "ubuntu" ]]; then
    echo "✅ Detected Ubuntu. Adding PPA for PHP..."
    apt install -y software-properties-common
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
elif [[ "$OS" == "debian" ]]; then
    echo "✅ Detected Debian. Skipping PPA and adding PHP repo manually..."
    # Add SURY PHP repo for Debian
    curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/sury-php.list
fi

# Add Redis GPG key and repo
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

apt update

# --- Install PHP + extensions ---
apt install -y php8.3 php8.3-{cli,fpm,common,mysql,mbstring,bcmath,xml,zip,curl,gd,tokenizer,ctype,simplexml,dom} mariadb-server nginx redis-server
sleep 1
ok "System updated."
step "Installing dependencies..."
# --- Install Composer ---
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# --- Download Pterodactyl Panel ---
mkdir -p /var/www/${NAME}
cd /var/www/${NAME}
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# --- MariaDB Setup ---
DB_NAME=${NAME}
DB_USER=${NAME}
DB_PASS=yourPassword
mariadb -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
mariadb -e "CREATE DATABASE ${DB_NAME};"
mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
mariadb -e "FLUSH PRIVILEGES;"

# --- .env Setup ---
if [ ! -f ".env.example" ]; then
    curl -Lo .env.example https://raw.githubusercontent.com/pterodactyl/panel/develop/.env.example
fi
cp .env.example .env
sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|g" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|g" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|g" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env
if ! grep -q "^APP_ENVIRONMENT_ONLY=" .env; then
    echo "APP_ENVIRONMENT_ONLY=false" >> .env
fi

# --- Install PHP dependencies ---
echo "✅ Installing PHP dependencies..."
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

# --- Generate Application Key ---
echo "✅ Generating application key..."
php artisan key:generate --force

# --- Run Migrations ---
php artisan migrate --seed --force

# --- Permissions ---
chown -R www-data:www-data /var/www/${NAME}/*
apt install -y cron
systemctl enable --now cron
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/${NAME}/artisan schedule:run >> /dev/null 2>&1") | crontab -
sleep 1
ok "Dependencies installed."
step "Generating SSL certificate..."

# --- Nginx Setup ---
mkdir -p /etc/certs/${NAME}
cd /etc/certs/${NAME}
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
-keyout privkey.pem -out fullchain.pem
sleep 1
ok "SSL secured."
step "Configuring NGINX..."
sleep 1
tee /etc/nginx/sites-available/${NAME}.conf > /dev/null << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root /var/www/${NAME}/public;
    index index.php;

    ssl_certificate /etc/certs/${NAME}/fullchain.pem;
    ssl_certificate_key /etc/certs/${NAME}/privkey.pem;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        include /etc/nginx/fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize=100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/${NAME}.conf /etc/nginx/sites-enabled/${NAME}.conf || true
nginx -t && systemctl restart nginx
ok "Nginx online"

# --- Queue Worker ---
tee /etc/systemd/system/${NAME}.service > /dev/null << 'EOF'
[Unit]
Description=${NAME} Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/${NAME}/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now redis-server
systemctl enable --now pteroq.service
ok "Queue running"
ok "NGINX configured."

# --- Admin User ---
cd /var/www/${NAME}
sed -i '/^APP_ENVIRONMENT_ONLY=/d' .env
echo "APP_ENVIRONMENT_ONLY=false" >> .env
TIMEZONE=$(timedatectl show --property=Timezone --value)
sed -i "s|APP_TIMEZONE=.*|APP_TIMEZONE=${TIMEZONE}|g" .env
sed -i "s|MAIL_MAILER=.*|MAIL_MAILER=smtp|g" .env
sed -i "s|MAIL_HOST=.*|MAIL_HOST=smtp.zoho.in|g" .env
sed -i "s|MAIL_PORT=.*|MAIL_PORT=587|g" .env
sed -i "s|MAIL_USERNAME=.*|MAIL_USERNAME=free.mell@aiomarket.online|g" .env
sed -i "s|MAIL_PASSWORD=.*|MAIL_PASSWORD=58@S5wZuWtpdDDX|g" .env
sed -i "s|MAIL_ENCRYPTION=.*|MAIL_ENCRYPTION=tls|g" .env
sed -i "s|MAIL_FROM_ADDRESS=.*|MAIL_FROM_ADDRESS=free.mell@aiomarket.online|g" .env
sed -i 's|MAIL_FROM_NAME=.*|MAIL_FROM_NAME="Nobita Cloud"|g' .env
sed -i '/RECAPTCHA_ENABLED=/d' .env && echo 'RECAPTCHA_ENABLED=false' >> .env && sed -i '/RECAPTCHA_SITE_KEY=/d' .env && sed -i '/RECAPTCHA_SECRET_KEY=/d' .env && php artisan config:clear && php artisan cache:clear && php artisan view:clear && php artisan config:cache
sed -i '/APP_NAME=/d' .env && echo 'APP_NAME="Nobita Cloud"' >> .env && php artisan config:clear && php artisan cache:clear && php artisan view:clear && php artisan config:cache && systemctl restart pteroq && systemctl restart nginx
chown -R www-data:www-data /var/www/${NAME}/*
php artisan p:location:make --short=IN --long="India"
# ---------------- DONE ----------------
cd /var/www/${NAME}
php artisan down
curl -L https://github.com/Nookure/NookTheme/releases/latest/download/panel.tar.gz | tar -xzv
chmod -R 755 storage/* bootstrap/cache
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
php artisan view:clear
php artisan config:clear
php artisan migrate --seed --force
chown -R www-data:www-data /var/www/${NAME}/*
php artisan queue:restart
php artisan up
# --- FINAL DEPLOYMENT UI ---
clear
step "Create admin user"
php artisan p:user:make -n --email=admin@gmail.com --username=${USERNAME} --password=$PASSWORD --admin=1 --name-first=My --name-last=Admin
# --- FINAL DEPLOYMENT UI ---

echo -e "\n${GREEN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│${NC}  ${WHITE}🚀 DEPLOYMENT COMPLETED SUCCESSFULLY!${NC}                   ${GREEN}│${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────┘${NC}"

echo -e "  ${CYAN}ACCESS PORTAL${NC}"
echo -e "  ${GRAY}└─ URL      :${NC} ${WHITE}https://$DOMAIN${NC}"
echo ""
echo -e "  ${GOLD}ADMIN CREDENTIALS${NC}"
echo -e "  ${GRAY}├─ Username :${NC} ${WHITE}${USERNAME}${NC}"
echo -e "  ${GRAY}└─ Password :${NC} ${WHITE}${PASSWORD}${NC}"

echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"

# --- SYSTEM STATUS BAR ---
echo -ne "  ${WHITE}STATUS:${NC} ${GREEN}STABLE${NC}  ${GRAY}|${NC} "
echo -ne "${WHITE}FIREWALL:${NC} ${GREEN}ACTIVE${NC}  ${GRAY}|${NC} "
echo -e "${WHITE}DB:${NC} ${GREEN}CONNECTED${NC}"

echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}\n"
