#!/bin/bash

set -e

echo "=== Installing Dependencies ==="

echo "[1/3] Updating package list..."
sudo apt update -qq

echo "[2/3] Installing git..."
sudo apt install -y -qq git

echo "[3/3] Installing fzf..."
if command -v fzf &>/dev/null; then
    echo "fzf already installed"
else
    sudo apt install -y -qq fzf
fi

echo ""
echo "=== Installed ==="
git --version
fzf --version
echo "Done."
