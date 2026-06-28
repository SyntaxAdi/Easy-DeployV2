#!/bin/bash

set -e

CLONE_DIR="/opt/bots"

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

    echo "Fetching repos from GitHub..."
    local repos
    repos=$(curl -s -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user/repos?per_page=100" \
        | grep -o '"full_name":"[^"]*"' \
        | cut -d'"' -f4)

    if [ -z "$repos" ]; then
        echo "No repos found or invalid token."
        exit 1
    fi

    echo "Select a repo to clone:"
    local selected
    selected=$(echo "$repos" | fzf --height 40% --reverse --prompt "Repo> ")

    if [ -z "$selected" ]; then
        echo "No repo selected."
        exit 1
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
        read -rp "Enter GitHub token: " github_token
        interactive_mode "$github_token"
        ;;
    *)
        echo "Invalid option."
        exit 1
        ;;
esac
