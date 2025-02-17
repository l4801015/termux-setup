#!/bin/bash
set -eo pipefail

# ---------------------------
# Configuration Variables
# ---------------------------
LOG_DIR="${HOME}/.setup_logs"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
TRUE_COLOR_TEST_URL="https://gist.githubusercontent.com/lifepillar/09a44b8cf0f9397465614e622979107f/raw/24-bit-color.sh"

# ---------------------------
# Logging Configuration
# ---------------------------
setup_logging() {
    mkdir -p "${LOG_DIR}"
    exec > >(tee -a "${LOG_DIR}/setup_output.log")
    exec 2> >(tee -a "${LOG_DIR}/setup_errors.log" >&2)
}

# ---------------------------
# Logging Functions
# ---------------------------
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local color=''
    
    case $level in
        INFO) color='\033[0;32m' ;;  # Green
        WARN) color='\033[1;33m' ;;  # Yellow
        ERROR) color='\033[0;31m' ;; # Red
        *) color='\033[0m' ;;
    esac
    
    echo -e "${color}[${timestamp}] [${level}] ${message}\033[0m"
}

run_step() {
    local description=$1
    local command=$2
    
    log "INFO" "Starting: ${description}"
    eval "${command}" || {
        log "ERROR" "Failed: ${description}"
        exit 1
    }
    log "INFO" "Completed: ${description}"
}

# ---------------------------
# Package Management
# ---------------------------
install_packages() {
    local package_manager=$1
    shift
    local packages=("$@")
    
    log "INFO" "Installing packages using ${package_manager}: ${packages[*]}"
    if [[ "${package_manager}" == "pkg" ]]; then
        pkg install -y "${packages[@]}" || return 1
    elif [[ "${package_manager}" == "apt" ]]; then
        apt update && apt install -y "${packages[@]}" || return 1
    else
        log "ERROR" "Unsupported package manager: ${package_manager}"
        return 1
    fi
}

# ---------------------------
# Environment Detection
# ---------------------------
detect_environment() {
    if [[ -d "${TERMUX_PREFIX}" ]]; then
        echo "termux"
    elif grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        echo "ubuntu"
    else
        log "ERROR" "Unsupported environment"
        exit 1
    fi
}

# ---------------------------
# Core Installations
# ---------------------------
install_termux_core() {
    local packages=(
        git nodejs curl wget openssh zsh neovim 
        ncurses-utils clang make proot proot-distro
    )
    run_step "Termux core packages installation" \
        "install_packages pkg \"${packages[*]}\""
}

install_ubuntu_core() {
    local packages=(
        git nodejs curl wget openssh-client zsh 
        neovim ncurses-base clang make
    )
    run_step "Ubuntu core packages installation" \
        "install_packages apt \"${packages[*]}\""
}

# ---------------------------
# Proot Ubuntu Installation
# ---------------------------
install_proot_ubuntu() {
    local rootfs_dir="${TERMUX_PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu"
    
    if [[ -d "${rootfs_dir}" ]]; then
        log "INFO" "Ubuntu rootfs already exists"
        return 0
    fi

    run_step "Ubuntu proot installation" "proot-distro install ubuntu"
}

# ---------------------------
# Terminal Configuration
# ---------------------------
configure_truecolor() {
    local termux_config="${HOME}/.termux/termux.properties"
    
    run_step "Truecolor configuration" "
        mkdir -p ~/.termux &&
        echo 'termux-transient-keys = enter,arrow' > '${termux_config}' &&
        echo 'export COLORTERM=truecolor TERM=xterm-256color' >> ~/.bashrc &&
        termux-reload-settings
    "
}

# ---------------------------
# Zsh Configuration
# ---------------------------
setup_zsh() {
    local zshrc="${HOME}/.zshrc"
    local omz_install_url="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    
    if ! command -v zsh >/dev/null; then
        run_step "Zsh installation" "install_packages ${PKG_MANAGER} zsh"
    fi

    if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
        run_step "Oh My Zsh installation" \
            "RUNZSH=no CHSH=no sh -c \"\$(curl -fsSL ${omz_install_url})\""
    fi

    run_step "Zsh theme configuration" "
        sed -i 's/^ZSH_THEME=.*/ZSH_THEME=\"af-magic\"/' '${zshrc}' &&
        grep -qxF 'export TERM=xterm-256color' '${zshrc}' || 
        echo 'export TERM=xterm-256color' >> '${zshrc}' &&
        echo 'exec zsh' >> ~/.profile
    "
}

# ---------------------------
# Neovim Configuration
# ---------------------------
configure_neovim() {
    local nvim_dir="${HOME}/.config/nvim"
    local plug_url="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    
    run_step "Neovim plugin manager installation" "
        curl -fLo ${nvim_dir}/autoload/plug.vim --create-dirs ${plug_url}
    "

    run_step "Neovim configuration" "
        mkdir -p '${nvim_dir}' && cat > '${nvim_dir}/init.vim' << 'EOF'
$(cat << 'INIT_VIM'
" Plugin management
call plug#begin('~/.local/share/nvim/plugged')
Plug 'preservim/nerdtree'
Plug 'itchyny/lightline.vim'
Plug 'morhetz/gruvbox'
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'Yggdroot/indentLine'
call plug#end()

" Gruvbox configuration
colorscheme gruvbox
set background=dark
let g:gruvbox_contrast_dark = 'medium'
let g:gruvbox_italic = 1

" IndentLine configuration
let g:indentLine_char = '│'
let g:indentLine_color_term = 239

" Treesitter configuration
lua << END
require'nvim-treesitter.configs'.setup {
  ensure_installed = {'javascript', 'typescript', 'lua', 'python', 'bash', 'json'},
  highlight = { enable = true },
  indent = { enable = true }
}
END

" Core editor settings
set termguicolors
set nocompatible
set tabstop=2 shiftwidth=2 expandtab
set nobackup nowritebackup noswapfile
set number cursorline scrolloff=8
syntax on
INIT_VIM
)
EOF"
}

# ---------------------------
# Post-Installation Setup
# ---------------------------
post_installation() {
    run_step "Neovim plugin installation" "nvim --headless +PlugInstall +qa"
    
    local parsers=(javascript typescript lua python bash json)
    run_step "Treesitter parser installation" \
        "nvim --headless -c 'TSInstallSync ${parsers[*]}' -c 'qall'"
}

# ---------------------------
# Verification & Final Steps
# ---------------------------
verify_environment() {
    local tools=(git node nvim zsh)
    log "INFO" "Verifying installations..."
    
    for tool in "${tools[@]}"; do
        if command -v "${tool}" >/dev/null; then
            log "INFO" "${tool} $(command ${tool} --version 2>&1 | head -n1)"
        else
            log "ERROR" "${tool} not found"
            exit 1
        fi
    done

    run_step "Truecolor verification" \
        "curl -fsSL ${TRUE_COLOR_TEST_URL} | bash"
}

show_completion() {
    log "INFO" $'\n\033[1;32mInstallation completed successfully!\033[0m'
    log "INFO" $'\nNext steps:'
    echo "1. Restart your terminal session"
    echo "2. Start Neovim with: nvim"
    echo "3. Run :checkhealth in Neovim to verify setup"
}

# ---------------------------
# Main Execution Flow
# ---------------------------
main() {
    setup_logging
    local env=$(detect_environment)
    local PKG_MANAGER="pkg"

    log "INFO" "Detected environment: ${env}"
    
    if [[ "${env}" == "termux" ]]; then
        install_termux_core
        install_proot_ubuntu
        configure_truecolor
    else
        PKG_MANAGER="apt"
        install_ubuntu_core
    fi

    setup_zsh
    configure_neovim
    post_installation
    verify_environment
    show_completion
}

main "$@"