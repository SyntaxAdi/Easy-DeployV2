#!/bin/bash

get_versions_msg() {
    local git_v python_v pip_v ffmpeg_v jq_v fzf_v mongosh_v
    git_v=$(git --version 2>/dev/null || echo "git: not installed")
    python_v=$(python3 --version 2>/dev/null || echo "python3: not installed")
    pip_v=$(pip3 --version 2>/dev/null || echo "pip3: not installed")
    ffmpeg_v=$(ffmpeg -version 2>/dev/null | head -n 1 || echo "ffmpeg: not installed")
    jq_v=$(jq --version 2>/dev/null | head -n 1 || echo "jq: not installed")
    fzf_v=$(fzf --version 2>/dev/null || echo "fzf: not installed")
    mongosh_v=$(mongosh --version 2>/dev/null | head -n 1 || echo "mongosh: not installed")

    echo "=== Installed Versions ==="
    echo "$git_v"
    echo "$python_v"
    echo "$pip_v"
    echo "$ffmpeg_v"
    echo "$jq_v"
    echo "$fzf_v"
    echo "$mongosh_v"
    echo ""
    echo "All dependencies installed successfully."
}

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
            MSG=$(get_versions_msg)
            exec bash "$0" "$MSG"
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
