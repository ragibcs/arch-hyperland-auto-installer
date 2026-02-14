#!/usr/bin/env bash
#=============================================================================
# SDDM Installation and Configuration Script
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

init_installer

print_header "SDDM Display Manager"

# Check for conflicting display managers
active_dm=$(detect_dm)
if [[ "$active_dm" != "none" && "$active_dm" != "sddm" ]]; then
    echo -e "${WARN} Active display manager detected: $active_dm"
    echo -e "${NOTE} Please disable it before installing SDDM:"
    echo -e "  sudo systemctl disable $active_dm.service"
    exit 1
fi

# Install SDDM and dependencies
sddm_pkgs=(
    sddm
    qt5-graphicaleffects
    qt5-quickcontrols2
    qt5-svg
)

echo -e "${NOTE} Installing SDDM packages..."
install_packages_sequential "${sddm_pkgs[@]}"

# Enable SDDM service
echo -e "\n${NOTE} Enabling SDDM service..."
sudo systemctl enable sddm.service

# Create SDDM configuration directory
sudo mkdir -p /etc/sddm.conf.d

# Configure SDDM for Wayland session
cat << 'EOF' | sudo tee /etc/sddm.conf.d/wayland.conf > /dev/null
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
SessionDir=/usr/share/wayland-sessions
EOF

echo -e "${OK} SDDM installation complete!"
echo -e "${NOTE} SDDM will start on next reboot."
