#!/bin/bash

set -e

LOCAL_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -d "$LOCAL_REPO_DIR/.git" ]; then
    (
        cd "$LOCAL_REPO_DIR"
        git pull origin main --quiet 2>/dev/null || true
    )
    clear
    echo "Scripts updated to latest version."
else
    echo "Not a git repo. Skipping update."
fi
