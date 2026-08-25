#!/bin/bash

set -e

SCRIPT_DIR_DOC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_DOC/config.sh"
source "$SCRIPT_DIR_DOC/auth.sh"
source "$SCRIPT_DIR_DOC/mongo.sh"

load_env

if [ -z "$MONGODB_URL" ]; then
    echo "Error: MONGODB_URL is not set. Run setup environment first."
    read -rp "Press Enter to return to main menu..."
    exit 0
fi

echo "Fetching saved deployments from MongoDB..."
raw_list=$(fetch_repos_from_mongo "$MONGODB_URL" || true)

if [ -z "$raw_list" ]; then
    echo "No saved 1-Click Deployments found in MongoDB."
    read -rp "Press Enter to return to main menu..."
    exit 0
fi

menu_list="[Back to Main Menu]
$raw_list"

echo "Select a 1-Click Deploy to delete:"
selected=""
if command -v fzf &>/dev/null; then
    selected=$(echo "$menu_list" | fzf --height 40% --reverse --prompt "Delete Deploy> ")
else
    i=1
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
        exit 0
    fi
    selected="${repo_map[$repo_num]}"
fi

if [ -z "$selected" ] || [ "$selected" = "[Back to Main Menu]" ]; then
    exit 0
fi

# Extract repo_name (before "|")
selected_repo_name=$(echo "$selected" | awk -F '|' '{print $1}' | xargs)

# Fetch repo details to get screen_name and target_path
repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$selected_repo_name" || true)

screen_name=""
target_path=""
if [ -n "$repo_json" ]; then
    if command -v jq &>/dev/null; then
        screen_name=$(echo "$repo_json" | jq -r '.screen_name // ""')
        target_path=$(echo "$repo_json" | jq -r '.target_path // ""')
    elif command -v python3 &>/dev/null; then
        screen_name=$(echo "$repo_json" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("screen_name", "") or "")' 2>/dev/null || echo "")
        target_path=$(echo "$repo_json" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("target_path", "") or "")' 2>/dev/null || echo "")
    fi
fi

# 1. Terminate screen session if running
if [ -n "$screen_name" ] && [ "$screen_name" != "null" ]; then
    if screen -list 2>/dev/null | grep -q "\.${screen_name}"; then
        echo "Stopping active screen session '$screen_name'..."
        screen -S "$screen_name" -X quit || true
        sleep 1
    fi
fi

# 2. Delete local project directory if exists
if [ -n "$target_path" ] && [ "$target_path" != "null" ] && [ -d "$target_path" ]; then
    echo "Removing local directory '$target_path'..."
    rm -rf "$target_path"
fi

# 3. Delete deployment document from MongoDB
echo "Deleting deployment '$selected_repo_name' from database..."
delete_repo_from_mongo "$MONGODB_URL" "$selected_repo_name"

echo "Deleted '$selected_repo_name' successfully."
read -rp "Press Enter to return to main menu..."
