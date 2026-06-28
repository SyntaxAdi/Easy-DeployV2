#!/bin/bash

set -e

SCRIPT_DIR_OC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_OC/config.sh"
source "$SCRIPT_DIR_OC/auth.sh"
source "$SCRIPT_DIR_OC/mongo.sh"
source "$SCRIPT_DIR_OC/git.sh"

one_click_deploy() {
    load_env
    if [ -z "$MONGODB_URL" ]; then
        echo "Error: MONGODB_URL is not set. Run setup environment first."
        return 1
    fi

    echo "Fetching saved repos from MongoDB..."
    local raw_list
    if ! raw_list=$(fetch_repos_from_mongo "$MONGODB_URL"); then
        return 1
    fi

    if [ -z "$raw_list" ]; then
        echo "No saved repositories found in MongoDB."
        return 1
    fi

    echo "Select a repo to deploy:"
    local selected
    if command -v fzf &>/dev/null; then
        selected=$(echo "$raw_list" | fzf --height 40% --reverse --prompt "Repo> ")
    else
        echo "$raw_list"
        read -rp "Enter repo line (e.g. repo_name | url): " selected
    fi

    if [ -z "$selected" ]; then
        echo "No repo selected."
        return 1
    fi

    local repo_name
    repo_name=$(echo "$selected" | awk -F '|' '{print $1}' | xargs)

    echo "Retrieving details for '$repo_name'..."
    local repo_json
    if ! repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name"); then
        return 1
    fi

    if [ -z "$repo_json" ]; then
        echo "Error: Repository details not found."
        return 1
    fi

    # Parse details
    local repo_url
    local venv_cmd
    local install_cmd
    local extra_install_cmd
    local env_file
    local env_content
    local screen_name
    local start_cmd

    repo_url=$(echo "$repo_json" | jq -r '.repo_url // ""')
    venv_cmd=$(echo "$repo_json" | jq -r '.venv_cmd // ""')
    install_cmd=$(echo "$repo_json" | jq -r '.install_cmd // ""')
    extra_install_cmd=$(echo "$repo_json" | jq -r '.extra_install_cmd // ""')
    env_file=$(echo "$repo_json" | jq -r '.env_file // ""')
    env_content=$(echo "$repo_json" | jq -r '.env_content // ""')
    screen_name=$(echo "$repo_json" | jq -r '.screen_name // ""')
    start_cmd=$(echo "$repo_json" | jq -r '.start_cmd // ""')

    local target="$PWD/$repo_name"
    
    echo ""
    echo "=== Starting One-Click Deploy for $repo_name ==="
    echo "Target: $target"
    echo ""

    # Step 1: Clone or Sync repository
    echo "Step 1: Syncing repository..."
    if [ -d "$target" ]; then
        echo "Directory already exists: $target"
        echo "Pulling latest changes..."
        (cd "$target" && git pull)
    else
        local auth_url
        auth_url=$(get_authenticated_url "$repo_url")
        echo "Cloning $repo_url into $target..."
        git clone "$auth_url" "$target"
    fi

    # Step 2: Setup Virtual Environment (venv)
    if [ -n "$venv_cmd" ] && [ "$venv_cmd" != "null" ]; then
        echo ""
        echo "Step 2: Setting up virtual environment..."
        echo "Running: $venv_cmd"
        (cd "$target" && eval "$venv_cmd")
    fi

    # Step 3: Install dependencies
    if [ -n "$install_cmd" ] && [ "$install_cmd" != "null" ]; then
        echo ""
        echo "Step 3: Installing dependencies..."
        echo "Running: $install_cmd"
        (cd "$target" && eval "$install_cmd")
    fi

    # Step 4: Install alternative/extra dependencies
    if [ -n "$extra_install_cmd" ] && [ "$extra_install_cmd" != "null" ]; then
        echo ""
        echo "Step 4: Installing extra/alternative dependencies..."
        if [ -n "$venv_cmd" ] && [ "$venv_cmd" != "null" ]; then
            echo "Running inside venv: source venv/bin/activate && $extra_install_cmd"
            (cd "$target" && eval "source venv/bin/activate && $extra_install_cmd")
        else
            echo "Running: $extra_install_cmd"
            (cd "$target" && eval "$extra_install_cmd")
        fi
    fi

    # Step 5: Setup Environment variables (.env file)
    if [ -n "$env_file" ] && [ "$env_file" != "null" ]; then
        echo ""
        echo "Step 5: Writing environment configuration to $env_file..."
        if [ -n "$env_content" ] && [ "$env_content" != "null" ]; then
            echo -n "$env_content" > "$target/$env_file"
            echo "Configuration saved."
        else
            touch "$target/$env_file"
            echo "Empty configuration file created."
        fi
    fi

    # Step 6: Start bot in screen
    if [ -n "$screen_name" ] && [ "$screen_name" != "null" ] && [ -n "$start_cmd" ] && [ "$start_cmd" != "null" ]; then
        echo ""
        echo "Step 6: Starting screen session and launching bot..."
        
        # Kill existing screen with the same name if running
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
        if [ -n "$venv_cmd" ] && [ "$venv_cmd" != "null" ]; then
            screen -S "$screen_name" -p 0 -X stuff "source venv/bin/activate$(printf \\r)"
        fi
        screen -S "$screen_name" -p 0 -X stuff "${start_cmd}$(printf \\r)"

        # Detach
        screen -S "$screen_name" -p 0 -X detach 2>/dev/null || true

        echo "Screen session '$screen_name' started and running in detached mode."
        echo "You can attach to it using: screen -r $screen_name"
    fi

    echo ""
    echo "=== One-Click Deploy Completed Successfully! ==="
    echo ""
    read -rp "Press Enter to return to main menu..."
}

one_click_deploy
