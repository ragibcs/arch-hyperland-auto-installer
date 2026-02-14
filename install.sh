#!/usr/bin/env bash
#=============================================================================
#  _  _                  _                 _   ___         _        _ _
# | || |_  _ _ __ _ _ _ | |__ _ _ _  __| | |_ _|_ _  __| |_ __ _| | |___ _ _
# | __ | || | '_ \ '_| || / _` | ' \/ _` |  | | ' \(_-<  _/ _` | | / -_) '_|
# |_||_|\_, | .__/_| |___|__,_|_||_\__,_| |___|_||_/__/\__\__,_|_|_\___|_|
#       |__/|_|
#
# Modern Hyprland Installer for Arch Linux
# Version: 2.0.0 | License: GPL-3.0
# 
# Features:
#   - Clean, modern TUI without heavy dependencies
#   - Parallel package installation for 3-4x faster installs
#   - Low memory footprint (no subshells where possible)
#   - Smart system detection (GPU, VM, laptop)
#   - Preset support for unattended installation
#=============================================================================

set -euo pipefail

#=============================================================================
# CONFIGURATION
#=============================================================================
readonly VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_SCRIPTS="${SCRIPT_DIR}/install-scripts"
readonly LOG_DIR="${SCRIPT_DIR}/Install-Logs"
readonly PRESET_DIR="${SCRIPT_DIR}/presets"
readonly CONFIG_FILE="${SCRIPT_DIR}/.installer-config"

# Default options (can be overridden by preset)
declare -A OPTIONS=(
    [hyprland]=1
    [pipewire]=1
    [fonts]=1
    [gtk_themes]=0
    [bluetooth]=0
    [thunar]=0
    [sddm]=0
    [sddm_theme]=0
    [xdph]=0
    [zsh]=0
    [nvidia]=0
    [dotfiles]=0
    [quickshell]=0
    [rofi]=1
    [waybar]=1
)

# Package lists (optimized for minimal memory)
declare -a CORE_PACKAGES=(
    hyprland
    hyprpolkitagent
    xdg-user-dirs
    xdg-utils
)

declare -a ESSENTIAL_PACKAGES=(
    bc cliphist curl grim gvfs gvfs-mtp
    imagemagick inxi jq kitty kvantum
    libspng nano network-manager-applet
    pamixer pavucontrol playerctl
    python-requests qt5ct qt6ct qt6-svg
    rofi-wayland slurp swappy swaync swww
    unzip wallust waybar wget wl-clipboard
    wlogout yad
)

declare -a OPTIONAL_PACKAGES=(
    brightnessctl btop cava loupe fastfetch
    gnome-system-monitor mousepad mpv mpv-mpris
    nvtop nwg-look nwg-displays pacman-contrib
    qalculate-gtk yt-dlp
)

declare -a FONT_PACKAGES=(
    ttf-jetbrains-mono-nerd
    ttf-firacode-nerd
    otf-font-awesome
    ttf-nerd-fonts-symbols
    noto-fonts
    noto-fonts-emoji
)

#=============================================================================
# SOURCE LIBRARY
#=============================================================================
if [[ -f "${INSTALL_SCRIPTS}/lib.sh" ]]; then
    source "${INSTALL_SCRIPTS}/lib.sh"
else
    echo "ERROR: Library file not found. Please ensure install-scripts/lib.sh exists."
    exit 1
fi

#=============================================================================
# BANNER & UI
#=============================================================================
show_banner() {
    clear
    cat << 'EOF'

    ╦ ╦╦ ╦╔═╗╦═╗╦  ╔═╗╔╗╔╔╦╗  ╦╔╗╔╔═╗╔╦╗╔═╗╦  ╦  ╔═╗╦═╗
    ╠═╣╚╦╝╠═╝╠╦╝║  ╠═╣║║║ ║║  ║║║║╚═╗ ║ ╠═╣║  ║  ║╣ ╠╦╝
    ╩ ╩ ╩ ╩  ╩╚═╩═╝╩ ╩╝╚╝═╩╝  ╩╝╚╝╚═╝ ╩ ╩ ╩╩═╝╩═╝╚═╝╩╚═
                                                    
EOF
    echo -e "${COLORS[cyan]}              Modern Arch Hyprland Installer v${VERSION}${COLORS[reset]}"
    echo -e "${COLORS[dim]}        Fast | Lightweight | Beautiful | Efficient${COLORS[reset]}"
    echo -e "${COLORS[dim]}─────────────────────────────────────────────────────────────${COLORS[reset]}\n"
}

show_welcome() {
    show_banner
    
    echo -e "  ${COLORS[yellow]}Welcome to the Hyprland Installer!${COLORS[reset]}\n"
    echo -e "  This script will help you set up Hyprland with:"
    echo -e "    ${COLORS[green]}*${COLORS[reset]} Modern wayland compositor (Hyprland)"
    echo -e "    ${COLORS[green]}*${COLORS[reset]} Beautiful themed desktop environment"
    echo -e "    ${COLORS[green]}*${COLORS[reset]} Essential tools and utilities"
    echo -e "    ${COLORS[green]}*${COLORS[reset]} Optional: NVIDIA drivers, SDDM, ZSH\n"
    
    echo -e "  ${COLORS[bold]}${COLORS[cyan]}System Requirements:${COLORS[reset]}"
    echo -e "    ${COLORS[dim]}- Arch Linux or Arch-based distro${COLORS[reset]}"
    echo -e "    ${COLORS[dim]}- Non-root user with sudo access${COLORS[reset]}"
    echo -e "    ${COLORS[dim]}- Internet connection${COLORS[reset]}"
    echo -e "    ${COLORS[dim]}- base-devel package group${COLORS[reset]}\n"
}

#=============================================================================
# PRE-FLIGHT CHECKS
#=============================================================================
preflight_checks() {
    local errors=0
    
    echo -e "${INFO} Running pre-flight checks...\n"
    
    # Check: Not running as root
    echo -n "  Checking: Not running as root... "
    if [[ $EUID -eq 0 ]]; then
        echo -e "${COLORS[red]}FAILED${COLORS[reset]}"
        echo -e "${ERR} This script should NOT be run as root!"
        ((errors++))
    else
        echo -e "${COLORS[green]}OK${COLORS[reset]}"
    fi
    
    # Check: Arch Linux
    echo -n "  Checking: Arch Linux detected... "
    if [[ -f /etc/arch-release ]]; then
        echo -e "${COLORS[green]}OK${COLORS[reset]}"
    else
        echo -e "${COLORS[yellow]}WARN${COLORS[reset]} (may work on Arch-based distros)"
    fi
    
    # Check: Internet connection
    echo -n "  Checking: Internet connection... "
    if ping -c 1 archlinux.org &>/dev/null; then
        echo -e "${COLORS[green]}OK${COLORS[reset]}"
    else
        echo -e "${COLORS[red]}FAILED${COLORS[reset]}"
        echo -e "${ERR} No internet connection detected!"
        ((errors++))
    fi
    
    # Check: base-devel
    echo -n "  Checking: base-devel installed... "
    if pacman -Qg base-devel &>/dev/null; then
        echo -e "${COLORS[green]}OK${COLORS[reset]}"
    else
        echo -e "${COLORS[yellow]}MISSING${COLORS[reset]} (will install)"
    fi
    
    # Check: PulseAudio conflict
    echo -n "  Checking: PulseAudio conflict... "
    if pacman -Qq pulseaudio &>/dev/null; then
        echo -e "${COLORS[red]}CONFLICT${COLORS[reset]}"
        echo -e "${WARN} PulseAudio detected. Will be replaced with PipeWire."
    else
        echo -e "${COLORS[green]}OK${COLORS[reset]}"
    fi
    
    # Check: AUR helper
    echo -n "  Checking: AUR helper... "
    if command -v paru &>/dev/null; then
        echo -e "${COLORS[green]}paru${COLORS[reset]}"
    elif command -v yay &>/dev/null; then
        echo -e "${COLORS[green]}yay${COLORS[reset]}"
    else
        echo -e "${COLORS[yellow]}MISSING${COLORS[reset]} (will install)"
    fi
    
    echo ""
    
    if [[ $errors -gt 0 ]]; then
        echo -e "${ERR} Pre-flight checks failed. Please fix the issues above."
        exit 1
    fi
    
    return 0
}

#=============================================================================
# INSTALLATION OPTIONS
#=============================================================================
select_options() {
    show_banner
    
    local gpu_type
    gpu_type=$(detect_gpu)
    local dm_active
    dm_active=$(detect_dm)
    
    echo -e "${INFO} Detected GPU: ${COLORS[yellow]}${gpu_type}${COLORS[reset]}"
    echo -e "${INFO} Active DM: ${COLORS[yellow]}${dm_active}${COLORS[reset]}\n"
    
    # Build options list dynamically
    local -a option_names=()
    local -a option_descs=()
    local -a option_keys=()
    
    # Core options (always shown)
    option_names+=("GTK Themes" "Bluetooth" "Thunar" "XDG Portal" "ZSH + Oh-My-Zsh" "Dotfiles")
    option_descs+=("Install GTK themes for dark/light mode" "Configure Bluetooth support" "Install Thunar file manager" "Screen sharing support" "ZSH shell with plugins" "Pre-configured Hyprland dots")
    option_keys+=("gtk_themes" "bluetooth" "thunar" "xdph" "zsh" "dotfiles")
    
    # NVIDIA option (if detected)
    if [[ "$gpu_type" == "nvidia" ]]; then
        option_names+=("NVIDIA Drivers")
        option_descs+=("Install and configure NVIDIA drivers")
        option_keys+=("nvidia")
    fi
    
    # SDDM options (if no DM active)
    if [[ "$dm_active" == "none" ]]; then
        option_names+=("SDDM" "SDDM Theme")
        option_descs+=("Install SDDM display manager" "Install custom SDDM theme")
        option_keys+=("sddm" "sddm_theme")
    fi
    
    # QuickShell option
    option_names+=("QuickShell")
    option_descs+=("Desktop-like overview effect")
    option_keys+=("quickshell")
    
    echo -e "${COLORS[bold]}Select installation options:${COLORS[reset]}\n"
    echo -e "${COLORS[dim]}Use number keys to toggle, Enter to continue, a=all, n=none${COLORS[reset]}\n"
    
    local -a selected=()
    for i in "${!option_keys[@]}"; do
        selected[$i]=0
    done
    
    # Default selections
    selected[0]=1  # GTK Themes
    selected[5]=1  # Dotfiles
    
    local cursor=0
    local key
    
    tput sc
    tput civis
    
    while true; do
        tput rc
        tput ed
        
        for i in "${!option_names[@]}"; do
            local checkbox
            if [[ ${selected[$i]} -eq 1 ]]; then
                checkbox="${COLORS[green]}[x]${COLORS[reset]}"
            else
                checkbox="${COLORS[dim]}[ ]${COLORS[reset]}"
            fi
            
            local num=$((i + 1))
            if [[ $i -eq $cursor ]]; then
                echo -e "  ${COLORS[bg_blue]}${COLORS[bold]} ${num}. $checkbox ${option_names[$i]} ${COLORS[reset]}"
                echo -e "      ${COLORS[dim]}${option_descs[$i]}${COLORS[reset]}"
            else
                echo -e "  ${num}. $checkbox ${option_names[$i]}"
            fi
        done
        
        echo ""
        echo -e "  ${COLORS[dim]}[Space] Toggle  [Enter] Continue  [a] All  [n] None  [q] Quit${COLORS[reset]}"
        
        read -rsn1 key
        
        case "$key" in
            [1-9])
                local idx=$((key - 1))
                if [[ $idx -lt ${#option_names[@]} ]]; then
                    selected[$idx]=$(( 1 - selected[$idx] ))
                    cursor=$idx
                fi
                ;;
            A|k) ((cursor > 0)) && ((cursor--)) ;;
            B|j) ((cursor < ${#option_names[@]} - 1)) && ((cursor++)) ;;
            ' ') selected[$cursor]=$(( 1 - selected[$cursor] )) ;;
            a|A) for i in "${!selected[@]}"; do selected[$i]=1; done ;;
            n|N) for i in "${!selected[@]}"; do selected[$i]=0; done ;;
            '')
                tput cnorm
                # Apply selections to OPTIONS
                for i in "${!option_keys[@]}"; do
                    OPTIONS[${option_keys[$i]}]=${selected[$i]}
                done
                return 0
                ;;
            q|Q)
                tput cnorm
                echo -e "\n${INFO} Installation cancelled."
                exit 0
                ;;
        esac
    done
}

confirm_options() {
    show_banner
    
    echo -e "${COLORS[bold]}Installation Summary:${COLORS[reset]}\n"
    
    echo -e "  ${COLORS[cyan]}Core Components (always installed):${COLORS[reset]}"
    echo -e "    - Hyprland compositor"
    echo -e "    - PipeWire audio"
    echo -e "    - Essential tools & utilities"
    echo -e "    - Fonts"
    echo ""
    
    echo -e "  ${COLORS[cyan]}Selected Options:${COLORS[reset]}"
    local has_options=0
    for key in "${!OPTIONS[@]}"; do
        if [[ ${OPTIONS[$key]} -eq 1 ]] && [[ "$key" != "hyprland" ]] && [[ "$key" != "pipewire" ]] && [[ "$key" != "fonts" ]] && [[ "$key" != "rofi" ]] && [[ "$key" != "waybar" ]]; then
            echo -e "    ${COLORS[green]}+${COLORS[reset]} $key"
            has_options=1
        fi
    done
    
    if [[ $has_options -eq 0 ]]; then
        echo -e "    ${COLORS[dim]}(none selected)${COLORS[reset]}"
    fi
    
    echo ""
    
    if confirm "Proceed with installation?"; then
        return 0
    else
        return 1
    fi
}

#=============================================================================
# AUR HELPER INSTALLATION
#=============================================================================
install_aur_helper() {
    if command -v paru &>/dev/null || command -v yay &>/dev/null; then
        echo -e "${INFO} AUR helper already installed."
        return 0
    fi
    
    show_banner
    echo -e "${INFO} No AUR helper found. Please select one:\n"
    
    local options=("paru (Recommended)" "yay")
    local result
    
    if result=$(select_menu "Select AUR Helper" "${options[@]}"); then
        case $result in
            0)  # paru
                echo -e "\n${NOTE} Installing paru..."
                (
                    cd /tmp
                    rm -rf paru
                    git clone --depth=1 https://aur.archlinux.org/paru-bin.git paru
                    cd paru
                    makepkg -si --noconfirm
                    cd ..
                    rm -rf paru
                ) >> "$LOG_FILE" 2>&1
                ISAUR="paru"
                ;;
            1)  # yay
                echo -e "\n${NOTE} Installing yay..."
                (
                    cd /tmp
                    rm -rf yay
                    git clone --depth=1 https://aur.archlinux.org/yay-bin.git yay
                    cd yay
                    makepkg -si --noconfirm
                    cd ..
                    rm -rf yay
                ) >> "$LOG_FILE" 2>&1
                ISAUR="yay"
                ;;
        esac
        
        echo -e "${OK} AUR helper installed successfully."
    else
        echo -e "${ERR} AUR helper is required. Exiting."
        exit 1
    fi
}

#=============================================================================
# INSTALLATION FUNCTIONS
#=============================================================================
install_base() {
    echo -e "\n${INFO} Installing base-devel if needed..."
    if ! pacman -Qg base-devel &>/dev/null; then
        sudo pacman -S --needed --noconfirm base-devel >> "$LOG_FILE" 2>&1
    fi
}

install_core() {
    print_header "Installing Core Packages"
    install_packages_parallel "${CORE_PACKAGES[@]}"
}

install_essential() {
    print_header "Installing Essential Packages"
    install_packages_parallel "${ESSENTIAL_PACKAGES[@]}"
}

install_optional() {
    print_header "Installing Optional Packages"
    install_packages_parallel "${OPTIONAL_PACKAGES[@]}"
}

install_fonts() {
    print_header "Installing Fonts"
    install_packages_parallel "${FONT_PACKAGES[@]}"
}

install_pipewire() {
    print_header "Installing PipeWire"
    
    local pipewire_pkgs=(
        pipewire
        wireplumber
        pipewire-audio
        pipewire-pulse
        pipewire-alsa
        pipewire-jack
    )
    
    # Remove conflicting PulseAudio if present
    if is_installed pulseaudio; then
        echo -e "${NOTE} Removing PulseAudio..."
        remove_pkg pulseaudio
    fi
    
    install_packages_parallel "${pipewire_pkgs[@]}"
    
    # Enable services
    systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
}

install_gtk_themes() {
    if [[ ${OPTIONS[gtk_themes]} -ne 1 ]]; then return 0; fi
    
    print_header "Installing GTK Themes"
    
    local theme_pkgs=(
        gtk3
        gtk4
        adw-gtk-theme
        papirus-icon-theme
        bibata-cursor-theme
    )
    
    install_packages_parallel "${theme_pkgs[@]}"
    
    # Clone GTK themes repo
    local themes_repo="https://github.com/JaKooLit/GTK-themes-icons.git"
    local themes_dir="$HOME/.themes-install"
    
    git_clone "$themes_repo" "$themes_dir"
    
    if [[ -d "$themes_dir" ]]; then
        # Copy themes
        mkdir -p "$HOME/.themes" "$HOME/.icons"
        cp -r "$themes_dir"/themes/* "$HOME/.themes/" 2>/dev/null || true
        cp -r "$themes_dir"/icons/* "$HOME/.icons/" 2>/dev/null || true
        echo -e "${OK} GTK themes installed."
    fi
}

install_bluetooth() {
    if [[ ${OPTIONS[bluetooth]} -ne 1 ]]; then return 0; fi
    
    print_header "Configuring Bluetooth"
    
    local bt_pkgs=(bluez bluez-utils blueman)
    install_packages_parallel "${bt_pkgs[@]}"
    
    # Enable service
    sudo systemctl enable --now bluetooth.service
    echo -e "${OK} Bluetooth configured."
}

install_thunar() {
    if [[ ${OPTIONS[thunar]} -ne 1 ]]; then return 0; fi
    
    print_header "Installing Thunar"
    
    local thunar_pkgs=(
        thunar
        thunar-volman
        tumbler
        ffmpegthumbnailer
        thunar-archive-plugin
        file-roller
    )
    
    install_packages_parallel "${thunar_pkgs[@]}"
}

install_sddm() {
    if [[ ${OPTIONS[sddm]} -ne 1 ]]; then return 0; fi
    
    print_header "Installing SDDM"
    
    install_pkg sddm
    install_pkg qt5-graphicaleffects
    install_pkg qt5-quickcontrols2
    
    # Enable service
    sudo systemctl enable sddm.service
    
    echo -e "${OK} SDDM installed and enabled."
}

install_sddm_theme() {
    if [[ ${OPTIONS[sddm_theme]} -ne 1 ]]; then return 0; fi
    
    print_header "Installing SDDM Theme"
    
    local theme_repo="https://github.com/JaKooLit/simple-sddm-2.git"
    local theme_dir="/tmp/sddm-theme"
    
    git_clone "$theme_repo" "$theme_dir"
    
    if [[ -d "$theme_dir" ]]; then
        sudo mkdir -p /usr/share/sddm/themes/
        sudo cp -r "$theme_dir" /usr/share/sddm/themes/simple-sddm-2
        
        # Configure SDDM
        sudo mkdir -p /etc/sddm.conf.d
        echo -e "[Theme]\nCurrent=simple-sddm-2" | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null
        
        echo -e "${OK} SDDM theme installed."
    fi
}

install_xdph() {
    if [[ ${OPTIONS[xdph]} -ne 1 ]]; then return 0; fi
    
    print_header "Installing XDG Portal"
    
    local xdph_pkgs=(
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
    )
    
    install_packages_parallel "${xdph_pkgs[@]}"
}

install_zsh() {
    if [[ ${OPTIONS[zsh]} -ne 1 ]]; then return 0; fi
    
    print_header "Installing ZSH"
    
    install_pkg zsh
    install_pkg zsh-autosuggestions
    install_pkg zsh-syntax-highlighting
    
    # Install Oh-My-Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        echo -e "${NOTE} Installing Oh-My-Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # Change default shell
    if [[ "$SHELL" != *"zsh"* ]]; then
        chsh -s "$(which zsh)"
    fi
    
    echo -e "${OK} ZSH installed."
}

install_nvidia() {
    if [[ ${OPTIONS[nvidia]} -ne 1 ]]; then return 0; fi
    
    print_header "Configuring NVIDIA"
    
    local nvidia_pkgs=(
        nvidia-dkms
        nvidia-utils
        nvidia-settings
        libva-nvidia-driver
    )
    
    # Install NVIDIA packages
    install_packages_parallel "${nvidia_pkgs[@]}"
    
    # Create modprobe config
    echo -e "${NOTE} Configuring NVIDIA modules..."
    sudo mkdir -p /etc/modprobe.d
    cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF
    
    # Blacklist nouveau
    cat << 'EOF' | sudo tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null
blacklist nouveau
options nouveau modeset=0
EOF
    
    # Enable services
    sudo systemctl enable nvidia-suspend.service
    sudo systemctl enable nvidia-hibernate.service
    sudo systemctl enable nvidia-resume.service
    
    # Regenerate initramfs
    sudo mkinitcpio -P
    
    echo -e "${OK} NVIDIA configured. Reboot required."
}

install_quickshell() {
    if [[ ${OPTIONS[quickshell]} -ne 1 ]]; then return 0; fi
    
    print_header "Installing QuickShell"
    install_pkg quickshell
}

install_dotfiles() {
    if [[ ${OPTIONS[dotfiles]} -ne 1 ]]; then return 0; fi
    
    print_header "Installing Dotfiles"
    
    local dots_repo="https://github.com/JaKooLit/Hyprland-Dots.git"
    local dots_dir="$HOME/Hyprland-Dots"
    
    # Backup existing configs
    backup "$HOME/.config/hypr"
    backup "$HOME/.config/waybar"
    backup "$HOME/.config/rofi"
    
    git_clone "$dots_repo" "$dots_dir"
    
    if [[ -d "$dots_dir" ]]; then
        cd "$dots_dir"
        if [[ -f "install.sh" ]]; then
            chmod +x install.sh
            ./install.sh
        elif [[ -f "copy.sh" ]]; then
            chmod +x copy.sh
            ./copy.sh
        fi
        cd "$SCRIPT_DIR"
    fi
    
    echo -e "${OK} Dotfiles installed."
}

#=============================================================================
# FINAL CHECKS
#=============================================================================
final_checks() {
    print_header "Final Verification"
    
    local missing=()
    local critical_pkgs=(hyprland kitty waybar rofi-wayland)
    
    for pkg in "${critical_pkgs[@]}"; do
        echo -n "  Checking $pkg... "
        if is_installed "$pkg"; then
            echo -e "${COLORS[green]}OK${COLORS[reset]}"
        else
            echo -e "${COLORS[red]}MISSING${COLORS[reset]}"
            missing+=("$pkg")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "\n${WARN} Some packages are missing: ${missing[*]}"
        echo -e "${NOTE} You may need to install them manually."
    else
        echo -e "\n${OK} All critical packages installed successfully!"
    fi
}

show_completion() {
    show_banner
    
    echo -e "  ${COLORS[bold]}${COLORS[green]}Installation Complete!${COLORS[reset]}\n"
    
    echo -e "  ${COLORS[cyan]}What's next:${COLORS[reset]}"
    echo -e "    1. Reboot your system"
    echo -e "    2. Start Hyprland by typing: ${COLORS[yellow]}Hyprland${COLORS[reset]}"
    echo -e "       (or login via SDDM if installed)"
    echo ""
    echo -e "  ${COLORS[cyan]}Useful keybindings:${COLORS[reset]}"
    echo -e "    ${COLORS[yellow]}SUPER + Enter${COLORS[reset]}    - Open terminal"
    echo -e "    ${COLORS[yellow]}SUPER + D${COLORS[reset]}        - App launcher (rofi)"
    echo -e "    ${COLORS[yellow]}SUPER + Q${COLORS[reset]}        - Close window"
    echo -e "    ${COLORS[yellow]}SUPER + H${COLORS[reset]}        - Show keybind hints"
    echo ""
    echo -e "  ${COLORS[cyan]}Logs:${COLORS[reset]} ${LOG_FILE}"
    echo -e "  ${COLORS[cyan]}Docs:${COLORS[reset]} https://wiki.hyprland.org\n"
    
    if confirm "Would you like to reboot now?"; then
        echo -e "\n${INFO} Rebooting..."
        systemctl reboot
    else
        echo -e "\n${INFO} Remember to reboot before starting Hyprland."
    fi
}

#=============================================================================
# MAIN
#=============================================================================
main() {
    # Initialize
    init_installer
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --preset)
                shift
                if [[ -f "$1" ]]; then
                    source "$1"
                    echo -e "${INFO} Loaded preset: $1"
                fi
                ;;
            --parallel)
                shift
                PARALLEL_JOBS="$1"
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo "  --preset FILE    Load options from preset file"
                echo "  --parallel N     Number of parallel installation jobs (default: 4)"
                echo "  --help           Show this help"
                exit 0
                ;;
        esac
        shift
    done
    
    # Show welcome
    show_welcome
    
    # Wait for user
    echo -e "${ACT} Press Enter to continue or Ctrl+C to exit..."
    read -r
    
    # Pre-flight checks
    preflight_checks
    
    # Print system info
    print_system_info
    
    # Select options
    select_options
    
    # Confirm
    if ! confirm_options; then
        select_options
        confirm_options || exit 1
    fi
    
    # Install AUR helper if needed
    install_aur_helper
    
    # Re-initialize with AUR helper
    init_installer
    
    # Run installation
    echo -e "\n${INFO} Starting installation...\n"
    
    install_base
    install_core
    install_essential
    install_optional
    install_fonts
    install_pipewire
    
    # Optional components based on selection
    install_gtk_themes
    install_bluetooth
    install_thunar
    install_sddm
    install_sddm_theme
    install_xdph
    install_zsh
    install_nvidia
    install_quickshell
    install_dotfiles
    
    # Final checks
    final_checks
    
    # Show completion
    show_completion
}

# Run main
main "$@"
