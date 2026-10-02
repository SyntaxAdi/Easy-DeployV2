#!/bin/bash

kill_screen() {
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
        echo " No active screen sessions to stop or kill."
        echo "====================================================="
        echo ""
        return
    fi

    display_options+=("[ Back to Screen Menu ]")

    local selected_display
    if command -v fzf &>/dev/null; then
        selected_display=$(printf '%s\n' "${display_options[@]}" | fzf --prompt="Select screen to kill: " --height=40% --reverse)
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
    echo "Stopping and killing screen session '$chosen_screen'..."
    screen -S "$chosen_screen" -X quit 2>/dev/null || true
    sleep 1

    if screen -ls 2>&1 | grep -q "[[:space:]]${chosen_pid}\."; then
        kill -9 "$chosen_pid" 2>/dev/null || true
        screen -wipe &>/dev/null || true
    fi

    echo "Screen session '$chosen_screen' killed successfully."
    sleep 2
    clear
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    kill_screen
fi
