#!/bin/bash

set -e

[ -n "$_SCREEN_MANAGER_SH_LOADED" ] && return 0
_SCREEN_MANAGER_SH_LOADED=1

SCRIPT_DIR_SCREEN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_SCREEN/config.sh"
source "$SCRIPT_DIR_SCREEN/mongo.sh"

run_screen_session() {
    local target="$1"
    local screen_name="$2"
    local start_cmd="$3"
    local use_venv="${4:-false}"

    if [ -z "$screen_name" ] || [ "$screen_name" = "null" ] || [ -z "$start_cmd" ] || [ "$start_cmd" = "null" ]; then
        return 0
    fi

    if screen -list | grep -q "\.${screen_name}"; then
        echo "Stopping existing screen session '$screen_name'..."
        screen -S "$screen_name" -X quit || true
        sleep 1
    fi

    echo "Running command: screen -S $screen_name"
    screen -dmS "$screen_name" bash
    sleep 1

    echo "Sending startup command to screen..."
    screen -S "$screen_name" -p 0 -X stuff "cd $target$(printf \\r)"
    if [ "$use_venv" = "true" ] || [ -d "$target/venv" ]; then
        screen -S "$screen_name" -p 0 -X stuff "source venv/bin/activate$(printf \\r)"
    fi
    screen -S "$screen_name" -p 0 -X stuff "${start_cmd}$(printf \\r)"

    screen -S "$screen_name" -p 0 -X detach 2>/dev/null || true

    echo "Screen session '$screen_name' started and running in detached mode."
    echo "You can attach to it using: screen -r $screen_name"
}

start_bot_in_screen() {
    local target="$1"
    local repo_name="$2"

    read -rp "Do you want to start screen and start the bot? (y/n): " start_bot
    if [[ ! "$start_bot" =~ ^[Yy]$ ]]; then
        return 0
    fi

    read -rp "Enter screen name (press Enter for default '$repo_name'): " screen_name
    screen_name="${screen_name:-$repo_name}"

    read -rp "Enter start command (e.g. python3 main.py): " start_cmd
    if [ -n "$start_cmd" ]; then
        run_screen_session "$target" "$screen_name" "$start_cmd" "true"
    else
        echo "No start command entered. Screen session skipped."
    fi

    load_env
    if [ -n "$MONGODB_URL" ] && [ -n "$repo_name" ]; then
        if update_repo_screen_details_in_mongo "$MONGODB_URL" "$repo_name" "$screen_name" "$start_cmd"; then
            echo "Saved screen details to MongoDB."
        else
            echo "Warning: Failed to save screen details to MongoDB." >&2
        fi
    fi
}
