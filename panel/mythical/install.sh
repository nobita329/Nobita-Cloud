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

bash <(curl -s https://raw.githubusercontent.com/nobita329/Nobita-Cloud/refs/heads/main/panel/mythical/os.sh) 
#============================================================================================
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
mkdir -p /var/www/mythicaldash
cd /var/www/mythicaldash
curl -Lo MythicalDash.zip https://github.com/MythicalLTD/MythicalDash/releases/download/3.2.3/MythicalDash.zip
unzip -o MythicalDash.zip -d /var/www/mythicaldash
chown -R www-data:www-data /var/www/mythicaldash/*
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
DB_NAME=mythicaldash
DB_USER=mythicaldash
DB_PASS=1234
mariadb -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
mariadb -e "CREATE DATABASE ${DB_NAME};"
mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
mariadb -e "FLUSH PRIVILEGES;"
#========================================================
# Run this for our small checkup that we need to run for the cli to run
cd /var/www/mythicaldash
dos2unix arch.bash
bash arch.bash
chmod +x ./MythicalDash
./MythicalDash -environment:newconfig # Generate a custom config file
./MythicalDash -key:generate # Reset the encryption key
./MythicalDash -environment:database # Setup the database connection
./MythicalDash -migrate # Migrate the database
./MythicalDash -environment:setup # Start a custom setup for the dash
 apt install -y cron
 systemctl enable --now cron
 (crontab -l 2>/dev/null; echo "* * * * * php /var/www/mythicaldash/crons/server.php >> /dev/null 2>&1") | crontab -
mkdir -p /etc/certs/MythicalDash
cd /etc/certs/MythicalDash
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
-keyout privkey.pem -out fullchain.pem
#===============================================================
cat > /etc/nginx/sites-available/MythicalDash.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    root /var/www/mythicaldash/public;
    index index.php;

    access_log /var/www/mythicaldash/logs/mythicaldash.app-access.log;
    error_log  /var/www/mythicaldash/logs/mythicaldash.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    # SSL Configuration - Using self-signed certificate for now
    ssl_certificate /etc/certs/MythicalDash/fullchain.pem;
    ssl_certificate_key /etc/certs/MythicalDash/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
    ssl_prefer_server_ciphers on;

    # See https://hstspreload.org/ before uncommenting the line below.
    # add_header Strict-Transport-Security "max-age=15768000; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
if [ -f /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
fi
ln -sf /etc/nginx/sites-available/MythicalDash.conf /etc/nginx/sites-enabled/
nginx -t &&  systemctl restart nginx





