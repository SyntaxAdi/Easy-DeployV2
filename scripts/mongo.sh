#!/bin/bash

set -e

[ -n "$_MONGO_SH_LOADED" ] && return 0
_MONGO_SH_LOADED=1

SCRIPT_DIR_MONGO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_MONGO/config.sh"

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

save_token_to_mongo() {
    local mongo_url="$1"
    local token="$2"

    mongosh "$mongo_url" --quiet --eval "
        const db = db.getSiblingDB('deploy');
        db.secrets.updateOne(
            {_id: 'github_token'},
            {\$set: {value: '$token'}},
            {upsert: true}
        );
    " 2>/dev/null || true
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

fetch_repos_from_mongo() {
    local mongo_url="$1"
    if [ -z "$mongo_url" ]; then
        echo ""
        return
    fi
    mongosh "$mongo_url" --quiet --eval "
        const db = db.getSiblingDB('deploy');
        const docs = db.repos.find().toArray();
        docs.forEach(d => {
            if (d.repo_name && d.repo_url) {
                print(d.repo_name + ' | ' + d.repo_url);
            }
        });
    " 2>/dev/null || true
}
