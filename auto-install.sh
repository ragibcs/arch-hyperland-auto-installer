#!/usr/bin/env bash
#=============================================================================
# Auto-Install Script - One-liner installation
# Usage: sh <(curl -fsSL https://raw.githubusercontent.com/ragibcs/arch-hyperland-auto-installer/main/auto-install.sh)
#=============================================================================

set -euo pipefail

# Colors (minimal, no tput dependency)
readonly RED='\e[31m'
readonly GREEN='\e[32m'
readonly YELLOW='\e[33m'
readonly CYAN='\e[36m'
readonly BOLD='\e[1m'
readonly RESET='\e[0m'

# Configuration
readonly REPO_URL="https://github.com/ragibcs/arch-hyperland-auto-installer.git"
readonly INSTALL_DIR="$HOME/arch-hyperland-auto-installer"

echo -e "${BOLD}${CYAN}"
cat << 'EOF'
    ╦ ╦╦ ╦╔═╗╦═╗╦  ╔═╗╔╗╔╔╦╗
    ╠═╣╚╦╝╠═╝╠╦╝║  ╠═╣║║║ ║║
    ╩ ╩ ╩ ╩  ╩╚═╩═╝╩ ╩╝╚╝═╩╝
    Auto-Installer
EOF
echo -e "${RESET}"

# Check for fish shell (unsupported)
if [[ "${SHELL##*/}" == "fish" ]]; then
    echo -e "${RED}ERROR:${RESET} Fish shell is not supported."
    echo -e "Please run this script from bash or zsh."
    exit 1
fi

# Check for root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}ERROR:${RESET} Do not run this script as root!"
    exit 1
fi

# Install git if needed
if ! command -v git &>/dev/null; then
    echo -e "${YELLOW}Installing git...${RESET}"
    sudo pacman -S --noconfirm git
fi

# Clone or update repository
if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${CYAN}Updating existing installation...${RESET}"
    cd "$INSTALL_DIR"
    git fetch origin
    git reset --hard origin/main
else
    echo -e "${CYAN}Cloning repository...${RESET}"
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Make installer executable
chmod +x install.sh

# Run installer
echo -e "${GREEN}Starting installer...${RESET}\n"
exec ./install.sh "$@"
