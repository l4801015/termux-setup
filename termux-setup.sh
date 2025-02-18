#!/bin/bash
set -e

# Redirect stdout to a log file and stderr to a separate log file
exec > >(tee -a setup_output.log) 2> >(tee -a setup_errors.log >&2)

# Function to print debug messages with timestamps and colors
debug_message() {
    # Define colors using ANSI escape codes
    local GREEN='\033[0;32m'  # Green text
    local YELLOW='\033[1;33m' # Bold yellow text
    local RESET='\033[0m'     # Reset to default terminal color

    # Print the message with a timestamp and color
    echo -e "${GREEN}[${YELLOW}$(date +"%Y-%m-%d %H:%M:%S")${GREEN}] ${RESET}$1"
}

# Core Installation Functions
install_termux_core() {
    debug_message "Installing Termux core packages..."
    pkg install -y git nodejs curl wget openssh zsh neovim ncurses-utils clang make proot proot-distro || {
        echo "Error: Termux core installation failed" >&2
        exit 1
    }
}

install_ubuntu_core() {
    debug_message "Installing Ubuntu core packages..."
    apt update && apt install -y git nodejs curl wget openssh-client zsh neovim ncurses-base clang make || {
        echo "Error: Ubuntu core installation failed" >&2
        exit 1
    }
}

# Function to install Ubuntu via proot-distro
install_ubuntu() {
    debug_message "Checking Ubuntu installation status..."

    # Robust check using installed rootfs directory
    if [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu" ]; then
        debug_message "Ubuntu rootfs detected. Installation exists."
        return 0
    fi

    debug_message "Starting Ubuntu installation..."

    # Install with error pattern matching
    if ! proot-distro install ubuntu 2>&1 | tee -a setup_errors.log; then
        if grep -q "already installed" setup_errors.log; then
            debug_message "Ubuntu already installed (hidden detection). Continuing..."
            return 0
        else
            echo "Error: Critical failure during Ubuntu installation" >&2
            exit 1
        fi
    fi

    debug_message "Ubuntu installed successfully."
}

# Function to configure truecolor support in Termux
configure_truecolor() {
    debug_message "Starting configuration of truecolor support..."
    mkdir -p ~/.termux || {
        echo "Error: Failed to create ~/.termux directory." >&2
        exit 1
    }
    echo "termux-transient-keys = enter,arrow" > ~/.termux/termux.properties || {
        echo "Error: Failed to write to ~/.termux/termux.properties." >&2
        exit 1
    }
    echo "export COLORTERM=truecolor" >> ~/.bashrc || {
        echo "Error: Failed to update ~/.bashrc." >&2
        exit 1
    }
    echo "export TERM=xterm-256color" >> ~/.bashrc || {
        echo "Error: Failed to update ~/.bashrc." >&2
        exit 1
    }
    termux-reload-settings || {
        echo "Error: Failed to reload Termux settings." >&2
        exit 1
    }
    debug_message "Finished configuration of truecolor support."
}

setup_zsh() {
    debug_message "Starting Zsh setup..."

    # Check if Zsh is installed
    if command -v zsh >/dev/null 2>&1; then
        echo "Zsh is already installed. Skipping Zsh installation..."
    else
        # Install Zsh
        debug_message "Installing Zsh..."
        pkg install -y zsh || {
            echo "Error: Failed to install Zsh." >&2
            exit 1
        }
    fi

    # Check if Oh My Zsh is installed
    OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
    if [ -d "$OH_MY_ZSH_DIR" ]; then
        echo "Oh My Zsh is already installed. Skipping Oh My Zsh installation..."
    else
        # Install Oh My Zsh without changing the default shell or running Zsh immediately
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
            echo "Error: Failed to install Oh My Zsh." >&2
            exit 1
        }
    fi

    # Update Zsh theme safely
    sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="af-magic"/' ~/.zshrc || {
        echo "Error: Failed to update Zsh theme in ~/.zshrc." >&2
        exit 1
    }

    # Ensure TERM variable is set without duplication
    grep -qxF 'export TERM=xterm-256color' ~/.zshrc || echo 'export TERM=xterm-256color' >> ~/.zshrc || {
        echo "Error: Failed to update ~/.zshrc." >&2
        exit 1
    }

    # Set Zsh as the default shell manually in Termux
    echo "exec zsh" >> ~/.profile || {
        echo "Error: Failed to set Zsh as default shell in ~/.profile." >&2
        exit 1
    }

    debug_message "Finished Zsh setup."
}


# Function to install vim-plug for Neovim
install_vim_plug() {
    debug_message "Starting installation of vim-plug..."
    VIM_PLUG_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"
    curl -fLo "$VIM_PLUG_PATH" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim || {
        echo "Error: Failed to install vim-plug." >&2
        exit 1
    }
    debug_message "Finished installation of vim-plug."
}

# Function to create Neovim configuration
configure_neovim() {
    debug_message "Starting Neovim configuration..."
    NVIM_DIR="$HOME/.config/nvim"
    mkdir -p "$NVIM_DIR" || {
        echo "Error: Failed to create Neovim config directory." >&2
        exit 1
    }

    cat > "$NVIM_DIR/init.vim" << 'EOF'
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
let g:indentLine_char = '│'      " Use Unicode vertical bar
let g:indentLine_color_term = 239 " Dark gray color
" Treesitter configuration
lua << END
require'nvim-treesitter.configs'.setup {
  ensure_installed = {'javascript', 'typescript', 'lua', 'python', 'bash', 'json'},
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
  indent = {
    enable = true
  }
}
END
" Truecolor configuration
set termguicolors
let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
" Core editor settings
set nocompatible
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set nobackup
set nowritebackup
set noswapfile
set smartindent
set cursorline
set scrolloff=8
set laststatus=2
set number
" NERDTree configuration
nnoremap <leader>n :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <C-f> :NERDTreeFind<CR>
" Lightline configuration
let g:lightline = {
      \ 'colorscheme': 'gruvbox',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'gitbranch', 'readonly', 'filename', 'modified' ] ]
      \ },
      \ }
syntax on
EOF
    debug_message "Finished Neovim configuration."
}

# Function to install Neovim plugins
install_neovim_plugins() {
    debug_message "Starting installation of Neovim plugins..."
    nvim --headless +PlugInstall +qa 2>/dev/null || {
        echo "Error: Failed to install Neovim plugins." >&2
        exit 1
    }
    debug_message "Finished installation of Neovim plugins."
}

# Function to compile Treesitter parsers
compile_treesitter_parsers() {
    debug_message "Initializing Tree-sitter environment..."

    # First ensure parsers are available through health check
    if nvim --headless -c "checkhealth treesitter" -c "qall" 2>/dev/null | grep -q "ERROR"; then
        debug_message "Found Tree-sitter initialization issues, fixing..."
        nvim --headless -c "TSUpdateSync" -c "qall" || {
            echo "Error: Critical Tree-sitter initialization failed" >&2
            exit 1
        }
    fi

    debug_message "Verifying Tree-sitter parsers..."

    # List of essential parsers (space-separated)
    local parsers=("javascript" "typescript" "lua" "python" "bash" "json")
    local missing=()

    # Check using Neovim's internal parser list
    for parser in "${parsers[@]}"; do
        if ! nvim --headless -c "lua if not vim.treesitter.language.get('$parser') then os.exit(1) end" -c "qall" 2>/dev/null; then
            missing+=("$parser")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        debug_message "All parsers already active. Skipping compilation."
        return 0
    fi

    debug_message "Installing missing parsers: ${missing[*]}..."

    # Install with explicit parser sync
    nvim --headless -c "TSInstallSync ${missing[*]}" -c "qall" || {
        echo "Error: Failed to install parsers: ${missing[*]}" >&2
        echo "Check available parsers with: nvim --headless -c 'TSInstallInfo' -c 'qall'" >&2
        exit 1
    }

    debug_message "Tree-sitter compilation verified."
}

# Function to verify installations
verify_installations() {
    debug_message "Verifying installations..."
    echo -e "\n\033[1;32mInstallation complete!\033[0m"
    echo -e "\nVersions:"
    git --version | head -n 1 || {
        echo "Error: Git version check failed." >&2
        exit 1
    }
    node --version || {
        echo "Error: Node.js version check failed." >&2
        exit 1
    }
    nvim --version | head -n 1 || {
        echo "Error: Neovim version check failed." >&2
        exit 1
    }
    zsh --version || {
        echo "Error: Zsh version check failed." >&2
        exit 1
    }
    echo -e "\n\033[38;2;255;100;100mTruecolor test:\033[0m"
    curl -s https://gist.githubusercontent.com/lifepillar/09a44b8cf0f9397465614e622979107f/raw/24-bit-color.sh | bash || {
        echo "Error: Truecolor test failed." >&2
        exit 1
    }
    debug_message "Finished verification."
}

# Function to display next steps
display_next_steps() {
    debug_message "Displaying next steps..."
    echo -e "\n\033[1;33mNext steps:\033[0m"
    echo "1. Restart Termux session to activate Zsh"
    echo "2. Start Neovim: nvim"
    debug_message "Finished displaying next steps."
}

# Shared Post-Installation Workflow
common_post_installation() {
    configure_truecolor
    setup_zsh
    install_vim_plug
    configure_neovim

    debug_message "Installing Neovim plugins and parsers..."
    install_neovim_plugins
    compile_treesitter_parsers

    verify_installations
    display_next_steps
}

# Main Execution Flow
main() {
    if [ -d "$PREFIX" ] && [ -d "/data/data/com.termux/files/usr" ]; then
        debug_message "Starting Termux environment setup"
        install_termux_core
        install_ubuntu  # Proot Ubuntu installation
        common_post_installation

    elif grep -q "Ubuntu" /etc/os-release; then
        debug_message "Starting Ubuntu environment setup"
        install_ubuntu_core
        common_post_installation

    else
        echo "Error: Unsupported environment" >&2
        exit 1
    fi
    debug_message "Setup completed successfully"
}

# Execute the main function
main