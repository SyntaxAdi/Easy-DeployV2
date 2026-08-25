#!/bin/bash

set -e

[ -n "$_INSTALL_DEPS_SH_LOADED" ] && return 0
_INSTALL_DEPS_SH_LOADED=1

SCRIPT_DIR_INSTALL_DEPS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_INSTALL_DEPS/config.sh"
source "$SCRIPT_DIR_INSTALL_DEPS/mongo.sh"
source "$SCRIPT_DIR_INSTALL_DEPS/setup_project_env.sh"
source "$SCRIPT_DIR_INSTALL_DEPS/screen_manager.sh"

normalize_apt_command() {
    local raw_input="$1"
    [ -z "$raw_input" ] && return 0

    raw_input=$(echo "$raw_input" | xargs)
    [ -z "$raw_input" ] && return 0

    local SUDO=""
    if command -v sudo &>/dev/null && [ "$(id -u)" -ne 0 ]; then
        SUDO="sudo "
    fi

    if [[ "$raw_input" =~ ^(sudo[[:space:]]+)?(apt-get|apt)([[:space:]]+.*)?$ ]]; then
        local cmd="$raw_input"
        
        if [ -n "$SUDO" ] && [[ ! "$cmd" =~ ^sudo[[:space:]] ]]; then
            cmd="sudo $cmd"
        fi

        if [[ "$cmd" =~ [[:space:]]install([[:space:]]|$) ]] && [[ ! "$cmd" =~ [[:space:]](-y|-qq|--yes)([[:space:]]|$) ]]; then
            cmd=$(echo "$cmd" | sed -E 's/([[:space:]]install)([[:space:]]|$)/\1 -y\2/')
        fi

        echo "$cmd"
    else
        echo "${SUDO}apt-get install -y $raw_input"
    fi
}

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
            local setup_success=0
            local apt_cmd=""
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

                        read -rp "Are there any additional apt packages to install? (y/n): " has_apt_pkgs
                        if [[ "$has_apt_pkgs" =~ ^[Yy]$ ]]; then
                            read -rp "Enter package name(s) or install command: " raw_apt_input
                            apt_cmd=$(normalize_apt_command "$raw_apt_input")
                            if [ -n "$apt_cmd" ]; then
                                echo "Installing system packages: $apt_cmd..."
                                eval "$apt_cmd" || echo "Warning: Some apt packages could not be installed." >&2
                            fi
                        fi

                        load_env
                        if [ -n "$MONGODB_URL" ] && [ -n "$repo_name" ]; then
                            if update_repo_commands_in_mongo "$MONGODB_URL" "$repo_name" "$venv_cmd" "$install_cmd" "$extra_cmd" "$apt_cmd"; then
                                echo "Saved setup/install commands to MongoDB."
                            else
                                echo "Warning: Failed to save setup commands to MongoDB." >&2
                            fi
                        fi
                        setup_success=1
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
                        setup_success=1
                    fi
                else
                    setup_success=1
                fi

                read -rp "Are there any additional apt packages to install? (y/n): " has_apt_pkgs
                if [[ "$has_apt_pkgs" =~ ^[Yy]$ ]]; then
                    read -rp "Enter package name(s) or install command: " raw_apt_input
                    apt_cmd=$(normalize_apt_command "$raw_apt_input")
                    if [ -n "$apt_cmd" ]; then
                        echo "Installing system packages: $apt_cmd..."
                        eval "$apt_cmd" || echo "Warning: Some apt packages could not be installed." >&2
                    fi
                fi

                if [ "$setup_success" -eq 1 ]; then
                    load_env
                    if [ -n "$MONGODB_URL" ] && [ -n "$repo_name" ]; then
                        if update_repo_commands_in_mongo "$MONGODB_URL" "$repo_name" "" "$install_cmd" "" "$apt_cmd"; then
                            echo "Saved install command to MongoDB."
                        else
                            echo "Warning: Failed to save install command to MongoDB." >&2
                        fi
                    fi
                fi
            fi
            
            if [ "$setup_success" -eq 1 ]; then
                setup_env_file "$target" "$repo_name"
                start_bot_in_screen "$target" "$repo_name"
            fi
            ;;
        *)
            ;;
    esac

    echo ""
    read -rp "Press Enter to return to main menu..."
}

post_clone_actions() {
    install_project_dependencies "$@"
}

