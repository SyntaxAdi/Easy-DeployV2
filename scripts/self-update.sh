#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -d "$SCRIPT_DIR/.git" ]; then
    cd "$SCRIPT_DIR"
    git pull origin main --quiet 2>/dev/null
    clear
    echo "Scripts updated to latest version."
else
    echo "Not a git repo. Skipping update."
fi
