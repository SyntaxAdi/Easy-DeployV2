#!/bin/bash

set -e

export PATH="$HOME/.local/bin:$PATH"

if command -v agy &>/dev/null || agy --version &>/dev/null 2>&1; then
    echo "AntiGravity CLI is already installed."
    exit 0
fi

echo "=== Installing AntiGravity CLI ==="
echo ""

curl -fsSL https://antigravity.google/cli/install.sh | bash

if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

export PATH="$HOME/.local/bin:$PATH"
echo "AntiGravity CLI installed successfully."
