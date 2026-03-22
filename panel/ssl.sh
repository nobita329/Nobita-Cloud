#!/bin/bash

# --- Colors & Formatting ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color
PHP_VERSION="8.3"
# --- Header ---
clear
echo -e "${CYAN}${BOLD}=========================================${NC}"
echo -e "${CYAN}      PTERODACTYL NGINX CONFIGURATOR     ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# --- 1. Selection Menu ---
echo -e "${BOLD}Select Configuration Mode:${NC}"
echo -e "  ${GREEN}[1]${NC} SSL / HTTPS ${YELLOW}(Secure)${NC}"
echo -e "  ${RED}[2]${NC} No SSL / HTTP ${YELLOW}(Insecure)${NC}"
echo -e "  ${RED}[2]${NC} CREATE / HTTP/HTTPS ${YELLOW}(Insecure)${NC}"
\
echo ""
read -p "Select option [1-2]: " OPTION

echo ""
echo -e "${CYAN}--- Configuration Details ---${NC}"
read -p "Enter your Domain (e.g., panel.example.com): " DOMAIN
# --- Check & Prepare ---
echo ""
echo -e "${YELLOW}[*] Preparing environment...${NC}"
cd /var/www/pterodactyl || { echo -e "${RED}[!] Pterodactyl directory not found!${NC}"; exit 1; }

# Remove old configs
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/pterodactyl.conf

# ================= SSL CONFIGURATION =================
if [ "$OPTION" == "1" ]; then
    echo -e "${YELLOW}[?] SSL Certificate Path Selection:${NC}"
    echo -e "    ${BOLD}y${NC} = Let's Encrypt (Standard)"
    echo -e "    ${BOLD}n${NC} = Custom/Default (/etc/certs/panel)"
    read -p "Use Let's Encrypt path? (y/n): " SSLTYPE

    if [ "$SSLTYPE" == "y" ]; then
        SETUP="letsencrypt/live/${DOMAIN}"
        FULLCHAIN="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
        PRIVKEY="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
    else
        SETUP="certs/panel"
        FULLCHAIN="/etc/certs/panel/fullchain.pem"
        PRIVKEY="/etc/certs/panel/privkey.pem"
    fi

    echo -e "${GREEN}[+] Setting APP_URL to HTTPS...${NC}"
    sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|g" .env

    # Create Nginx Config (SSL)
    cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
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

    ssl_certificate ${FULLCHAIN};
    ssl_certificate_key ${PRIVKEY};

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
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# ================= NO SSL CONFIGURATION =================
elif [ "$OPTION" == "2" ]; then
    echo -e "${YELLOW}[*] Preparing environment...${NC}"
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-available/pterodactyl.conf
    cd /var/www/pterodactyl || { echo -e "${RED}[!] Pterodactyl directory not found!${NC}"; exit 1; }
    echo -e "${GREEN}[+] Setting APP_URL to HTTP...${NC}"
    sed -i "s|APP_URL=.*|APP_URL=http://${DOMAIN}|g" .env

    # Create Nginx Config (Non-SSL)
    cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    root /var/www/pterodactyl/public;
    index index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize=100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

else
    echo -e "${RED}[!] Invalid Option selected. Exiting.${NC}"
    exit 1
fi

# --- Finalize ---
echo -e "${YELLOW}[*] Enabling Configuration...${NC}"
echo -e "${YELLOW}[*] Testing Nginx Configuration...${NC}"
nginx -t

if [ $? -eq 0 ]; then
    systemctl restart nginx
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${GREEN}✔ Setup Successfully Completed!${NC}"
    echo -e "Panel URL: ${BOLD}http$( [ "$OPTION" == "1" ] && echo "s" )://${DOMAIN}${NC}"
    echo -e "${CYAN}=========================================${NC}"
else
    echo ""
    echo -e "${RED}[!] Nginx configuration failed. Please check errors above.${NC}"
fi

# ================= NO SSL CONFIGURATION =================
elif [ "$OPTION" == "3" ]; then
# --- Header ---
clear
echo -e "${CYAN}${BOLD}=========================================${NC}"
echo -e "${CYAN}      AUTO SSL GENERATOR (Certbot)       ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
EMAIL="ssl$(tr -dc a-z0-9 </dev/urandom | head -c6)@nobita.com"
# --- 1. Get Inputs ---
read -p "Enter your Domain (e.g., panel.example.com): " DOMAIN
# --- 2. Install Dependencies ---
echo ""
echo -e "${YELLOW}[*] Updating system repositories...${NC}"
apt update -y

echo -e "${YELLOW}[*] Installing Certbot and Nginx plugin...${NC}"
apt install certbot python3-certbot-nginx -y
# --- 4. Run Certbot ---
echo ""
echo -e "${GREEN}[*] Requesting SSL Certificate...${NC}"

# The magic command
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL} --redirect

# --- 5. Verify Success ---
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${GREEN}✔ SSL Installed Successfully!${NC}"
    echo -e "${GREEN}✔ HTTPS Redirection Enabled.${NC}"
    echo -e "Your Panel is live at: ${BOLD}https://${DOMAIN}${NC}"
    echo -e "${CYAN}=========================================${NC}"
else
    echo ""
    echo -e "${RED}[!] SSL Generation Failed.${NC}"
    echo -e "${YELLOW}Please check if your domain points to this IP address.${NC}"
fi
