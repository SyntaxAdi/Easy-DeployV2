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

    local escaped_repo_name
    local escaped_repo_url
    local escaped_target_path
    
    escaped_repo_name=$(echo "$repo_name" | sed "s/'/\\\\'/g")
    escaped_repo_url=$(echo "$repo_url" | sed "s/'/\\\\'/g")
    escaped_target_path=$(echo "$target_path" | sed "s/'/\\\\'/g")

    local output
    local exit_code=0

    output=$(mongosh "$mongo_url" --quiet --eval "
        const d = db.getSiblingDB('deploy');
        d.repos.updateOne(
            { repo_name: '$escaped_repo_name' },
            { \$set: { repo_name: '$escaped_repo_name', repo_url: '$escaped_repo_url', target_path: '$escaped_target_path', updated_at: new Date() } },
            { upsert: true }
        );
    " 2>&1) || exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "MongoDB error saving repo: $output" >&2
        return 1
    fi
}

update_repo_commands_in_mongo() {
    local mongo_url="$1"
    local repo_name="$2"
    local venv_cmd="$3"
    local install_cmd="$4"
    local extra_install_cmd="$5"

    if [ -z "$mongo_url" ]; then
        return
    fi

    local escaped_repo_name
    local escaped_venv_cmd
    local escaped_install_cmd
    local escaped_extra_install_cmd

    escaped_repo_name=$(echo "$repo_name" | sed "s/'/\\\\'/g")
    escaped_venv_cmd=$(echo "$venv_cmd" | sed "s/'/\\\\'/g")
    escaped_install_cmd=$(echo "$install_cmd" | sed "s/'/\\\\'/g")
    escaped_extra_install_cmd=$(echo "$extra_install_cmd" | sed "s/'/\\\\'/g")

    local output
    local exit_code=0

    output=$(mongosh "$mongo_url" --quiet --eval "
        const d = db.getSiblingDB('deploy');
        d.repos.updateOne(
            { repo_name: '$escaped_repo_name' },
            { \$set: { venv_cmd: '$escaped_venv_cmd', install_cmd: '$escaped_install_cmd', extra_install_cmd: '$escaped_extra_install_cmd', updated_at: new Date() } }
        );
    " 2>&1) || exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "MongoDB error updating repo commands: $output" >&2
        return 1
    fi
}

update_repo_env_file_in_mongo() {
    local mongo_url="$1"
    local repo_name="$2"
    local env_file="$3"
    local env_content="$4"

    if [ -z "$mongo_url" ]; then
        return
    fi

    local escaped_repo_name
    local escaped_env_file
    local escaped_env_content

    escaped_repo_name=$(echo "$repo_name" | sed "s/'/\\\\'/g")
    escaped_env_file=$(echo "$env_file" | sed "s/'/\\\\'/g")

    if command -v python3 &>/dev/null; then
        escaped_env_content=$(echo -n "$env_content" | python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))')
    else
        local cleaned
        cleaned=$(echo "$env_content" | sed "s/'/\\\\'/g")
        escaped_env_content="'$cleaned'"
    fi

    local output
    local exit_code=0

    output=$(mongosh "$mongo_url" --quiet --eval "
        const d = db.getSiblingDB('deploy');
        d.repos.updateOne(
            { repo_name: '$escaped_repo_name' },
            { \$set: { env_file: '$escaped_env_file', env_content: $escaped_env_content, updated_at: new Date() } }
        );
    " 2>&1) || exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "MongoDB error updating repo env file: $output" >&2
        return 1
    fi
}

update_repo_screen_details_in_mongo() {
    local mongo_url="$1"
    local repo_name="$2"
    local screen_name="$3"
    local start_cmd="$4"

    if [ -z "$mongo_url" ]; then
        return
    fi

    local escaped_repo_name
    local escaped_screen_name
    local escaped_start_cmd

    escaped_repo_name=$(echo "$repo_name" | sed "s/'/\\\\'/g")
    escaped_screen_name=$(echo "$screen_name" | sed "s/'/\\\\'/g")
    escaped_start_cmd=$(echo "$start_cmd" | sed "s/'/\\\\'/g")

    local output
    local exit_code=0

    output=$(mongosh "$mongo_url" --quiet --eval "
        const d = db.getSiblingDB('deploy');
        d.repos.updateOne(
            { repo_name: '$escaped_repo_name' },
            { \$set: { screen_name: '$escaped_screen_name', start_cmd: '$escaped_start_cmd', updated_at: new Date() } }
        );
    " 2>&1) || exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "MongoDB error updating repo screen details: $output" >&2
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

