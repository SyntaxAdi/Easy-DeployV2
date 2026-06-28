#!/bin/bash

set -e

SCRIPT_DIR_SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_SETUP/config.sh"
source "$SCRIPT_DIR_SETUP/mongo.sh"

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

clear
echo "=== Environment Setup ==="
echo ""

load_env

setup_mongo_url
echo ""
setup_github_token
