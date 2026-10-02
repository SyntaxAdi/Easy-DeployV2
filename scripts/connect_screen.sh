#!/bin/bash

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
    sleep 3
    screen -r "$chosen_screen" || screen -x "$chosen_screen" || true
    clear
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    connect_screen
fi
