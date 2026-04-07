#!/bin/bash

# 🎨 Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
MAGENTA="\e[35m"
RESET="\e[0m"

draw_box() {
    echo -e "${CYAN}╔══════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}      CONTROL PANEL UI      ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════╝${RESET}"
}

pause() {
    echo ""
    read -p "   Press Enter to continue..." dummy
}

while true; do
    clear

    # Check install every loop (fix)
    if command -v blueprint >/dev/null 2>&1; then
        status="${GREEN}● ONLINE${RESET}"
        installed=true
    else
        status="${RED}● OFFLINE${RESET}"
        installed=false
    fi

    draw_box
    echo ""
    echo -e "   Blueprint Status : $status"
    echo ""
    echo -e "   ${YELLOW}[1]${RESET} Blueprint"
    echo -e "   ${YELLOW}[2]${RESET} Theme"
    echo -e "   ${YELLOW}[3]${RESET} Extensions"
    echo -e "   ${YELLOW}[4]${RESET} Hyper V1 🚀"
    echo ""
    echo -e "   ${RED}[0] Exit${RESET}"
    echo ""

    read -p "   ➤ Select Option : " main

    case $main in
        1)
            while true; do
                clear

                # Re-check inside submenu (important fix)
                if command -v blueprint >/dev/null 2>&1; then
                    status="${GREEN}● ONLINE${RESET}"
                    installed=true
                else
                    status="${RED}● OFFLINE${RESET}"
                    installed=false
                fi

                draw_box
                echo ""
                echo -e "   ${CYAN}BLUEPRINT PANEL${RESET}"
                echo -e "   Status : $status"
                echo ""

                if [ "$installed" = false ]; then
                    echo -e "   ${GREEN}[1] Install${RESET}"
                    echo -e "   ${RED}[0] Back${RESET}"
                else
                    echo -e "   ${GREEN}[1] Reinstall${RESET}"
                    echo -e "   ${GREEN}[2] Update${RESET}"
                    echo -e "   ${GREEN}[3] Info${RESET}"
                    echo -e "   ${GREEN}[4] Version${RESET}"
                    echo -e "   ${RED}[5] Uninstall${RESET}"
                    echo -e "   ${RED}[0] Back${RESET}"
                fi

                echo ""
                read -p "   ➤ Select : " bp

                case $bp in
                    1)
                        if [ "$installed" = false ]; then
                            echo -e "${CYAN}Installing...${RESET}"
                            rm -f /etc/apt/keyrings/nodesource.gpg 2>/dev/null
                            yes | bash <(curl -s https://raw.githubusercontent.com/nobita329/hub/refs/heads/main/Codinghub/thames/install.sh)
                        else
                            yes | blueprint -rerun-install
                        fi
                        pause
                        ;;
                    2)
                        yes | blueprint -upgrade
                        pause
                        ;;
                    3)
                        blueprint -info
                        pause
                        ;;
                    4)
                        blueprint -version
                        pause
                        ;;
                    5)
                        echo -e "${RED}Uninstalling...${RESET}"
                        path=$(which blueprint 2>/dev/null)

                        if [ -n "$path" ]; then
                            rm -f "$path"
                            rm -rf ~/.blueprint ~/.config/blueprint /var/www/pterodactyl/.blueprint
                            echo -e "${GREEN}Removed successfully ✔${RESET}"
                        else
                            echo -e "${RED}Not installed ❌${RESET}"
                        fi
                        pause
                        ;;
                    0)
                        break
                        ;;
                    *)
                        echo -e "${RED}Invalid option${RESET}"
                        sleep 1
                        ;;
                esac
            done
            ;;

        2)
            clear
            draw_box
            echo ""
            echo -e "${CYAN}Launching Theme...${RESET}"
            bash <(curl -s https://raw.githubusercontent.com/nobita329/hub/refs/heads/main/Codinghub/thames/Theme/th.sh)
            pause
            ;;

        3)
            clear
            draw_box
            echo ""
            echo -e "${CYAN}Launching Extensions...${RESET}"
            bash <(curl -s https://raw.githubusercontent.com/nobita329/hub/refs/heads/main/Codinghub/thames/Extensions/ext.sh)
            pause
            ;;

        4)
            clear
            draw_box
            echo ""
            echo -e "${MAGENTA}Launching Hyper V1...${RESET}"
            wget -O installer.sh https://r2.rolexdev.tech/hyperv1/installer.sh
            chmod +x installer.sh
            sudo ./installer.sh
            rm installer.sh
            cd /var/www/pterodactyl
            php artisan view:clear
            php artisan config:clear
            php artisan queue:restart
            pause
            ;;

        0)
            clear
            echo -e "${RED}Exiting...${RESET}"
            exit
            ;;

        *)
            echo -e "${RED}Invalid option${RESET}"
            sleep 1
            ;;
    esac
done

