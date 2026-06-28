#!/bin/bash

LOCAL_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -d "$LOCAL_REPO_DIR/.git" ]; then
    OUTPUT=$(cd "$LOCAL_REPO_DIR" && git pull origin main 2>&1)
    if echo "$OUTPUT" | grep -q "Already up to date"; then
        exit 0
    else
        clear
        echo "Scripts updated to latest version."
        exit 1
    fi
else
    echo "Not a git repo. Skipping update."
    exit 0
fi
