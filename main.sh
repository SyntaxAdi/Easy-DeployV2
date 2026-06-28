#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/scripts"

show_menu() {
    echo "==============================="
    echo "       Easy Deploy Menu"
    echo "==============================="
    echo "1) Update packages"
    echo "2) Install requirements"
    echo "3) Clone a repo"
    echo "4) Exit"
    echo "==============================="
}

while true; do
    show_menu
    read -rp "Choose an option: " choice

    case "$choice" in
        1)
            source "$SCRIPT_DIR/update.sh"
            ;;
        2)
            source "$SCRIPT_DIR/install.sh"
            ;;
        3)
            source "$SCRIPT_DIR/clone.sh"
            ;;
        4)
            echo "Bye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            ;;
    esac

    echo ""
done
