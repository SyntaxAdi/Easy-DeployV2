#!/bin/bash

SCRIPT_DIR_SU="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO_DIR="$(dirname "$SCRIPT_DIR_SU")"

if [ -d "$LOCAL_REPO_DIR/.git" ]; then
    cd "$LOCAL_REPO_DIR"
    
    if pull_out=$(git pull origin main 2>&1); then
        if [[ "$pull_out" == *"Already up to date."* ]]; then
            echo "Scripts are already up to date."
        else
            echo "Scripts successfully updated to the latest version."
        fi
    else
        echo "Error checking for updates."
    fi
else
    echo "Not a git repo. Skipping update."
fi
