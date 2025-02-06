#!/bin/bash
set -e

# Function to print debug messages with timestamps
debug_message() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# Function to install core packages
install_core_packages() {
    debug_message "Starting installation of core packages..."
    pkg install -y git nodejs curl wget openssh zsh neovim ncurses-utils clang make proot proot-distro
    debug_message "Finished installation of core packages."
}

# Function to install Ubuntu via proot-distro
install_ubuntu() {
    debug_message "Starting installation of Ubuntu via proot-distro..."
    proot-distro install ubuntu
    debug_message "Finished installation of Ubuntu."
}

# Function to configure truecolor support in Termux
configure_truecolor() {
    debug_message "Starting configuration of truecolor support..."
    mkdir -p ~/.termux
    echo "termux-transient-keys = enter,arrow" > ~/.termux/termux.properties
    echo "export COLORTERM=truecolor" >> ~/.bashrc
    echo "export TERM=xterm-256color" >> ~/.bashrc
    termux-reload-settings
    debug_message "Finished configuration of truecolor support."
}

# Function to set up Zsh and Oh My Zsh
setup_zsh() {
    debug_message "Starting Zsh setup..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="af-magic"/' ~/.zshrc
    echo "export TERM=xterm-256color" >> ~/.zshrc
    chsh -s zsh
    debug_message "Finished Zsh setup."
}

# Function to install vim-plug for Neovim
install_vim_plug() {
    debug_message "Starting installation of vim-plug..."
    VIM_PLUG_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"
    curl -fLo "$VIM_PLUG_PATH" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    debug_message "Finished installation of vim-plug."
}

# Function to create Neovim configuration
configure_neovim() {
    debug_message "Starting Neovim configuration..."
    NVIM_DIR="$HOME/.config/nvim"
    mkdir -p "$NVIM_DIR"

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
    nvim --headless +PlugInstall +qa 2>/dev/null
    debug_message "Finished installation of Neovim plugins."
}

# Function to compile Treesitter parsers
compile_treesitter_parsers() {
    debug_message "Starting compilation of Treesitter parsers..."
    nvim --headless -c "TSInstallSync javascript typescript lua python bash json" -c "qall"
    debug_message "Finished compilation of Treesitter parsers."
}

# Function to verify installations
verify_installations() {
    debug_message "Verifying installations..."
    echo -e "\n\033[1;32mInstallation complete!\033[0m"
    echo -e "\nVersions:"
    git --version | head -n 1
    node --version
    nvim --version | head -n 1
    zsh --version
    echo -e "\n\033[38;2;255;100;100mTruecolor test:\033[0m"
    curl -s https://gist.githubusercontent.com/lifepillar/09a44b8cf0f9397465614e622979107f/raw/24-bit-color.sh | bash
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

# Main function to execute all setup steps
main() {
    install_core_packages
    install_ubuntu
    configure_truecolor
    setup_zsh
    install_vim_plug
    configure_neovim

    # Run Neovim plugin installation and Treesitter compilation in parallel
    debug_message "Running Neovim plugin installation and Treesitter compilation in parallel..."
    install_neovim_plugins &
    PID_PLUGINS=$!
    compile_treesitter_parsers &
    PID_TREESITTER=$!

    # Wait for both processes to complete
    wait $PID_PLUGINS
    debug_message "Neovim plugins process completed."
    wait $PID_TREESITTER
    debug_message "Treesitter compilation process completed."

    verify_installations
    display_next_steps
}

# Execute the main function
main