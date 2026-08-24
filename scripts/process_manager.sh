#!/bin/bash

set -e

[ -n "$_PROCESS_MANAGER_SH_LOADED" ] && return 0
_PROCESS_MANAGER_SH_LOADED=1

SCRIPT_DIR_PM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_PM/config.sh"
source "$SCRIPT_DIR_PM/mongo.sh"
source "$SCRIPT_DIR_PM/screen_manager.sh"

apply_env_updates() {
    local target_path="$1"
    local repo_name="$2"
    local env_file="$3"
    local env_content="$4"
    local repo_json="$5"

    # Save to MongoDB
    update_repo_env_file_in_mongo "$MONGODB_URL" "$repo_name" "$env_file" "$env_content"

    local screen_name
    local start_cmd
    local venv_cmd
    screen_name=$(echo "$repo_json" | jq -r '.screen_name // ""')
    start_cmd=$(echo "$repo_json" | jq -r '.start_cmd // ""')
    venv_cmd=$(echo "$repo_json" | jq -r '.venv_cmd // ""')

    local was_running=0
    if [ -n "$screen_name" ] && [ "$screen_name" != "null" ]; then
        if screen -list | grep -q "\.${screen_name}"; then
            was_running=1
        fi
    fi

    if [ "$was_running" -eq 1 ]; then
        echo "Process screen session '$screen_name' is running. Stopping it..."
        screen -S "$screen_name" -X quit || true
        sleep 1
    fi

    # Update env file directly
    if [ -d "$target_path" ] && [ -n "$env_file" ] && [ "$env_file" != "null" ]; then
        echo -n "$env_content" > "$target_path/$env_file"
        echo "Updated local env file at $target_path/$env_file."
    fi

    if [ "$was_running" -eq 1 ] && [ -n "$start_cmd" ] && [ "$start_cmd" != "null" ]; then
        echo "Restarting process in screen..."
        local has_venv="false"
        if [ -n "$venv_cmd" ] && [ "$venv_cmd" != "null" ]; then
            has_venv="true"
        fi
        run_screen_session "$target_path" "$screen_name" "$start_cmd" "$has_venv"
    fi
}
