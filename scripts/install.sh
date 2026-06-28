#!/bin/bash

set -e

echo "=== Installing Dependencies ==="

echo "[1/4] Updating package list..."
sudo apt update -qq

echo "[2/4] Installing git..."
sudo apt install -y -qq git

echo "[3/4] Installing fzf..."
if command -v fzf &>/dev/null; then
    echo "fzf already installed"
else
    sudo apt install -y -qq fzf
fi

echo "[4/4] Installing mongosh..."
if command -v mongosh &>/dev/null; then
    echo "mongosh already installed"
else
    sudo apt install -y -qq gnupg curl
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    sudo apt update -qq
    sudo apt install -y -qq mongosh
fi

echo ""
echo "=== Installed ==="
git --version
fzf --version
mongosh --version
echo "Done."
