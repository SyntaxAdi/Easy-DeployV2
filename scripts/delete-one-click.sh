#!/bin/bash

set -e

SCRIPT_DIR_DOC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_DOC/config.sh"
source "$SCRIPT_DIR_DOC/auth.sh"
source "$SCRIPT_DIR_DOC/mongo.sh"

MONGO_URL=$(get_mongo_url)

if [ -z "$MONGO_URL" ]; then
    echo "MongoDB URL is not configured. Setup environment first."
    sleep 2
    exit 0
fi

repos_output=$(fetch_repos_from_mongo "$MONGO_URL" || true)

if [ -z "$repos_output" ]; then
    echo "No 1-Click Deployments found in database."
    sleep 2
    exit 0
fi

options=("[ Back to Main Menu ]")
while IFS= read -r line; do
    [ -n "$line" ] && options+=("$line")
done <<< "$repos_output"

if command -v fzf &>/dev/null; then
    selected=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select 1-Click Deploy to delete: " --height=40% --reverse)
else
    echo "Select 1-Click Deploy to delete:"
    select selected in "${options[@]}"; do
        break
    done
fi

if [ -z "$selected" ] || [ "$selected" = "[ Back to Main Menu ]" ]; then
    clear
    exit 0
fi

# Extract repo_name (before " | ")
selected_repo_name=$(echo "$selected" | awk -F ' \\| ' '{print $1}')

# Fetch repo details to get screen_name and target_path
repo_json=$(fetch_repo_details_from_mongo "$MONGO_URL" "$selected_repo_name" || true)

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

# 2. Delete local project files/directory if exists
if [ -n "$target_path" ] && [ "$target_path" != "null" ] && [ -d "$target_path" ]; then
    echo "Removing local directory '$target_path'..."
    rm -rf "$target_path"
fi

# 3. Delete deployment document from MongoDB
echo "Deleting deployment '$selected_repo_name' from database..."
delete_repo_from_mongo "$MONGO_URL" "$selected_repo_name"

echo "Deleted '$selected_repo_name' successfully."
sleep 1.5
clear
