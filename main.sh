#!/bin/bash

set -e

clear

show_menu() {
    echo "==============================="
    echo "       Easy Deploy Menu"
    echo "==============================="
    echo "1) Update packages"
    echo "2) Install requirements"
    echo "3) Setup environment"
    echo "4) Clone a repo"
    echo "5) Fetch script updates"
    echo "6) Exit"
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
            bash scripts/self-update.sh
            exec bash "$0"
            ;;
        6)
            echo "Bye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            ;;
    esac

    echo ""
done
