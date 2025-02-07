#!/bin/bash
set -e

# Redirect stdout and stderr to log files
exec > >(tee -a setup_output.log) 2> >(tee -a setup_errors.log >&2)

# Function to print debug messages
debug_message() {
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RESET='\033[0m'
    echo -e "${GREEN}[${YELLOW}$(date +"%Y-%m-%d %H:%M:%S")${GREEN}] ${RESET}$1"
}

# Environment detection
detect_environment() {
    if [ -n "$TERMUX_VERSION" ] && [ ! -d "/proc/1/root/.proot-dir" ]; then
        echo "termux"
    elif [ -f "/etc/os-release" ] && grep -qi 'ubuntu' /etc/os-release && [ -d "/proc/1/root/.proot-dir" ]; then
        echo "ubuntu_proot"
    else
        echo "unknown"
    fi
}

# Package manager setup
setup_package_manager() {
    case $ENV_TYPE in
        "termux")
            UPDATE_CMD="pkg update -y"
            INSTALL_CMD="pkg install -y"
            ;;
        "ubuntu_proot")
            UPDATE_CMD="apt update -y"
            INSTALL_CMD="apt install -y"
            # Ensure sudo is available
            if ! command -v sudo >/dev/null; then
                $INSTALL_CMD sudo
            fi
            ;;
        *)
            echo "Unsupported environment" >&2
            exit 1
            ;;
    esac
}

# Core package installation
install_core_packages() {
    debug_message "Installing core packages for $ENV_TYPE..."
    
    case $ENV_TYPE in
        "termux")
            $INSTALL_CMD git nodejs curl wget openssh zsh neovim ncurses-utils \
                clang make proot proot-distro termux-tools
            ;;
        "ubuntu_proot")
            $INSTALL_CMD git nodejs curl wget openssh zsh neovim ncurses-utils \
                clang make proot
            ;;
    esac || {
        echo "Error: Package installation failed" >&2
        exit 1
    }
}

# Truecolor configuration
configure_truecolor() {
    debug_message "Configuring terminal display..."
    
    case $ENV_TYPE in
        "termux")
            mkdir -p ~/.termux
            if ! grep -q "termux-transient-keys" ~/.termux/termux.properties 2>/dev/null; then
                echo "termux-transient-keys = enter,arrow" >> ~/.termux/termux.properties
            fi
            termux-reload-settings
            ;;
    esac

    # Common truecolor config
    if ! grep -q "COLORTERM=truecolor" ~/.zshrc 2>/dev/null; then
        echo "export COLORTERM=truecolor" >> ~/.zshrc
    fi
    if ! grep -q "TERM=xterm-256color" ~/.zshrc 2>/dev/null; then
        echo "export TERM=xterm-256color" >> ~/.zshrc
    fi
}

# Zsh setup
setup_zsh() {
    debug_message "Configuring Zsh environment..."
    
    # Install Oh My Zsh
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
        echo "Error: Oh My Zsh installation failed" >&2
        exit 1
    }

    # Set Zsh as default shell
    case $ENV_TYPE in
        "termux")
            chsh -s zsh || {
                echo "Error: Failed to set Zsh as default shell" >&2
                exit 1
            }
            ;;
        "ubuntu_proot")
            sudo chsh -s "$(command -v zsh)" "$(whoami)" || {
                echo "Error: Failed to set Zsh as default shell" >&2
                exit 1
            }
            ;;
    esac
}

# Neovim configuration
configure_neovim() {
    debug_message "Setting up Neovim..."
    NVIM_DIR="$HOME/.config/nvim"
    mkdir -p "$NVIM_DIR"
    
    if [ ! -f "$NVIM_DIR/init.vim" ]; then
        cat > "$NVIM_DIR/init.vim" << 'EOF'
" Plugin management
call plug#begin('~/.local/share/nvim/plugged')
Plug 'preservim/nerdtree'
Plug 'itchyny/lightline.vim'
Plug 'morhetz/gruvbox'
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'Yggdroot/indentLine'
call plug#end()

" Core configuration
set termguicolors
colorscheme gruvbox
set background=dark

" Plugin configs
let g:indentLine_char = '│'
lua << END
require'nvim-treesitter.configs'.setup {
  highlight = { enable = true },
  indent = { enable = true }
}
END

set tabstop=2 shiftwidth=2 expandtab
set number cursorline
nnoremap <C-n> :NERDTreeToggle<CR>
EOF
    fi
}

# Neovim plugin installation
install_neovim_plugins() {
    debug_message "Installing Neovim plugins..."
    nvim --headless +PlugInstall +qa 2>/dev/null || {
        echo "Error: Plugin installation failed" >&2
        exit 1
    }
}

# Verification
verify_installation() {
    debug_message "Verifying installations..."
    echo -e "\n\033[1;32mInstallation complete!\033[0m"
    
    echo -e "\nVersions:"
    command -v git >/dev/null && git --version
    command -v node >/dev/null && node --version
    command -v nvim >/dev/null && nvim --version | head -n1
    
    debug_message "Testing truecolor support..."
    curl -s https://gist.githubusercontent.com/lifepillar/09a44b8cf0f9397465614e622979107f/raw/24-bit-color.sh | bash
}

# Main function
main() {
    debug_message "Starting installation process..."
    ENV_TYPE=$(detect_environment)
    debug_message "Detected environment: $ENV_TYPE"
    
    # Initialize package manager
    setup_package_manager
    
    # Update packages
    debug_message "Updating package lists..."
    $UPDATE_CMD || {
        echo "Error: Failed to update packages" >&2
        exit 1
    }
    
    install_core_packages
    configure_truecolor
    setup_zsh
    configure_neovim
    install_neovim_plugins
    verify_installation

    echo -e "\n\033[1;33mNext steps:\033[0m"
    case $ENV_TYPE in
        "termux")
            echo "1. Restart Termux session"
            echo "2. Run: nvim"
            echo "3. Access Ubuntu: proot-distro login ubuntu"
            ;;
        "ubuntu_proot")
            echo "1. Restart your shell"
            echo "2. Run: nvim"
            ;;
    esac
}

# Start main process
main
