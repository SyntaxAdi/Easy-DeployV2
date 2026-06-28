#!/bin/bash

set -e

[ -n "$_AUTH_SH_LOADED" ] && return 0
_AUTH_SH_LOADED=1

SCRIPT_DIR_AUTH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_AUTH/config.sh"
source "$SCRIPT_DIR_AUTH/mongo.sh"

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
        export GITHUB_TOKEN="$token"
        echo "$token" | tr -d '\r\n '
        return
    fi

    if [ -t 0 ]; then
        read -rp "Enter GitHub token: " token
    else
        read -rp "Enter GitHub token: " token < /dev/tty 2>/dev/null || true
    fi

    token=$(echo "$token" | tr -d '\r\n ')
    if [ -n "$token" ]; then
        export GITHUB_TOKEN="$token"
    fi
    echo "$token"
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
    local token="${2:-}"

    if [ -z "$token" ]; then
        token=$(get_github_token || true)
    fi

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
