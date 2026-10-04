#!/bin/bash

set -e

SCRIPT_DIR_EDIT_OC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_EDIT_OC/config.sh"
source "$SCRIPT_DIR_EDIT_OC/mongo.sh"
source "$SCRIPT_DIR_EDIT_OC/setup_project_env.sh"
source "$SCRIPT_DIR_EDIT_OC/install_deps.sh"

edit_repo_field() {
    local repo_name="$1"
    local field_name="$2"
    local field_label="$3"
    local current_val="$4"

    echo ""
    echo "Current $field_label: $current_val"
    read -rp "Enter new value (press Enter to keep current): " new_val

    if [ -n "$new_val" ] && [ "$new_val" != "$current_val" ]; then
        if update_repo_field_in_mongo "$MONGODB_URL" "$repo_name" "$field_name" "$new_val"; then
            echo "Updated $field_label successfully in MongoDB."
            return 0
        else
            echo "Failed to update $field_label in MongoDB." >&2
            return 1
        fi
    else
        echo "No changes made to $field_label."
        return 0
    fi
}

edit_repo_env_content() {
    local repo_name="$1"
    local target_path="$2"
    local env_file="$3"
    local current_content="$4"

    echo ""
    # Diagnostics for corrupted/empty content
    if [ -z "$current_content" ] || [ "$current_content" = "null" ] || ! echo "$current_content" | grep -q "="; then
        if [ -n "$current_content" ] && [ "$current_content" != "null" ] && ! echo "$current_content" | grep -q "="; then
            echo "Warning: stored env_content looks corrupted (len=$(echo -n "$current_content" | wc -c | xargs), preview='$(echo -n "$current_content" | head -c 40 | cat -A)') - no KEY=VALUE found."
        fi
        echo "Note: config.env is GLOBAL config only. Per-bot env is MongoDB env_content + $target_path/$env_file."
        if [ -n "$target_path" ] && [ -f "$target_path/$env_file" ]; then
            echo "Disk file found at $target_path/$env_file ($(wc -c < "$target_path/$env_file" | xargs) bytes) - will sync on save."
        fi
    fi
    echo "=== Environment Content Options ==="
    echo "1) View current env content"
    echo "2) Replace with new multiline paste (finish with 'EOF' or Ctrl+D)"
    echo "3) Append variable (KEY=VALUE)"
    echo "4) Clear env content"
    echo "5) Cancel"
    echo "6) Edit single variable (fix corrupted value without re-pasting all)"
    echo "7) Import from another bot"
    read -rp "Choose option: " env_opt

    local new_content="$current_content"

    case "$env_opt" in
        1)
            echo ""
            echo "--- Current Environment Content ---"
            if [ -n "$current_content" ]; then
                echo "$current_content"
            else
                echo "(Empty)"
            fi
            echo "-----------------------------------"
            read -rp "Press Enter to continue..."
            return 0
            ;;
        2)
            echo "Paste your env file content below (type 'EOF' on a new line or press Ctrl+D to finish):"
            local pasted_content=""
            while IFS= read -r line || [ -n "$line" ]; do
                if [ "$line" = "EOF" ]; then
                    break
                fi
                if [ -z "$pasted_content" ]; then
                    pasted_content="$line"
                else
                    pasted_content="${pasted_content}
${line}"
                fi
            done
            new_content="$pasted_content"
            ;;
        3)
            read -rp "Enter KEY=VALUE: " kv_line
            if [[ "$kv_line" =~ = ]]; then
                if [ -z "$new_content" ]; then
                    new_content="$kv_line"
                else
                    new_content="${new_content}
${kv_line}"
                fi
            else
                echo "Invalid format. Must contain '='."
                return 1
            fi
            ;;
        4)
            read -rp "Are you sure you want to clear the env content? (y/n): " confirm_clear
            if [[ "$confirm_clear" =~ ^[Yy]$ ]]; then
                new_content=""
            else
                echo "Clear cancelled."
                return 0
            fi
            ;;
        5)
            return 0
            ;;
        6)
            # Edit single variable in place
            if [ -z "$current_content" ] || ! echo "$current_content" | grep -q "="; then
                echo "No valid env to edit. Use option 2 to paste fresh content first."
                read -rp "Press Enter to continue..."
                return 1
            fi
            source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env_modifier.sh"
            local clean
            clean=$(printf "%s" "$current_content" | tr -d '\r')
            local keys=()
            declare -A vmap
            while IFS= read -r line || [ -n "$line" ]; do
                [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
                if [[ "$line" == *"="* ]]; then
                    local k="${line%%=*}"
                    k="${k#"${k%%[![:space:]]*}"}"
                    k="${k%"${k##*[![:space:]]}"}"
                    keys+=("$k")
                    vmap["$k"]="${line#*=}"
                fi
            done <<< "$clean"
            echo "Select variable to update value:"
            local i=1; declare -A kmap
            for k in "${keys[@]}"; do echo "  $i) $k=${vmap[$k]}"; kmap[$i]="$k"; i=$((i+1)); done
            echo "  $i) Cancel"
            read -rp "Enter number: " vc
            if [ -z "$vc" ] || [ "$vc" -eq "$i" ] 2>/dev/null; then return 0; fi
            local sel="${kmap[$vc]}"
            if [ -z "$sel" ]; then echo "Invalid choice."; return 1; fi
            echo "Current $sel=${vmap[$sel]}"
            read -rp "Enter new value for $sel: " nval
            # Preserve existing if Enter pressed (allow empty string if user types empty? Use :- fallback)
            if [ -z "$nval" ] && [ -n "${vmap[$sel]}" ]; then
                nval="${vmap[$sel]}"
            fi
            local tmp_new
            tmp_new=$(modify_env_var "$current_content" "$sel" "$nval")
            if [ "$(printf "%s" "$tmp_new" | grep -c "=" || true)" -lt "$(printf "%s" "$current_content" | grep -c "=" || true)" ]; then
                echo "Error: would delete variables. Aborted." >&2
                return 1
            fi
            new_content="$tmp_new"
            echo "Will update $sel."
            ;;
        7)
            echo "Import env from another bot..."
            local sib_list
            sib_list=$(fetch_repos_from_mongo "$MONGODB_URL" 2>/dev/null | grep -v "^${repo_name} |" || true)
            local si=1; declare -A smap
            while IFS= read -r sline; do
                [ -z "$sline" ] && continue
                local sname=$(echo "$sline" | awk -F '|' '{print $1}' | xargs)
                local sj=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$sname" 2>/dev/null || echo "")
                local slen=$(echo "$sj" | jq -r '.env_content // "" | length' 2>/dev/null || echo 0)
                if [ "$slen" -gt 10 ]; then echo "  $si) $sname (${slen} chars)"; smap[$si]="$sname"; si=$((si+1)); fi
            done <<< "$sib_list"
            if [ ${#smap[@]} -eq 0 ]; then echo "No source with valid env."; return 1; fi
            read -rp "Enter number to import: " sc
            if [ -z "$sc" ] || [ -z "${smap[$sc]:-}" ]; then echo "Cancelled."; return 0; fi
            local src="${smap[$sc]}"
            local src_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$src" 2>/dev/null)
            new_content=$(echo "$src_json" | jq -r '.env_content // ""')
            echo "Imported from $src ($(echo "$new_content" | grep -c "=") vars). Review with option 1 after save."
            ;;
        *)
            echo "Invalid option."
            return 1
            ;;
    esac

    # MongoDB-only per user request (no disk write, no restart)
    if update_repo_field_in_mongo "$MONGODB_URL" "$repo_name" "env_content" "$new_content"; then
        echo "Updated environment content in MongoDB (no disk write, no restart)."
        return 0
    else
        echo "Failed to update environment content in MongoDB." >&2
        return 1
    fi
}

edit_one_click_repo() {
    local repo_name="$1"

    while true; do
        echo "Retrieving latest details for '$repo_name'..."
        local repo_json
        if ! repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$repo_name"); then
            echo "Error: Failed to fetch repo details."
            read -rp "Press Enter to return..."
            return 1
        fi

        if [ -z "$repo_json" ]; then
            echo "Error: Repository details not found."
            read -rp "Press Enter to return..."
            return 1
        fi

        local repo_url venv_cmd install_cmd extra_install_cmd apt_cmd env_file env_content screen_name start_cmd target_path
        repo_url=$(echo "$repo_json" | jq -r '.repo_url // ""')
        venv_cmd=$(echo "$repo_json" | jq -r '.venv_cmd // ""')
        install_cmd=$(echo "$repo_json" | jq -r '.install_cmd // ""')
        extra_install_cmd=$(echo "$repo_json" | jq -r '.extra_install_cmd // ""')
        apt_cmd=$(echo "$repo_json" | jq -r '.apt_cmd // ""')
        env_file=$(echo "$repo_json" | jq -r '.env_file // ""')
        env_content=$(echo "$repo_json" | jq -r '.env_content // ""')
        screen_name=$(echo "$repo_json" | jq -r '.screen_name // ""')
        start_cmd=$(echo "$repo_json" | jq -r '.start_cmd // ""')
        target_path=$(echo "$repo_json" | jq -r '.target_path // ""')

        echo ""
        echo "=========================================="
        echo "  Edit One-Click Configuration: $repo_name"
        echo "=========================================="
        echo "1) Repository URL       : ${repo_url:-<not set>}"
        echo "2) APT Packages Command : ${apt_cmd:-<not set>}"
        echo "3) Venv Command         : ${venv_cmd:-<not set>}"
        echo "4) Install Command      : ${install_cmd:-<not set>}"
        echo "5) Extra Install Command: ${extra_install_cmd:-<not set>}"
        echo "6) Env File Name        : ${env_file:-<not set>}"
        echo "7) Env Content          : $([ -n "$env_content" ] && echo "<configured>" || echo "<empty>")"
        echo "8) Screen Session Name  : ${screen_name:-<not set>}"
        echo "9) Bot Start Command    : ${start_cmd:-<not set>}"
        echo "10) Back to Repo Selection"
        echo "11) Back to Main Menu"
        echo "=========================================="
        read -rp "Choose setting to edit (1-11): " choice

        case "$choice" in
            1)
                edit_repo_field "$repo_name" "repo_url" "Repository URL" "$repo_url"
                ;;
            2)
                echo ""
                echo "Current APT Command: $apt_cmd"
                read -rp "Enter package name(s) or install command (Enter to keep current): " raw_apt
                if [ -n "$raw_apt" ]; then
                    norm_apt=$(normalize_apt_command "$raw_apt")
                    if update_repo_field_in_mongo "$MONGODB_URL" "$repo_name" "apt_cmd" "$norm_apt"; then
                        echo "Updated APT Command: $norm_apt"
                    fi
                fi
                ;;
            3)
                edit_repo_field "$repo_name" "venv_cmd" "Venv Command" "$venv_cmd"
                ;;
            4)
                edit_repo_field "$repo_name" "install_cmd" "Install Command" "$install_cmd"
                ;;
            5)
                edit_repo_field "$repo_name" "extra_install_cmd" "Extra Install Command" "$extra_install_cmd"
                ;;
            6)
                edit_repo_field "$repo_name" "env_file" "Env File Name" "$env_file"
                ;;
            7)
                edit_repo_env_content "$repo_name" "$target_path" "$env_file" "$env_content"
                ;;
            8)
                edit_repo_field "$repo_name" "screen_name" "Screen Session Name" "$screen_name"
                ;;
            9)
                edit_repo_field "$repo_name" "start_cmd" "Bot Start Command" "$start_cmd"
                ;;
            10)
                return 0
                ;;
            11)
                return 100
                ;;
            *)
                echo "Invalid choice. Please enter 1-11."
                ;;
        esac

        echo ""
    done
}

edit_one_click_menu() {
    load_env
    if [ -z "$MONGODB_URL" ]; then
        echo "Error: MONGODB_URL is not set. Run setup environment first."
        read -rp "Press Enter to return to main menu..."
        return 0
    fi

    while true; do
        echo "Fetching saved deployments from MongoDB..."
        local raw_list
        if ! raw_list=$(fetch_repos_from_mongo "$MONGODB_URL"); then
            read -rp "Press Enter to return to main menu..."
            return 1
        fi

        if [ -z "$raw_list" ]; then
            echo "No saved deployments found in MongoDB."
            read -rp "Press Enter to return to main menu..."
            return 0
        fi

        local menu_list="[Back to Main Menu]
$raw_list"

        echo "Select a deployment to edit (supports fuzzy search):"
        local selected=""
        if command -v fzf &>/dev/null; then
            selected=$(echo "$menu_list" | fzf --height 40% --reverse --prompt "Edit Deployment> ")
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

        if [ -z "$repo_name" ]; then
            continue
        fi

        edit_one_click_repo "$repo_name"
        local ret_code=$?
        if [ "$ret_code" -eq 100 ]; then
            return 0
        fi
    done
}

edit_one_click_menu
