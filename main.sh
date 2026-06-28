#!/bin/bash

set -e

# Auto-update scripts on startup
bash scripts/self-update.sh
if [ $? -eq 1 ]; then
    exec bash "$0" "$@"
fi

show_menu() {
    echo "==============================="
    echo "       Easy Deploy Menu"
    echo "==============================="
    echo "1) Update packages"
    echo "2) Install requirements"
    echo "3) Setup environment"
    echo "4) Clone a repo"
    echo "5) Exit"
    echo "==============================="
}

while true; do
    show_menu
    read -rp "Choose an option: " choice

    case "$choice" in
        1)
            bash scripts/updates.sh
            ;;
        2)
            bash scripts/install.sh
            ;;
        3)
            bash scripts/setup-env.sh
            ;;
        4)
            bash scripts/clone.sh
            ;;
        5)
            echo "Bye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            ;;
    esac

    echo ""
done
