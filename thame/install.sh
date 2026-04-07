
#!/bin/bash

# ==================================================
#  BLUEPRINT AUTO-INSTALLER | ONE-CLICK
# ==================================================

# --- COLORS ---
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; W="\e[37m"; N="\e[0m"

# --- CONFIG ---
PT_DIR="/var/www/pterodactyl"

# --- 1. CHECK ROOT ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${R}❌ Error: Please run as root (sudo bash $0)${N}"
    exit 1
fi

# --- 2. PRE-FLIGHT CHECK ---
clear
echo -e "${B}╔══════════════════════════════════════════════════════╗${N}"
echo -e "${B}║${W}       🚀 PTERODACTYL BLUEPRINT AUTO-INSTALLER        ${B}║${N}"
echo -e "${B}╚══════════════════════════════════════════════════════╝${N}"
echo
echo -e "${Y}⚠️  This script will automatically install Blueprint on:${N}"
echo -e "${C}   $PT_DIR${N}"
echo
echo -e "Starting in 3 seconds... (Press Ctrl+C to cancel)"
sleep 3

# --- 3. EXECUTION ---

# Step 1: Check Directory
echo -e "\n${B}[1/6] Checking Pterodactyl Directory...${N}"
if [ ! -d "$PT_DIR" ]; then
    echo -e "${R}❌ Error: Pterodactyl not found at $PT_DIR${N}"
    exit 1
fi
echo -e "${G}✔ Found directory.${N}"

# Step 2: Install Dependencies
echo -e "\n${B}[2/6] Installing System Dependencies...${N}"
apt update -y -q
apt install -y curl wget unzip ca-certificates git gnupg zip -q
echo -e "${G}✔ Dependencies installed.${N}"

# Step 3: Install Node.js & Yarn
echo -e "\n${B}[3/6] Configuring Node.js environment...${N}"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
apt update -y -q
apt install -y nodejs -q
npm i -g yarn
echo -e "${G}✔ Node.js & Yarn ready.${N}"

# Step 4: Download Blueprint
echo -e "\n${B}[4/6] Downloading Blueprint Framework...${N}"
cd "$PT_DIR"
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | grep 'release.zip' | cut -d '"' -f 4)
wget -q "$DOWNLOAD_URL" -O "$PT_DIR/release.zip"
unzip -o -q release.zip
echo -e "${G}✔ Files extracted.${N}"

# Step 5: Configuration
echo -e "\n${B}[5/6] Generating Configuration...${N}"
cat <<EOF > "$PT_DIR/.blueprintrc"
WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";
EOF
chmod +x "$PT_DIR/blueprint.sh"
chown -R www-data:www-data "$PT_DIR"
echo -e "${G}✔ Config generated.${N}"

# Step 6: Install
echo -e "\n${B}[6/6] Running Blueprint Internal Installer...${N}"
# Auto-confirm flags often needed for automated scripts, 
# typically blueprint.sh requires interaction, we run it directly.
yes | bash "$PT_DIR/blueprint.sh"

# --- FINISH ---
echo -e "\n${G}══════════════════════════════════════════════════════${N}"
echo -e "${G}   🎉 INSTALLATION COMPLETE!${N}"
echo -e "${W}   Blueprint Framework is now active on your panel.${N}"
echo -e "${G}══════════════════════════════════════════════════════${N}"
