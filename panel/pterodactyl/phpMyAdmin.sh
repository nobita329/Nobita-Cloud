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
HEADER_LINE="${GRAY}────────────────────────────────────────────────────────────${NC}"
PHP_VERSION="8.3"

# --- UI HELPERS ---
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
                                                                                                                                                 dddddddd                                                                                                                                                                                                                                                                     dddddddd                                                                                        
                   hhhhhhh                                MMMMMMMM               MMMMMMMM                             AAA                        d::::::d                          iiii                                                                   iiii          tttt         hhhhhhh                  PPPPPPPPPPPPPPPPP            tttt                                                                               d::::::d                                              tttt                              lllllll 
                   h:::::h                                M:::::::M             M:::::::M                            A:::A                       d::::::d                         i::::i                                                                 i::::i      ttt:::t         h:::::h                  P::::::::::::::::P        ttt:::t                                                                               d::::::d                                           ttt:::t                              l:::::l 
                   h:::::h                                M::::::::M           M::::::::M                           A:::::A                      d::::::d                          iiii                                                                   iiii       t:::::t         h:::::h                  P::::::PPPPPP:::::P       t:::::t                                                                               d::::::d                                           t:::::t                              l:::::l 
                   h:::::h                                M:::::::::M         M:::::::::M                          A:::::::A                     d:::::d                                                                                                             t:::::t         h:::::h                  PP:::::P     P:::::P      t:::::t                                                                               d:::::d                                            t:::::t                              l:::::l 
ppppp   ppppppppp   h::::h hhhhh      ppppp   ppppppppp   M::::::::::M       M::::::::::Myyyyyyy           yyyyyyyA:::::::::A            ddddddddd:::::d    mmmmmmm    mmmmmmm   iiiiiiinnnn  nnnnnnnn         wwwwwww           wwwww           wwwwwwwiiiiiiittttttt:::::ttttttt    h::::h hhhhh              P::::P     P:::::Pttttttt:::::ttttttt        eeeeeeeeeeee    rrrrr   rrrrrrrrr      ooooooooooo       ddddddddd:::::d   aaaaaaaaaaaaa      ccccccccccccccccttttttt:::::tttttttyyyyyyy           yyyyyyyl::::l 
p::::ppp:::::::::p  h::::hh:::::hhh   p::::ppp:::::::::p  M:::::::::::M     M:::::::::::M y:::::y         y:::::yA:::::A:::::A         dd::::::::::::::d  mm:::::::m  m:::::::mm i:::::in:::nn::::::::nn        w:::::w         w:::::w         w:::::w i:::::it:::::::::::::::::t    h::::hh:::::hhh           P::::P     P:::::Pt:::::::::::::::::t      ee::::::::::::ee  r::::rrr:::::::::r   oo:::::::::::oo   dd::::::::::::::d   a::::::::::::a   cc:::::::::::::::ct:::::::::::::::::t y:::::y         y:::::y l::::l 
p:::::::::::::::::p h::::::::::::::hh p:::::::::::::::::p M:::::::M::::M   M::::M:::::::M  y:::::y       y:::::yA:::::A A:::::A       d::::::::::::::::d m::::::::::mm::::::::::m i::::in::::::::::::::nn        w:::::w       w:::::::w       w:::::w   i::::it:::::::::::::::::t    h::::::::::::::hh         P::::PPPPPP:::::P t:::::::::::::::::t     e::::::eeeee:::::eer:::::::::::::::::r o:::::::::::::::o d::::::::::::::::d   aaaaaaaaa:::::a c:::::::::::::::::ct:::::::::::::::::t  y:::::y       y:::::y  l::::l 
pp::::::ppppp::::::ph:::::::hhh::::::hpp::::::ppppp::::::pM::::::M M::::M M::::M M::::::M   y:::::y     y:::::yA:::::A   A:::::A     d:::::::ddddd:::::d m::::::::::::::::::::::m i::::inn:::::::::::::::n        w:::::w     w:::::::::w     w:::::w    i::::itttttt:::::::tttttt    h:::::::hhh::::::h        P:::::::::::::PP  tttttt:::::::tttttt    e::::::e     e:::::err::::::rrrrr::::::ro:::::ooooo:::::od:::::::ddddd:::::d            a::::ac:::::::cccccc:::::ctttttt:::::::tttttt   y:::::y     y:::::y   l::::l 
 p:::::p     p:::::ph::::::h   h::::::hp:::::p     p:::::pM::::::M  M::::M::::M  M::::::M    y:::::y   y:::::yA:::::A     A:::::A    d::::::d    d:::::d m:::::mmm::::::mmm:::::m i::::i  n:::::nnnn:::::n         w:::::w   w:::::w:::::w   w:::::w     i::::i      t:::::t          h::::::h   h::::::h       P::::PPPPPPPPP          t:::::t          e:::::::eeeee::::::e r:::::r     r:::::ro::::o     o::::od::::::d    d:::::d     aaaaaaa:::::ac::::::c     ccccccc      t:::::t          y:::::y   y:::::y    l::::l 
 p:::::p     p:::::ph:::::h     h:::::hp:::::p     p:::::pM::::::M   M:::::::M   M::::::M     y:::::y y:::::yA:::::AAAAAAAAA:::::A   d:::::d     d:::::d m::::m   m::::m   m::::m i::::i  n::::n    n::::n          w:::::w w:::::w w:::::w w:::::w      i::::i      t:::::t          h:::::h     h:::::h       P::::P                  t:::::t          e:::::::::::::::::e  r:::::r     rrrrrrro::::o     o::::od:::::d     d:::::d   aa::::::::::::ac:::::c                   t:::::t           y:::::y y:::::y     l::::l 
 p:::::p     p:::::ph:::::h     h:::::hp:::::p     p:::::pM::::::M    M:::::M    M::::::M      y:::::y:::::yA:::::::::::::::::::::A  d:::::d     d:::::d m::::m   m::::m   m::::m i::::i  n::::n    n::::n           w:::::w:::::w   w:::::w:::::w       i::::i      t:::::t          h:::::h     h:::::h       P::::P                  t:::::t          e::::::eeeeeeeeeee   r:::::r            o::::o     o::::od:::::d     d:::::d  a::::aaaa::::::ac:::::c                   t:::::t            y:::::y:::::y      l::::l 
 p:::::p    p::::::ph:::::h     h:::::hp:::::p    p::::::pM::::::M     MMMMM     M::::::M       y:::::::::yA:::::AAAAAAAAAAAAA:::::A d:::::d     d:::::d m::::m   m::::m   m::::m i::::i  n::::n    n::::n            w:::::::::w     w:::::::::w        i::::i      t:::::t    tttttth:::::h     h:::::h       P::::P                  t:::::t    tttttte:::::::e            r:::::r            o::::o     o::::od:::::d     d:::::d a::::a    a:::::ac::::::c     ccccccc      t:::::t    tttttt   y:::::::::y       l::::l 
 p:::::ppppp:::::::ph:::::h     h:::::hp:::::ppppp:::::::pM::::::M               M::::::M        y:::::::yA:::::A             A:::::Ad::::::ddddd::::::ddm::::m   m::::m   m::::mi::::::i n::::n    n::::n             w:::::::w       w:::::::w        i::::::i     t::::::tttt:::::th:::::h     h:::::h     PP::::::PP                t::::::tttt:::::te::::::::e           r:::::r            o:::::ooooo:::::od::::::ddddd::::::dda::::a    a:::::ac:::::::cccccc:::::c      t::::::tttt:::::t    y:::::::y       l::::::l
 p::::::::::::::::p h:::::h     h:::::hp::::::::::::::::p M::::::M               M::::::M         y:::::yA:::::A               A:::::Ad:::::::::::::::::dm::::m   m::::m   m::::mi::::::i n::::n    n::::n              w:::::w         w:::::w         i::::::i     tt::::::::::::::th:::::h     h:::::h     P::::::::P                tt::::::::::::::t e::::::::eeeeeeee   r:::::r            o:::::::::::::::o d:::::::::::::::::da:::::aaaa::::::a c:::::::::::::::::c      tt::::::::::::::t     y:::::y        l::::::l
 p::::::::::::::pp  h:::::h     h:::::hp::::::::::::::pp  M::::::M               M::::::M        y:::::yA:::::A                 A:::::Ad:::::::::ddd::::dm::::m   m::::m   m::::mi::::::i n::::n    n::::n               w:::w           w:::w          i::::::i       tt:::::::::::tth:::::h     h:::::h     P::::::::P                  tt:::::::::::tt  ee:::::::::::::e   r:::::r             oo:::::::::::oo   d:::::::::ddd::::d a::::::::::aa:::a cc:::::::::::::::c        tt:::::::::::tt    y:::::y         l::::::l
 p::::::pppppppp    hhhhhhh     hhhhhhhp::::::pppppppp    MMMMMMMM               MMMMMMMM       y:::::yAAAAAAA                   AAAAAAAddddddddd   dddddmmmmmm   mmmmmm   mmmmmmiiiiiiii nnnnnn    nnnnnn                www             www           iiiiiiii         ttttttttttt  hhhhhhh     hhhhhhh     PPPPPPPPPP                    ttttttttttt      eeeeeeeeeeeeee   rrrrrrr               ooooooooooo      ddddddddd   ddddd  aaaaaaaaaa  aaaa   cccccccccccccccc          ttttttttttt     y:::::y          llllllll
 p:::::p                               p:::::p                                                 y:::::y                                                                                                                                                                                                                                                                                                                                                                                              y:::::y                   
 p:::::p                               p:::::p                                                y:::::y                                                                                                                                                                                                                                                                                                                                                                                              y:::::y                    
p:::::::p                             p:::::::p                                              y:::::y                                                                                                                                                                                                                                                                                                                                                                                              y:::::y                     
p:::::::p                             p:::::::p                                             y:::::y                                                                                                                                                                                                                                                                                                                                                                                              y:::::y                      
p:::::::p                             p:::::::p                                            yyyyyyy                                                                                                                                                                                                                                                                                                                                                                                              yyyyyyy                       
ppppppppp                             ppppppppp                                                                                                                                                                                                                                                                                                                                                                                                                                                                               

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
EOF
    echo -e "           ${WHITE}PREMIUM PTERODACTYL INSTALLER${NC}"
    echo -e "${HEADER_LINE}"
}

ok() {
    echo -e "  ${GREEN}[OK]${NC} $1"
}

step() {
    echo -e "\n  ${PURPLE}::${NC} ${WHITE}$1${NC}"
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
ask "Panel Domain" "phpmyadmin.nobita.indevs.in" DOMAIN
ask "Admin Email" "admin@gmail.com" EMAIL
ask "Admin Username" "admin" USERNAME
ask "Admin Password" "admin" PASSWORD


# --- FINAL VALIDATION LOOP ---
echo -e "\n  ${GOLD}┌─[ REVIEW CONFIGURATION ]${NC}"
echo -e "  ${GOLD}│${NC} ${GRAY}Domain:${NC}   $DOMAIN"
echo -e "  ${GOLD}│${NC} ${GRAY}Email:${NC}    $EMAIL"
echo -e "  ${GOLD}│${NC} ${GRAY}User:${NC}     $USERNAME"
echo -e "  ${GOLD}└───────────────────────────${NC}"

while true; do
    echo -ne "\n  ${CYAN}Start Installation?${NC} ${WHITE}(y/n)${NC}${GRAY}:${NC} "
    read -n 1 -r CONFIRM
    echo ""

    case $CONFIRM in
        [Yy]* )
            echo -e "  ${GREEN}Proceeding to deployment...${NC}"
            break
            ;;
        [Nn]* )
            echo -e "  ${RED}Installation aborted by user.${NC}"
            exit
            ;;
        * )
            echo -e "  ${GRAY}Invalid input. Enter ${NC}${WHITE}y${NC}${GRAY} or ${NC}${WHITE}n${NC}${GRAY}.${NC}"
            ;;
    esac
done

echo -e "${HEADER_LINE}"
# --------------------------------------------------------- #


#!/bin/bash

set -e

INSTALL_DIR="/var/www/phpmyadmin"
SSL_DIR="/etc/certs/phpMyAdmin"

#################################
# Detect OS (Ubuntu/Debian only)
#################################

source /etc/os-release

case "$ID" in
ubuntu|debian)
    echo "Detected: $PRETTY_NAME"
    ;;
*)
    echo "Unsupported OS"
    exit 1
    ;;
esac

#################################
# Install packages
#################################

apt update

apt install -y \
wget \
tar \
nginx \
openssl \
php-fpm

#################################
# Install phpMyAdmin
#################################

mkdir -p "$INSTALL_DIR/tmp"

cd "$INSTALL_DIR"

wget -O phpMyAdmin.tar.gz \
https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-english.tar.gz

tar -xzf phpMyAdmin.tar.gz

PMA_DIR=$(find . -maxdepth 1 -type d -name "phpMyAdmin-*-english" | head -n1)

mv "$PMA_DIR"/* .

rm -rf "$PMA_DIR" phpMyAdmin.tar.gz

#################################
# phpMyAdmin config
#################################

mkdir -p config

chmod o+rw config

cp config.sample.inc.php config/config.inc.php

chmod o+w config/config.inc.php

#################################
# Permissions
#################################
chown -R www-data:www-data *
chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
cp /var/www/phpmyadmin/config/config.inc.php /var/www/phpmyadmin
rm -rf /var/www/phpmyadmin/config
rm -rf /var/www/phpmyadmin/setup


#################################
# Create SSL certificate
#################################

mkdir -p "$SSL_DIR"

cd "$SSL_DIR"

openssl req \
-new \
-newkey rsa:4096 \
-days 3650 \
-nodes \
-x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=$DOMAIN" \
-keyout privkey.pem \
-out fullchain.pem

#################################
# Auto detect PHP-FPM socket
#################################

PHP_SOCKET=$(find /run/php \
-name "php*-fpm.sock" \
| head -n1)

#################################
# Create Nginx config
#################################

cat > /etc/nginx/sites-available/phpmyadmin.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    root $INSTALL_DIR;
    index index.php;

    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    ssl_certificate $SSL_DIR/fullchain.pem;
    ssl_certificate_key $SSL_DIR/privkey.pem;

    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;

    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {

        fastcgi_split_path_info ^(.+\.php)(/.+)$;

        fastcgi_pass unix:$PHP_SOCKET;

        fastcgi_index index.php;

        include fastcgi_params;

        fastcgi_param SCRIPT_FILENAME \
\$document_root\$fastcgi_script_name;

        fastcgi_param PHP_VALUE "
upload_max_filesize=100M
post_max_size=100M";

        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;

        fastcgi_intercept_errors off;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

#################################
# Enable site
#################################

sudo ln -sf \
/etc/nginx/sites-available/phpmyadmin.conf \
/etc/nginx/sites-enabled/phpmyadmin.conf

#################################
# Test & restart nginx
#################################

nginx -t

systemctl restart nginx

echo ""
echo "=================================="
echo "phpMyAdmin Installed Successfully"
echo "URL: https://$DOMAIN"
echo "Path: $INSTALL_DIR"
echo "=================================="

