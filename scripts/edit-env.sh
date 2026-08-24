#!/bin/bash

set -e

SCRIPT_DIR_EDIT_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_EDIT_ENV/config.sh"
source "$SCRIPT_DIR_EDIT_ENV/mongo.sh"
source "$SCRIPT_DIR_EDIT_ENV/screen_manager.sh"

apply_env_updates() {
    local target_path="$1"
    local repo_name="$2"
    local env_file="$3"
    local env_content="$4"
    local repo_json="$5"

    # Save to MongoDB
    update_repo_env_file_in_mongo "$MONGODB_URL" "$repo_name" "$env_file" "$env_content"

    local screen_name
    local start_cmd
    local venv_cmd
    screen_name=$(echo "$repo_json" | jq -r '.screen_name // ""')
    start_cmd=$(echo "$repo_json" | jq -r '.start_cmd // ""')
    venv_cmd=$(echo "$repo_json" | jq -r '.venv_cmd // ""')

    local was_running=0
    if [ -n "$screen_name" ] && [ "$screen_name" != "null" ]; then
        if screen -list | grep -q "\.${screen_name}"; then
            was_running=1
        fi
    fi

    if [ "$was_running" -eq 1 ]; then
        echo "Process screen session '$screen_name' is running. Stopping it..."
        screen -S "$screen_name" -X quit || true
        sleep 1
    fi

    # Update env file directly
    if [ -d "$target_path" ] && [ -n "$env_file" ] && [ "$env_file" != "null" ]; then
        echo -n "$env_content" > "$target_path/$env_file"
        echo "Updated local env file at $target_path/$env_file."
    fi

    if [ "$was_running" -eq 1 ] && [ -n "$start_cmd" ] && [ "$start_cmd" != "null" ]; then
        echo "Restarting process in screen..."
        local has_venv="false"
        if [ -n "$venv_cmd" ] && [ "$venv_cmd" != "null" ]; then
            has_venv="true"
        fi
        run_screen_session "$target_path" "$screen_name" "$start_cmd" "$has_venv"
    fi
}

edit_env_variables() {
    load_env
    if [ -z "$MONGODB_URL" ]; then
        echo "Error: MONGODB_URL is not set. Run setup environment first."
        read -rp "Press Enter to return to main menu..."
        return 0
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

    local menu_list="[Back to Main Menu]
$raw_list"

    echo "Select a repo to edit environment variables:"
    local selected=""
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
        return 1
    fi

    if [ -z "$repo_json" ]; then
        echo "Error: Repository details not found."
        return 1
    fi

    local env_file
    local env_content
    env_file=$(echo "$repo_json" | jq -r '.env_file // ""')
    env_content=$(echo "$repo_json" | jq -r '.env_content // ""')

    if [ -z "$env_file" ] || [ "$env_file" = "null" ]; then
        env_file=".env"
    fi

    local target_path
    target_path=$(echo "$repo_json" | jq -r '.target_path // ""')

    while true; do
        local clean_content
        clean_content=$(echo "$env_content" | tr -d '\r')

        local keys=()
        declare -A val_map
        
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                continue
            fi
            if [[ "$line" =~ = ]]; then
                local key="${line%%=*}"
                local val="${line#*=}"
                key=$(echo "$key" | xargs)
                keys+=("$key")
                val_map["$key"]="$val"
            fi
        done <<< "$clean_content"

        if [ ${#keys[@]} -eq 0 ]; then
            echo "No environment variables found in $env_file."
            read -rp "Would you like to add a new variable? (y/n): " add_new
            if [[ "$add_new" =~ ^[Yy]$ ]]; then
                read -rp "Enter Variable Name: " new_key
                read -rp "Enter Variable Value: " new_val
                if [ -n "$new_key" ]; then
                    new_key=$(echo "$new_key" | xargs)
                    if [ -z "$env_content" ]; then
                        env_content="${new_key}=${new_val}"
                    else
                        env_content="${env_content}
${new_key}=${new_val}"
                    fi
                    apply_env_updates "$target_path" "$repo_name" "$env_file" "$env_content" "$repo_json"
                    echo "Variable added."
                fi
            else
                break
            fi
            continue
        fi

        echo ""
        echo "Select a variable to manage:"
        local selected_key=""
        
        local keys_str="[Back to Main Menu]
[Add New Variable]
"
        for k in "${keys[@]}"; do
            keys_str="${keys_str}${k}
"
        done
        
        if command -v fzf &>/dev/null; then
            selected_key=$(echo -n "$keys_str" | fzf --height 40% --reverse --prompt "Var> ")
            if [ "$selected_key" = "[Back to Main Menu]" ] || [ -z "$selected_key" ]; then
                break
            elif [ "$selected_key" = "[Add New Variable]" ]; then
                read -rp "Enter Variable Name: " new_key
                read -rp "Enter Variable Value: " new_val
                if [ -n "$new_key" ]; then
                    new_key=$(echo "$new_key" | xargs)
                    env_content="${env_content}
${new_key}=${new_val}"
                    apply_env_updates "$target_path" "$repo_name" "$env_file" "$env_content" "$repo_json"
                fi
                continue
            fi
        else
            local i=1
            declare -A key_map
            for k in "${keys[@]}"; do
                key_map[$i]="$k"
                echo "$i) $k=${val_map[$k]}"
                i=$((i+1))
            done
            echo "$i) [Add New Variable]"
            echo "$((i+1))) [Back to Main Menu]"
            read -rp "Enter option: " var_choice
            if [ "$var_choice" -eq "$i" ]; then
                read -rp "Enter Variable Name: " new_key
                read -rp "Enter Variable Value: " new_val
                if [ -n "$new_key" ]; then
                    new_key=$(echo "$new_key" | xargs)
                    env_content="${env_content}
${new_key}=${new_val}"
                    apply_env_updates "$target_path" "$repo_name" "$env_file" "$env_content" "$repo_json"
                fi
                continue
            elif [ "$var_choice" -eq "$((i+1))" ] || [ -z "$var_choice" ]; then
                break
            fi
            selected_key="${key_map[$var_choice]}"
        fi

        if [ -z "$selected_key" ]; then
            break
        fi

        while true; do
            local current_val="${val_map[$selected_key]}"
            echo ""
            echo "=== Variable: $selected_key ==="
            echo "Current Value: $current_val"
            echo "--------------------------------"
            echo "1) Modify variable value"
            echo "2) Modify variable name"
            echo "3) Delete this variable"
            echo "4) Back"
            read -rp "Choose option: " var_opt

            case "$var_opt" in
                1)
                    read -rp "Enter new value (press Enter to keep current): " new_val
                    new_val="${new_val:-$current_val}"
                    val_map["$selected_key"]="$new_val"
                    
                    local old_selected_key="$selected_key"
                    
                    local new_content=""
                    local cleaned_input
                    cleaned_input=$(echo "$env_content" | tr -d '\r')

                    while IFS= read -r line || [ -n "$line" ]; do
                        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                            if [ -z "$new_content" ]; then
                                new_content="$line"
                            else
                                new_content="${new_content}
${line}"
                            fi
                            continue
                        fi

                        if [[ "$line" =~ = ]]; then
                            local line_key="${line%%=*}"
                            line_key=$(echo "$line_key" | xargs)
                            
                            if [ "$line_key" = "$old_selected_key" ]; then
                                local updated_line="${selected_key}=${val_map[$selected_key]}"
                                if [ -z "$new_content" ]; then
                                    new_content="$updated_line"
                                else
                                    new_content="${new_content}
${updated_line}"
                                fi
                            else
                                if [ -z "$new_content" ]; then
                                    new_content="$line"
                                else
                                    new_content="${new_content}
${line}"
                                fi
                            fi
                        else
                            if [ -z "$new_content" ]; then
                                new_content="$line"
                            else
                                new_content="${new_content}
${line}"
                            fi
                        fi
                    done <<< "$cleaned_input"

                    env_content="$new_content"
                    apply_env_updates "$target_path" "$repo_name" "$env_file" "$env_content" "$repo_json"

                    echo "Value updated."
                    break
                    ;;
                2)
                    read -rp "Enter new name: " new_name
                    if [ -n "$new_name" ]; then
                        new_name=$(echo "$new_name" | xargs)
                        local old_val="${val_map[$selected_key]}"
                        unset val_map["$selected_key"]
                        val_map["$new_name"]="$old_val"
                        
                        local old_selected_key="$selected_key"
                        local new_key_name="$new_name"
                        
                        local new_content=""
                        local cleaned_input
                        cleaned_input=$(echo "$env_content" | tr -d '\r')

                        while IFS= read -r line || [ -n "$line" ]; do
                            if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                                if [ -z "$new_content" ]; then
                                    new_content="$line"
                                else
                                    new_content="${new_content}
${line}"
                               fi
                                continue
                            fi

                            if [[ "$line" =~ = ]]; then
                                local line_key="${line%%=*}"
                                line_key=$(echo "$line_key" | xargs)
                                
                                if [ "$line_key" = "$old_selected_key" ]; then
                                    local updated_line="${new_key_name}=${val_map[$new_key_name]}"
                                    if [ -z "$new_content" ]; then
                                        new_content="$updated_line"
                                    else
                                        new_content="${new_content}
${updated_line}"
                                    fi
                                else
                                    if [ -z "$new_content" ]; then
                                        new_content="$line"
                                    else
                                        new_content="${new_content}
${line}"
                                    fi
                                fi
                            else
                                if [ -z "$new_content" ]; then
                                    new_content="$line"
                                else
                                    new_content="${new_content}
${line}"
                                fi
                            fi
                        done <<< "$cleaned_input"

                        env_content="$new_content"
                        apply_env_updates "$target_path" "$repo_name" "$env_file" "$env_content" "$repo_json"

                        selected_key="$new_name"
                        echo "Name updated to $new_name."
                    fi
                    break
                    ;;
                3)
                    unset val_map["$selected_key"]
                    
                    local old_selected_key="$selected_key"
                    
                    local new_content=""
                    local cleaned_input
                    cleaned_input=$(echo "$env_content" | tr -d '\r')

                    while IFS= read -r line || [ -n "$line" ]; do
                        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                            if [ -z "$new_content" ]; then
                                  new_content="$line"
                            else
                                new_content="${new_content}
${line}"
                            fi
                            continue
                        fi

                        if [[ "$line" =~ = ]]; then
                            local line_key="${line%%=*}"
                            line_key=$(echo "$line_key" | xargs)
                            
                            if [ "$line_key" = "$old_selected_key" ]; then
                                continue
                            else
                                if [ -z "$new_content" ]; then
                                    new_content="$line"
                                else
                                    new_content="${new_content}
${line}"
                                fi
                            fi
                        else
                            if [ -z "$new_content" ]; then
                                new_content="$line"
                            else
                                new_content="${new_content}
${line}"
                            fi
                        fi
                    done <<< "$cleaned_input"

                    env_content="$new_content"
                    apply_env_updates "$target_path" "$repo_name" "$env_file" "$env_content" "$repo_json"

                    echo "Variable deleted."
                    break 2
                    ;;
                4|*)
                    break 2
                    ;;
            esac
        done
    done
}

edit_env_variables
