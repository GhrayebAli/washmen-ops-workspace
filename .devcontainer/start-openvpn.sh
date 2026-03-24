#!/usr/bin/env bash
# Starts OpenVPN using the pre-generated vpnconfig.ovpn.
# Run during postStartCommand (every start/restart).
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

nohup ${sudo_cmd} /bin/sh -c "openvpn --config $DEVCONTAINER_DIR/vpnconfig.ovpn --log $DEVCONTAINER_DIR/openvpn-tmp/openvpn.log &" \
    | tee "$DEVCONTAINER_DIR/openvpn-tmp/openvpn-launch.log"

echo "OpenVPN started — check $DEVCONTAINER_DIR/openvpn-tmp/openvpn.log for status"
