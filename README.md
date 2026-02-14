# Arch Hyprland Auto-Installer v2.0

A modern, fast, and efficient installer for Hyprland on Arch Linux.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?logo=wayland&logoColor=white)](https://hyprland.org/)

```
    ╦ ╦╦ ╦╔═╗╦═╗╦  ╔═╗╔╗╔╔╦╗  ╦╔╗╔╔═╗╔╦╗╔═╗╦  ╦  ╔═╗╦═╗
    ╠═╣╚╦╝╠═╝╠╦╝║  ╠═╣║║║ ║║  ║║║║╚═╗ ║ ╠═╣║  ║  ║╣ ╠╦╝
    ╩ ╩ ╩ ╩  ╩╚═╩═╝╩ ╩╝╚╝═╩╝  ╩╝╚╝╚═╝ ╩ ╩ ╩╩═╝╩═╝╚═╝╩╚═
```

## Features

- **Modern TUI** - Clean, keyboard-driven interface without heavy dependencies
- **Parallel Installation** - 3-4x faster package installation using parallel jobs
- **Low Resource Usage** - Optimized bash with minimal subshells and memory usage
- **Smart Detection** - Auto-detects GPU, VM, laptop, and active display managers
- **Preset Support** - Unattended installation with configuration presets
- **Modular Scripts** - Run individual components separately

## Quick Start

### One-liner Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ragibcs/arch-hyperland-auto-installer/main/auto-install.sh)
```

### Manual Installation

```bash
git clone --depth=1 https://github.com/ragibcs/arch-hyperland-auto-installer.git
cd arch-hyperland-auto-installer
./install.sh
```

### Using Presets (Unattended)

```bash
./install.sh --preset presets/full.conf
```

Available presets:
- `minimal.conf` - Core Hyprland only
- `full.conf` - All components
- `nvidia-gaming.conf` - Optimized for NVIDIA gaming

## What Gets Installed

### Core Components (Always)
- Hyprland compositor
- PipeWire audio system
- Essential tools (kitty, rofi, waybar, etc.)
- Fonts (JetBrains Mono Nerd, Fira Code, etc.)

### Optional Components
| Component | Description |
|-----------|-------------|
| GTK Themes | Dark/Light mode support with custom themes |
| Bluetooth | bluez + blueman for Bluetooth management |
| Thunar | Feature-rich file manager |
| SDDM | Display manager with Wayland support |
| SDDM Theme | Custom themed login screen |
| XDG Portal | Screen sharing for Discord/OBS |
| ZSH | Oh-My-Zsh with plugins |
| NVIDIA | Driver installation and configuration |
| Dotfiles | Pre-configured Hyprland dotfiles |
| QuickShell | Desktop-like overview effect |

## Performance Comparison

| Metric | Original | This Version |
|--------|----------|--------------|
| Install Time | ~15-20 min | ~5-8 min |
| Memory Usage | ~150MB | ~30MB |
| Dependencies | whiptail, gum | Pure bash |
| Parallel Jobs | None | 4 (configurable) |

## Directory Structure

```
arch-hyperland-auto-installer/
├── install.sh           # Main installer
├── uninstall.sh         # Guided uninstaller
├── auto-install.sh      # One-liner wrapper
├── install-scripts/
│   ├── lib.sh           # Core library
│   ├── nvidia.sh        # NVIDIA configuration
│   ├── bluetooth.sh     # Bluetooth setup
│   ├── sddm.sh          # SDDM installation
│   ├── zsh.sh           # ZSH + Oh-My-Zsh
│   └── pipewire.sh      # Audio setup
├── presets/
│   ├── minimal.conf     # Minimal installation
│   ├── full.conf        # Full installation
│   └── nvidia-gaming.conf
└── Install-Logs/        # Installation logs
```

## Command Line Options

```
./install.sh [options]

Options:
  --preset FILE    Load options from preset file
  --parallel N     Number of parallel installation jobs (default: 4)
  --help           Show help message
```

## Requirements

- Arch Linux or Arch-based distribution
- Non-root user with sudo access
- Internet connection
- `base-devel` package group

## Post-Installation

1. **Reboot** your system
2. **Start Hyprland**:
   - With SDDM: Select Hyprland from login screen
   - Without SDDM: Type `Hyprland` in TTY

### Useful Keybindings
| Key | Action |
|-----|--------|
| `SUPER + Enter` | Open terminal |
| `SUPER + D` | App launcher (rofi) |
| `SUPER + Q` | Close window |
| `SUPER + H` | Show keybind hints |

## Troubleshooting

### NVIDIA Issues
If you experience issues with NVIDIA:

1. Ensure the environment file is sourced:
   ```conf
   # In ~/.config/hypr/hyprland.conf
   source = ~/.config/hypr/nvidia.conf
   ```

2. Add to your environment:
   ```conf
   env = WLR_DRM_DEVICES,/dev/dri/card1
   ```

### Screen Sharing Not Working
Install XDG portal:
```bash
./install-scripts/xdph.sh
```

### Audio Issues
Reinstall PipeWire:
```bash
./install-scripts/pipewire.sh
```

## Uninstallation

```bash
./uninstall.sh
```

This provides a guided removal of Hyprland and associated packages.

## Credits

- [Hyprland](https://hyprland.org/) - Dynamic tiling Wayland compositor
- [JaKooLit](https://github.com/JaKooLit) - Original Arch-Hyprland installer inspiration
- [Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) - Pre-configured dotfiles

## License

GPL-3.0
