#!/bin/bash

set -e

ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"

save_env() {
    local key="$1"
    local value="$2"

    if [ -f "$ENV_FILE" ] && grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

load_env() {
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
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
    read -rp "Enter MongoDB URL: " MONGODB_URL
    save_env "MONGODB_URL" "$MONGODB_URL"
}

setup_github_token() {
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

    save_env "GITHUB_TOKEN" "$token"
    save_token_to_mongo "$MONGODB_URL" "$token"
}

echo "=== Environment Setup ==="
echo ""

load_env

if [ -n "$MONGODB_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "MongoDB URL and GitHub token already configured."
    read -rp "Do you want to modify? (y/n): " modify
    if [ "$modify" != "y" ]; then
        clear
        return 2>/dev/null || exit 0
    fi
    read -rp "Enter new GitHub token: " token
    save_env "GITHUB_TOKEN" "$token"
    save_token_to_mongo "$MONGODB_URL" "$token"
else
    setup_mongo_url
    setup_github_token
fi

clear
echo "Environment configured."
