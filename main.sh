#!/bin/bash

set -e

show_menu() {
    clear
    if [ -n "$1" ]; then
        echo "$1"
        echo ""
    fi
    echo "==============================="
    echo "       Easy Deploy Menu"
    echo "==============================="
    echo "1) Fetch script updates"
    echo "2) Update packages"
    echo "3) Install requirements"
    echo "4) Setup environment"
    echo "5) Clone a repo"
    echo "6) One-click Deploy"
    echo "7) Edit Env Variables"
    echo "8) Exit"
    echo "==============================="
}

MSG="${1:-}"

while true; do
    show_menu "$MSG"
    MSG=""
    read -rp "Choose an option: " choice

    case "$choice" in
        1)
            MSG=$(bash scripts/self-update.sh)
            exec bash "$0" "$MSG"
            ;;
        2)
            bash scripts/updates.sh
            MSG="All system packages updated successfully."
            exec bash "$0" "$MSG"
            ;;
        3)
            bash scripts/install.sh
            ;;
        4)
            bash scripts/setup-env.sh
            MSG="Environment configured successfully."
            ;;
        5)
            bash scripts/clone.sh
            ;;
        6)
            bash scripts/one-click.sh
            ;;
        7)
            bash scripts/edit-env.sh
            ;;
        8)
            echo "Bye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            ;;
    esac

    echo ""
done
