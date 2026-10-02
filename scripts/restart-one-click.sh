#!/bin/bash

SCRIPT_DIR_ROC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_ROC/config.sh"
source "$SCRIPT_DIR_ROC/mongo.sh"
source "$SCRIPT_DIR_ROC/screen_manager.sh"

restart_one_click() {
    load_env
    if [ -z "$MONGODB_URL" ]; then
        echo "Error: MONGODB_URL is not set. Run setup environment first."
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    echo "Fetching saved deployments from MongoDB..."
    local raw_list
    if ! raw_list=$(fetch_repos_from_mongo "$MONGODB_URL"); then
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    if [ -z "$raw_list" ]; then
        echo "No saved deployments found in MongoDB."
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    local menu_list="[Back to Main Menu]
$raw_list"

    echo "Select a deployment to restart:"
    local selected=""
    if command -v fzf &>/dev/null; then
        selected=$(echo "$menu_list" | fzf --height 40% --reverse --prompt "Restart Deployment> ")
    else
        local i=1
        declare -A repo_map
        echo "0) [Back to Main Menu]"
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                repo_map[$i]="$line"
                echo "$i) $line"
                i=$((i+1))
            fi
        done <<< "$raw_list"
        read -rp "Enter number: " repo_num
        if [ "$repo_num" = "0" ] || [ -z "$repo_num" ]; then
            return 0
        fi
        selected="${repo_map[$repo_num]}"
    fi

    if [ -z "$selected" ] || [ "$selected" = "[Back to Main Menu]" ]; then
        return 0
    fi

    local repo_name
    repo_name=$(echo "$selected" | awk -F '|' '{print $1}' | xargs)

    if [ -z "$repo_name" ]; then
        return 0
    fi

    echo "Retrieving details for '$repo_name'..."
    local repo_json
    if ! repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name"); then
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    if [ -z "$repo_json" ]; then
        echo "Error: Deployment details not found for '$repo_name'."
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    local target_path screen_name start_cmd venv_cmd
    target_path=$(echo "$repo_json" | jq -r '.target_path // ""')
    screen_name=$(echo "$repo_json" | jq -r '.screen_name // ""')
    start_cmd=$(echo "$repo_json" | jq -r '.start_cmd // ""')
    venv_cmd=$(echo "$repo_json" | jq -r '.venv_cmd // ""')

    local target="$target_path"
    if [ -z "$target" ] || [ "$target" = "null" ] || [ ! -d "$target" ]; then
        target="$PWD/$repo_name"
    fi

    if [ ! -d "$target" ]; then
        echo "Error: Project directory '$target' not found."
        echo "Please deploy first using One-click Deploy (Option 6)."
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    if [ -z "$screen_name" ] || [ "$screen_name" = "null" ]; then
        screen_name="$repo_name"
    fi

    if [ -z "$start_cmd" ] || [ "$start_cmd" = "null" ]; then
        echo "No start command configured for '$repo_name'."
        read -rp "Enter bot start command (e.g. python3 -m bot): " start_cmd
        if [ -n "$start_cmd" ]; then
            update_repo_screen_details_in_mongo "$MONGODB_URL" "$repo_name" "$screen_name" "$start_cmd" || true
        else
            echo "Restart aborted: missing start command."
            read -rp "Press Enter to return to main menu..."
            return 1
        fi
    fi

    local has_venv="false"
    if [ -n "$venv_cmd" ] && [ "$venv_cmd" != "null" ]; then
        has_venv="true"
    elif [ -d "$target/venv" ]; then
        has_venv="true"
    fi

    echo ""
    echo "=== Restarting $repo_name ==="
    echo "Directory : $target"
    echo "Screen    : $screen_name"
    echo "Command   : $start_cmd"
    echo "Venv      : $has_venv"
    echo ""

    run_screen_session "$target" "$screen_name" "$start_cmd" "$has_venv"

    echo ""
    echo "=== Restart Completed Successfully! ==="
    echo ""
    read -rp "Press Enter to return to main menu..."
}

restart_one_click
