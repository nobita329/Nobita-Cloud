#!/bin/bash

# COLORS
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; M="\e[35m"; W="\e[37m"; N="\e[0m"

# NEW UI STYLE FUNCTIONS
print_box() {
    local text="$1"
    local color="$2"
    local width=50
    local padding=$(( (width - ${#text} - 2) / 2 ))
    
    echo -e "${color}┌$(printf '─%.0s' $(seq 1 $((width-2))))┐${N}"
    printf "${color}│%*s%s%*s│${N}\n" $padding "" "$text" $((padding - ((${#text} % 2) ? 1 : 0))) ""
    echo -e "${color}└$(printf '─%.0s' $(seq 1 $((width-2))))┘${N}"
}

print_header() {
    clear
    echo -e "\n${C}╔════════════════════════════════════════════════╗${N}"
    echo -e "${C}║${W}           D E V E L O P M E N T   M E N U          ${C}║${N}"
    echo -e "${C}╚════════════════════════════════════════════════╝${N}\n"
}

print_option() {
    local num="$1"
    local text="$2"
    local color="$3"
    
    echo -e "  ${color}┌──────────────────────────────────────┐${N}"
    echo -e "  ${color}│${W}  [$num]  $text$(printf '%*s' $((31 - ${#text} - 6)))${color}│${N}"
    echo -e "  ${color}└──────────────────────────────────────┘${N}\n"
}

print_status() {
    local text="$1"
    local color="$2"
    echo -e "\n${color}▶▶ ${text}${N}\n"
}

# MAIN MENU LOOP
while true; do
    print_header
    
    print_option "1" "RDX Tool" "$G"
    print_option "2" "𝗥𝘂𝗻 𝘃𝗺 1 Kvm" "$Y"
    print_option "3" "𝗥𝘂𝗻 𝘃𝗺 2 No Kvm" "$B"
    print_option "4" "𝗥𝘂𝗻 𝘃𝗺 3 ALL SETUP" "$B"
    print_option "5" "Exit" "$R"

    
    echo -e "${M}════════════════════════════════════════════════${N}"
    echo -ne "${W}Select Option → ${N}"
    read -p "" op
    
    case $op in
    
    # =========================================================
    # (1) IDX TOOL - ENHANCED
    # =========================================================
    1)
        clear
        print_status "🔧 Running IDX Tool Setup..." "$Y"
        echo -e "${M}════════════════════════════════════════════════${N}\n"
        
        echo -e "${C}🧹 Cleaning up old files...${N}"
        cd
        rm -rf myapp
        rm -rf flutter
        
        cd vm
        
        if [ ! -d ".idx" ]; then
            echo -e "${G}📁 Creating .idx directory...${N}"
            mkdir .idx
            cd .idx
            
            echo -e "${C}📝 Creating dev.nix configuration...${N}"
            cat <<EOF > dev.nix
{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = with pkgs; [
    unzip
    openssh
    git
    qemu_kvm
    sudo
    cdrkit
    cloud-utils
    qemu
  ];

  env = {
    EDITOR = "nano";
  };

  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];

    workspace = {
      onCreate = { };
      onStart = { };
    };

    previews = {
      enable = false;
    };
  };
}
EOF
            
            echo -e "\n${G}✅ IDX Tool setup complete!${N}"
            echo -e "${W}┌──────────────────────────────────────┐${N}"
            echo -e "${W}│ ${G}Status${W}: ${Y}Ready to use${W}                 │${N}"
            echo -e "${W}│ ${G}Location${W}: ${Y}~/vps123/.idx${W}              │${N}"
            echo -e "${W}└──────────────────────────────────────┘${N}"
        else
            echo -e "${Y}⚠ Directory .idx already exists — skipping.${N}"
        fi
        
        echo -e "\n${M}════════════════════════════════════════════════${N}"
        read -p "↩ Press Enter..."
        ;;
    
    # =========================================================
    # (2) 𝗥𝘂𝗻 𝘃𝗺𝟭 Kvm — ENHANCED
    # =========================================================
    2)
        clear
        print_status "🌐 Starting IDX VM From GitHub Script..." "$B"
        echo -e "${M}════════════════════════════════════════════════${N}\n"
        
        echo -e "${C}📡 Fetching script from GitHub...${N}"
        bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/vm/vm.sh)
        
        echo -e "\n${M}════════════════════════════════════════════════${N}"
        read -p "↩ Press Enter..."
        ;;

    # =========================================================
    # (3) 𝗥𝘂𝗻 𝘃𝗺𝟮 No kvm  — ENHANCED
    # =========================================================
    3)
        clear
        print_status "🌐 Starting vm 2 From GitHub Script..." "$B"
        echo -e "${M}════════════════════════════════════════════════${N}\n"
        
        echo -e "${C}📡 Fetching script from GitHub...${N}"

        bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/vm/dd.sh)
        bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/vm/vm2.sh)
        
        echo -e "\n${M}════════════════════════════════════════════════${N}"
        read -p "↩ Press Enter..."
        ;;

    # =========================================================
    # (4) 𝗥𝘂𝗻 𝘃𝗺3 no+yes setup  — ENHANCED
    # =========================================================
    4)
        clear
        print_status "🌐 Starting vm 2 From GitHub Script..." "$B"
        echo -e "${M}════════════════════════════════════════════════${N}\n"
        
        echo -e "${C}📡 Fetching script from GitHub...${N}"

        bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/vm/proxmox.sh)
        
        echo -e "\n${M}════════════════════════════════════════════════${N}"
        read -p "↩ Press Enter..."
        ;;  
    # =========================================================
    # EXIT - ENHANCED
    # =========================================================
    5)
        clear
        echo -e "\n${C}╔════════════════════════════════════════════════╗${N}"
        echo -e "${C}║${R}                 E X I T I N G                  ${C}║${N}"
        echo -e "${C}╚════════════════════════════════════════════════╝${N}\n"
        echo -e "${Y}👋 Thank you for using the Development Menu!${N}\n"
        exit 0
        ;;
    
    *)
        echo -e "\n${R}❌ Invalid Option! Please try again.${N}"
        sleep 1
        ;;
    esac
done
