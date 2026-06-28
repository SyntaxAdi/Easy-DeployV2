#!/bin/bash

set -e

echo "=== Installing Dependencies ==="

echo "[1/13] Updating package list..."
sudo apt update -qq

echo "[2/13] Installing git..."
sudo apt install -y -qq git

echo "[3/13] Installing wget..."
sudo apt install -y -qq wget

echo "[4/13] Installing curl..."
sudo apt install -y -qq curl

echo "[5/13] Installing neofetch..."
sudo apt install -y -qq neofetch

echo "[6/13] Installing screen..."
sudo apt install -y -qq screen

echo "[7/13] Installing nano..."
sudo apt install -y -qq nano

echo "[8/13] Installing ffmpeg..."
sudo apt install -y -qq ffmpeg

echo "[9/13] Installing python3..."
sudo apt install -y -qq python3

echo "[10/13] Installing python3-venv..."
sudo apt install -y -qq python3-venv

echo "[11/13] Installing python3-pip..."
sudo apt install -y -qq python3-pip

echo "[12/13] Installing fzf..."
if command -v fzf &>/dev/null; then
    echo "fzf already installed"
else
    sudo apt install -y -qq fzf
fi

echo "[13/13] Installing mongosh..."
if command -v mongosh &>/dev/null; then
    echo "mongosh already installed"
else
    curl -fsSL https://downloads.mongodb.com/compass/mongodb-mongosh_2.9.0_amd64.deb -o /tmp/mongosh.deb
    sudo dpkg -i /tmp/mongosh.deb
    rm /tmp/mongosh.deb
fi

echo ""
echo "=== Installed Versions ==="
git --version
python3 --version
pip3 --version
ffmpeg -version | head -n 1
fzf --version
mongosh --version
echo ""
echo "All dependencies installed successfully."

clear
