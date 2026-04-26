#!/bin/bash

set -e

echo "🚀 Starting Smart Auto Installer..."

# Detect Debian version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_ID=$VERSION_ID
    CODENAME=$VERSION_CODENAME
else
    echo "❌ Cannot detect OS"
    exit 1
fi

# Validate Debian
if [[ "$OS" != "debian" ]]; then
    echo "❌ This script only supports Debian!"
    exit 1
fi

echo "📌 Detected: Debian $VERSION_ID ($CODENAME)"

# Supported versions
if [[ "$VERSION_ID" != "11" && "$VERSION_ID" != "12" && "$VERSION_ID" != "13" ]]; then
    echo "⚠️ Unsupported Debian version. Trying anyway..."
fi

# Update system
echo "📦 Updating system..."
apt update && apt upgrade -y

# Base packages
echo "🔧 Installing dependencies..."
apt install -y software-properties-common curl ca-certificates gnupg2 sudo lsb-release apt-transport-https

# Add PHP repo
echo "🐘 Adding PHP repo for $CODENAME..."
echo "deb https://packages.sury.org/php/ $CODENAME main" > /etc/apt/sources.list.d/sury-php.list
curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg

# Update repos
apt update

# Install PHP
echo "⚡ Installing PHP 8.2..."
apt install -y php8.2 php8.2-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip}


# Install stack
echo "🌐 Installing full stack..."
apt install -y mariadb-server nginx tar unzip git redis-server zip dos2unix

# Enable services
echo "🔄 Enabling services..."
systemctl enable nginx mariadb redis-server php8.2-fpm
systemctl start nginx mariadb redis-server php8.2-fpm

# Final output
echo ""
echo "✅ Installation completed!"
echo "👉 OS: Debian $VERSION_ID ($CODENAME)"
echo "👉 PHP: $(php -v | head -n 1)"
echo "👉 Nginx: $(nginx -v 2>&1)"
echo "👉 MariaDB: $(mysql -V)"

echo "🎉 Server ekdum ready hai!"
