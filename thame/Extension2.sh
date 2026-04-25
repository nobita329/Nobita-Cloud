# !/bin/bash

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

URL="https://github.com/nobita329/Nobita-Cloud/raw/refs/heads/main/thame/Extension"
selected_indices=()

trap 'echo -e "\n${R}[!] Force exit detected.${N}"; exit 1' SIGINT

# ==========================================
# 🧠 BLUEPRINT LIST
# ==========================================
names=(
"adminauditlogs.blueprint" "huxregister.blueprint" "loader.blueprint" 
"lyrdyannounce.blueprint" "mclogs.blueprint" "mcplugins.blueprint"
"mctools.blueprint" "minecraftplayermanager.blueprint" "playerlisting.blueprint" 
"resourcealerts.blueprint" "resourcemanager.blueprint" "serverbackgrounds.blueprint"
"serversplitter.blueprint" "simplefavicons.blueprint" "snowflakes.blueprint" 
"sociallogin.blueprint" "startupchanger.blueprint" "subdomains.blueprint"
"tawkto.blueprint" "versionchanger.blueprint" "pteromonaco.blueprint" 
"urldownloader.blueprint" "consolelogs.blueprint" "laravellogs.blueprint"
"vanillatweaks.blueprint" "modrinthbrowser.blueprint" "nopagination.blueprint" 
"activitypurges.blueprint" "redirect.blueprint" "simplefooters.blueprint"
"paneladdressoverride.blueprint" "shownodeids.blueprint" "votifiertester.blueprint" 
"sidebar.blueprint" "translations.blueprint" "monacoeditor.blueprint"
"minecraftpluginmanager.blueprint" "subdomainmanager.blueprint" "serverimporter.blueprint" 
"pstatistics.blueprint" "pullfiles.blueprint" "serverpropsmanager.blueprint" 
"motdmaker.blueprint" "servericonimporter.blueprint" "sagaautosuspension.blueprint"
"sagaminecraftmodpackinstaller.blueprint" "blueannoucements.blueprint" "trashbin.blueprint" 
"eggchanger.blueprint"
)

# ==========================================
# 🔍 HELPERS
# ==========================================
is_installed() {
    [[ -d "/var/www/pterodactyl/storage/extensions/${1%.blueprint}" ]] && return 0 || return 1
}

is_selected() {
    local index=$1
    [[ " ${selected_indices[*]} " =~ " $index " ]] && return 0 || return 1
}

run_blueprint() {
    local NAME="$1"
    local ACTION="$2"
    cd /var/www/pterodactyl || exit 1
    if [[ "$ACTION" == "install" ]]; then
        echo -e "${G}📥 Installing ${NAME%.blueprint}...${N}"
        wget -q "$URL/$NAME" -O "$NAME"
        [[ -s "$NAME" ]] && yes | blueprint -i "$NAME" && rm -f "$NAME"
    else
        echo -e "${R}🗑️ Removing ${NAME%.blueprint}...${N}"
        yes | blueprint -r "${NAME%.blueprint}"
    fi
}

get_title() { echo 'ICAgICAg44CCIOKAjCDigJMgTm9iaXRhLmRldiBDT05UUk9MIEhVQiDigJMg44CCICAgICAg' | base64 -d; }

# ==========================================
# 📋 MENU
# ==========================================
show_menu() {
    clear
    echo -e "${BC} ╔══════════════════════════════════════════════════════════╗${N}"
    printf " ${BC}║${BW}%-58s${BC}║${N}\n" "$(get_title)"
    echo -e "${BC} ╚══════════════════════════════════════════════════════════╝${N}"
    
    local count=0
    for i in "${!names[@]}"; do
        num=$((i+1))
        clean_name="${names[$i]%.blueprint}"
        
        # Status Icon
        is_installed "$clean_name" && status="${BG}●${N}" || status="${R}○${N}"
        # Selection Icon
        is_selected "$i" && select_mark="${BY}[+]${N}" || select_mark="   "

        # Truncate long names to 22 chars to protect the 2-column layout
        display_name="${clean_name:0:22}"

        printf " %b ${BG}%2d${N} %-22s %b  " "$select_mark" "$num" "$display_name" "$status"
        ((count++))
        [[ $((count % 2)) -eq 0 ]] && echo ""
    done

    # Add a newline if list ends on an odd number
    [[ $((count % 2)) -ne 0 ]] && echo ""

    echo -e "${C} ──────────────────────────────────────────────────────────${N}"
    echo -e " ${BW}SELECTED:${N} ${BY}${#selected_indices[@]}${N} items"
    echo -e " ${BG}[i]${N} Install  ${BR}[r]${N} Remove  ${BM}[a]${N} Select All  ${BC}[c]${N} Clear  ${R}[0]${N} Exit"
    echo -e "${C} ──────────────────────────────────────────────────────────${N}"
}

# ==========================================
# 🔁 MAIN LOOP
# ==========================================
while true; do
    show_menu
    read -p " 👉 Select ID(s) or Action: " choice

    case $choice in
        0) echo -e "\n${M} Bye!${N}"; exit 0 ;;
        c|C) selected_indices=() ;;
        a|A) 
            selected_indices=()
            for i in "${!names[@]}"; do
                selected_indices+=("$i")
            done
            ;;
        i|I|r|R)
            if [[ ${#selected_indices[@]} -eq 0 ]]; then
                echo -e "${R}Nothing selected!${N}"; sleep 1; continue
            fi
            action_type="install"
            [[ "$choice" =~ [rR] ]] && action_type="remove"
            
            for idx in "${selected_indices[@]}"; do
                run_blueprint "${names[$idx]}" "$action_type"
            done
            selected_indices=()
            echo ""
            read -p "Done. Press Enter to return..."
            ;;
        *)
            # Multi-select toggle logic (supports space-separated numbers like "1 4 12")
            for val in $choice; do
                if [[ "$val" =~ ^[0-9]+$ ]] && (( val >= 1 && val <= ${#names[@]} )); then
                    idx=$((val-1))
                    if is_selected "$idx"; then
                        # Remove from array
                        for i in "${!selected_indices[@]}"; do
                            if [[ ${selected_indices[i]} -eq $idx ]]; then
                                unset 'selected_indices[i]'
                            fi
                        done
                        selected_indices=("${selected_indices[@]}") # Re-index array
                    else
                        selected_indices+=("$idx")
                    fi
                else
                    echo -e "${R}Invalid option: $val${N}"; sleep 0.5
                fi
            done
            ;;
    esac
done
