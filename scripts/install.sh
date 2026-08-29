#!/bin/bash

set -e

IS_TERMUX=false
if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ] || [[ "${PREFIX:-}" == *"com.termux"* ]]; then
    IS_TERMUX=true
fi

SUDO=""
if [ "$IS_TERMUX" = "false" ] && command -v sudo &>/dev/null && [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

PKG_INSTALL="$SUDO apt install -y"
if [ "$IS_TERMUX" = "true" ]; then
    mkdir -p "${PREFIX:-/data/data/com.termux/files/usr}/etc"
    if [ ! -f "${PREFIX:-/data/data/com.termux/files/usr}/etc/resolv.conf" ]; then
        echo "nameserver 8.8.8.8" > "${PREFIX:-/data/data/com.termux/files/usr}/etc/resolv.conf"
        echo "nameserver 1.1.1.1" >> "${PREFIX:-/data/data/com.termux/files/usr}/etc/resolv.conf"
    fi
    if command -v pkg &>/dev/null; then
        PKG_INSTALL="pkg install -y"
    else
        PKG_INSTALL="apt install -y"
    fi
fi

echo "=== Installing Dependencies ==="

echo "[1/12] Updating package list..."
if [ "$IS_TERMUX" = "true" ]; then
    pkg update -y 2>/dev/null || apt update -y 2>/dev/null || true
else
    $SUDO apt update -y || true
fi

echo "[2/12] Installing git..."
$PKG_INSTALL git

echo "[3/12] Installing wget..."
$PKG_INSTALL wget

echo "[4/12] Installing curl..."
$PKG_INSTALL curl

echo "[5/12] Installing screen..."
$PKG_INSTALL screen

echo "[6/12] Installing nano..."
$PKG_INSTALL nano

echo "[7/12] Installing ffmpeg..."
$PKG_INSTALL ffmpeg || true

echo "[8/12] Installing python & build tools..."
if [ "$IS_TERMUX" = "true" ]; then
    $PKG_INSTALL python build-essential clang binutils libffi openssl || true
else
    $PKG_INSTALL python3 build-essential libffi-dev libssl-dev python3-dev || true
    echo "[8b/12] Installing python3-venv & python3-pip..."
    $PKG_INSTALL python3-venv python3-pip || true
fi

if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null; then
    python3 -m ensurepip --upgrade 2>/dev/null || (curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && python3 /tmp/get-pip.py --break-system-packages 2>/dev/null && rm -f /tmp/get-pip.py) || true
fi

pip3 install --upgrade pip setuptools wheel --break-system-packages 2>/dev/null || pip3 install --upgrade pip setuptools wheel 2>/dev/null || true

echo "[9/12] Installing jq..."
$PKG_INSTALL jq || true

echo "[10/12] Installing fzf..."
$PKG_INSTALL fzf || true

echo "[11/12] Installing system info tool..."
$PKG_INSTALL screenfetch 2>/dev/null || $PKG_INSTALL neofetch 2>/dev/null || $PKG_INSTALL fastfetch 2>/dev/null || true

echo "[12/12] Installing MongoDB backend (pymongo)..."
if command -v pip3 &>/dev/null; then
    pip3 install "pymongo[srv]" --break-system-packages 2>/dev/null || pip3 install "pymongo[srv]" 2>/dev/null || true
elif python3 -m pip --version &>/dev/null; then
    python3 -m pip install "pymongo[srv]" --break-system-packages 2>/dev/null || python3 -m pip install "pymongo[srv]" 2>/dev/null || true
fi

ARCH=$(uname -m 2>/dev/null || echo "")
if [ "$IS_TERMUX" = "false" ] && [ "$ARCH" = "x86_64" ] && command -v dpkg &>/dev/null; then
    if ! command -v mongosh &>/dev/null; then
        echo "Attempting optional mongosh binary install for x86_64..."
        curl -fsSL https://downloads.mongodb.com/compass/mongodb-mongosh_2.9.0_amd64.deb -o /tmp/mongosh.deb 2>/dev/null || true
        if [ -f /tmp/mongosh.deb ]; then
            ($SUDO dpkg -i /tmp/mongosh.deb || $SUDO apt-get install -f -y) 2>/dev/null || true
            rm -f /tmp/mongosh.deb
        fi
    fi
fi
