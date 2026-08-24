#!/bin/bash

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
    echo "3) Back to main menu"
    echo "==============================="
}

list_screens() {
    clear
    echo "=== Active Screens ==="
    screen -ls || true
    echo ""
}

connect_screen() {
    local screens
    screens=$(screen -ls | awk '/^[[:space:]]*[0-9]+\.[^[:space:]]+/ {print $1}')

    if [ -z "$screens" ]; then
        clear
        echo "No active screen sessions found."
        echo ""
        return
    fi

    local options=()
    while IFS= read -r s; do
        [ -n "$s" ] && options+=("$s")
    done <<< "$screens"
    options+=("[ Back to Screen Menu ]")

    local choice
    if command -v fzf &>/dev/null; then
        choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select screen to connect: " --height=40% --reverse)
    else
        echo "Active screens:"
        select choice in "${options[@]}"; do
            break
        done
    fi

    if [ -z "$choice" ] || [ "$choice" = "[ Back to Screen Menu ]" ]; then
        clear
        return
    fi

    clear
    echo "Connecting to screen '$choice'..."
    echo "(Use Ctrl+A then D to detach)"
    sleep 1
    screen -r "$choice" || screen -x "$choice" || true
    clear
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
