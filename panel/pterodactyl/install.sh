#!/bin/bash

# --- SEMA NEON THEME ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;214m'
NC='\033[0m'

# --- UI HELPER ---
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
  ██████╗ ███████╗████████╗███████╗██████╗  ██████╗ 
  ██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔═══██╗
  ██████╔╝█████╗     ██║   █████╗  ██████╔╝██║   ██║
  ██╔═══╝ ██╔══╝     ██║   ██╔══╝  ██╔══██╗██║   ██║
  ██║     ███████╗   ██║   ███████╗██║  ██║╚██████╔╝
  ╚═╝     ╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝ ╚═════╝ 
EOF
    echo -e "           ${WHITE}PREMIUM PTERODACTYL INSTALLER${NC}"
    echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
}

# --- INPUT FUNCTION ---
ask() {
    local label=$1
    local default=$2
    local var_name=$3
    echo -ne "  ${PURPLE}•${NC} ${WHITE}$label${NC} ${GRAY}[$default]${NC}\n  ${GRAY}╰─>${NC} "
    read input
    if [ -z "$input" ]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

# --- START ---
show_banner

# --- DATA COLLECTION ---
ask "Panel Domain" "panel.kavo.dpdns.org" DOMAIN
ask "Admin Email" "admin@gmail.com" EMAIL
ask "Admin Username" "admin" USERNAME
ask "Admin Password" "password123" PASSWORD

# --- FINAL VALIDATION LOOP ---
echo -e "\n  ${GOLD}┌─[ REVIEW CONFIGURATION ]${NC}"
echo -e "  ${GOLD}│${NC} ${GRAY}Domain:${NC}   $DOMAIN"
echo -e "  ${GOLD}│${NC} ${GRAY}Email:${NC}    $EMAIL"
echo -e "  ${GOLD}│${NC} ${GRAY}User:${NC}     $USERNAME"
echo -e "  ${GOLD}└───────────────────────────${NC}"

while true; do
    echo -ne "\n  ${CYAN}🚀 Start Installation?${NC} ${WHITE}(y/n)${NC}${GRAY}:${NC} "
    read -n 1 -r CONFIRM
    echo "" # Move to new line

    case $CONFIRM in
        [Yy]* ) 
            echo -e "  ${GREEN}✔ Proceeding to deployment...${NC}"
            break
            ;;
        [Nn]* ) 
            echo -e "  ${RED}✖ Installation aborted by user.${NC}"
            exit
            ;;
        * ) 
            echo -e "  ${GRAY}Invalid input. Please enter ${NC}${WHITE}y${NC}${GRAY} or ${NC}${WHITE}n${NC}${GRAY}.${NC}"
            ;;
    esac
done

# --- PROGRESS SIMULATION ---
echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
steps=("Core Setup" "Database Link" "Asset Build")
for step in "${steps[@]}"; do
    echo -ne "  ${PURPLE}process:${NC} $step..."
    sleep 1
    echo -e " ${GREEN}[COMPLETE]${NC}"
done

echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
echo -e "  ${CYAN}SUCCESS:${NC} ${WHITE}Panel is live at http://$DOMAIN${NC}"

# --- Dependencies ---
apt update && apt install -y curl apt-transport-https ca-certificates gnupg unzip git tar sudo lsb-release

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
sudo rm /usr/share/keyrings/redis-archive-keyring.gpg
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
apt update
# --- Install PHP + extensions ---
apt install -y php8.3 php8.3-{cli,fpm,common,mysql,mbstring,bcmath,xml,zip,curl,gd,tokenizer,ctype,simplexml,dom} mariadb-server nginx redis-server
# --- Install Composer ---
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
# --- Download Pterodactyl Panel ---
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/
# --- MariaDB Setup ---
DB_NAME=panel
DB_USER=pterodactyl
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
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
# --- Generate Application Key ---
php artisan key:generate --force
# --- Run Migrations ---
php artisan migrate --seed --force
# --- Permissions ---
chown -R www-data:www-data /var/www/pterodactyl/*
apt install -y cron
systemctl enable --now cron
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
# --- Nginx Setup ---
mkdir -p /etc/certs/panel
cd /etc/certs/panel
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
-keyout privkey.pem -out fullchain.pem

tee /etc/nginx/sites-available/pterodactyl.conf > /dev/null << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root /var/www/pterodactyl/public;
    index index.php;

    ssl_certificate /etc/certs/panel/fullchain.pem;
    ssl_certificate_key /etc/certs/panel/privkey.pem;

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

ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf || true
nginx -t && systemctl restart nginx

# --- Queue Worker ---
tee /etc/systemd/system/pteroq.service > /dev/null << 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now redis-server
systemctl enable --now pteroq.service
ok "Queue running"
clear
step "Create admin user"
# --- Admin User ---
cd /var/www/pterodactyl
sed -i '/^APP_ENVIRONMENT_ONLY=/d' .env
echo "APP_ENVIRONMENT_ONLY=false" >> .env
# Disable reCAPTCHA
sed -i '/RECAPTCHA_ENABLED=/d' .env
echo 'RECAPTCHA_ENABLED=false' >> .env
# Set app name
sed -i '/APP_NAME=/d' .env
echo 'APP_NAME="Nobita Cloud"' >> .env
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
php artisan p:location:make --short=IN --long="India"
# ---------------- DONE ----------------
php artisan down
curl -L https://github.com/Nookure/NookTheme/releases/latest/download/panel.tar.gz | tar -xzv
chmod -R 755 storage/* bootstrap/cache
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
php artisan view:clear
php artisan config:clear
php artisan config:clear
php artisan cache:clear
php artisan view:clear
php artisan config:cache
php artisan migrate --seed --force
chown -R www-data:www-data /var/www/pterodactyl/*
php artisan queue:restart
php artisan up
# --- END REPORT ---
php artisan p:user:make -n --email=$EMAIL --username=${USERNAME} --password=$PASSWORD --admin=1 --name-first=My --name-last=Admin
echo -e "  $header_line"
echo -e "\n  ${CYAN}DEPLOYMENT COMPLETE${NC}"
echo -e "  ${GRAY}Panel URL :${NC} ${WHITE}http://$DOMAIN${NC}"
echo -e "  ${GRAY}Username  :${NC} ${WHITE}$USERNAME${NC}"
echo -e "  ${GRAY}Password  :${NC} ${WHITE}$PASSWORD${NC}"
echo -e "  ${GRAY}Email     :${NC} ${WHITE}$EMAIL${NC}"
# Cleaned up the closing message
echo -e "\n  ${PURPLE}Enjoy your new Pterodactyl Panel!${NC}"
echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
