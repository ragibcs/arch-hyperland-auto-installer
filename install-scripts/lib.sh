#!/usr/bin/env bash
# Hyprland Installer - Core Library
# Optimized for low memory/CPU usage with modern UI
# License: GPL-3.0

set -euo pipefail

#=============================================================================
# COLOR DEFINITIONS (Lazy loaded, no subshells)
#=============================================================================
declare -A COLORS=(
    [reset]="\e[0m"
    [bold]="\e[1m"
    [dim]="\e[2m"
    [red]="\e[31m"
    [green]="\e[32m"
    [yellow]="\e[33m"
    [blue]="\e[34m"
    [magenta]="\e[35m"
    [cyan]="\e[36m"
    [white]="\e[37m"
    [bg_red]="\e[41m"
    [bg_green]="\e[42m"
    [bg_blue]="\e[44m"
    [bg_cyan]="\e[46m"
)

# Status prefixes (pre-computed to avoid repeated string operations)
readonly OK="${COLORS[green]}[OK]${COLORS[reset]}"
readonly ERR="${COLORS[red]}[ERROR]${COLORS[reset]}"
readonly WARN="${COLORS[yellow]}[WARN]${COLORS[reset]}"
readonly INFO="${COLORS[blue]}[INFO]${COLORS[reset]}"
readonly NOTE="${COLORS[cyan]}[NOTE]${COLORS[reset]}"
readonly ACT="${COLORS[magenta]}[ACTION]${COLORS[reset]}"

#=============================================================================
# GLOBALS
#=============================================================================
declare -g LOG_DIR="${LOG_DIR:-Install-Logs}"
declare -g LOG_FILE=""
declare -g ISAUR=""
declare -g PARALLEL_JOBS="${PARALLEL_JOBS:-4}"
declare -g SCRIPT_DIR=""
declare -g INSTALL_QUEUE=()
declare -g FAILED_PACKAGES=()
declare -g SUCCESSFUL_PACKAGES=()

#=============================================================================
# INITIALIZATION
#=============================================================================
init_installer() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
    
    # Detect AUR helper (cached for performance)
    if command -v paru &>/dev/null; then
        ISAUR="paru"
    elif command -v yay &>/dev/null; then
        ISAUR="yay"
    else
        ISAUR=""
    fi
    
    # Set terminal settings for better UX
    stty -echo 2>/dev/null || true
    trap cleanup EXIT INT TERM
}

cleanup() {
    stty echo 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    echo -e "\n${COLORS[reset]}"
}

#=============================================================================
# LOGGING (Optimized - no subshells)
#=============================================================================
log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1
    printf '[%s] [%s] %s\n' "$timestamp" "$level" "$msg" >> "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_error() { log "ERROR" "$@"; }
log_warn() { log "WARN" "$@"; }

#=============================================================================
# UI COMPONENTS (Modern, lightweight)
#=============================================================================

# Print styled header
print_header() {
    local text="$1"
    local width="${2:-60}"
    local padding=$(( (width - ${#text} - 2) / 2 ))
    
    echo -e "\n${COLORS[bold]}${COLORS[cyan]}"
    printf '%*s' "$width" | tr ' ' '='
    echo
    printf '%*s %s %*s\n' "$padding" "" "$text" "$padding" ""
    printf '%*s' "$width" | tr ' ' '='
    echo -e "${COLORS[reset]}\n"
}

# Print styled box
print_box() {
    local title="$1"
    local content="$2"
    local width="${3:-50}"
    
    echo -e "${COLORS[cyan]}+$(printf '%*s' $((width-2)) | tr ' ' '-')+${COLORS[reset]}"
    echo -e "${COLORS[cyan]}|${COLORS[bold]}${COLORS[white]} $title$(printf '%*s' $((width - ${#title} - 3)) '')${COLORS[cyan]}|${COLORS[reset]}"
    echo -e "${COLORS[cyan]}+$(printf '%*s' $((width-2)) | tr ' ' '-')+${COLORS[reset]}"
    echo -e "${COLORS[cyan]}|${COLORS[reset]} $content$(printf '%*s' $((width - ${#content} - 3)) '')${COLORS[cyan]}|${COLORS[reset]}"
    echo -e "${COLORS[cyan]}+$(printf '%*s' $((width-2)) | tr ' ' '-')+${COLORS[reset]}"
}

# Animated spinner (memory efficient)
spinner() {
    local pid="$1"
    local msg="${2:-Processing}"
    local frames=('.' '..' '...' '....' '.....')
    local i=0
    
    tput civis  # Hide cursor
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${INFO} %s %s   " "$msg" "${frames[i]}"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.2
    done
    
    tput cnorm  # Show cursor
}

# Modern progress bar
progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-40}"
    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    
    printf "\r${COLORS[cyan]}["
    printf '%*s' "$filled" | tr ' ' '#'
    printf '%*s' "$empty" | tr ' ' '-'
    printf "] %3d%% (%d/%d)${COLORS[reset]}" "$percent" "$current" "$total"
}

# Interactive menu using pure bash (no external deps)
select_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local key
    
    # Save cursor position
    tput sc
    tput civis  # Hide cursor
    
    while true; do
        tput rc  # Restore cursor position
        
        echo -e "\n${COLORS[bold]}${COLORS[cyan]}$title${COLORS[reset]}\n"
        echo -e "${COLORS[dim]}Use arrow keys to navigate, Enter to select, q to quit${COLORS[reset]}\n"
        
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "  ${COLORS[bg_cyan]}${COLORS[bold]} > ${options[$i]} ${COLORS[reset]}"
            else
                echo -e "    ${options[$i]}"
            fi
        done
        
        # Read single keypress
        read -rsn1 key
        
        case "$key" in
            A|k) # Up arrow or k
                ((selected > 0)) && ((selected--))
                ;;
            B|j) # Down arrow or j
                ((selected < ${#options[@]} - 1)) && ((selected++))
                ;;
            '') # Enter
                tput cnorm
                echo "$selected"
                return 0
                ;;
            q|Q)
                tput cnorm
                return 1
                ;;
        esac
    done
}

# Multi-select checkbox menu
checkbox_menu() {
    local title="$1"
    shift
    local -a options=("$@")
    local -a selected=()
    local cursor=0
    local key
    
    # Initialize all as unselected
    for i in "${!options[@]}"; do
        selected[$i]=0
    done
    
    tput sc
    tput civis
    
    while true; do
        tput rc
        tput ed  # Clear from cursor to end of screen
        
        echo -e "\n${COLORS[bold]}${COLORS[cyan]}$title${COLORS[reset]}\n"
        echo -e "${COLORS[dim]}Space to toggle, Enter to confirm, a=all, n=none, q=quit${COLORS[reset]}\n"
        
        for i in "${!options[@]}"; do
            local checkbox
            if [[ ${selected[$i]} -eq 1 ]]; then
                checkbox="${COLORS[green]}[x]${COLORS[reset]}"
            else
                checkbox="${COLORS[dim]}[ ]${COLORS[reset]}"
            fi
            
            if [[ $i -eq $cursor ]]; then
                echo -e "  ${COLORS[bg_blue]}${COLORS[bold]} > $checkbox ${options[$i]} ${COLORS[reset]}"
            else
                echo -e "    $checkbox ${options[$i]}"
            fi
        done
        
        read -rsn1 key
        
        case "$key" in
            A|k) ((cursor > 0)) && ((cursor--)) ;;
            B|j) ((cursor < ${#options[@]} - 1)) && ((cursor++)) ;;
            ' ') selected[$cursor]=$(( 1 - selected[$cursor] )) ;;
            a|A) for i in "${!selected[@]}"; do selected[$i]=1; done ;;
            n|N) for i in "${!selected[@]}"; do selected[$i]=0; done ;;
            '')  # Enter - return selected indices
                tput cnorm
                local result=""
                for i in "${!selected[@]}"; do
                    [[ ${selected[$i]} -eq 1 ]] && result+="$i "
                done
                echo "$result"
                return 0
                ;;
            q|Q)
                tput cnorm
                return 1
                ;;
        esac
    done
}

# Yes/No prompt with default
confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local response
    
    if [[ "$default" == "y" ]]; then
        prompt+=" [Y/n]: "
    else
        prompt+=" [y/N]: "
    fi
    
    echo -en "${ACT} $prompt"
    read -r response
    response="${response:-$default}"
    
    [[ "${response,,}" =~ ^(y|yes)$ ]]
}

#=============================================================================
# PACKAGE MANAGEMENT (Optimized for performance)
#=============================================================================

# Check if package is installed (cached results)
declare -A PKG_CACHE=()
is_installed() {
    local pkg="$1"
    
    # Check cache first
    if [[ -n "${PKG_CACHE[$pkg]:-}" ]]; then
        [[ "${PKG_CACHE[$pkg]}" == "1" ]]
        return $?
    fi
    
    # Query and cache
    if pacman -Qi "$pkg" &>/dev/null; then
        PKG_CACHE[$pkg]=1
        return 0
    else
        PKG_CACHE[$pkg]=0
        return 1
    fi
}

# Install single package (pacman)
install_pacman() {
    local pkg="$1"
    
    if is_installed "$pkg"; then
        echo -e "${INFO} ${COLORS[magenta]}$pkg${COLORS[reset]} already installed, skipping"
        return 0
    fi
    
    echo -e "${NOTE} Installing ${COLORS[yellow]}$pkg${COLORS[reset]}..."
    
    if sudo pacman -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1; then
        echo -e "${OK} ${COLORS[green]}$pkg${COLORS[reset]} installed successfully"
        PKG_CACHE[$pkg]=1
        SUCCESSFUL_PACKAGES+=("$pkg")
        return 0
    else
        echo -e "${ERR} Failed to install ${COLORS[red]}$pkg${COLORS[reset]}"
        FAILED_PACKAGES+=("$pkg")
        return 1
    fi
}

# Install single package (AUR)
install_aur() {
    local pkg="$1"
    
    if [[ -z "$ISAUR" ]]; then
        echo -e "${ERR} No AUR helper found"
        return 1
    fi
    
    if is_installed "$pkg"; then
        echo -e "${INFO} ${COLORS[magenta]}$pkg${COLORS[reset]} already installed, skipping"
        return 0
    fi
    
    echo -e "${NOTE} Installing ${COLORS[yellow]}$pkg${COLORS[reset]} from AUR..."
    
    if $ISAUR -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1; then
        echo -e "${OK} ${COLORS[green]}$pkg${COLORS[reset]} installed successfully"
        PKG_CACHE[$pkg]=1
        SUCCESSFUL_PACKAGES+=("$pkg")
        return 0
    else
        echo -e "${ERR} Failed to install ${COLORS[red]}$pkg${COLORS[reset]}"
        FAILED_PACKAGES+=("$pkg")
        return 1
    fi
}

# Install package (auto-detect source)
install_pkg() {
    local pkg="$1"
    
    if is_installed "$pkg"; then
        echo -e "${INFO} ${COLORS[magenta]}$pkg${COLORS[reset]} already installed"
        return 0
    fi
    
    # Try pacman first, then AUR
    if pacman -Si "$pkg" &>/dev/null; then
        install_pacman "$pkg"
    elif [[ -n "$ISAUR" ]]; then
        install_aur "$pkg"
    else
        echo -e "${ERR} Package $pkg not found and no AUR helper available"
        return 1
    fi
}

# Parallel package installation (significant performance boost)
install_packages_parallel() {
    local -a packages=("$@")
    local total=${#packages[@]}
    local count=0
    local pids=()
    local pkg_pids=()
    
    echo -e "\n${INFO} Installing ${COLORS[bold]}$total${COLORS[reset]} packages (${PARALLEL_JOBS} parallel jobs)...\n"
    
    for pkg in "${packages[@]}"; do
        # Skip if already installed
        if is_installed "$pkg"; then
            echo -e "${INFO} ${COLORS[dim]}$pkg${COLORS[reset]} - already installed"
            ((count++))
            progress_bar "$count" "$total"
            continue
        fi
        
        # Wait if we've reached max parallel jobs
        while [[ ${#pids[@]} -ge $PARALLEL_JOBS ]]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    wait "${pids[$i]}" && SUCCESSFUL_PACKAGES+=("${pkg_pids[$i]}") || FAILED_PACKAGES+=("${pkg_pids[$i]}")
                    unset 'pids[i]' 'pkg_pids[i]'
                fi
            done
            pids=("${pids[@]}")
            pkg_pids=("${pkg_pids[@]}")
            sleep 0.1
        done
        
        # Start background installation
        (
            if pacman -Si "$pkg" &>/dev/null; then
                sudo pacman -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1
            elif [[ -n "$ISAUR" ]]; then
                $ISAUR -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1
            fi
        ) &
        
        pids+=($!)
        pkg_pids+=("$pkg")
        
        ((count++))
        progress_bar "$count" "$total"
    done
    
    # Wait for remaining jobs
    for i in "${!pids[@]}"; do
        wait "${pids[$i]}" && SUCCESSFUL_PACKAGES+=("${pkg_pids[$i]}") || FAILED_PACKAGES+=("${pkg_pids[$i]}")
    done
    
    echo -e "\n\n${OK} Installation complete"
    echo -e "${INFO} Successful: ${#SUCCESSFUL_PACKAGES[@]} | Failed: ${#FAILED_PACKAGES[@]}"
    
    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "${WARN} Failed packages: ${FAILED_PACKAGES[*]}"
    fi
}

# Sequential installation with progress
install_packages_sequential() {
    local -a packages=("$@")
    local total=${#packages[@]}
    local count=0
    
    echo -e "\n${INFO} Installing ${COLORS[bold]}$total${COLORS[reset]} packages...\n"
    
    for pkg in "${packages[@]}"; do
        ((count++))
        progress_bar "$count" "$total"
        echo ""
        install_pkg "$pkg"
    done
    
    echo -e "\n${OK} Installation complete"
}

# Remove package
remove_pkg() {
    local pkg="$1"
    
    if ! is_installed "$pkg"; then
        echo -e "${INFO} ${COLORS[dim]}$pkg${COLORS[reset]} not installed, skipping"
        return 0
    fi
    
    echo -e "${NOTE} Removing ${COLORS[yellow]}$pkg${COLORS[reset]}..."
    
    if sudo pacman -Rns --noconfirm "$pkg" >> "$LOG_FILE" 2>&1; then
        echo -e "${OK} ${COLORS[green]}$pkg${COLORS[reset]} removed"
        PKG_CACHE[$pkg]=0
        return 0
    else
        echo -e "${ERR} Failed to remove ${COLORS[red]}$pkg${COLORS[reset]}"
        return 1
    fi
}

#=============================================================================
# SYSTEM DETECTION
#=============================================================================

# Detect GPU
detect_gpu() {
    local gpu_info
    gpu_info=$(lspci 2>/dev/null | grep -iE "vga|3d|display" || true)
    
    if echo "$gpu_info" | grep -qi "nvidia"; then
        echo "nvidia"
    elif echo "$gpu_info" | grep -qi "amd\|radeon"; then
        echo "amd"
    elif echo "$gpu_info" | grep -qi "intel"; then
        echo "intel"
    else
        echo "unknown"
    fi
}

# Detect if running in VM
detect_vm() {
    if systemd-detect-virt -q 2>/dev/null; then
        systemd-detect-virt
    elif [[ -d /proc/vz ]]; then
        echo "openvz"
    elif grep -qi "hypervisor" /proc/cpuinfo 2>/dev/null; then
        echo "unknown-vm"
    else
        echo "none"
    fi
}

# Check if laptop
is_laptop() {
    [[ -d /sys/class/power_supply/BAT0 ]] || [[ -d /sys/class/power_supply/BAT1 ]]
}

# Detect active display manager
detect_dm() {
    local dms=("gdm" "gdm3" "lightdm" "lxdm" "sddm")
    
    for dm in "${dms[@]}"; do
        if systemctl is-active --quiet "$dm.service" 2>/dev/null; then
            echo "$dm"
            return 0
        fi
    done
    
    echo "none"
}

#=============================================================================
# SCRIPT EXECUTION
#=============================================================================

# Execute script from install-scripts directory
run_script() {
    local script="$1"
    local script_path="${SCRIPT_DIR}/${script}"
    
    if [[ -f "$script_path" ]]; then
        chmod +x "$script_path"
        log_info "Executing: $script"
        
        if bash "$script_path"; then
            log_info "Completed: $script"
            return 0
        else
            log_error "Failed: $script"
            return 1
        fi
    else
        echo -e "${ERR} Script not found: $script"
        log_error "Script not found: $script"
        return 1
    fi
}

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

# Backup file/directory
backup() {
    local target="$1"
    local backup_dir="${2:-$HOME/.config-backup}"
    local timestamp
    printf -v timestamp '%(%Y%m%d-%H%M%S)T' -1
    
    if [[ -e "$target" ]]; then
        mkdir -p "$backup_dir"
        cp -r "$target" "$backup_dir/$(basename "$target").$timestamp"
        echo -e "${OK} Backed up: $target"
        log_info "Backed up: $target -> $backup_dir"
    fi
}

# Download file with progress
download() {
    local url="$1"
    local dest="$2"
    
    if command -v curl &>/dev/null; then
        curl -fsSL --progress-bar -o "$dest" "$url"
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -O "$dest" "$url"
    else
        echo -e "${ERR} Neither curl nor wget found"
        return 1
    fi
}

# Clone git repo
git_clone() {
    local repo="$1"
    local dest="$2"
    local depth="${3:-1}"
    
    if [[ -d "$dest" ]]; then
        echo -e "${INFO} Updating existing repo: $dest"
        git -C "$dest" pull --ff-only >> "$LOG_FILE" 2>&1
    else
        echo -e "${NOTE} Cloning: $repo"
        git clone --depth="$depth" "$repo" "$dest" >> "$LOG_FILE" 2>&1
    fi
}

# Print system info
print_system_info() {
    echo -e "\n${COLORS[bold]}${COLORS[cyan]}System Information${COLORS[reset]}"
    echo -e "${COLORS[dim]}─────────────────────────────────────${COLORS[reset]}"
    echo -e "  ${COLORS[yellow]}Distro:${COLORS[reset]}     $(grep -oP '(?<=^NAME=).+' /etc/os-release | tr -d '"')"
    echo -e "  ${COLORS[yellow]}Kernel:${COLORS[reset]}     $(uname -r)"
    echo -e "  ${COLORS[yellow]}GPU:${COLORS[reset]}        $(detect_gpu)"
    echo -e "  ${COLORS[yellow]}VM:${COLORS[reset]}         $(detect_vm)"
    echo -e "  ${COLORS[yellow]}Laptop:${COLORS[reset]}     $(is_laptop && echo "Yes" || echo "No")"
    echo -e "  ${COLORS[yellow]}DM:${COLORS[reset]}         $(detect_dm)"
    echo -e "  ${COLORS[yellow]}AUR:${COLORS[reset]}        ${ISAUR:-none}"
    echo -e "${COLORS[dim]}─────────────────────────────────────${COLORS[reset]}\n"
}

#=============================================================================
# EXPORT ALL FUNCTIONS
#=============================================================================
export -f log log_info log_error log_warn
export -f print_header print_box spinner progress_bar
export -f select_menu checkbox_menu confirm
export -f is_installed install_pacman install_aur install_pkg
export -f install_packages_parallel install_packages_sequential remove_pkg
export -f detect_gpu detect_vm is_laptop detect_dm
export -f run_script backup download git_clone
export -f print_system_info
