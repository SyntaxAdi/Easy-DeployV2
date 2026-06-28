#!/bin/bash

set -e

[ -n "$_CONFIG_SH_LOADED" ] && return 0
_CONFIG_SH_LOADED=1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/config.env"
if [ ! -f "$ENV_FILE" ] && [ -f "$REPO_ROOT/.env" ]; then
    ENV_FILE="$REPO_ROOT/.env"
fi

save_env() {
    local key="$1"
    local value="$2"
    local tmp_file="${ENV_FILE}.tmp"
    local found=0

    touch "$ENV_FILE"
    > "$tmp_file"

    while IFS= read -r line || [ -n "$line" ]; do
        local clean_line
        clean_line=$(echo "$line" | tr -d '\r')
        if [[ "$clean_line" =~ ^[[:space:]]*${key}[[:space:]]*= ]]; then
            echo "${key}=${value}" >> "$tmp_file"
            found=1
        else
            echo "$line" >> "$tmp_file"
        fi
    done < "$ENV_FILE"

    if [ "$found" -eq 0 ]; then
        echo "${key}=${value}" >> "$tmp_file"
    fi

    mv "$tmp_file" "$ENV_FILE"
}

load_env() {
    local target_file=""
    if [ -f "$ENV_FILE" ]; then
        target_file="$ENV_FILE"
    elif [ -f "$REPO_ROOT/.env" ]; then
        target_file="$REPO_ROOT/.env"
    fi

    if [ -n "$target_file" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | tr -d '\r')
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                local k="${BASH_REMATCH[1]}"
                local v="${BASH_REMATCH[2]}"
                if [[ "$v" =~ ^\"(.*)\"$ ]] || [[ "$v" =~ ^\'(.*)\'$ ]]; then
                    v="${BASH_REMATCH[1]}"
                fi
                export "$k"="$v"
            fi
        done < "$target_file"
    fi

    if [ -z "$MONGODB_URL" ]; then
        if [ -n "$MONGO_URL" ]; then
            MONGODB_URL="$MONGO_URL"
        elif [ -n "$MONGODB_URI" ]; then
            MONGODB_URL="$MONGODB_URI"
        elif [ -n "$MONGO_URI" ]; then
            MONGODB_URL="$MONGO_URI"
        fi
        export MONGODB_URL
    fi

    if [ -z "$GITHUB_TOKEN" ] && [ -n "$GH_TOKEN" ]; then
        GITHUB_TOKEN="$GH_TOKEN"
        export GITHUB_TOKEN
    fi
}
