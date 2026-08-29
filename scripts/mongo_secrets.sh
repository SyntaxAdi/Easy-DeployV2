#!/bin/bash

set -e

[ -n "$_MONGO_SECRETS_SH_LOADED" ] && return 0
_MONGO_SECRETS_SH_LOADED=1

SCRIPT_DIR_MONGO_SECRETS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_MONGO_SECRETS/config.sh"
source "$SCRIPT_DIR_MONGO_SECRETS/mongo_store.sh"

fetch_token_from_mongo() {
    local mongo_url="$1"
    if [ -z "$mongo_url" ]; then
        return
    fi

    if command -v python3 &>/dev/null; then
        python3 "$SCRIPT_DIR_MONGO_SECRETS/mongo_helper.py" fetch_token "$mongo_url"
        return
    fi

    local output
    local exit_code=0
    output=$(mongosh "$mongo_url" --quiet --eval "
        const d = db.getSiblingDB('deploy');
        const doc = d.secrets.findOne({_id: 'github_token'});
        doc ? doc.value : '';
    " 2>&1) || exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "MongoDB error fetching token: $output" >&2
        return 1
    fi

    echo "$output" | tr -d '\r\n '
}

save_token_to_mongo() {
    local mongo_url="$1"
    local token="$2"

    if [ -z "$mongo_url" ]; then
        return
    fi

    if command -v python3 &>/dev/null; then
        python3 "$SCRIPT_DIR_MONGO_SECRETS/mongo_helper.py" save_token "$mongo_url" "$token"
        return
    fi

    local output
    local exit_code=0

    output=$(mongosh "$mongo_url" --quiet --eval "
        const d = db.getSiblingDB('deploy');
        d.secrets.updateOne(
            {_id: 'github_token'},
            {\$set: {value: '$token'}},
            {upsert: true}
        );
    " 2>&1) || exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "MongoDB error saving token: $output" >&2
        return 1
    fi
}
