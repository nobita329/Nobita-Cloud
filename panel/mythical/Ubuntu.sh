#!/bin/bash

set -e

echo "🚀 Starting Smart Auto Installer for Ubuntu..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_ID=$VERSION_ID
    CODENAME=$VERSION_CODENAME
else
    echo "❌ Cannot detect OS"
    exit 1
fi

# Validate Ubuntu
if [[ "$OS" != "ubuntu" ]]; then
    echo "❌ This script only supports Ubuntu!"
    exit 1
fi

echo "📌 Detected: Ubuntu $VERSION_ID ($CODENAME)"

# Supported versions
if [[ "$VERSION_ID" != "22.04" && "$VERSION_ID" != "24.04" ]]; then
    echo "⚠️ Unsupported Ubuntu version. Trying anyway..."
fi

# Update system
echo "📦 Updating system..."
apt update && apt upgrade -y

# Base packages
echo "🔧 Installing dependencies..."
apt install -y software-properties-common curl ca-certificates gnupg2 sudo lsb-release apt-transport-https

# Add PHP repo (Sury works on Ubuntu too)
echo "🐘 Adding PHP repo..."
echo "deb https://packages.sury.org/php/ $CODENAME main" > /etc/apt/sources.list.d/sury-php.list
curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg

# Update repos
apt update

# Install PHP
echo "⚡ Installing PHP 8.2..."
apt install -y php8.2 php8.2-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip}

# MariaDB setup
echo "🛢️ Setting up MariaDB repo..."
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash

# Install stack
echo "🌐 Installing full stack..."
apt install -y mariadb-server nginx tar unzip git redis-server zip dos2unix

# Enable services
echo "🔄 Enabling services..."
systemctl enable nginx mariadb redis-server php8.2-fpm
systemctl start nginx mariadb redis-server php8.2-fpm

# Output
echo ""
echo "✅ Installation completed!"
echo "👉 OS: Ubuntu $VERSION_ID ($CODENAME)"
echo "👉 PHP: $(php -v | head -n 1)"
echo "👉 Nginx: $(nginx -v 2>&1)"
echo "👉 MariaDB: $(mysql -V)"

echo "🎉 Server ready hai — full power mode ON 🔥"
