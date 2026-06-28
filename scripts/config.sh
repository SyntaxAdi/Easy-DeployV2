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
        if [[ "$line" =~ ^${key}= ]]; then
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
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
    fi
}
