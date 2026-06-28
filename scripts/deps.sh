#!/bin/bash

set -e

[ -n "$_DEPS_SH_LOADED" ] && return 0
_DEPS_SH_LOADED=1

SCRIPT_DIR_DEPS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_DEPS/config.sh"
source "$SCRIPT_DIR_DEPS/mongo.sh"

setup_env_file() {
    local target="$1"
    local repo_name="$2"
    
    read -rp "Do you want to add an env file? (y/n): " add_env
    if [[ ! "$add_env" =~ ^[Yy]$ ]]; then
        return 0
    fi

    read -rp "Enter env file name (press Enter for default '.env'): " env_file_name
    env_file_name="${env_file_name:-.env}"
    local env_path="$target/$env_file_name"

    echo ""
    echo "How would you like to enter environment variables?"
    echo "1) Key-value pairs one by one"
    echo "2) Paste entire env file content"
    echo "3) Enter KEY=VALUE lines"
    read -rp "Choose option: " env_opt

    local env_content=""
    case "$env_opt" in
        1)
            echo "Enter environment variables (press Enter on empty variable name to finish):"
            touch "$env_path"
            while true; do
                read -rp "Variable name: " var_name
                if [ -z "$var_name" ]; then
                    break
                fi
                read -rp "Value for $var_name: " var_val
                local line="${var_name}=${var_val}"
                echo "$line" >> "$env_path"
                if [ -z "$env_content" ]; then
                    env_content="$line"
                else
                    env_content="${env_content}
${line}"
                fi
            done
            ;;
        2)
            echo "Paste your env file content below (press Enter on empty line or type EOF to finish):"
            touch "$env_path"
            while true; do
                read -r line
                if [ -z "$line" ] || [ "$line" = "EOF" ]; then
                    break
                fi
                echo "$line" >> "$env_path"
                if [ -z "$env_content" ]; then
                    env_content="$line"
                else
                    env_content="${env_content}
${line}"
                fi
            done
            ;;
        3)
            echo "Enter KEY=VALUE lines (press Enter on empty line to finish):"
            touch "$env_path"
            while true; do
                read -rp "> " line
                if [ -z "$line" ]; then
                    break
                fi
                if [[ "$line" =~ = ]]; then
                    echo "$line" >> "$env_path"
                    if [ -z "$env_content" ]; then
                        env_content="$line"
                    else
                        env_content="${env_content}
${line}"
                    fi
                else
                    echo "Invalid format, must contain '='."
                fi
            done
            ;;
        *)
            echo "Invalid option. Env file setup skipped."
            return 1
            ;;
    esac

    echo "Environment file successfully saved at: $env_path"

    # Save to MongoDB
    load_env
    if [ -n "$MONGODB_URL" ] && [ -n "$repo_name" ]; then
        if update_repo_env_file_in_mongo "$MONGODB_URL" "$repo_name" "$env_file_name" "$env_content"; then
            echo "Saved environment file name and contents to MongoDB."
        else
            echo "Warning: Failed to save environment details to MongoDB." >&2
        fi
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
                        load_env
                        if [ -n "$MONGODB_URL" ] && [ -n "$repo_name" ]; then
                            if update_repo_commands_in_mongo "$MONGODB_URL" "$repo_name" "" "$install_cmd" ""; then
                                echo "Saved install command to MongoDB."
                            else
                                echo "Warning: Failed to save install command to MongoDB." >&2
                            fi
                        fi
                        setup_success=1
                    fi
                else
                    # User skipped entering install command
                    setup_success=1
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

    clear
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

    echo "Running command: screen -S $screen_name"
    screen -dmS "$screen_name" bash

    # Wait a tiny moment for screen to initialize
    sleep 1

    read -rp "Enter start command (e.g. python3 main.py): " start_cmd
    if [ -n "$start_cmd" ]; then
        # Send the commands to the screen session:
        # 1. Change directory to the target path
        # 2. If venv exists, activate it
        # 3. Execute the start_cmd
        screen -S "$screen_name" -p 0 -X stuff "cd $target$(printf \\r)"
        if [ -d "$target/venv" ]; then
            screen -S "$screen_name" -p 0 -X stuff "source venv/bin/activate$(printf \\r)"
        fi
        screen -S "$screen_name" -p 0 -X stuff "${start_cmd}$(printf \\r)"
        
        # Detach the screen session
        screen -S "$screen_name" -p 0 -X detach 2>/dev/null || true
        
        echo "Screen session '$screen_name' started and running in detached mode."
        echo "You can attach to it using: screen -r $screen_name"
    else
        echo "No start command entered. Screen session '$screen_name' is idle."
    fi

    # Save details to MongoDB
    load_env
    if [ -n "$MONGODB_URL" ] && [ -n "$repo_name" ]; then
        if update_repo_screen_details_in_mongo "$MONGODB_URL" "$repo_name" "$screen_name" "$start_cmd"; then
            echo "Saved screen details to MongoDB."
        else
            echo "Warning: Failed to save screen details to MongoDB." >&2
        fi
    fi
}

post_clone_actions() {
    install_project_dependencies "$@"
}
