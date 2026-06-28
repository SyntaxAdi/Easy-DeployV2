#!/bin/bash

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/config.env"

# Fallback to .env if config.env does not exist yet
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

fetch_token_from_mongo() {
    local mongo_url="$1"
    local token
    token=$(mongosh "$mongo_url" --quiet --eval "
        const db = db.getSiblingDB('deploy');
        const doc = db.secrets.findOne({_id: 'github_token'});
        doc ? doc.value : '';
    " 2>/dev/null)

    if [ -n "$token" ]; then
        echo "$token"
    else
        echo ""
    fi
}

save_token_to_mongo() {
    local mongo_url="$1"
    local token="$2"

    mongosh "$mongo_url" --quiet --eval "
        const db = db.getSiblingDB('deploy');
        db.secrets.updateOne(
            {_id: 'github_token'},
            {\$set: {value: '$token'}},
            {upsert: true}
        );
    " 2>/dev/null
}

setup_mongo_url() {
    if [ -n "$MONGODB_URL" ]; then
        echo "Current MongoDB URL: $MONGODB_URL"
        read -rp "Do you wish to update it? (y/n): " update_mongo
        if [ "$update_mongo" != "y" ]; then
            return
        fi
    fi
    read -rp "Enter MongoDB URL: " new_mongo_url
    if [ -n "$new_mongo_url" ]; then
        MONGODB_URL="$new_mongo_url"
        save_env "MONGODB_URL" "$MONGODB_URL"
    fi
}

setup_github_token() {
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "Current GitHub Token is configured."
        read -rp "Do you wish to update it? (y/n): " update_token
        if [ "$update_token" != "y" ]; then
            return
        fi
    fi

    read -rp "Enter GitHub token (or leave blank to fetch from MongoDB): " token

    if [ -z "$token" ]; then
        token=$(fetch_token_from_mongo "$MONGODB_URL")
        if [ -n "$token" ]; then
            echo "Token fetched from MongoDB."
        else
            echo "No token found in MongoDB."
            read -rp "Enter GitHub token: " token
        fi
    fi

    if [ -n "$token" ]; then
        GITHUB_TOKEN="$token"
        save_env "GITHUB_TOKEN" "$GITHUB_TOKEN"
        if [ -n "$MONGODB_URL" ]; then
            save_token_to_mongo "$MONGODB_URL" "$GITHUB_TOKEN"
        fi
    fi
}

echo "=== Environment Setup ==="
echo ""

load_env

setup_mongo_url
echo ""
setup_github_token

clear
echo "Environment configured."
