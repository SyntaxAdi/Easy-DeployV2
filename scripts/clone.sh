#!/bin/bash

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/config.env"
if [ ! -f "$ENV_FILE" ] && [ -f "$REPO_ROOT/.env" ]; then
    ENV_FILE="$REPO_ROOT/.env"
fi

CLONE_DIR="/opt/bots"

load_env() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
    fi
}

fetch_token_from_mongo() {
    local mongo_url="$1"
    if [ -z "$mongo_url" ]; then
        echo ""
        return
    fi
    local token
    token=$(mongosh "$mongo_url" --quiet --eval "
        const db = db.getSiblingDB('deploy');
        const doc = db.secrets.findOne({_id: 'github_token'});
        doc ? doc.value : '';
    " 2>/dev/null)

    echo "$token"
}

get_github_token() {
    load_env

    if [ -n "$GITHUB_TOKEN" ]; then
        echo "$GITHUB_TOKEN"
        return
    fi

    local token=""
    if [ -n "$MONGODB_URL" ]; then
        token=$(fetch_token_from_mongo "$MONGODB_URL")
    fi

    if [ -n "$token" ]; then
        echo "$token"
        return
    fi

    read -rp "Enter GitHub token: " token
    echo "$token"
}

clone_repo() {
    local url="$1"
    local repo_name
    repo_name=$(basename "$url" .git)
    local target="$CLONE_DIR/$repo_name"

    if [ -d "$target" ]; then
        echo "Directory already exists: $target"
        echo "Pulling latest changes..."
        cd "$target"
        git pull
    else
        echo "Cloning $url into $target..."
        mkdir -p "$CLONE_DIR"
        git clone "$url" "$target"
    fi
    echo "Done: $target"
}

interactive_mode() {
    local token="$1"

    if [ -z "$token" ]; then
        echo "Error: GitHub token unavailable."
        return 1
    fi

    echo "Fetching repos from GitHub..."
    local repos
    repos=$(curl -s -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user/repos?per_page=100" \
        | grep -o '"full_name":"[^"]*"' \
        | cut -d'"' -f4)

    if [ -z "$repos" ]; then
        echo "No repos found or invalid token."
        return 1
    fi

    echo "Select a repo to clone:"
    local selected
    selected=$(echo "$repos" | fzf --height 40% --reverse --prompt "Repo> ")

    if [ -z "$selected" ]; then
        echo "No repo selected."
        return 1
    fi

    local url="https://github.com/$selected.git"
    clone_repo "$url"
}

echo "--- Clone Repo ---"
echo "1) Enter repo URL directly"
echo "2) Browse repos with GitHub token"
read -rp "Choose mode: " mode

case "$mode" in
    1)
        read -rp "Enter repo URL: " repo_url
        clone_repo "$repo_url"
        ;;
    2)
        github_token=$(get_github_token)
        interactive_mode "$github_token"
        ;;
    *)
        echo "Invalid option."
        return 1 2>/dev/null || exit 1
        ;;
esac
