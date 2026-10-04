#!/bin/bash
# SRP: orchestration/UI only. Data access via mongo_repos.sh:search_repos_by_env (DIP).
# KISS: literal substring match, flat scripts/ (no lib/ per review), masked display.
set -e
SCRIPT_DIR_SBE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_SBE/config.sh"
source "$SCRIPT_DIR_SBE/mongo.sh"

mask_line() {
    local line="$1"
    if [[ "$line" == *"="* ]]; then
        local k="${line%%=*}"
        local v="${line#*=}"
        k=$(echo "$k" | xargs)
        local len=${#v}
        if [ "$len" -le 8 ]; then
            echo "${k}=****"
        else
            local head=${v:0:4}
            local tail=${v: -4}
            echo "${k}=${head}****${tail} (${len} chars)"
        fi
    else
        echo "$line"
    fi
}

search_by_env() {
    load_env
    if [ -z "$MONGODB_URL" ]; then
        echo "Error: MONGODB_URL is not set. Run setup environment first."
        read -rp "Press Enter to return to main menu..."
        return 0
    fi

    echo "==============================="
    echo "     Search by ENV"
    echo "==============================="
    echo "Paste the ENV value / line to search."
    echo "Supports single line or multiline paste."
    echo "Finish multiline with 'EOF' on new line or Ctrl+D."
    echo "(Paste BOT_TOKEN=xxx or just the value xxx)"
    echo ""

    local query=""
    # Try single read first - if user pastes one line and presses Enter, use it.
    # If input needs multiline, they can paste multiple lines ending with EOF.
    echo "Paste query then press Enter (or paste multiline then type EOF):"
    local first_line=""
    IFS= read -r first_line || true
    first_line=$(echo "$first_line" | tr -d '\r')
    if [ -z "$first_line" ]; then
        echo "No input provided."
        read -rp "Press Enter to return..."
        return 0
    fi

    # If only one line pasted without EOF, use it. If more lines follow, collect until EOF/empty+CtrlD.
    # Peek if stdin still has data (pasted multiline remaining in buffer)
    # Simple KISS: if first_line == EOF sentinel already -> empty
    if [ "$first_line" = "EOF" ]; then
        echo "No input provided."
        read -rp "Press Enter to return..."
        return 0
    fi

    query="$first_line"
    # Non-blocking check for additional buffered lines (multiline paste)
    # Read with short timeout to collect remaining paste without hanging on interactive single-line.
    while IFS= read -r -t 0.3 line 2>/dev/null; do
        line=$(echo "$line" | tr -d '\r')
        [ "$line" = "EOF" ] && break
        query="${query}
${line}"
    done || true

    # Trim leading/trailing whitespace of whole query for matching, but keep inner.
    # Use first non-empty meaningful substring: if query contains newline, match literal multiline.
    # For most use-cases user pastes one token/line.
    local trimmed
    trimmed=$(echo "$query" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r')
    if [ -z "$trimmed" ]; then
        echo "Empty query."
        read -rp "Press Enter to return..."
        return 0
    fi
    # For search, use trimmed first line if multiline pasted due to accidental newline buffering
    # but if query is truly multiline (contains \n), search the full literal.
    # KISS: if multiline contains multiple KEY=VALUE lines, search using first line token.
    # Prefer full trimmed query for exact match.
    query="$trimmed"

    echo ""
    echo "Searching for: '$(echo "$query" | head -n1 | cut -c1-60)...'"
    local hits_json
    if ! hits_json=$(search_repos_by_env "$MONGODB_URL" "$query"); then
        echo "Search failed. Check MongoDB connection."
        read -rp "Press Enter to return..."
        return 1
    fi

    if [ -z "$hits_json" ] || [ "$hits_json" = "[]" ]; then
        echo "No project found containing that ENV value."
        echo "Tip: try pasting just the token value without KEY=, or check for extra spaces."
        read -rp "Press Enter to return..."
        return 0
    fi

    local count
    if command -v jq &>/dev/null; then
        count=$(echo "$hits_json" | jq 'length')
    else
        count=$(echo "$hits_json" | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))' 2>/dev/null || echo "?")
    fi

    if [ "$count" = "0" ] || [ "$count" = "0.0" ]; then
        echo "No project found containing that ENV value."
        read -rp "Press Enter to return..."
        return 0
    fi

    echo ""
    echo "Found $count match(es):"
    echo "--------------------------------"

    # Build display list
    local display_items=()
    local repo_names=()
    if command -v jq &>/dev/null; then
        while IFS= read -r obj; do
            local rn url ef ml
            rn=$(echo "$obj" | jq -r '.repo_name')
            url=$(echo "$obj" | jq -r '.repo_url // ""')
            ef=$(echo "$obj" | jq -r '.env_file // ".env"')
            ml=$(echo "$obj" | jq -r '.matched_lines[0] // ""' | cut -c1-80)
            local masked
            masked=$(mask_line "$ml")
            echo "  - $rn | $ef | $masked"
            [ -n "$url" ] && echo "    $url"
            repo_names+=("$rn")
            display_items+=("$rn | $ef | $masked")
        done < <(echo "$hits_json" | jq -c '.[]')
    else
        while IFS= read -r line; do
            echo "  $line"
        done < <(echo "$hits_json" | python3 -c '
import json,sys
for d in json.load(sys.stdin):
    print(d.get("repo_name","") + " | " + d.get("env_file","") + " | " + (d.get("matched_lines",[""])[0][:80] if d.get("matched_lines") else ""))
')
        mapfile -t repo_names < <(echo "$hits_json" | python3 -c 'import json,sys; [print(d.get("repo_name","")) for d in json.load(sys.stdin)]')
    fi

    echo "--------------------------------"

    # Select repo
    local selected_repo=""
    if [ "$count" = "1" ]; then
        selected_repo="${repo_names[0]}"
        echo "Single match auto-selected: $selected_repo"
    else
        echo ""
        echo "Select a project:"
        if command -v fzf &>/dev/null; then
            local fzf_input=""
            for rn in "${repo_names[@]}"; do fzf_input+="$rn\n"; done
            selected_repo=$(printf "%b" "$fzf_input" | fzf --height 40% --reverse --prompt "Select Project> ")
        else
            local i=1
            for rn in "${repo_names[@]}"; do echo "$i) $rn"; i=$((i+1)); done
            echo "0) Back"
            read -rp "Enter number: " num
            if [ "$num" = "0" ] || [ -z "$num" ]; then return 0; fi
            selected_repo="${repo_names[$((num-1))]}"
        fi
    fi

    if [ -z "$selected_repo" ]; then
        return 0
    fi

    echo ""
    echo "Selected: $selected_repo"
    # Show matched lines full vs masked toggle
    local obj
    if command -v jq &>/dev/null; then
        obj=$(echo "$hits_json" | jq -c ".[] | select(.repo_name==\"$selected_repo\")" | head -n1)
        echo "Matched line(s) (masked):"
        echo "$obj" | jq -r '.matched_lines[]' | while IFS= read -r l; do mask_line "$l"; done
    fi

    while true; do
        echo ""
        echo "Actions for '$selected_repo':"
        echo "1) View full details (repo + env)"
        echo "2) Edit ENV Variables"
        echo "3) Edit One-Click Deploy"
        echo "4) Delete Deployment"
        echo "5) Search again"
        echo "6) Back to Main Menu"
        read -rp "Choose action: " act
        case "$act" in
            1)
                local details
                details=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$selected_repo" || true)
                if [ -n "$details" ]; then
                    echo "--- Details ---"
                    if command -v jq &>/dev/null; then echo "$details" | jq '.'; else echo "$details"; fi
                    echo "---------------"
                else
                    echo "No details found."
                fi
                ;;
            2)
                # Reuse edit-env.sh logic with preselected repo: export hint and call
                echo "Opening Edit Env for $selected_repo..."
                # edit-env.sh expects interactive selection; we set env var to skip selection if supported
                # Fallback: just run edit-env.sh and user can select again (KISS, no coupling)
                bash "$SCRIPT_DIR_SBE/edit-env.sh"
                ;;
            3)
                bash "$SCRIPT_DIR_SBE/edit-one-click.sh"
                ;;
            4)
                read -rp "Type '$selected_repo' to confirm delete: " confirm
                if [ "$confirm" != "$selected_repo" ]; then
                    echo "Confirm failed. Delete cancelled."
                    continue
                fi
                local repo_json sc tp
                repo_json=$(fetch_repo_details_from_mongo "$MONGODB_URL" "$selected_repo" || true)
                sc=""; tp=""
                if [ -n "$repo_json" ]; then
                    if command -v jq &>/dev/null; then
                        sc=$(echo "$repo_json" | jq -r '.screen_name // ""')
                        tp=$(echo "$repo_json" | jq -r '.target_path // ""')
                    else
                        sc=$(echo "$repo_json" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("screen_name","") or "")' 2>/dev/null || echo "")
                        tp=$(echo "$repo_json" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("target_path","") or "")' 2>/dev/null || echo "")
                    fi
                fi
                if [ -n "$sc" ] && [ "$sc" != "null" ]; then
                    if screen -list 2>/dev/null | grep -q "\\.${sc}"; then
                        echo "Stopping screen '$sc'..."
                        screen -S "$sc" -X quit || true; sleep 1
                    fi
                fi
                if [ -n "$tp" ] && [ "$tp" != "null" ] && [ -d "$tp" ]; then
                    echo "Removing directory '$tp'..."
                    rm -rf "$tp"
                fi
                echo "Deleting from database..."
                delete_repo_from_mongo "$MONGODB_URL" "$selected_repo"
                echo "Deleted '$selected_repo' successfully."
                read -rp "Press Enter to continue..."
                return 0
                ;;
            5)
                search_by_env
                return 0
                ;;
            6|*)
                return 0
                ;;
        esac
    done
}

search_by_env
