#!/bin/bash

set -e

[ -n "$_GIT_SH_LOADED" ] && return 0
_GIT_SH_LOADED=1

SCRIPT_DIR_GIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_GIT/config.sh"
source "$SCRIPT_DIR_GIT/auth.sh"
source "$SCRIPT_DIR_GIT/mongo.sh"
source "$SCRIPT_DIR_GIT/deps.sh"

git_sync_repo() {
    local url="$1"
    local target="$2"
    local token="${3:-}"

    if [ -z "$url" ] || [ -z "$target" ]; then
        echo "Error: missing parameters for git_sync_repo" >&2
        return 1
    fi

    local auth_url
    auth_url=$(get_authenticated_url "$url" "$token")

    if [ -d "$target" ]; then
        echo "Directory already exists: $target"
        echo "Pulling latest changes..."
        (cd "$target" && git pull)
    else
        echo "Cloning $url into $target..."
        git clone "$auth_url" "$target"
    fi
}

clone_repo() {
    local url="$1"
    local token="${2:-}"
    local default_name
    default_name=$(basename "$url" .git)

    read -rp "Enter folder name (press Enter for default '$default_name'): " custom_name
    local folder_name="${custom_name:-$default_name}"
    local target="$PWD/$folder_name"

    git_sync_repo "$url" "$target" "$token"

    load_env
    if [ -n "$MONGODB_URL" ]; then
        if save_repo_to_mongo "$MONGODB_URL" "$folder_name" "$url" "$target"; then
            echo "Saved repository details to MongoDB."
        else
            echo "Warning: Failed to save repository details to MongoDB." >&2
        fi
    fi

    echo "Done: $target"
    install_project_dependencies "$target" "$folder_name"
}
