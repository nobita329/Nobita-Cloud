#!/bin/bash
clear
# Define colors for the UI
GRAY='\033[1;30m'
WHITE='\033[1;37m'
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# ==========================================
# 1) CREATE CONTAINER
# ==========================================
function create_container() {
    echo -e "\n${CYAN}--- Create New Container ---${NC}"
    echo -e "${WHITE}Select your OS:${NC}"
    echo -e "  1) Ubuntu 22"
    echo -e "  2) Ubuntu 24"
    echo -e "  3) Debian 11"
    echo -e "  4) Debian 12"
    echo -e "  5) Debian 13"
    echo -ne "  ${GRAY}├─ Choice ${NC} ${WHITE}(default: 1)${NC}${GRAY}:${NC} "
    read OS_CHOICE

    case ${OS_CHOICE:-1} in
      1) IMAGE="nobitaa/ubuntu:22" ; DEFAULT_HOST="ubuntu22" ;;
      2) IMAGE="nobitaa/ubuntu:24" ; DEFAULT_HOST="ubuntu24" ;;
      3) IMAGE="nobitaa/debain:11" ; DEFAULT_HOST="debian11" ;;
      4) IMAGE="nobitaa/debain:12" ; DEFAULT_HOST="debian12" ;;
      5) IMAGE="nobitaa/debain:13" ; DEFAULT_HOST="debian13" ;;
      *) IMAGE="nobitaa/debain:12" ; DEFAULT_HOST="debian12" ;;
    esac

    echo -ne "  ${GRAY}├─ HOSTNAME ${NC} ${WHITE}(default: $DEFAULT_HOST)${NC}${GRAY}:${NC} "
    read INPUT_HOSTNAME
    HOSTNAME=${INPUT_HOSTNAME:-$DEFAULT_HOST}

    echo -ne "  ${GRAY}├─ CONTAINERNAME ${NC} ${WHITE}(default: $DEFAULT_HOST)${NC}${GRAY}:${NC} "
    read INPUT_CONTAINERNAME
    CONTAINERNAME=${INPUT_CONTAINERNAME:-$DEFAULT_HOST}

    echo -ne "  ${GRAY}├─ RAM in GB ${NC} ${WHITE}(default: 2)${NC}${GRAY}:${NC} "
    read INPUT_RAM
    RAM=${INPUT_RAM:-2}

    echo -ne "  ${GRAY}├─ CPU Cores ${NC} ${WHITE}(default: 1)${NC}${GRAY}:${NC} "
    read INPUT_CPU
    CPU=${INPUT_CPU:-1}

    echo -ne "  ${GRAY}├─ DISK in GB ${NC} ${WHITE}(default: 10)${NC}${GRAY}:${NC} "
    read INPUT_DISK
    DISK=${INPUT_DISK:-10}

    echo -ne "  ${GRAY}├─ SSH PORT ${NC} ${WHITE}(default: 2215)${NC}${GRAY}:${NC} "
    read INPUT_PORT
    PORT=${INPUT_PORT:-2215}

    echo -e "\n${GREEN}Starting container '$CONTAINERNAME' with image '$IMAGE'...${NC}\n"

    docker run -it --rm \
      --privileged \
      --name "$CONTAINERNAME" \
      -e HOSTNAME="$HOSTNAME" \
      -e CONTAINERNAME="$CONTAINERNAME" \
      -e RAM="$RAM" \
      -e CPU="$CPU" \
      -e DISK="$DISK" \
      -p "$PORT":22 \
      "$IMAGE"
}

# ==========================================
# 2) UNINSTALL CONTAINER
# ==========================================
function uninstall_container() {
    echo -e "\n${CYAN}--- Uninstall/Remove Container ---${NC}"
    echo -e "Currently running/stopped containers:"
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
    
    echo -ne "\n  ${GRAY}├─ Enter CONTAINERNAME to remove ${NC}${GRAY}:${NC} "
    read TARGET_CONTAINER
    
    if [ -n "$TARGET_CONTAINER" ]; then
        # Force remove the container
        docker rm -f "$TARGET_CONTAINER" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Container '$TARGET_CONTAINER' successfully removed.${NC}"
        else
            echo -e "${RED}Failed to remove '$TARGET_CONTAINER'. It may not exist.${NC}"
        fi
    else
        echo -e "${RED}Operation cancelled. No name provided.${NC}"
    fi
}

# ==========================================
# 3) EDITOR
# ==========================================
function open_editor() {
    echo -e "\n${CYAN}--- File Editor ---${NC}"
    echo -ne "  ${GRAY}├─ Enter filename to edit ${NC}${WHITE}(default: script.sh)${NC}${GRAY}:${NC} "
    read EDIT_FILE
    FILE=${EDIT_FILE:-script.sh}
    
    # Check for available editors and open the file
    if command -v nano &> /dev/null; then
        nano "$FILE"
    elif command -v vim &> /dev/null; then
        vim "$FILE"
    elif command -v vi &> /dev/null; then
        vi "$FILE"
    else
        echo -e "${RED}No text editor (nano/vim/vi) found on this system.${NC}"
    fi
}

# ==========================================
# 4) INFO
# ==========================================
function show_info() {
    echo -e "\n${CYAN}--- System & Docker Info ---${NC}"
    echo -e "${WHITE}Host OS:${NC} $(uname -srm)"
    echo -e "${WHITE}Docker Version:${NC} $(docker --version 2>/dev/null || echo 'Docker is not installed or not in PATH')"
    
    echo -e "\n${WHITE}Active Containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}"
    
    echo -e "\n${WHITE}System Resources:${NC}"
    free -h | grep -E "Mem|Swap"
    
    echo -ne "\n${GRAY}Press Enter to return to the menu...${NC}"
    read
}

# ==========================================
# MAIN MENU LOOP
# ==========================================
while true; do
    echo -e "\n${CYAN}=======================================${NC}"
    echo -e "${WHITE}           DOCKER VM MANAGER           ${NC}"
    echo -e "${CYAN}=======================================${NC}"
    echo -e "  1) Create"
    echo -e "  2) Uninstall"
    echo -e "  3) Editor"
    echo -e "  4) Info"
    echo -e "  0) Exit"
    echo -ne "  ${GRAY}├─ Select an option ${NC}${GRAY}:${NC} "
    read MENU_CHOICE

    case $MENU_CHOICE in
        1) create_container ;;
        2) uninstall_container ;;
        3) open_editor ;;
        4) show_info ;;
        0) echo -e "${GREEN}Exiting... Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option. Please try again.${NC}" ;;
    esac
done
