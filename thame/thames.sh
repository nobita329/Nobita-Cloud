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
# 🧠 BLUEPRINT LIST
# ==========================================
names=(
"nebula.blueprint"
"euphoriatheme.blueprint"
"BetterAdmin.blueprint"
"abysspurple.blueprint"
"amberabyss.blueprint"
"catppuccindactyl.blueprint"
"crimsonabyss.blueprint"
"emeraldabyss.blueprint"
"nightadmin.blueprint"
"refreshtheme.blueprint"
)

# ==========================================
# ⚙️ RUN FUNCTION
# ==========================================
run_blueprint() {
    local NAME="$1"
    local ACTION="$2"

    cd /var/www/pterodactyl || exit

    if [[ "$ACTION" == "install" ]]; then
        echo -e "\n${G}Installing ${NAME%.blueprint}...${N}"
        wget -q "$URL/$NAME"
        yes | blueprint -i "$NAME"
        rm -f "$NAME"
    else
        echo -e "\n${R}Uninstalling ${NAME%.blueprint}...${N}"
        yes | blueprint -r "$NAME"
    fi
}

# ==========================================
# 🧬 ENCODED TITLE (OBFUSCATED)
# ==========================================
get_title() {
    echo 'ICAgICAg44CCIOKAjCDigJMgTm9iaXRhLmRldiBDT05UUk9MIEhVQiDigJMg44CCICAgICAg' | base64 -d
}

# ==========================================
# 📋 HEADER
# ==========================================
header() {
  clear
  echo -e "${BC}"
  echo " ╔══════════════════════════════════════════════════════════╗"
  echo " ║                                                          ║"

  TITLE=$(get_title)
  printf " ║${BW}%-58s${BC}║\n" "$TITLE"

  echo " ║                                                          ║"
  printf " ║${B}%-58s${BC}║\n" "     Minimal • Clean • High Performance     "
  echo " ║                                                          ║"
  echo " ╚══════════════════════════════════════════════════════════╝"
  echo -e "${N}"

  echo -e " ${B}User:${N} $(whoami)  ${B}Host:${N} $(hostname)  ${B}Time:${N} $(date +'%H:%M')"
  echo -e "${C} ──────────────────────────────────────────────────────────${N}"
}

# ==========================================
# 📋 MENU
# ==========================================
show_menu() {
  header
  echo -e "${BW} SELECT AN OPTION:${N}\n"

  for i in "${!names[@]}"; do
      num=$((i+1))
      clean_name="${names[$i]%.blueprint}"
      echo -e "  ${BG}[ $num ]${N} $clean_name"
  done

  echo -e ""
  echo -e "  ${BR}[ 0 ]${N} ❌ Exit"
  echo -e "\n${C} ──────────────────────────────────────────────────────────${N}"
}

# ==========================================
# 🔁 LOOP
# ==========================================
while true; do
  show_menu
  read -p " 👉 Enter choice: " opt

  if [[ "$opt" == "0" ]]; then
      echo -e "\n${M} 👋 Exit... Nobita.dev so gaya 😴${N}"
      exit
  fi

  index=$((opt-1))
  NAME="${names[$index]}"

  if [[ -z "$NAME" ]]; then
      echo -e "\n${R} ❌ Invalid option${N}"
      sleep 1
      continue
  fi

  clean_name="${NAME%.blueprint}"

  clear
  echo -e "\n${C} ──────────────────────────────────────────────────────────${N}"
  echo -e " ${BW} SELECT ACTION (${clean_name}):${N}\n"

  echo -e "  ${BG}[ 1 ]${N} Install"
  echo -e "  ${BR}[ 2 ]${N} Uninstall"
  echo -e "  ${BY}[ 0 ]${N} Back"

  echo -e "\n${C} ──────────────────────────────────────────────────────────${N}"

  read -p " 👉 Action: " action

  case $action in
      1) run_blueprint "$NAME" "install" ;;
      2) run_blueprint "$NAME" "remove" ;;
      0) continue ;;
      *) echo -e "${R}Invalid action${N}" ;;
  esac

  echo
  read -p " ↩️ Press Enter to return..."
done
