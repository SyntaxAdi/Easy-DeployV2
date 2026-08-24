#!/bin/bash

set -e

echo "=== Installing AntiGravity CLI ==="
echo ""

curl -fsSL https://antigravity.google/cli/install.sh | bash

if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

export PATH="$HOME/.local/bin:$PATH"
