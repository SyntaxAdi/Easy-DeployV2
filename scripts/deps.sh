#!/bin/bash

set -e

[ -n "$_DEPS_SH_LOADED" ] && return 0
_DEPS_SH_LOADED=1

SCRIPT_DIR_DEPS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_DEPS/config.sh"
source "$SCRIPT_DIR_DEPS/mongo.sh"

install_project_dependencies() {
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

post_clone_actions() {
    install_project_dependencies "$@"
}
