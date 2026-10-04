#!/bin/bash

set -e

[ -n "$_ENV_MODIFIER_SH_LOADED" ] && return 0
_ENV_MODIFIER_SH_LOADED=1

modify_env_var() {
    local content="$1"
    local target_key="$2"
    local new_val="$3"
    
    local clean_content
    # Use printf to preserve trailing newlines and avoid echo mangling of $ etc
    clean_content=$(printf "%s" "$content" | tr -d '\r')
    
    local new_content=""
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

        if [[ "$line" == *"="* ]]; then
            local key="${line%%=*}"
            # trim whitespace without using xargs subshell that eats $ etc
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"
            if [ "$key" = "$target_key" ]; then
                # Build updated line without word splitting; new_val may contain = $ etc
                local updated_line
                printf -v updated_line "%s=%s" "$target_key" "$new_val"
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
    done <<< "$clean_content"
    printf "%s" "$new_content"
}

rename_env_var() {
    local content="$1"
    local old_key="$2"
    local new_key="$3"
    
    local clean_content
    clean_content=$(printf "%s" "$content" | tr -d '\r')
    
    local new_content=""
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

        if [[ "$line" == *"="* ]]; then
            local key="${line%%=*}"
            local val="${line#*=}"
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"
            if [ "$key" = "$old_key" ]; then
                local updated_line
                printf -v updated_line "%s=%s" "$new_key" "$val"
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
    done <<< "$clean_content"
    printf "%s" "$new_content"
}

delete_env_var() {
    local content="$1"
    local target_key="$2"
    
    local clean_content
    clean_content=$(printf "%s" "$content" | tr -d '\r')
    
    local new_content=""
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

        if [[ "$line" == *"="* ]]; then
            local key="${line%%=*}"
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"
            if [ "$key" = "$target_key" ]; then
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
    done <<< "$clean_content"
    printf "%s" "$new_content"
}
