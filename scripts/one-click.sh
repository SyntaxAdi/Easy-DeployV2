#!/bin/bash

SCRIPT_DIR_OC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_OC/config.sh"
source "$SCRIPT_DIR_OC/auth.sh"
source "$SCRIPT_DIR_OC/mongo.sh"
source "$SCRIPT_DIR_OC/git.sh"
source "$SCRIPT_DIR_OC/setup_project_env.sh"
source "$SCRIPT_DIR_OC/screen_manager.sh"
source "$SCRIPT_DIR_OC/install_deps.sh"

one_click_deploy() {
    load_env
    if [ -z "$MONGODB_URL" ]; then
        echo "Error: MONGODB_URL is not set. Run setup environment first."
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    echo "Fetching saved repos from MongoDB..."
    local raw_list
    if ! raw_list=$(fetch_repos_from_mongo "$MONGODB_URL"); then
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    if [ -z "$raw_list" ]; then
        echo "No saved repositories found in MongoDB."
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    local menu_list="[Back to Main Menu]
$raw_list"

    echo "Select a repo to deploy:"
    local selected
    if command -v fzf &>/dev/null; then
        selected=$(echo "$menu_list" | fzf --height 40% --reverse --prompt "Repo> ")
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

    echo "Retrieving details for '$repo_name'..."
    local repo_json
    if ! repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name"); then
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    if [ -z "$repo_json" ]; then
        echo "Error: Repository details not found."
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    local repo_url venv_cmd install_cmd extra_install_cmd apt_cmd env_file env_content screen_name start_cmd
    repo_url=$(echo "$repo_json" | jq -r '.repo_url // ""')
    venv_cmd=$(echo "$repo_json" | jq -r '.venv_cmd // ""')
    install_cmd=$(echo "$repo_json" | jq -r '.install_cmd // ""')
    extra_install_cmd=$(echo "$repo_json" | jq -r '.extra_install_cmd // ""')
    apt_cmd=$(echo "$repo_json" | jq -r '.apt_cmd // ""')
    env_file=$(echo "$repo_json" | jq -r '.env_file // ""')
    env_content=$(echo "$repo_json" | jq -r '.env_content // ""')
    screen_name=$(echo "$repo_json" | jq -r '.screen_name // ""')
    start_cmd=$(echo "$repo_json" | jq -r '.start_cmd // ""')

    local target="$PWD/$repo_name"
    
    echo ""
    echo "=== Starting One-Click Deploy for $repo_name ==="
    echo "Target: $target"
    echo ""

    echo "Step 1: Syncing repository..."
    if ! git_sync_repo "$repo_url" "$target"; then
        echo ""
        echo "Error: Failed to clone or sync repository." >&2
        read -rp "Press Enter to return to main menu..."
        return 1
    fi

    if [ -n "$apt_cmd" ] && [ "$apt_cmd" != "null" ]; then
        echo ""
        echo "Step: Installing system apt packages..."
        local exec_apt_cmd
        exec_apt_cmd=$(normalize_apt_command "$apt_cmd")
        [ -z "$exec_apt_cmd" ] && exec_apt_cmd="$apt_cmd"
        echo "Running: $exec_apt_cmd"
        eval "$exec_apt_cmd" || echo "Warning: Some apt packages failed to install." >&2
    fi

    if [ -n "$venv_cmd" ] && [ "$venv_cmd" != "null" ]; then
        echo ""
        echo "Step 2: Setting up virtual environment..."
        echo "Running: $venv_cmd"
        if ! (cd "$target" && eval "$venv_cmd"); then
            echo ""
            echo "Error: Virtual environment setup failed." >&2
            read -rp "Press Enter to return to main menu..."
            return 1
        fi
    fi

    if [ -n "$install_cmd" ] && [ "$install_cmd" != "null" ]; then
        echo ""
        echo "Step 3: Installing dependencies..."
        echo "Running: $install_cmd"
        if ! (cd "$target" && eval "$install_cmd"); then
            echo ""
            echo "Error: Installing dependencies failed." >&2
            echo "Tip: If wheel compilation failed, install build tools (e.g. clang, build-essential, libffi, openssl)." >&2
            read -rp "Press Enter to return to main menu..."
            return 1
        fi
    fi

    if [ -n "$extra_install_cmd" ] && [ "$extra_install_cmd" != "null" ]; then
        echo ""
        echo "Step 4: Installing extra/alternative dependencies..."
        if [ -n "$venv_cmd" ] && [ "$venv_cmd" != "null" ]; then
            echo "Running inside venv: source venv/bin/activate && $extra_install_cmd"
            if ! (cd "$target" && eval "source venv/bin/activate && $extra_install_cmd"); then
                echo ""
                echo "Error: Extra dependencies installation failed." >&2
                read -rp "Press Enter to return to main menu..."
                return 1
            fi
        else
            echo "Running: $extra_install_cmd"
            if ! (cd "$target" && eval "$extra_install_cmd"); then
                echo ""
                echo "Error: Extra dependencies installation failed." >&2
                read -rp "Press Enter to return to main menu..."
                return 1
            fi
        fi
    fi

    if [ -n "$env_file" ] && [ "$env_file" != "null" ]; then
        echo ""
        echo "Step 5: Writing environment configuration..."
        write_env_file_direct "$target" "$env_file" "$env_content"
    fi

    if [ -n "$screen_name" ] && [ "$screen_name" != "null" ] && [ -n "$start_cmd" ] && [ "$start_cmd" != "null" ]; then
        echo ""
        echo "Step 6: Starting screen session and launching bot..."
        local has_venv="false"
        if [ -n "$venv_cmd" ] && [ "$venv_cmd" != "null" ]; then
            has_venv="true"
        fi
        run_screen_session "$target" "$screen_name" "$start_cmd" "$has_venv"
    fi

    echo ""
    echo "=== One-Click Deploy Completed Successfully! ==="
    echo ""
    read -rp "Press Enter to return to main menu..."
}

one_click_deploy
