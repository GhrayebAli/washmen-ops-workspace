#!/usr/bin/env bash
# Starts OpenVPN using the pre-generated vpnconfig.ovpn.
# Run during postStartCommand (every start/restart).
# Waits for the VPN tunnel to be established before returning.
set -e

DEVCONTAINER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$DEVCONTAINER_DIR/vpnconfig.ovpn" ]; then
    echo "WARNING: vpnconfig.ovpn not found — skipping VPN startup (is VPN_PRIVATE_KEY secret set?)"
    exit 0
fi

mkdir -p "$DEVCONTAINER_DIR/openvpn-tmp"
touch "$DEVCONTAINER_DIR/openvpn-tmp/openvpn.log"

sudo_cmd=""
if [ "$(id -u)" != "0" ]; then
    sudo_cmd="sudo"
fi

# Start OpenVPN in background
${sudo_cmd} openvpn --config "$DEVCONTAINER_DIR/vpnconfig.ovpn" --log "$DEVCONTAINER_DIR/openvpn-tmp/openvpn.log" --daemon

# Wait for VPN tunnel to be established (up to 30 seconds)
echo "Waiting for VPN connection..."
for i in $(seq 1 30); do
    if grep -q "Initialization Sequence Completed" "$DEVCONTAINER_DIR/openvpn-tmp/openvpn.log" 2>/dev/null; then
        echo "VPN connected."
        exit 0
    fi
    sleep 1
done

echo "WARNING: VPN did not connect within 30s — services may fail to reach internal resources"
echo "Check $DEVCONTAINER_DIR/openvpn-tmp/openvpn.log for details"
