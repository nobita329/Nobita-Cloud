#!/bin/bash

# --- SEMA NEON THEME ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;214m'
NC='\033[0m'
HEADER_LINE="${GRAY}────────────────────────────────────────────────────────────${NC}"
PHP_VERSION="8.3"

# --- UI HELPERS ---
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
                                                                                                                                                 dddddddd                                                                                                                                                                                                                                                                     dddddddd                                                                                        
                   hhhhhhh                                MMMMMMMM               MMMMMMMM                             AAA                        d::::::d                          iiii                                                                   iiii          tttt         hhhhhhh                  PPPPPPPPPPPPPPPPP            tttt                                                                               d::::::d                                              tttt                              lllllll 
                   h:::::h                                M:::::::M             M:::::::M                            A:::A                       d::::::d                         i::::i                                                                 i::::i      ttt:::t         h:::::h                  P::::::::::::::::P        ttt:::t                                                                               d::::::d                                           ttt:::t                              l:::::l 
                   h:::::h                                M::::::::M           M::::::::M                           A:::::A                      d::::::d                          iiii                                                                   iiii       t:::::t         h:::::h                  P::::::PPPPPP:::::P       t:::::t                                                                               d::::::d                                           t:::::t                              l:::::l 
                   h:::::h                                M:::::::::M         M:::::::::M                          A:::::::A                     d:::::d                                                                                                             t:::::t         h:::::h                  PP:::::P     P:::::P      t:::::t                                                                               d:::::d                                            t:::::t                              l:::::l 
ppppp   ppppppppp   h::::h hhhhh      ppppp   ppppppppp   M::::::::::M       M::::::::::Myyyyyyy           yyyyyyyA:::::::::A            ddddddddd:::::d    mmmmmmm    mmmmmmm   iiiiiiinnnn  nnnnnnnn         wwwwwww           wwwww           wwwwwwwiiiiiiittttttt:::::ttttttt    h::::h hhhhh              P::::P     P:::::Pttttttt:::::ttttttt        eeeeeeeeeeee    rrrrr   rrrrrrrrr      ooooooooooo       ddddddddd:::::d   aaaaaaaaaaaaa      ccccccccccccccccttttttt:::::tttttttyyyyyyy           yyyyyyyl::::l 
p::::ppp:::::::::p  h::::hh:::::hhh   p::::ppp:::::::::p  M:::::::::::M     M:::::::::::M y:::::y         y:::::yA:::::A:::::A         dd::::::::::::::d  mm:::::::m  m:::::::mm i:::::in:::nn::::::::nn        w:::::w         w:::::w         w:::::w i:::::it:::::::::::::::::t    h::::hh:::::hhh           P::::P     P:::::Pt:::::::::::::::::t      ee::::::::::::ee  r::::rrr:::::::::r   oo:::::::::::oo   dd::::::::::::::d   a::::::::::::a   cc:::::::::::::::ct:::::::::::::::::t y:::::y         y:::::y l::::l 
p:::::::::::::::::p h::::::::::::::hh p:::::::::::::::::p M:::::::M::::M   M::::M:::::::M  y:::::y       y:::::yA:::::A A:::::A       d::::::::::::::::d m::::::::::mm::::::::::m i::::in::::::::::::::nn        w:::::w       w:::::::w       w:::::w   i::::it:::::::::::::::::t    h::::::::::::::hh         P::::PPPPPP:::::P t:::::::::::::::::t     e::::::eeeee:::::eer:::::::::::::::::r o:::::::::::::::o d::::::::::::::::d   aaaaaaaaa:::::a c:::::::::::::::::ct:::::::::::::::::t  y:::::y       y:::::y  l::::l 
pp::::::ppppp::::::ph:::::::hhh::::::hpp::::::ppppp::::::pM::::::M M::::M M::::M M::::::M   y:::::y     y:::::yA:::::A   A:::::A     d:::::::ddddd:::::d m::::::::::::::::::::::m i::::inn:::::::::::::::n        w:::::w     w:::::::::w     w:::::w    i::::itttttt:::::::tttttt    h:::::::hhh::::::h        P:::::::::::::PP  tttttt:::::::tttttt    e::::::e     e:::::err::::::rrrrr::::::ro:::::ooooo:::::od:::::::ddddd:::::d            a::::ac:::::::cccccc:::::ctttttt:::::::tttttt   y:::::y     y:::::y   l::::l 
 p:::::p     p:::::ph::::::h   h::::::hp:::::p     p:::::pM::::::M  M::::M::::M  M::::::M    y:::::y   y:::::yA:::::A     A:::::A    d::::::d    d:::::d m:::::mmm::::::mmm:::::m i::::i  n:::::nnnn:::::n         w:::::w   w:::::w:::::w   w:::::w     i::::i      t:::::t          h::::::h   h::::::h       P::::PPPPPPPPP          t:::::t          e:::::::eeeee::::::e r:::::r     r:::::ro::::o     o::::od::::::d    d:::::d     aaaaaaa:::::ac::::::c     ccccccc      t:::::t          y:::::y   y:::::y    l::::l 
 p:::::p     p:::::ph:::::h     h:::::hp:::::p     p:::::pM::::::M   M:::::::M   M::::::M     y:::::y y:::::yA:::::AAAAAAAAA:::::A   d:::::d     d:::::d m::::m   m::::m   m::::m i::::i  n::::n    n::::n          w:::::w w:::::w w:::::w w:::::w      i::::i      t:::::t          h:::::h     h:::::h       P::::P                  t:::::t          e:::::::::::::::::e  r:::::r     rrrrrrro::::o     o::::od:::::d     d:::::d   aa::::::::::::ac:::::c                   t:::::t           y:::::y y:::::y     l::::l 
 p:::::p     p:::::ph:::::h     h:::::hp:::::p     p:::::pM::::::M    M:::::M    M::::::M      y:::::y:::::yA:::::::::::::::::::::A  d:::::d     d:::::d m::::m   m::::m   m::::m i::::i  n::::n    n::::n           w:::::w:::::w   w:::::w:::::w       i::::i      t:::::t          h:::::h     h:::::h       P::::P                  t:::::t          e::::::eeeeeeeeeee   r:::::r            o::::o     o::::od:::::d     d:::::d  a::::aaaa::::::ac:::::c                   t:::::t            y:::::y:::::y      l::::l 
 p:::::p    p::::::ph:::::h     h:::::hp:::::p    p::::::pM::::::M     MMMMM     M::::::M       y:::::::::yA:::::AAAAAAAAAAAAA:::::A d:::::d     d:::::d m::::m   m::::m   m::::m i::::i  n::::n    n::::n            w:::::::::w     w:::::::::w        i::::i      t:::::t    tttttth:::::h     h:::::h       P::::P                  t:::::t    tttttte:::::::e            r:::::r            o::::o     o::::od:::::d     d:::::d a::::a    a:::::ac::::::c     ccccccc      t:::::t    tttttt   y:::::::::y       l::::l 
 p:::::ppppp:::::::ph:::::h     h:::::hp:::::ppppp:::::::pM::::::M               M::::::M        y:::::::yA:::::A             A:::::Ad::::::ddddd::::::ddm::::m   m::::m   m::::mi::::::i n::::n    n::::n             w:::::::w       w:::::::w        i::::::i     t::::::tttt:::::th:::::h     h:::::h     PP::::::PP                t::::::tttt:::::te::::::::e           r:::::r            o:::::ooooo:::::od::::::ddddd::::::dda::::a    a:::::ac:::::::cccccc:::::c      t::::::tttt:::::t    y:::::::y       l::::::l
 p::::::::::::::::p h:::::h     h:::::hp::::::::::::::::p M::::::M               M::::::M         y:::::yA:::::A               A:::::Ad:::::::::::::::::dm::::m   m::::m   m::::mi::::::i n::::n    n::::n              w:::::w         w:::::w         i::::::i     tt::::::::::::::th:::::h     h:::::h     P::::::::P                tt::::::::::::::t e::::::::eeeeeeee   r:::::r            o:::::::::::::::o d:::::::::::::::::da:::::aaaa::::::a c:::::::::::::::::c      tt::::::::::::::t     y:::::y        l::::::l
 p::::::::::::::pp  h:::::h     h:::::hp::::::::::::::pp  M::::::M               M::::::M        y:::::yA:::::A                 A:::::Ad:::::::::ddd::::dm::::m   m::::m   m::::mi::::::i n::::n    n::::n               w:::w           w:::w          i::::::i       tt:::::::::::tth:::::h     h:::::h     P::::::::P                  tt:::::::::::tt  ee:::::::::::::e   r:::::r             oo:::::::::::oo   d:::::::::ddd::::d a::::::::::aa:::a cc:::::::::::::::c        tt:::::::::::tt    y:::::y         l::::::l
 p::::::pppppppp    hhhhhhh     hhhhhhhp::::::pppppppp    MMMMMMMM               MMMMMMMM       y:::::yAAAAAAA                   AAAAAAAddddddddd   dddddmmmmmm   mmmmmm   mmmmmmiiiiiiii nnnnnn    nnnnnn                www             www           iiiiiiii         ttttttttttt  hhhhhhh     hhhhhhh     PPPPPPPPPP                    ttttttttttt      eeeeeeeeeeeeee   rrrrrrr               ooooooooooo      ddddddddd   ddddd  aaaaaaaaaa  aaaa   cccccccccccccccc          ttttttttttt     y:::::y          llllllll
 p:::::p                               p:::::p                                                 y:::::y                                                                                                                                                                                                                                                                                                                                                                                              y:::::y                   
 p:::::p                               p:::::p                                                y:::::y                                                                                                                                                                                                                                                                                                                                                                                              y:::::y                    
p:::::::p                             p:::::::p                                              y:::::y                                                                                                                                                                                                                                                                                                                                                                                              y:::::y                     
p:::::::p                             p:::::::p                                             y:::::y                                                                                                                                                                                                                                                                                                                                                                                              y:::::y                      
p:::::::p                             p:::::::p                                            yyyyyyy                                                                                                                                                                                                                                                                                                                                                                                              yyyyyyy                       
ppppppppp                             ppppppppp                                                                                                                                                                                                                                                                                                                                                                                                                                                                               

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
EOF
    echo -e "           ${WHITE}PREMIUM PTERODACTYL INSTALLER${NC}"
    echo -e "${HEADER_LINE}"
}

ok() {
    echo -e "  ${GREEN}[OK]${NC} $1"
}

step() {
    echo -e "\n  ${PURPLE}::${NC} ${WHITE}$1${NC}"
}

# --- INPUT FUNCTION ---
ask() {
    local label=$1
    local default=$2
    local var_name=$3
    echo -ne "  ${PURPLE}•${NC} ${WHITE}$label${NC} ${GRAY}[$default]${NC}\n  ${GRAY}╰─>${NC} "
    read input
    if [ -z "$input" ]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

# --- START ---
show_banner

# --- DATA COLLECTION ---
ask "Panel Domain" "panel.nobita.indevs.in" DOMAIN
ask "Admin Email" "admin@gmail.com" EMAIL
ask "Admin Username" "admin" USERNAME
ask "Admin Password" "admin" PASSWORD

# --- FINAL VALIDATION LOOP ---
echo -e "\n  ${GOLD}┌─[ REVIEW CONFIGURATION ]${NC}"
echo -e "  ${GOLD}│${NC} ${GRAY}Domain:${NC}   $DOMAIN"
echo -e "  ${GOLD}│${NC} ${GRAY}Email:${NC}    $EMAIL"
echo -e "  ${GOLD}│${NC} ${GRAY}User:${NC}     $USERNAME"
echo -e "  ${GOLD}└───────────────────────────${NC}"

while true; do
    echo -ne "\n  ${CYAN}Start Installation?${NC} ${WHITE}(y/n)${NC}${GRAY}:${NC} "
    read -n 1 -r CONFIRM
    echo ""

    case $CONFIRM in
        [Yy]* )
            echo -e "  ${GREEN}Proceeding to deployment...${NC}"
            break
            ;;
        [Nn]* )
            echo -e "  ${RED}Installation aborted by user.${NC}"
            exit
            ;;
        * )
            echo -e "  ${GRAY}Invalid input. Enter ${NC}${WHITE}y${NC}${GRAY} or ${NC}${WHITE}n${NC}${GRAY}.${NC}"
            ;;
    esac
done

echo -e "${HEADER_LINE}"
# --------------------------------------------------------- #




