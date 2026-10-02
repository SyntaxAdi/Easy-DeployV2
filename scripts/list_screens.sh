#!/bin/bash

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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    list_screens
fi
