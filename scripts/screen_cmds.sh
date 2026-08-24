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
    local screen_output
    screen_output=$(screen -ls 2>&1 || true)

    echo "==============================="
    echo "        Active Screens"
    echo "==============================="

    local count=0
    local rows=()
    local re_sock='^[[:space:]]*([0-9]+)\.([^[:space:]]+)'

    while IFS= read -r line; do
        if [[ "$line" =~ $re_sock ]]; then
            local pid="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            rows+=("$(printf " %-8s %s" "$pid" "$name")")
            ((count++))
        fi
    done <<< "$screen_output"

    if [ "$count" -eq 0 ]; then
        echo " No active screens found."
    else
        printf " %-8s %s\n" "PID" "NAME"
        echo "-------------------------------"
        for r in "${rows[@]}"; do
            echo "$r"
        done
    fi
    echo "==============================="
    echo ""
}

connect_screen() {
    local screen_output
    screen_output=$(screen -ls 2>&1 || true)
    local screens=()
    local display_options=()
    local re_sock='^[[:space:]]*([0-9]+)\.([^[:space:]]+)'

    while IFS= read -r line; do
        if [[ "$line" =~ $re_sock ]]; then
            local pid="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            local full_id="${pid}.${name}"
            screens+=("$full_id")
            display_options+=("$(printf "%-8s | %-18s" "$pid" "$name")")
        fi
    done <<< "$screen_output"

    if [ "${#screens[@]}" -eq 0 ]; then
        clear
        echo "====================================================="
        echo " No active screen sessions to connect."
        echo "====================================================="
        echo ""
        return
    fi

    display_options+=("[ Back to Screen Menu ]")

    local selected_display
    if command -v fzf &>/dev/null; then
        selected_display=$(printf '%s\n' "${display_options[@]}" | fzf --prompt="Select screen to connect: " --height=40% --reverse)
    else
        echo "Active screens:"
        select selected_display in "${display_options[@]}"; do
            break
        done
    fi

    if [ -z "$selected_display" ] || [ "$selected_display" = "[ Back to Screen Menu ]" ]; then
        clear
        return
    fi

    # Extract PID or full session name
    local chosen_screen
    local chosen_pid
    chosen_pid=$(echo "$selected_display" | awk '{print $1}')

    for s in "${screens[@]}"; do
        if [[ "$s" == "$chosen_pid"* ]]; then
            chosen_screen="$s"
            break
        fi
    done

    [ -z "$chosen_screen" ] && chosen_screen="$chosen_pid"

    clear
    echo "Connecting to screen session '$chosen_screen'..."
    echo "(Press Ctrl+A followed by D to detach)"
    sleep 1
    screen -r "$chosen_screen" || screen -x "$chosen_screen" || true
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
