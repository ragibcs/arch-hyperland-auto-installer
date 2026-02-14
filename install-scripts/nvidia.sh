#!/usr/bin/env bash
#=============================================================================
# NVIDIA Configuration Script
# Configures NVIDIA drivers for Hyprland
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

init_installer

print_header "NVIDIA Driver Configuration"

# Detect NVIDIA GPU
if ! lspci | grep -qi nvidia; then
    echo -e "${WARN} No NVIDIA GPU detected. Skipping..."
    exit 0
fi

echo -e "${INFO} NVIDIA GPU detected. Installing drivers..."

# Determine driver package based on GPU
gpu_info=$(lspci | grep -i nvidia | head -1)
echo -e "${NOTE} GPU: $gpu_info"

# Package list
nvidia_pkgs=(
    linux-headers
    nvidia-dkms
    nvidia-utils
    lib32-nvidia-utils
    nvidia-settings
    libva-nvidia-driver
    egl-wayland
)

# Install packages
echo -e "\n${NOTE} Installing NVIDIA packages..."
for pkg in "${nvidia_pkgs[@]}"; do
    install_pkg "$pkg" || true
done

# Create modprobe configuration
echo -e "\n${NOTE} Configuring kernel modules..."

sudo mkdir -p /etc/modprobe.d

# Main NVIDIA configuration
cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
# Enable DRM kernel mode setting
options nvidia_drm modeset=1 fbdev=1

# Preserve video memory for suspend/hibernate
options nvidia NVreg_PreserveVideoMemoryAllocations=1

# Disable GSP firmware (may help with some issues)
# options nvidia NVreg_EnableGpuFirmware=0
EOF

# Blacklist nouveau
cat << 'EOF' | sudo tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null
# Blacklist nouveau (open source NVIDIA driver)
blacklist nouveau
options nouveau modeset=0
EOF

echo -e "${OK} Kernel module configuration created"

# Configure mkinitcpio
echo -e "\n${NOTE} Updating mkinitcpio configuration..."

if [[ -f /etc/mkinitcpio.conf ]]; then
    # Backup original
    sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
    
    # Add nvidia modules if not present
    if ! grep -q "nvidia nvidia_modeset nvidia_uvm nvidia_drm" /etc/mkinitcpio.conf; then
        sudo sed -i 's/MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        # Clean up double spaces
        sudo sed -i 's/MODULES=(  /MODULES=(/' /etc/mkinitcpio.conf
    fi
fi

# Regenerate initramfs
echo -e "${NOTE} Regenerating initramfs..."
sudo mkinitcpio -P

# Enable NVIDIA services for suspend/hibernate
echo -e "\n${NOTE} Enabling NVIDIA power management services..."
sudo systemctl enable nvidia-suspend.service 2>/dev/null || true
sudo systemctl enable nvidia-hibernate.service 2>/dev/null || true
sudo systemctl enable nvidia-resume.service 2>/dev/null || true

# Create environment variables file for Hyprland
echo -e "\n${NOTE} Creating Hyprland environment configuration..."

mkdir -p "$HOME/.config/hypr"
cat << 'EOF' > "$HOME/.config/hypr/nvidia.conf"
# NVIDIA Environment Variables for Hyprland
# Source this in your hyprland.conf: source = ~/.config/hypr/nvidia.conf

env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = GBM_BACKEND,nvidia-drm

# Cursor fix
env = WLR_NO_HARDWARE_CURSORS,1

# Force GBM as buffer backend
env = __GL_GSYNC_ALLOWED,1
env = __GL_VRR_ALLOWED,1

# Use Wayland where possible
env = QT_QPA_PLATFORM,wayland;xcb
env = GDK_BACKEND,wayland,x11
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland
env = XDG_SESSION_TYPE,wayland
env = XDG_CURRENT_DESKTOP,Hyprland

# Firefox Wayland
env = MOZ_ENABLE_WAYLAND,1
EOF

echo -e "${OK} NVIDIA configuration complete!"
echo -e "${NOTE} Environment file created: ~/.config/hypr/nvidia.conf"
echo -e "${WARN} Please reboot your system for changes to take effect."
