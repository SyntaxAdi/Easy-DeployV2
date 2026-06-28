#!/bin/bash

set -e

echo "[+] Updating system package index..."
sudo apt update

echo "[+] Upgrading system packages..."
sudo apt upgrade -y

echo "[+] Package update completed successfully."
