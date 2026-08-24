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
    echo "9) Screen cmds"
    echo "10) Exit"
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
            echo "==============================="
            echo "       Installed Versions"
            echo "==============================="
            if command -v git &>/dev/null; then git --version; else echo "git: not installed"; fi
            if command -v python3 &>/dev/null; then python3 --version; else echo "python3: not installed"; fi
            if command -v pip3 &>/dev/null; then pip3 --version; elif python3 -m pip --version &>/dev/null; then python3 -m pip --version; else echo "pip3: not installed"; fi
            if command -v ffmpeg &>/dev/null; then ffmpeg -version 2>/dev/null | head -n 1; else echo "ffmpeg: not installed"; fi
            if command -v jq &>/dev/null; then jq --version; else echo "jq: not installed"; fi
            if command -v fzf &>/dev/null; then fzf --version 2>/dev/null | head -n 1; else echo "fzf: not installed"; fi
            if command -v mongosh &>/dev/null; then mongosh --version 2>/dev/null | head -n 1; else echo "mongosh: not installed"; fi
            echo "==============================="
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
            bash scripts/screen_cmds.sh
            ;;
        10)
            echo "Bye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            ;;
    esac

    echo ""
done
