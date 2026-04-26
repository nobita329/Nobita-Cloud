#!/bin/bash

set -e

echo "🧠 Detecting OS..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ OS detect nahi hua"
    exit 1
fi

echo "📌 OS Detected: $OS"

# Make scripts executable
chmod +x Ubuntu.sh Debian.sh 2>/dev/null || true

# Auto run based on OS
if [[ "$OS" == "ubuntu" ]]; then
    echo "🚀 Running Ubuntu installer..."
    bash Ubuntu.sh

elif [[ "$OS" == "debian" ]]; then
    echo "🚀 Running Debian installer..."
    bash <(curl -s https://raw.githubusercontent.com/nobita329/Nobita-Cloud/refs/heads/main/panel/mythical/Debian.sh) 
else
    echo "❌ Unsupported OS: $OS"
    exit 1
fi

echo "✅ Done! System ready."
