#!/usr/bin/env bash
set -e

# Switch to the .devcontainer folder
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Build vpnconfig.ovpn from template + secret
if [ -z "$VPN_PRIVATE_KEY" ]; then
    echo "WARNING: VPN_PRIVATE_KEY secret not set — skipping VPN startup"
    exit 0
fi

# Replace the placeholder with the full PEM key from the secret
awk -v key="$VPN_PRIVATE_KEY" '{gsub(/__VPN_PRIVATE_KEY__/, key); print}' vpnconfig.ovpn.template > vpnconfig.ovpn
chmod 600 vpnconfig.ovpn

# Create a temporary directory for logs
mkdir -p openvpn-tmp
cd openvpn-tmp

touch openvpn.log

# If we are running as root, we do not need to use sudo
sudo_cmd=""
if [ "$(id -u)" != "0" ]; then
    sudo_cmd="sudo"
fi

# Start up the VPN client
nohup ${sudo_cmd} /bin/sh -c "openvpn --config ../vpnconfig.ovpn --log openvpn.log &" | tee openvpn-launch.log

echo "OpenVPN started — check .devcontainer/openvpn-tmp/openvpn.log for status"
