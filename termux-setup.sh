#!/bin/bash
set -e

# Redirect stdout and stderr to log files
exec > >(tee -a setup_output.log) 2> >(tee -a setup_errors.log >&2)

# Function to print debug messages with timestamps and colors
debug_message() {
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RESET='\033[0m'
    echo -e "${GREEN}[${YELLOW}$(date +"%Y-%m-%d %H:%M:%S")${GREEN}] ${RESET}$1"
}

# Function to update packages and install core dependencies
install_core_packages() {
    debug_message "Updating package repositories..."
    pkg update -y || {
        echo "Error: Failed to update packages." >&2
        exit 1
    }

    debug_message "Installing core packages..."
    pkg install -y git nodejs curl wget openssh zsh neovim ncurses-utils \
        clang make proot proot-distro termux-tools || {
        echo "Error: Core package installation failed." >&2
        exit 1
    }
}

# Function to install Ubuntu via proot-distro
install_ubuntu() {
    debug_message "Installing Ubuntu distribution..."
    proot-distro install ubuntu || {
        echo "Error: Ubuntu installation failed." >&2
        exit 1
    }
}

# Function to configure terminal truecolor support
configure_truecolor() {
    debug_message "Configuring truecolor support..."
    mkdir -p ~/.termux || exit 1

    # Configure transient keys
    if ! grep -q "termux-transient-keys" ~/.termux/termux.properties 2>/dev/null; then
        echo "termux-transient-keys = enter,arrow" >> ~/.termux/termux.properties
    fi

    # Configure truecolor in Zsh (after Oh My Zsh installation)
    local ZSHRC="$HOME/.zshrc"
    if [ -f "$ZSHRC" ]; then
        for var in "COLORTERM=truecolor" "TERM=xterm-256color"; do
            if ! grep -q "$var" "$ZSHRC"; then
                echo "export $var" >> "$ZSHRC"
            fi
        done
    fi

    termux-reload-settings || {
        echo "Error: Failed to apply terminal settings." >&2
        exit 1
    }
}

# Function to set up Zsh and Oh My Zsh
setup_zsh() {
    debug_message "Configuring Zsh environment..."
    
    # Install Oh My Zsh without auto-chsh
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
        echo "Error: Oh My Zsh installation failed." >&2
        exit 1
    }

    # Set Zsh as default shell
    if ! chsh -s zsh; then
        echo "Error: Failed to set Zsh as default shell. Try:" >&2
        echo "1. Run 'termux-reload-settings'" >&2
        echo "2. Restart Termux session" >&2
        exit 1
    fi

    debug_message "Zsh configuration completed."
}

# Function to install vim-plug plugin manager
install_vim_plug() {
    debug_message "Installing vim-plug..."
    VIM_PLUG_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"
    if [ ! -f "$VIM_PLUG_PATH" ]; then
        curl -fLo "$VIM_PLUG_PATH" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim || {
            echo "Error: vim-plug installation failed." >&2
            exit 1
        }
    fi
}

# Function to configure Neovim
configure_neovim() {
    debug_message "Setting up Neovim..."
    NVIM_DIR="$HOME/.config/nvim"
    mkdir -p "$NVIM_DIR" || exit 1

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
let g:gruvbox_contrast_dark = 'medium'
let g:gruvbox_italic = 1

" Plugin configurations
let g:indentLine_char = '│'
let g:indentLine_color_term = 239

lua << END
require'nvim-treesitter.configs'.setup {
  ensure_installed = {'javascript', 'typescript', 'lua', 'python', 'bash', 'json'},
  highlight = { enable = true },
  indent = { enable = true }
}
END

set tabstop=2 shiftwidth=2 expandtab
set number cursorline scrolloff=8
nnoremap <C-n> :NERDTreeToggle<CR>
EOF
    fi
}

# Function to install Neovim plugins
install_neovim_plugins() {
    debug_message "Installing Neovim plugins..."
    if nvim --headless +PlugInstall +qa 2>/dev/null; then
        debug_message "Plugin installation completed."
    else
        echo "Error: Plugin installation failed." >&2
        exit 1
    fi
}

# Verification function
verify_installation() {
    debug_message "Verifying installations..."
    echo -e "\n\033[1;32mInstallation complete!\033[0m"
    echo -e "Versions:"
    command -v git >/dev/null && git --version
    command -v node >/dev/null && node --version
    command -v nvim >/dev/null && nvim --version | head -n1
    
    debug_message "Testing truecolor support..."
    if curl -s https://gist.githubusercontent.com/lifepillar/09a44b8cf0f9397465614e622979107f/raw/24-bit-color.sh | bash; then
        debug_message "Truecolor test completed."
    else
        echo "Warning: Truecolor test failed (network error?)" >&2
    fi
}

# Main execution flow
main() {
    install_core_packages
    install_ubuntu
    setup_zsh
    configure_truecolor
    install_vim_plug
    configure_neovim
    install_neovim_plugins
    verify_installation

    echo -e "\n\033[1;33mNext steps:\033[0m"
    echo "1. Restart Termux session"
    echo "2. Start Neovim: nvim"
    echo "3. Access Ubuntu: proot-distro login ubuntu"
}

main
