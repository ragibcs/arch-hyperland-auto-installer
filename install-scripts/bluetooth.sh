#!/usr/bin/env bash
#=============================================================================
# Bluetooth Configuration Script
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

init_installer

print_header "Bluetooth Configuration"

# Install packages
bluetooth_pkgs=(
    bluez
    bluez-utils
    blueman
)

echo -e "${NOTE} Installing Bluetooth packages..."
install_packages_sequential "${bluetooth_pkgs[@]}"

# Enable and start Bluetooth service
echo -e "\n${NOTE} Enabling Bluetooth service..."
sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service

# Configure Bluetooth for auto-enable
echo -e "${NOTE} Configuring Bluetooth settings..."
sudo mkdir -p /etc/bluetooth

if [[ -f /etc/bluetooth/main.conf ]]; then
    # Enable AutoEnable
    sudo sed -i 's/#AutoEnable=false/AutoEnable=true/' /etc/bluetooth/main.conf
    sudo sed -i 's/AutoEnable=false/AutoEnable=true/' /etc/bluetooth/main.conf
else
    cat << 'EOF' | sudo tee /etc/bluetooth/main.conf > /dev/null
[General]
AutoEnable=true
EOF
fi

echo -e "${OK} Bluetooth configuration complete!"
echo -e "${NOTE} Use 'blueman-manager' to manage Bluetooth devices."
