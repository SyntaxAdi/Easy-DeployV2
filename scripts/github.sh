#!/bin/bash

set -e

[ -n "$_GITHUB_SH_LOADED" ] && return 0
_GITHUB_SH_LOADED=1

SCRIPT_DIR_GITHUB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_GITHUB/config.sh"
source "$SCRIPT_DIR_GITHUB/auth.sh"

fetch_repos_from_github() {
    local token="$1"

    if [ -z "$token" ]; then
        echo "Error: GitHub token unavailable." >&2
        return 1
    fi

    echo "Fetching repos from GitHub..." >&2
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
            echo "GitHub API Error: $msg" >&2
        else
            echo "No repos found or invalid token." >&2
        fi
        return 1
    fi

    echo "$repos"
}
