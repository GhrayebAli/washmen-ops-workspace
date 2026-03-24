#!/usr/bin/env bash
# Generates vpnconfig.ovpn from template + VPN_PRIVATE_KEY secret.
# Run during postCreateCommand when secrets are available.
set -e

DEVCONTAINER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$VPN_PRIVATE_KEY" ]; then
    echo "WARNING: VPN_PRIVATE_KEY secret not set — VPN config not generated"
    exit 0
fi

awk -v key="$VPN_PRIVATE_KEY" '{gsub(/__VPN_PRIVATE_KEY__/, key); print}' \
    "$DEVCONTAINER_DIR/vpnconfig.ovpn.template" > "$DEVCONTAINER_DIR/vpnconfig.ovpn"
chmod 600 "$DEVCONTAINER_DIR/vpnconfig.ovpn"

echo "VPN config generated at $DEVCONTAINER_DIR/vpnconfig.ovpn"
