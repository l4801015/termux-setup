#!/bin/bash
set -e

# Install core utilities with compiler and PRoot packages
echo "Installing core packages..."
pkg install -y git nodejs curl wget openssh zsh neovim ncurses-utils clang make proot proot-distro

# Configure terminal for truecolor
echo "Setting up truecolor support..."
mkdir -p ~/.termux
echo "termux-transient-keys = enter,arrow" > ~/.termux/termux.properties
echo "export COLORTERM=truecolor" >> ~/.bashrc
echo "export TERM=xterm-256color" >> ~/.bashrc
termux-reload-settings

# Setup Zsh and Oh My Zsh
echo "Configuring Zsh environment..."
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="af-magic"/' ~/.zshrc
echo "export TERM=xterm-256color" >> ~/.zshrc
chsh -s zsh

# Configure Neovim properly
echo "Setting up Neovim environment..."
NVIM_DIR="$HOME/.config/nvim"
mkdir -p "$NVIM_DIR"

# Install vim-plug FIRST
echo "Installing vim-plug plugin manager..."
VIM_PLUG_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"
curl -fLo "$VIM_PLUG_PATH" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Create config AFTER plugin manager installation
echo "Creating Neovim config..."
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

# Install plugins AFTER config creation
echo "Installing Neovim plugins..."
nvim --headless +PlugInstall +qa 2>/dev/null

# Install Treesitter parsers LAST
echo "Compiling Treesitter parsers..."
nvim --headless -c "TSInstallSync javascript typescript lua python bash json" -c "qall"

# Verify installations
echo -e "\n\033[1;32mInstallation complete!\033[0m"
echo -e "\nVersions:"
git --version | head -n 1
node --version
nvim --version | head -n 1
zsh --version

echo -e "\n\033[38;2;255;100;100mTruecolor test:\033[0m"
curl -s https://gist.githubusercontent.com/lifepillar/09a44b8cf0f9397465614e622979107f/raw/24-bit-color.sh | bash

echo -e "\n\033[1;33mNext steps:\033[0m"
echo "1. Restart Termux session to activate Zsh"
echo "2. Start Neovim: nvim"