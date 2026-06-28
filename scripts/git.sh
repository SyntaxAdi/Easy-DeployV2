#!/bin/bash

set -e

[ -n "$_GIT_SH_LOADED" ] && return 0
_GIT_SH_LOADED=1

SCRIPT_DIR_GIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_GIT/config.sh"
source "$SCRIPT_DIR_GIT/auth.sh"
source "$SCRIPT_DIR_GIT/mongo.sh"

post_clone_actions() {
    local target="$1"
    local repo_name="$2"
    echo ""
    echo "--- Post-Clone Actions ---"
    echo "1) Install dependencies/requirements"
    echo "2) Back to main menu"
    read -rp "Choose option: " post_choice

    case "$post_choice" in
        1)
            read -rp "Is this a Python tech stack project? (y/n): " is_python
            if [[ "$is_python" =~ ^[Yy]$ ]]; then
                local venv_cmd="python3 -m venv venv"
                local install_cmd="source venv/bin/activate && pip3 install -r requirements.txt"
                
                echo "Creating virtual environment: $venv_cmd..."
                if (cd "$target" && eval "$venv_cmd"); then
                    echo "Installing requirements: $install_cmd..."
                    if (cd "$target" && eval "$install_cmd"); then
                        read -rp "Is there any other requirements file? (y/n): " other_reqs
                        local extra_cmd=""
                        if [[ "$other_reqs" =~ ^[Yy]$ ]]; then
                            read -rp "Enter install command (e.g. pip3 install -r requirements-cli.txt): " extra_cmd
                            if [ -n "$extra_cmd" ]; then
                                echo "Executing extra install command: source venv/bin/activate && $extra_cmd..."
                                (cd "$target" && eval "source venv/bin/activate && $extra_cmd")
                            fi
                        fi

                        # Save to MongoDB
                        load_env
                        if [ -n "$MONGODB_URL" ] && [ -n "$repo_name" ]; then
                            if update_repo_commands_in_mongo "$MONGODB_URL" "$repo_name" "$venv_cmd" "$install_cmd" "$extra_cmd"; then
                                echo "Saved python setup/install commands to MongoDB."
                            else
                                echo "Warning: Failed to save setup commands to MongoDB." >&2
                            fi
                        fi
                    else
                        echo "Error: Failed to install requirements." >&2
                    fi
                else
                    echo "Error: Failed to create venv." >&2
                fi
            else
                read -rp "Enter install command (e.g. npm install): " install_cmd
                if [ -n "$install_cmd" ]; then
                    echo "Executing: $install_cmd inside $target..."
                    if (cd "$target" && eval "$install_cmd"); then
                        load_env
                        if [ -n "$MONGODB_URL" ] && [ -n "$repo_name" ]; then
                            if update_repo_commands_in_mongo "$MONGODB_URL" "$repo_name" "" "$install_cmd" ""; then
                                echo "Saved install command to MongoDB."
                            else
                                echo "Warning: Failed to save install command to MongoDB." >&2
                            fi
                        fi
                    fi
                fi
            fi
            ;;
        *)
            ;;
    esac

    clear
}

clone_repo() {
    local url="$1"
    local token="${2:-}"
    local default_name
    default_name=$(basename "$url" .git)

    read -rp "Enter folder name (press Enter for default '$default_name'): " custom_name
    local folder_name="${custom_name:-$default_name}"
    local target="$PWD/$folder_name"

    local auth_url
    auth_url=$(get_authenticated_url "$url" "$token")

    if [ -d "$target" ]; then
        echo "Directory already exists: $target"
        echo "Pulling latest changes..."
        (cd "$target" && git pull)
    else
        echo "Cloning $url into $target..."
        git clone "$auth_url" "$target"
    fi

    load_env
    if [ -n "$MONGODB_URL" ]; then
        if save_repo_to_mongo "$MONGODB_URL" "$folder_name" "$url" "$target"; then
            echo "Saved repository details to MongoDB."
        else
            echo "Warning: Failed to save repository details to MongoDB." >&2
        fi
    fi

    echo "Done: $target"
    post_clone_actions "$target" "$folder_name"
}
