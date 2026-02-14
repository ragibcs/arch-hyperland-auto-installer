#!/usr/bin/env bash
#=============================================================================
# PipeWire Audio Installation Script
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

init_installer

print_header "PipeWire Audio Setup"

# Check for PulseAudio conflict
if is_installed pulseaudio; then
    echo -e "${NOTE} PulseAudio detected. Removing..."
    
    # Stop PulseAudio service
    systemctl --user stop pulseaudio.socket pulseaudio.service 2>/dev/null || true
    systemctl --user disable pulseaudio.socket pulseaudio.service 2>/dev/null || true
    
    # Remove PulseAudio
    sudo pacman -Rdd --noconfirm pulseaudio pulseaudio-alsa 2>/dev/null || true
fi

# Install PipeWire packages
pipewire_pkgs=(
    pipewire
    wireplumber
    pipewire-audio
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    lib32-pipewire
)

echo -e "${NOTE} Installing PipeWire packages..."
install_packages_sequential "${pipewire_pkgs[@]}"

# Enable and start services
echo -e "\n${NOTE} Enabling PipeWire services..."

# User services
systemctl --user enable pipewire.socket 2>/dev/null || true
systemctl --user enable pipewire-pulse.socket 2>/dev/null || true
systemctl --user enable wireplumber.service 2>/dev/null || true

# Start services
systemctl --user start pipewire.socket 2>/dev/null || true
systemctl --user start pipewire-pulse.socket 2>/dev/null || true
systemctl --user start wireplumber.service 2>/dev/null || true

# Verify installation
echo -e "\n${NOTE} Verifying PipeWire..."
if command -v pactl &>/dev/null; then
    if pactl info 2>/dev/null | grep -q "PipeWire"; then
        echo -e "${OK} PipeWire is running correctly!"
    else
        echo -e "${WARN} PipeWire installed but may need a reboot to activate."
    fi
else
    echo -e "${INFO} PipeWire installed. Reboot to activate."
fi

echo -e "\n${OK} PipeWire audio setup complete!"
