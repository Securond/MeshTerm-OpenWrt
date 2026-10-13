#!/bin/sh
# Quick installer for MeshTerm on OpenWrt GTW360
# Run this on your router:
#     curl -fsSL https://raw.githubusercontent.com/your-username/MeshTerm/main/scripts/openwrt-gtw360/install.sh | sh

set -eu

REPO_URL="${REPO_URL:-https://github.com/jpmartineau/MeshTerm.git}"
INSTALL_DIR="${INSTALL_DIR:-/opt/meshterm}"
SKIP_SWAP="${SKIP_SWAP:-0}"
WITH_BLE="${WITH_BLE:-0}"
INSTALL_LUCI="${INSTALL_LUCI:-1}"

echo "=== MeshTerm Quick Installer for OpenWrt GTW360 ==="
echo ""
echo "Configuration:"
echo "  Repository: $REPO_URL"
echo "  Install dir: $INSTALL_DIR"
echo "  Skip swap: $SKIP_SWAP"
echo "  With BLE: $WITH_BLE"
echo "  With LuCI: $INSTALL_LUCI"
echo ""

# Check if running as root
if [ "$(id -u)" != 0 ]; then
    echo "Error: This script must be run as root"
    echo "Run: sudo sh install.sh"
    exit 1
fi

# Install git if not present
if ! command -v git >/dev/null 2>&1; then
    echo "Installing git..."
    opkg update
    opkg install git-http ca-bundle
fi

# Clone repository
echo "Cloning MeshTerm repository..."
if [ -d "$INSTALL_DIR/src" ]; then
    echo "Directory exists, updating..."
    cd "$INSTALL_DIR/src"
    git pull || echo "Update failed, continuing..."
else
    mkdir -p "$INSTALL_DIR"
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR/src"
fi

# Run setup script
echo "Running setup script..."
cd "$INSTALL_DIR/src/scripts/openwrt-gtw360"

export SKIP_SWAP
export WITH_BLE
export INSTALL_LUCI

sh openwrt-setup.sh

echo ""
echo "=== Installation complete ==="
echo ""
echo "Access MeshTerm:"
echo "  SSH:      ssh -t root@$(uci -q get network.lan.ipaddr 2>/dev/null || echo GATEWAY) meshterm"
echo "  Web:      http://$(uci -q get network.lan.ipaddr 2>/dev/null || echo GATEWAY):7681"
echo "  LuCI:     Services -> MeshTerm"
echo ""
