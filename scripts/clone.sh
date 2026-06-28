#!/bin/bash

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/config.env"
if [ ! -f "$ENV_FILE" ] && [ -f "$REPO_ROOT/.env" ]; then
    ENV_FILE="$REPO_ROOT/.env"
fi

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
    " 2>/dev/null || true)

    echo "$token" | tr -d '\r\n '
}

save_repo_to_mongo() {
    local mongo_url="$1"
    local repo_name="$2"
    local repo_url="$3"
    local target_path="$4"

    if [ -z "$mongo_url" ]; then
        return
    fi

    mongosh "$mongo_url" --quiet --eval "
        const db = db.getSiblingDB('deploy');
        db.repos.updateOne(
            { repo_name: '$repo_name' },
            { \$set: { repo_name: '$repo_name', repo_url: '$repo_url', target_path: '$target_path', updated_at: new Date() } },
            { upsert: true }
        );
    " 2>/dev/null || true
}

get_github_token() {
    load_env

    if [ -n "$GITHUB_TOKEN" ]; then
        echo "$GITHUB_TOKEN" | tr -d '\r\n '
        return
    fi

    local token=""
    if [ -n "$MONGODB_URL" ]; then
        token=$(fetch_token_from_mongo "$MONGODB_URL")
    fi

    if [ -n "$token" ]; then
        echo "$token" | tr -d '\r\n '
        return
    fi

    read -rp "Enter GitHub token: " token
    echo "$token" | tr -d '\r\n '
}

fetch_github_username() {
    local token="$1"
    if [ -z "$token" ]; then
        echo ""
        return
    fi
    local res
    res=$(curl -s -H "Authorization: Bearer $token" -H "User-Agent: Easy-Deploy" https://api.github.com/user 2>/dev/null || true)
    local user=""
    if command -v jq &>/dev/null; then
        user=$(echo "$res" | jq -r '.login' 2>/dev/null || true)
    fi
    if [ -z "$user" ] || [ "$user" = "null" ]; then
        user=$(echo "$res" | grep -o '"login":"[^"]*"' | cut -d'"' -f4 || true)
    fi
    echo "$user"
}

get_authenticated_url() {
    local url="$1"
    local token
    token=$(get_github_token || true)

    if [ -z "$token" ]; then
        echo "$url"
        return
    fi

    local username
    username=$(fetch_github_username "$token")
    
    local clean_url="${url#https://}"
    clean_url="${clean_url#http://}"

    if [ -n "$username" ]; then
        echo "https://${username}:${token}@${clean_url}"
    else
        echo "https://x-access-token:${token}@${clean_url}"
    fi
}

clone_repo() {
    local url="$1"
    local default_name
    default_name=$(basename "$url" .git)

    read -rp "Enter folder name (press Enter for default '$default_name'): " custom_name
    local folder_name="${custom_name:-$default_name}"
    local target="$PWD/$folder_name"

    local auth_url
    auth_url=$(get_authenticated_url "$url")

    if [ -d "$target" ]; then
        echo "Directory already exists: $target"
        echo "Pulling latest changes..."
        (cd "$target" && git pull)
    else
        echo "Cloning $url into $target..."
        git clone "$auth_url" "$target"
    fi

    load_env
    if [ -n "$MONGODB_URL" ]; then
        save_repo_to_mongo "$MONGODB_URL" "$folder_name" "$url" "$target"
        echo "Saved repository details to MongoDB."
    fi

    echo "Done: $target"
}

clone_from_mongo() {
    load_env
    if [ -z "$MONGODB_URL" ]; then
        echo "Error: MONGODB_URL is not set. Run setup environment first."
        return 1
    fi

    echo "Fetching saved repos from MongoDB..."
    local raw_list
    raw_list=$(mongosh "$MONGODB_URL" --quiet --eval "
        const db = db.getSiblingDB('deploy');
        const docs = db.repos.find().toArray();
        docs.forEach(d => {
            if (d.repo_name && d.repo_url) {
                print(d.repo_name + ' | ' + d.repo_url);
            }
        });
    " 2>/dev/null || true)

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
}

interactive_mode() {
    local token="$1"

    if [ -z "$token" ]; then
        echo "Error: GitHub token unavailable."
        return 1
    fi

    echo "Fetching repos from GitHub..."
    local response
    response=$(curl -s -H "Authorization: Bearer $token" \
        -H "User-Agent: Easy-Deploy" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user/repos?per_page=100&affiliation=owner,collaborator,organization_member&sort=updated")

    local repos=""
    if command -v jq &>/dev/null; then
        repos=$(echo "$response" | jq -r '.[].full_name' 2>/dev/null || true)
    fi

    if [ -z "$repos" ]; then
        repos=$(echo "$response" | grep -o '"full_name":"[^"]*"' | cut -d'"' -f4 || true)
    fi

    if [ -z "$repos" ]; then
        local msg
        msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 || true)
        if [ -n "$msg" ]; then
            echo "GitHub API Error: $msg"
        else
            echo "No repos found or invalid token."
        fi
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
