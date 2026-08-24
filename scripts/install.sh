#!/bin/bash

set -e

echo "=== Installing Dependencies ==="

echo "[1/14] Updating package list..."
sudo apt update -qq

echo "[2/14] Installing git..."
sudo apt install -y -qq git

echo "[3/14] Installing wget..."
sudo apt install -y -qq wget

echo "[4/14] Installing curl..."
sudo apt install -y -qq curl

echo "[5/14] Installing screenfetch..."
sudo apt install -y -qq screenfetch

echo "[6/14] Installing screen..."
sudo apt install -y -qq screen

echo "[7/14] Installing nano..."
sudo apt install -y -qq nano

echo "[8/14] Installing ffmpeg..."
sudo apt install -y -qq ffmpeg

echo "[9/14] Installing python3..."
sudo apt install -y -qq python3

echo "[10/14] Installing python3-venv..."
sudo apt install -y -qq python3-venv

echo "[11/14] Installing python3-pip..."
sudo apt install -y -qq python3-pip

echo "[12/14] Installing jq..."
sudo apt install -y -qq jq

echo "[13/14] Installing fzf..."
sudo apt install -y -qq fzf

echo "[14/14] Installing mongosh..."
if command -v mongosh &>/dev/null; then
    echo "mongosh already installed"
else
    curl -fsSL https://downloads.mongodb.com/compass/mongodb-mongosh_2.9.0_amd64.deb -o /tmp/mongosh.deb
    sudo dpkg -i /tmp/mongosh.deb
    rm /tmp/mongosh.deb
fi

clear

echo ""
echo "=== Installed Versions ==="
git --version
python3 --version
pip3 --version
ffmpeg -version | head -n 1
jq --version
fzf --version
mongosh --version
echo ""
echo "All dependencies installed successfully."

echo ""
read -rp "Press Enter to return to main menu..."
