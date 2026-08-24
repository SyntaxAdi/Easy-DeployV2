#!/bin/bash

set -e

echo "=== Installing Dependencies ==="

echo "[1/14] Updating package list..."
sudo apt update -y || true

echo "[2/14] Installing git..."
sudo apt install -y git

echo "[3/14] Installing wget..."
sudo apt install -y wget

echo "[4/14] Installing curl..."
sudo apt install -y curl

echo "[5/14] Installing screenfetch..."
sudo apt install -y screenfetch || sudo apt install -y neofetch || true

echo "[6/14] Installing screen..."
sudo apt install -y screen

echo "[7/14] Installing nano..."
sudo apt install -y nano

echo "[8/14] Installing ffmpeg..."
sudo apt install -y ffmpeg

echo "[9/14] Installing python3..."
sudo apt install -y python3

echo "[10/14] Installing python3-venv..."
sudo apt install -y python3-venv || true

echo "[11/14] Installing python3-pip..."
sudo apt install -y python3-pip || true
if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null; then
    python3 -m ensurepip --upgrade 2>/dev/null || (curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && python3 /tmp/get-pip.py --break-system-packages 2>/dev/null && rm -f /tmp/get-pip.py) || true
fi

echo "[12/14] Installing jq..."
sudo apt install -y jq

echo "[13/14] Installing fzf..."
sudo apt install -y fzf || true

echo "[14/14] Installing mongosh..."
if command -v mongosh &>/dev/null; then
    echo "mongosh already installed"
else
    curl -fsSL https://downloads.mongodb.com/compass/mongodb-mongosh_2.9.0_amd64.deb -o /tmp/mongosh.deb
    sudo dpkg -i /tmp/mongosh.deb || sudo apt-get install -f -y
    rm -f /tmp/mongosh.deb
fi
