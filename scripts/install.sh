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
    curl -fsSL https://downloads.mongodb.com/compass/mongodb-mongosh_2.9.0_amd64.deb -o /tmp/mongosh.deb
    sudo dpkg -i /tmp/mongosh.deb
    rm /tmp/mongosh.deb
fi

echo ""
echo "=== Installed ==="
git --version
fzf --version
mongosh --version
echo "Done."
