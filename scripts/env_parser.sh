#!/bin/bash

set -e

[ -n "$_ENV_PARSER_SH_LOADED" ] && return 0
_ENV_PARSER_SH_LOADED=1

modify_env_var() {
    local content="$1"
    local target_key="$2"
    local new_val="$3"
    
    local clean_content
    clean_content=$(echo "$content" | tr -d '\r')
    
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

        if [[ "$line" =~ = ]]; then
            local key="${line%%=*}"
            key=$(echo "$key" | xargs)
            if [ "$key" = "$target_key" ]; then
                local updated_line="${target_key}=${new_val}"
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
    echo -n "$new_content"
}

rename_env_var() {
    local content="$1"
    local old_key="$2"
    local new_key="$3"
    
    local clean_content
    clean_content=$(echo "$content" | tr -d '\r')
    
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

        if [[ "$line" =~ = ]]; then
            local key="${line%%=*}"
            local val="${line#*=}"
            key=$(echo "$key" | xargs)
            if [ "$key" = "$old_key" ]; then
                local updated_line="${new_key}=${val}"
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
    echo -n "$new_content"
}

delete_env_var() {
    local content="$1"
    local target_key="$2"
    
    local clean_content
    clean_content=$(echo "$content" | tr -d '\r')
    
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

        if [[ "$line" =~ = ]]; then
            local key="${line%%=*}"
            key=$(echo "$key" | xargs)
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
    echo -n "$new_content"
}
