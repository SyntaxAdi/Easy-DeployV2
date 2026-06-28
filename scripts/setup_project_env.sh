#!/bin/bash

set -e

[ -n "$_SETUP_PROJECT_ENV_SH_LOADED" ] && return 0
_SETUP_PROJECT_ENV_SH_LOADED=1

SCRIPT_DIR_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_ENV/config.sh"
source "$SCRIPT_DIR_ENV/mongo.sh"

write_env_file_direct() {
    local target="$1"
    local env_file="$2"
    local env_content="$3"

    if [ -z "$env_file" ] || [ "$env_file" = "null" ]; then
        return 0
    fi

    echo "Writing environment configuration to $env_file..."
    if [ -n "$env_content" ] && [ "$env_content" != "null" ]; then
        echo -n "$env_content" > "$target/$env_file"
        echo "Configuration saved."
    else
        touch "$target/$env_file"
        echo "Empty configuration file created."
    fi
}

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

    load_env
    if [ -n "$MONGODB_URL" ] && [ -n "$repo_name" ]; then
        if update_repo_env_file_in_mongo "$MONGODB_URL" "$repo_name" "$env_file_name" "$env_content"; then
            echo "Saved environment file name and contents to MongoDB."
        else
            echo "Warning: Failed to save environment details to MongoDB." >&2
        fi
    fi
}
