#!/usr/bin/env bash
#=============================================================================
# Hyprland Uninstaller
# Guided removal of Hyprland and associated packages
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
readonly RED='\e[31m'
readonly GREEN='\e[32m'
readonly YELLOW='\e[33m'
readonly CYAN='\e[36m'
readonly BOLD='\e[1m'
readonly DIM='\e[2m'
readonly RESET='\e[0m'

# Status prefixes
readonly OK="${GREEN}[OK]${RESET}"
readonly ERR="${RED}[ERROR]${RESET}"
readonly WARN="${YELLOW}[WARN]${RESET}"
readonly INFO="${CYAN}[INFO]${RESET}"
readonly NOTE="${YELLOW}[NOTE]${RESET}"

show_banner() {
    clear
    echo -e "${BOLD}${RED}"
    cat << 'EOF'
    ╦ ╦╔╗╔╦╔╗╔╔═╗╔╦╗╔═╗╦  ╦  ╔═╗╦═╗
    ║ ║║║║║║║║╚═╗ ║ ╠═╣║  ║  ║╣ ╠╦╝
    ╚═╝╝╚╝╩╝╚╝╚═╝ ╩ ╩ ╩╩═╝╩═╝╚═╝╩╚═
EOF
    echo -e "${RESET}"
    echo -e "${DIM}    Hyprland Uninstaller${RESET}\n"
}

# Packages that will be removed
core_packages=(
    hyprland
    hyprland-git
    hyprpolkitagent
)

optional_packages=(
    waybar
    rofi-wayland
    rofi
    swaync
    swww
    wlogout
    kitty
    thunar
    thunar-volman
    blueman
    sddm
    wallust
    nwg-look
    nwg-displays
)

config_dirs=(
    "$HOME/.config/hypr"
    "$HOME/.config/waybar"
    "$HOME/.config/rofi"
    "$HOME/.config/swaync"
    "$HOME/.config/wlogout"
    "$HOME/.config/kitty"
    "$HOME/.config/swww"
)

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    echo -en "${YELLOW}$prompt${RESET} "
    read -r response
    response="${response:-$default}"
    
    [[ "${response,,}" =~ ^(y|yes)$ ]]
}

remove_packages() {
    local -a packages=("$@")
    local to_remove=()
    
    # Check which packages are installed
    for pkg in "${packages[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            to_remove+=("$pkg")
        fi
    done
    
    if [[ ${#to_remove[@]} -eq 0 ]]; then
        echo -e "${INFO} No packages to remove."
        return 0
    fi
    
    echo -e "${NOTE} The following packages will be removed:"
    for pkg in "${to_remove[@]}"; do
        echo -e "  ${RED}-${RESET} $pkg"
    done
    echo ""
    
    if confirm "Proceed with removal? [y/N]"; then
        sudo pacman -Rns --noconfirm "${to_remove[@]}" 2>/dev/null || {
            # Try without dependencies
            sudo pacman -R --noconfirm "${to_remove[@]}" 2>/dev/null || true
        }
        echo -e "${OK} Packages removed."
    else
        echo -e "${INFO} Skipped package removal."
    fi
}

remove_configs() {
    echo -e "\n${NOTE} The following config directories can be removed:"
    
    local existing_dirs=()
    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            existing_dirs+=("$dir")
            echo -e "  ${RED}-${RESET} $dir"
        fi
    done
    
    if [[ ${#existing_dirs[@]} -eq 0 ]]; then
        echo -e "${INFO} No config directories found."
        return 0
    fi
    
    echo ""
    
    if confirm "Remove config directories? [y/N]"; then
        # Create backup first
        local backup_dir="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        
        for dir in "${existing_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                echo -e "${INFO} Backing up: $dir"
                cp -r "$dir" "$backup_dir/" 2>/dev/null || true
                rm -rf "$dir"
            fi
        done
        
        echo -e "${OK} Configs removed. Backup at: $backup_dir"
    else
        echo -e "${INFO} Skipped config removal."
    fi
}

disable_services() {
    echo -e "\n${NOTE} Disabling services..."
    
    # SDDM
    if systemctl is-enabled sddm.service &>/dev/null; then
        if confirm "Disable SDDM? [y/N]"; then
            sudo systemctl disable sddm.service
            echo -e "${OK} SDDM disabled."
        fi
    fi
    
    # Bluetooth (optional)
    if systemctl is-enabled bluetooth.service &>/dev/null; then
        if confirm "Disable Bluetooth? [y/N]"; then
            sudo systemctl disable bluetooth.service
            echo -e "${OK} Bluetooth disabled."
        fi
    fi
}

remove_nvidia_config() {
    if [[ -f /etc/modprobe.d/nvidia.conf ]]; then
        echo -e "\n${NOTE} NVIDIA configuration detected."
        
        if confirm "Remove NVIDIA modprobe configuration? [y/N]"; then
            sudo rm -f /etc/modprobe.d/nvidia.conf
            sudo rm -f /etc/modprobe.d/blacklist-nouveau.conf
            
            # Regenerate initramfs
            echo -e "${INFO} Regenerating initramfs..."
            sudo mkinitcpio -P
            
            echo -e "${OK} NVIDIA configuration removed."
        fi
    fi
}

main() {
    show_banner
    
    echo -e "${BOLD}${RED}WARNING:${RESET} This will remove Hyprland and related packages.\n"
    echo -e "${WARN} It is HIGHLY recommended to use timeshift or snapper"
    echo -e "${WARN} to restore your system instead of this script.\n"
    
    if ! confirm "Do you want to continue? [y/N]"; then
        echo -e "\n${INFO} Uninstallation cancelled."
        exit 0
    fi
    
    echo -e "\n${BOLD}Step 1: Core Packages${RESET}"
    echo -e "${DIM}─────────────────────────────────────${RESET}"
    remove_packages "${core_packages[@]}"
    
    echo -e "\n${BOLD}Step 2: Optional Packages${RESET}"
    echo -e "${DIM}─────────────────────────────────────${RESET}"
    
    if confirm "Remove optional packages (waybar, rofi, etc.)? [y/N]"; then
        remove_packages "${optional_packages[@]}"
    fi
    
    echo -e "\n${BOLD}Step 3: Services${RESET}"
    echo -e "${DIM}─────────────────────────────────────${RESET}"
    disable_services
    
    echo -e "\n${BOLD}Step 4: NVIDIA Configuration${RESET}"
    echo -e "${DIM}─────────────────────────────────────${RESET}"
    remove_nvidia_config
    
    echo -e "\n${BOLD}Step 5: Configuration Files${RESET}"
    echo -e "${DIM}─────────────────────────────────────${RESET}"
    remove_configs
    
    echo -e "\n${BOLD}${GREEN}Uninstallation Complete!${RESET}\n"
    echo -e "${NOTE} You may want to:"
    echo -e "  - Reboot your system"
    echo -e "  - Install another window manager/DE"
    echo -e "  - Check for orphaned packages: pacman -Qtdq"
    echo ""
    
    if confirm "Reboot now? [y/N]"; then
        systemctl reboot
    fi
}

main "$@"
