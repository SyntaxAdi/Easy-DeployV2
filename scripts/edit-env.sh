#!/bin/bash

set -e

SCRIPT_DIR_EDIT_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_EDIT_ENV/config.sh"
source "$SCRIPT_DIR_EDIT_ENV/mongo.sh"
source "$SCRIPT_DIR_EDIT_ENV/env_modifier.sh"
source "$SCRIPT_DIR_EDIT_ENV/process_manager.sh"

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
            # --- Enhanced diagnostics + recovery for empty/corrupted env ---
            echo ""
            echo "No environment variables found in MongoDB for '$repo_name' ($env_file)."
            local _gc_len
            _gc_len=$(echo -n "$env_content" | wc -c | xargs)
            local _gc_preview
            _gc_preview=$(echo -n "$env_content" | head -c 60 | cat -A | head -n 1)
            if [ -z "$env_content" ] || [ "$env_content" = "null" ]; then
                echo "  Mongo env_content: <empty>"
            else
                echo "  Mongo env_content: len=${_gc_len} preview='${_gc_preview}' (may be corrupted)"
                if ! echo "$env_content" | grep -q "="; then
                    echo "  Warning: content contains no '=' -> treated as corrupted/empty."
                fi
            fi
            echo "  Target path: ${target_path:-<not set>}"
            local _disk_info=""
            local _disk_exists=0
            local _disk_lines=0
            if [ -n "$target_path" ] && [ -f "$target_path/$env_file" ]; then
                _disk_exists=1
                _disk_lines=$(wc -l < "$target_path/$env_file" 2>/dev/null | xargs)
                local _disk_size
                _disk_size=$(wc -c < "$target_path/$env_file" 2>/dev/null | xargs)
                _disk_info="exists (${_disk_lines} lines, ${_disk_size} bytes)"
                if [ -r "$target_path/$env_file" ]; then
                    echo "  Disk file: $target_path/$env_file -> $_disk_info [readable]"
                else
                    echo "  Disk file: $target_path/$env_file -> $_disk_info [not readable - permission denied]"
                fi
            else
                echo "  Disk file: ${target_path:-?}/$env_file -> not found"
            fi
            echo "  Note: config.env is GLOBAL (MONGODB_URL/GITHUB_TOKEN) and not per-bot. Per-bot env is stored in MongoDB env_content."
            echo ""
            echo "Recovery options:"
            echo "  1) Add single variable (KEY=VALUE)"
            echo "  2) Paste entire env file (multiline, end with EOF or Ctrl+D)"
            echo "  3) Import from another bot's env"
            echo "  4) Import from disk file ($env_file) if exists"
            echo "  5) Clear corrupted content (reset to empty)"
            echo "  6) Back to repo selection"
            read -rp "Choose option [1-6]: " empty_opt
            case "$empty_opt" in
                1)
                    read -rp "Enter Variable Name: " new_key
                    read -rp "Enter Variable Value: " new_val
                    if [ -n "$new_key" ]; then
                        new_key=$(echo "$new_key" | xargs)
                        # if current content is garbage without '=', replace instead of append
                        if [ -z "$env_content" ] || [ "$env_content" = "null" ] || ! echo "$env_content" | grep -q "="; then
                            env_content="${new_key}=${new_val}"
                        else
                            env_content="${env_content}
${new_key}=${new_val}"
                        fi
                        apply_env_updates "$target_path" "$repo_name" "$env_file" "$env_content" "$repo_json"
                        # refresh repo_json after update for next loop
                        repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name" 2>/dev/null || echo "$repo_json")
                        env_content=$(echo "$repo_json" | jq -r '.env_content // ""')
                        echo "Variable added."
                    fi
                    ;;
                2)
                    echo "Paste your env file content below (type 'EOF' on a new line or press Ctrl+D to finish):"
                    local pasted=""
                    while IFS= read -r line || [ -n "$line" ]; do
                        if [ "$line" = "EOF" ]; then
                            break
                        fi
                        if [ -z "$pasted" ]; then
                            pasted="$line"
                        else
                            pasted="${pasted}
${line}"
                        fi
                    done
                    if [ -z "$pasted" ]; then
                        echo "No content pasted. Cancelled."
                    elif ! echo "$pasted" | grep -q "="; then
                        echo "Invalid content: must contain at least one 'KEY=VALUE' line."
                    else
                        env_content="$pasted"
                        apply_env_updates "$target_path" "$repo_name" "$env_file" "$env_content" "$repo_json"
                        repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name" 2>/dev/null || echo "$repo_json")
                        env_content=$(echo "$repo_json" | jq -r '.env_content // ""')
                        echo "Environment content replaced from paste."
                    fi
                    ;;
                3)
                    echo "Fetching other deployments..."
                    local sibling_list
                    sibling_list=$(fetch_repos_from_mongo "$MONGODB_URL" 2>/dev/null | grep -v "^${repo_name} |" || true)
                    if [ -z "$sibling_list" ]; then
                        echo "No other deployments found."
                    else
                        echo "Available sources:"
                        local si=1
                        declare -A sib_map
                        while IFS= read -r sline; do
                            [ -z "$sline" ] && continue
                            local sname
                            sname=$(echo "$sline" | awk -F '|' '{print $1}' | xargs)
                            # check that source has env
                            local sjson
                            sjson=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$sname" 2>/dev/null || echo "")
                            local slen
                            slen=$(echo "$sjson" | jq -r '.env_content // "" | length' 2>/dev/null || echo 0)
                            if [ "$slen" -gt 10 ]; then
                                echo "  $si) $sname (${slen} chars)"
                                sib_map[$si]="$sname"
                                si=$((si+1))
                            fi
                        done <<< "$sibling_list"
                        if [ ${#sib_map[@]} -eq 0 ]; then
                            echo "No sibling with valid env found."
                        else
                            read -rp "Enter number to import from (or Enter to cancel): " sib_choice
                            if [ -n "$sib_choice" ] && [ -n "${sib_map[$sib_choice]:-}" ]; then
                                local src="${sib_map[$sib_choice]}"
                                local src_json
                                src_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$src" 2>/dev/null)
                                local src_content
                                src_content=$(echo "$src_json" | jq -r '.env_content // ""')
                                echo "Preview keys from $src: $(echo "$src_content" | cut -d= -f1 | tr '\n' ',' | cut -c1-80)"
                                read -rp "Import this env to $repo_name? You will edit values after. (y/n): " conf
                                if [[ "$conf" =~ ^[Yy]$ ]]; then
                                    env_content="$src_content"
                                    apply_env_updates "$target_path" "$repo_name" "$env_file" "$env_content" "$repo_json"
                                    repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name" 2>/dev/null || echo "$repo_json")
                                    env_content=$(echo "$repo_json" | jq -r '.env_content // ""')
                                    echo "Imported from $src. Now edit values as needed."
                                fi
                            fi
                        fi
                    fi
                    ;;
                4)
                    if [ "$_disk_exists" -eq 1 ] && [ -r "$target_path/$env_file" ]; then
                        local disk_content
                        disk_content=$(cat "$target_path/$env_file" 2>/dev/null || echo "")
                        if [ -z "$disk_content" ]; then
                            echo "Disk file is empty."
                        elif ! echo "$disk_content" | grep -q "="; then
                            echo "Disk file has no KEY=VALUE lines."
                        else
                            echo "Disk preview: $(head -n 3 "$target_path/$env_file" 2>/dev/null | cut -d= -f1 | tr '\n' ',' | cut -c1-80)"
                            read -rp "Overwrite MongoDB env with disk file? (y/n): " conf2
                            if [[ "$conf2" =~ ^[Yy]$ ]]; then
                                env_content="$disk_content"
                                apply_env_updates "$target_path" "$repo_name" "$env_file" "$env_content" "$repo_json"
                                repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name" 2>/dev/null || echo "$repo_json")
                                env_content=$(echo "$repo_json" | jq -r '.env_content // ""')
                                echo "Synced from disk to MongoDB."
                            fi
                        fi
                    else
                        echo "No readable disk file to import. Use option 2 to paste instead."
                    fi
                    ;;
                5)
                    read -rp "Clear corrupted content in MongoDB? (y/n): " conf_clear
                    if [[ "$conf_clear" =~ ^[Yy]$ ]]; then
                        env_content=""
                        apply_env_updates "$target_path" "$repo_name" "$env_file" "$env_content" "$repo_json"
                        repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name" 2>/dev/null || echo "$repo_json")
                        env_content=$(echo "$repo_json" | jq -r '.env_content // ""')
                        echo "Cleared. You can now add variables fresh."
                    fi
                    ;;
                6|*)
                    break
                    ;;
            esac
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
                    # Guard: if env_content was somehow truncated, re-fetch from Mongo first
                    local fresh_check
                    fresh_check=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name" 2>/dev/null || echo "")
                    if [ -n "$fresh_check" ]; then
                        local fresh_env
                        fresh_env=$(echo "$fresh_check" | jq -r '.env_content // ""')
                        # Use fresh if it has more keys than current (prevents blank overwrite)
                        local fresh_keys cur_keys
                        fresh_keys=$(printf "%s" "$fresh_env" | grep -c "=" || true)
                        cur_keys=$(printf "%s" "$env_content" | grep -c "=" || true)
                        if [ "$fresh_keys" -gt "$cur_keys" ]; then
                            echo "Refreshing from MongoDB (local copy stale: $cur_keys vs $fresh_keys keys)..."
                            env_content="$fresh_env"
                            repo_json="$fresh_check"
                        fi
                    fi
                    local updated_content
                    updated_content=$(modify_env_var "$env_content" "$selected_key" "$new_val")
                    # Validate: ensure we didn't lose keys
                    local before_cnt after_cnt
                    before_cnt=$(printf "%s" "$env_content" | grep -c "=" || true)
                    after_cnt=$(printf "%s" "$updated_content" | grep -c "=" || true)
                    if [ "$after_cnt" -lt "$before_cnt" ]; then
                        echo "Error: update would delete variables ($before_cnt -> $after_cnt). Aborted." >&2
                        echo "Debug: before first key=$(printf "%s" "$env_content" | head -n1 | cut -c1-20), after first key=$(printf "%s" "$updated_content" | head -n1 | cut -c1-20)" >&2
                    else
                        env_content="$updated_content"
                        if update_repo_env_file_in_mongo "$MONGODB_URL" "$repo_name" "$env_file" "$env_content"; then
                            echo "Saved to MongoDB (no restart, no disk write). Value updated."
                            # refresh local cache from Mongo to stay consistent
                            repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name" 2>/dev/null || echo "$repo_json")
                            env_content=$(echo "$repo_json" | jq -r '.env_content // ""')
                        else
                            echo "Failed to save to MongoDB." >&2
                        fi
                    fi
                    break
                    ;;
                2)
                    read -rp "Enter new name: " new_name
                    if [ -n "$new_name" ]; then
                        new_name="${new_name#"${new_name%%[![:space:]]*}"}"
                        new_name="${new_name%"${new_name##*[![:space:]]}"}"
                        local renamed
                        renamed=$(rename_env_var "$env_content" "$selected_key" "$new_name")
                        # validate not losing keys
                        if [ "$(printf "%s" "$renamed" | grep -c "=" || true)" -lt "$(printf "%s" "$env_content" | grep -c "=" || true)" ]; then
                            echo "Error: rename would delete variables. Aborted." >&2
                        else
                            env_content="$renamed"
                            if update_repo_env_file_in_mongo "$MONGODB_URL" "$repo_name" "$env_file" "$env_content"; then
                                echo "Saved to MongoDB. Name updated to $new_name."
                                repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name" 2>/dev/null || echo "$repo_json")
                                env_content=$(echo "$repo_json" | jq -r '.env_content // ""')
                                selected_key="$new_name"
                            else
                                echo "Failed to save to MongoDB." >&2
                            fi
                        fi
                    fi
                    break
                    ;;
                3)
                    local deleted
                    deleted=$(delete_env_var "$env_content" "$selected_key")
                    env_content="$deleted"
                    if update_repo_env_file_in_mongo "$MONGODB_URL" "$repo_name" "$env_file" "$env_content"; then
                        echo "Saved to MongoDB. Variable deleted."
                        repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name" 2>/dev/null || echo "$repo_json")
                        env_content=$(echo "$repo_json" | jq -r '.env_content // ""')
                    else
                        echo "Failed to save to MongoDB." >&2
                    fi
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
