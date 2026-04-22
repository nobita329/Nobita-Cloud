#!/bin/bash

# ==========================================
# 🔐 BASIC PROTECTION
# ==========================================
[[ $EUID -ne 0 ]] && echo "Run as root!" && exit 1

# ==========================================
# 🎨 COLORS
# ==========================================
R="\e[31m"; G="\e[32m"; Y="\e[33m"
B="\e[34m"; M="\e[35m"; C="\e[36m"
W="\e[97m"; N="\e[0m"

BR="\e[1;31m"; BG="\e[1;32m"; BY="\e[1;33m"
BM="\e[1;35m"; BC="\e[1;36m"; BW="\e[1;97m"

URL="https://github.com/nobita329/Nobita-Cloud/raw/refs/heads/main/thame/UI"

trap 'echo -e "\n${R}[!] Force exit detected.${N}"; exit 1' SIGINT

# ==========================================
# 🧠 BLUEPRINT LIST (THEMES)
# ==========================================
names=(
"nebula.blueprint" "euphoriatheme.blueprint"
"BetterAdmin.blueprint" "abysspurple.blueprint"
"amberabyss.blueprint" "catppuccindactyl.blueprint"
"crimsonabyss.blueprint" "emeraldabyss.blueprint"
"nightadmin.blueprint" "refreshtheme.blueprint"
"slice.blueprint" "darkenate.blueprint"
"recolor.blueprint" "bluetables.blueprint"
"ultradarkadmin.blueprint" "xlpaneltheme.blueprint"
"lememtheme.blueprint" "slate.blueprint"
"kaelixprime.blueprint"
)

# ==========================================
# 🔍 CHECK INSTALLATION STATUS
# ==========================================
is_installed() {
    local slug="${1%.blueprint}"
    if [[ -d "/var/www/pterodactyl/storage/extensions/$slug" ]]; then
        return 0 # Installed
    else
        return 1 # Not Installed
    fi
}

# ==========================================
# ⚙️ RUN FUNCTION
# ==========================================
run_blueprint() {
    local NAME="$1"
    local ACTION="$2"
    cd /var/www/pterodactyl || { echo -e "${R}Directory not found!${N}"; exit 1; }

    if [[ "$ACTION" == "install" ]]; then
        echo -e "\n${G}📥 Downloading & Installing ${NAME%.blueprint}...${N}"
        wget -q "$URL/$NAME" -O "$NAME"
        if [[ -f "$NAME" ]]; then
            yes | blueprint -i "$NAME"
            rm -f "$NAME"
        else
            echo -e "${R}❌ Download failed!${N}"
        fi
    else
        echo -e "\n${R}🗑️ Removing ${NAME%.blueprint}...${N}"
        yes | blueprint -r "${NAME%.blueprint}"
    fi
}

get_title() { echo 'ICAgICAg44CCIOKAjCDigJMgTm9iaXRhLmRldiBDT05UUk9MIEhVQiDigJMg44CCICAgICAg' | base64 -d; }

# ==========================================
# 📋 HEADER
# ==========================================
header() {
  clear
  echo -e "${BC} ╔══════════════════════════════════════════════════════════╗${N}"
  printf " ${BC}║${BW}%-58s${BC}║${N}\n" "$(get_title)"
  printf " ${BC}║${B}%-58s${BC}║${N}\n" "      Minimal • Clean • High Performance      "
  echo -e "${BC} ╚══════════════════════════════════════════════════════════╝${N}"
  echo -e " ${B}User:${N} $(whoami)  ${B}Host:${N} $(hostname)  ${B}Time:${N} $(date +'%H:%M')"
  echo -e "${C} ──────────────────────────────────────────────────────────${N}"
}

# ==========================================
# 📋 MENU (TWO COLUMN TYPE)
# ==========================================
show_menu() {
  header
  echo -e "${BW} SELECT A THEME UI:${N}\n"
  
  local count=0
  for i in "${!names[@]}"; do
      num=$((i+1))
      clean_name="${names[$i]%.blueprint}"
      
      # Status Detection
      if is_installed "$clean_name"; then
          status="${BG}●${N}" # Green dot
      else
          status="${R}○${N}" # Red circle
      fi
      
      # Two Column Print
      printf "  ${BG}%2d${N} %-22s %b   " "$num" "$clean_name" "$status"
      
      ((count++))
      if (( count % 2 == 0 )); then echo ""; fi
  done

  echo -e "\n\n  ${BR} 0 ${N} Exit"
  echo -e "${C} ──────────────────────────────────────────────────────────${N}"
}

# ==========================================
# 🔁 MAIN LOOP
# ==========================================
while true; do
  show_menu
  read -p " 👉 Enter choice: " opt

  if [[ "$opt" == "0" ]]; then
      echo -e "\n${M} 👋 Nobita.dev so gaya... Bye!${N}"
      exit
  fi

  index=$((opt-1))
  NAME="${names[$index]}"

  if [[ -z "$NAME" ]]; then
      echo -e "\n${R} ❌ Invalid Option${N}"
      sleep 1
      continue
  fi

  clean_name="${NAME%.blueprint}"

  clear
  header
  
  if is_installed "$clean_name"; then
      cur_status="${BG}ALREADY INSTALLED${N}"
  else
      cur_status="${R}NOT INSTALLED${N}"
  fi

  echo -e " ${BW}SELECTED UI:${N} ${BC}$clean_name${N}"
  echo -e " ${BW}STATUS:${N}      $cur_status"
  echo -e "${C} ──────────────────────────────────────────────────────────${N}"
  echo -e "  ${BG}[ 1 ]${N} Install"
  echo -e "  ${BR}[ 2 ]${N} Uninstall"
  echo -e "  ${BY}[ 0 ]${N} Back to Menu"
  echo -e "${C} ──────────────────────────────────────────────────────────${N}"

  read -p " 👉 Action: " action

  case $action in
      1) run_blueprint "$NAME" "install" ;;
      2) run_blueprint "$NAME" "remove" ;;
      0) continue ;;
      *) echo -e "${R}Invalid Choice${N}" ;;
  esac

  echo
  read -p " ↩️ Press [Enter] to return..."
done
