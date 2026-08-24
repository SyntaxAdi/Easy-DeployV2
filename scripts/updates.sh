#!/bin/bash

set -e

SUDO=""
if command -v sudo &>/dev/null && [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

echo "[+] Updating system package index..."
$SUDO apt update

echo "[+] Upgrading system packages..."
$SUDO apt upgrade -y
