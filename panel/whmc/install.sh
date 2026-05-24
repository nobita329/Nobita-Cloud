#!/bin/bash

set -e

clear
echo "====== WHMCS Auto Installer (Nginx + PHP 8.4) ======"
echo

read -p "Enter Domain (example: billing.example.com): " DOMAIN

WEBROOT="/var/www/whmcs"
DB_HOST="localhost"
DB_NAME="whmcs"
DB_USER="whmcsuser"
DB_PASS="1234"


echo ">>> Installing packages..."
apt update -y
apt install -y wget curl unzip openssl ca-certificates

apt install -y \
  nginx mariadb-server \
  php8.4 php8.4-fpm php8.4-cli php8.4-common \
  php8.4-mysql php8.4-curl php8.4-xml \
  php8.4-mbstring php8.4-gd php8.4-zip \
  php8.4-intl php8.4-bcmath php8.4-soap

systemctl enable nginx mariadb php8.4-fpm
systemctl restart nginx mariadb php8.4-fpm

echo ">>> Installing ionCube Loader..."
PHP_EXT_DIR=$(php8.4 -i | grep "^extension_dir" | awk '{print $NF}')
wget -q -O /tmp/ioncube.tar.gz "https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz"
tar xzf /tmp/ioncube.tar.gz -C /tmp
cp "/tmp/ioncube/ioncube_loader_lin_8.4.so" "$PHP_EXT_DIR/"
echo "zend_extension=ioncube_loader_lin_8.4.so" > /etc/php/8.4/mods-available/ioncube.ini
phpenmod -v 8.4 ioncube
mv /etc/php/8.4/fpm/conf.d/20-ioncube.ini /etc/php/8.4/fpm/conf.d/00-ioncube.ini
mv /etc/php/8.4/cli/conf.d/20-ioncube.ini /etc/php/8.4/cli/conf.d/00-ioncube.ini
systemctl restart php8.4-fpm
rm -rf /tmp/ioncube /tmp/ioncube.tar.gz

echo ">>> Setting up database..."
DB_PASS='yourPassword' && mariadb -e "CREATE DATABASE IF NOT EXISTS panel; CREATE USER IF NOT EXISTS 'pterodactyl'@'localhost' IDENTIFIED BY '$DB_PASS'; CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DB_PASS'; GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'localhost'; GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1'; FLUSH PRIVILEGES;"
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/php -q /var/www/whmcs/crons/cron.php") | crontab -
mkdir -p "$WEBROOT"

echo ">>> Downloading WHMCS..."
wget -q --show-progress -O /tmp/whmcs.zip "https://files.catbox.moe/2ba11q.zip"
unzip -o /tmp/whmcs.zip -d "$WEBROOT"
rm -f /tmp/whmcs.zip

chown -R www-data:www-data "$WEBROOT"
find "$WEBROOT" -type d -exec chmod 755 {} \;
find "$WEBROOT" -type f -exec chmod 644 {} \;

echo ">>> Configuring Nginx..."
cat > /etc/nginx/sites-available/whmcs <<NGINX
server {
    listen 80;
    server_name $DOMAIN;

    root $WEBROOT;
    index index.php index.html;

    client_max_body_size 100M;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/whmcs /etc/nginx/sites-enabled/whmcs
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl restart nginx

CC_HASH=$(openssl rand -base64 128 | tr -d '\n\/+=' | cut -c 1-64)


echo "$JSON" | php8.4 "$WEBROOT/install/bin/installer.php" -i -n -c


IP=$(hostname -I | awk '{print $1}')

clear
echo "=================================="
echo "      WHMCS INSTALL COMPLETE"
echo "=================================="
echo " Domain     : http://$DOMAIN"
echo " Fallback   : http://$IP"
echo ""
echo " Admin User : $ADMIN_USER"
echo " Admin Pass : $ADMIN_PASS"
echo " Email      : $ADMIN_EMAIL"
echo ""
echo " DB Name    : $DB_NAME"
echo " DB User    : $DB_USER"
echo " DB Pass    : $DB_PASS"
echo ""
echo " Path       : $WEBROOT"
echo "=================================="
