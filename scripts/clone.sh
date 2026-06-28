#!/bin/bash

set -e

SCRIPT_DIR_CLONE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_CLONE/config.sh"
source "$SCRIPT_DIR_CLONE/auth.sh"
source "$SCRIPT_DIR_CLONE/mongo.sh"
source "$SCRIPT_DIR_CLONE/github.sh"
source "$SCRIPT_DIR_CLONE/git.sh"

clone_from_mongo() {
    load_env
    if [ -z "$MONGODB_URL" ]; then
        echo "Error: MONGODB_URL is not set. Run setup environment first."
        return 1
    fi

    echo "Fetching saved repos from MongoDB..."
    local raw_list
    raw_list=$(fetch_repos_from_mongo "$MONGODB_URL")

    if [ -z "$raw_list" ]; then
        echo "No saved repositories found in MongoDB."
        return 1
    fi

    echo "Select a saved repo to clone:"
    local selected
    if command -v fzf &>/dev/null; then
        selected=$(echo "$raw_list" | fzf --height 40% --reverse --prompt "Saved Repo> ")
    else
        echo "$raw_list"
        read -rp "Enter repo line (e.g. repo_name | url): " selected
    fi

    if [ -z "$selected" ]; then
        echo "No repo selected."
        return 1
    fi

    local repo_name
    local repo_url
    repo_name=$(echo "$selected" | awk -F '|' '{print $1}' | xargs)
    repo_url=$(echo "$selected" | awk -F '|' '{print $2}' | xargs)

    if [ -z "$repo_name" ] || [ -z "$repo_url" ]; then
        echo "Error parsing repository info."
        return 1
    fi

    local target="$PWD/$repo_name"
    local auth_url
    auth_url=$(get_authenticated_url "$repo_url")

    if [ -d "$target" ]; then
        echo "Directory already exists: $target"
        echo "Pulling latest changes..."
        (cd "$target" && git pull)
    else
        echo "Cloning $repo_url into $target..."
        git clone "$auth_url" "$target"
    fi
    echo "Done: $target"
    post_clone_actions "$target"
}

interactive_mode() {
    local token="$1"
    local repos
    repos=$(fetch_repos_from_github "$token") || return 1

    echo "Select a repo to clone:"
    local selected
    selected=$(echo "$repos" | fzf --height 40% --reverse --prompt "Repo> ")

    if [ -z "$selected" ]; then
        echo "No repo selected."
        return 1
    fi

    local url="https://github.com/$selected.git"
    clone_repo "$url" "$token"
}

echo "--- Clone Repo ---"
echo "1) Enter repo URL directly"
echo "2) Browse repos with GitHub token"
echo "3) Clone saved repo from MongoDB"
echo "4) Back to main menu"
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
    3)
        clone_from_mongo
        ;;
    4)
        clear
        return 0 2>/dev/null || exit 0
        ;;
    *)
        echo "Invalid option."
        return 1 2>/dev/null || exit 1
        ;;
esac
