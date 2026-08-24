#!/bin/bash

show_menu() {
    local should_clear="${2:-true}"
    if [ "$should_clear" = "true" ]; then
        clear
    fi
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
    echo "8) Generate string session"
    echo "9) Exit"
    echo "==============================="
}

MSG="${1:-}"
CLEAR_MENU="true"

while true; do
    show_menu "$MSG" "$CLEAR_MENU"
    CLEAR_MENU="true"
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
            clear
            echo "All dependencies installed successfully."
            echo ""
            echo "=== Installed Versions ==="
            git --version 2>/dev/null || echo "git: not installed"
            python3 --version 2>/dev/null || echo "python3: not installed"
            pip3 --version 2>/dev/null || echo "pip3: not installed"
            ffmpeg -version 2>/dev/null | head -n 1 || echo "ffmpeg: not installed"
            jq --version 2>/dev/null | head -n 1 || echo "jq: not installed"
            fzf --version 2>/dev/null || echo "fzf: not installed"
            mongosh --version 2>/dev/null | head -n 1 || echo "mongosh: not installed"
            echo ""
            CLEAR_MENU="false"
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
            python3 scripts/session.py
            ;;
        9)
            echo "Bye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            ;;
    esac

    echo ""
done
