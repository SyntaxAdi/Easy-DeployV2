#!/bin/bash

SCRIPT_DIR_SCREEN_CMDS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_SCREEN_CMDS/list_screens.sh"
source "$SCRIPT_DIR_SCREEN_CMDS/connect_screen.sh"
source "$SCRIPT_DIR_SCREEN_CMDS/kill_screen.sh"

show_screen_menu() {
    local should_clear="${1:-true}"
    if [ "$should_clear" = "true" ]; then
        clear
    fi
    echo "==============================="
    echo "       Screen Manager"
    echo "==============================="
    echo "1) List all screens"
    echo "2) Connect to a screen"
    echo "3) Stop / Kill a screen"
    echo "4) Back to main menu"
    echo "==============================="
}

main_screen_menu() {
    local should_clear="true"
    while true; do
        show_screen_menu "$should_clear"
        should_clear="true"
        read -rp "Choose an option: " choice

        case "$choice" in
            1)
                list_screens
                should_clear="false"
                ;;
            2)
                connect_screen
                should_clear="false"
                ;;
            3)
                kill_screen
                should_clear="false"
                ;;
            4)
                clear
                break
                ;;
            *)
                echo "Invalid option. Try again."
                sleep 1
                ;;
        esac
    done
}

main_screen_menu
