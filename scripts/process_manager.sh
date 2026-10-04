#!/bin/bash

set -e

[ -n "$_PROCESS_MANAGER_SH_LOADED" ] && return 0
_PROCESS_MANAGER_SH_LOADED=1

SCRIPT_DIR_PM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_PM/config.sh"
source "$SCRIPT_DIR_PM/mongo.sh"
source "$SCRIPT_DIR_PM/screen_manager.sh"

apply_env_updates() {
    local target_path="$1"
    local repo_name="$2"
    local env_file="$3"
    local env_content="$4"
    local repo_json="$5"

    # MongoDB-only update (no screen restart, no disk write per user request)
    if ! update_repo_env_file_in_mongo "$MONGODB_URL" "$repo_name" "$env_file" "$env_content"; then
        echo "Failed to save to MongoDB." >&2
        return 1
    fi
    echo "Saved to MongoDB (no restart, no disk write)."
}
