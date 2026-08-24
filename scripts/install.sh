#!/bin/bash

set -e

SUDO=""
if command -v sudo &>/dev/null && [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

echo "=== Installing Dependencies ==="

echo "[1/14] Updating package list..."
$SUDO apt update -y || true

echo "[2/14] Installing git..."
$SUDO apt install -y git

echo "[3/14] Installing wget..."
$SUDO apt install -y wget

echo "[4/14] Installing curl..."
$SUDO apt install -y curl

echo "[5/14] Installing screenfetch..."
$SUDO apt install -y screenfetch || $SUDO apt install -y neofetch || true

echo "[6/14] Installing screen..."
$SUDO apt install -y screen

echo "[7/14] Installing nano..."
$SUDO apt install -y nano

echo "[8/14] Installing ffmpeg..."
$SUDO apt install -y ffmpeg

echo "[9/14] Installing python3..."
$SUDO apt install -y python3

echo "[10/14] Installing python3-venv..."
$SUDO apt install -y python3-venv || true

echo "[11/14] Installing python3-pip..."
$SUDO apt install -y python3-pip || true
if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null; then
    python3 -m ensurepip --upgrade 2>/dev/null || (curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && python3 /tmp/get-pip.py --break-system-packages 2>/dev/null && rm -f /tmp/get-pip.py) || true
fi

echo "[12/14] Installing jq..."
$SUDO apt install -y jq

echo "[13/14] Installing fzf..."
$SUDO apt install -y fzf || true

echo "[14/14] Installing mongosh..."
if command -v mongosh &>/dev/null; then
    echo "mongosh already installed"
else
    curl -fsSL https://downloads.mongodb.com/compass/mongodb-mongosh_2.9.0_amd64.deb -o /tmp/mongosh.deb
    $SUDO dpkg -i /tmp/mongosh.deb || $SUDO apt-get install -f -y
    rm -f /tmp/mongosh.deb
fi
