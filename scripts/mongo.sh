#!/bin/bash

set -e

[ -n "$_MONGO_SH_LOADED" ] && return 0
_MONGO_SH_LOADED=1

SCRIPT_DIR_MONGO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_MONGO/config.sh"

fetch_token_from_mongo() {
    local mongo_url="$1"
    if [ -z "$mongo_url" ]; then
        return
    fi
    local token
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

save_repo_to_mongo() {
    local mongo_url="$1"
    local repo_name="$2"
    local repo_url="$3"
    local target_path="$4"

    if [ -z "$mongo_url" ]; then
        return
    fi
    local output
    local exit_code=0

    output=$(mongosh "$mongo_url" --quiet --eval "
        const d = db.getSiblingDB('deploy');
        d.repos.updateOne(
            { repo_name: '$repo_name' },
            { \$set: { repo_name: '$repo_name', repo_url: '$repo_url', target_path: '$target_path', updated_at: new Date() } },
            { upsert: true }
        );
    " 2>&1) || exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "MongoDB error saving repo: $output" >&2
        return 1
    fi
}

fetch_repos_from_mongo() {
    local mongo_url="$1"
    if [ -z "$mongo_url" ]; then
        echo "Error: MongoDB URL is empty." >&2
        return 1
    fi
    local output
    local exit_code=0
    output=$(mongosh "$mongo_url" --quiet --eval "
        const d = db.getSiblingDB('deploy');
        const docs = d.repos.find().toArray();
        docs.forEach(doc => {
            if (doc.repo_name && doc.repo_url) {
                print(doc.repo_name + ' | ' + doc.repo_url);
            }
        });
    " 2>&1) || exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "MongoDB error fetching repos: $output" >&2
        return 1
    fi
    echo "$output"
}

