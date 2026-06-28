#!/bin/bash

set -e

clear

show_menu() {
    echo "==============================="
    echo "       Easy Deploy Menu"
    echo "==============================="
    echo "1) Fetch script updates"
    echo "2) Update packages"
    echo "3) Install requirements"
    echo "4) Setup environment"
    echo "5) Clone a repo"
    echo "6) Exit"
    echo "==============================="
}

while true; do
    show_menu
    read -rp "Choose an option: " choice

    case "$choice" in
        1)
            bash scripts/self-update.sh
            exec bash "$0"
            ;;
        2)
            bash scripts/updates.sh
            ;;
        3)
            bash scripts/install.sh
            ;;
        4)
            bash scripts/setup-env.sh
            ;;
        5)
            bash scripts/clone.sh
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
