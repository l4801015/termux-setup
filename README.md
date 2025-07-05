```
bash -c 'set -e; exec > >(tee -a setup_output.log) 2> >(tee -a setup_errors.log >&2); \
debug_message() { local GREEN="\033[0;32m"; local YELLOW="\033[1;33m"; local RESET="\033[0m"; echo -e "${GREEN}[${YELLOW}$(date +"%Y-%m-%d %H:%M:%S")${GREEN}] ${RESET}$1"; }; \
check_storage() { [ -d ~/storage/downloads ] && [ -w ~/storage/downloads ]; }; \
setup_storage() { local timeout=60; local start_time=$(date +%s); debug_message "Setting up storage..."; termux-setup-storage; \
while true; do local current_time=$(date +%s); local elapsed=$((current_time - start_time)); \
if [ $elapsed -ge $timeout ]; then debug_message "Timeout reached while waiting for storage setup."; echo "Error: Storage setup timed out." >&2; exit 1; fi; \
if check_storage; then debug_message "Storage setup completed successfully."; return 0; fi; \
local time_left=$((timeout - elapsed)); printf "\rWaiting for storage setup... Time left: %02d:%02d" $((time_left/60)) $((time_left%60)); sleep 1; done; }; \
install_termux_core() { debug_message "Installing Termux core packages..."; \
pkg install -y git nodejs curl wget openssh zsh neovim ncurses-utils clang make || { \
echo "Error: Termux core installation failed" >&2; exit 1; }; }; \
configure_truecolor() { debug_message "Starting configuration of truecolor support..."; \
mkdir -p ~/.termux || { echo "Error: Failed to create ~/.termux directory." >&2; exit 1; }; \
echo "termux-transient-keys = enter,arrow" > ~/.termux/termux.properties || { \
echo "Error: Failed to write to ~/.termux/termux.properties." >&2; exit 1; }; \
echo "export COLORTERM=truecolor" >> ~/.bashrc || { echo "Error: Failed to update ~/.bashrc." >&2; exit 1; }; \
echo "export TERM=xterm-256color" >> ~/.bashrc || { echo "Error: Failed to update ~/.bashrc." >&2; exit 1; }; \
termux-reload-settings || { echo "Error: Failed to reload Termux settings." >&2; exit 1; }; \
debug_message "Finished configuration of truecolor support."; }; \
setup_zsh() { debug_message "Starting Zsh setup..."; \
if command -v zsh >/dev/null 2>&1; then echo "Zsh is already installed. Skipping Zsh installation..."; \
else debug_message "Installing Zsh..."; pkg install -y zsh || { echo "Error: Failed to install Zsh in Termux." >&2; exit 1; }; fi; \
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"; \
if [ -d "$OH_MY_ZSH_DIR" ]; then echo "Oh My Zsh is already installed. Skipping Oh My Zsh installation..."; \
else RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || { \
echo "Error: Failed to install Oh My Zsh." >&2; exit 1; }; fi; \
sed -i "s/^ZSH_THEME=\".*\"/ZSH_THEME=\"af-magic\"/" ~/.zshrc || { \
echo "Error: Failed to update Zsh theme in ~/.zshrc." >&2; exit 1; }; \
# ADDED PLUGINS CONFIGURATION START
debug_message "Configuring Zsh plugins..."; \
OH_MY_ZSH_PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"; \
mkdir -p "$OH_MY_ZSH_PLUGINS_DIR"; \
git clone https://github.com/zsh-users/zsh-autosuggestions.git "$OH_MY_ZSH_PLUGINS_DIR/zsh-autosuggestions" 2>/dev/null || true; \
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$OH_MY_ZSH_PLUGINS_DIR/zsh-syntax-highlighting" 2>/dev/null || true; \
sed -i "s/^plugins=(.*)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/" ~/.zshrc || { \
echo "Error: Failed to add plugins to ~/.zshrc." >&2; exit 1; }; \
# IMPORTANT: Load syntax highlighting AFTER autosuggestions
echo "source $OH_MY_ZSH_PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc || { \
echo "Error: Failed to load syntax highlighting." >&2; exit 1; }; \
# ADDED PLUGINS CONFIGURATION END
grep -qxF "export TERM=xterm-256color" ~/.zshrc || echo "export TERM=xterm-256color" >> ~/.zshrc || { \
echo "Error: Failed to update ~/.zshrc." >&2; exit 1; }; \
echo "exec zsh" >> ~/.profile || { echo "Error: Failed to set Zsh as default shell in ~/.profile." >&2; exit 1; }; \
debug_message "Finished Zsh setup."; }; \
install_vim_plug() { debug_message "Starting installation of vim-plug..."; \
VIM_PLUG_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"; \
curl -fLo "$VIM_PLUG_PATH" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim || { \
echo "Error: Failed to install vim-plug." >&2; exit 1; }; \
debug_message "Finished installation of vim-plug."; }; \
configure_neovim() { debug_message "Starting Neovim configuration..."; \
NVIM_DIR="$HOME/.config/nvim"; mkdir -p "$NVIM_DIR" || { \
echo "Error: Failed to create Neovim config directory." >&2; exit 1; }; \
printf "%s\n" \
"call plug#begin('\''~/.local/share/nvim/plugged'\'')" \
"Plug '\''preservim/nerdtree'\''" \
"Plug '\''itchyny/lightline.vim'\''" \
"Plug '\''morhetz/gruvbox'\''" \
"Plug '\''Yggdroot/indentLine'\''" \
"call plug#end()" \
"try" \
" colorscheme gruvbox" \
"catch /^Vim\\%((\\a\\+\\))\\=:E185/" \
"endtry" \
"set background=dark" \
"let g:gruvbox_contrast_dark = '\''medium'\''" \
"let g:gruvbox_italic = 1" \
"let g:indentLine_char = '\''│'\''" \
"let g:indentLine_color_term = 239" \
"set termguicolors" \
"let &t_8f = \"\\<Esc>[38;2;%lu;%lu;%lum\"" \
"let &t_8b = \"\\<Esc>[48;2;%lu;%lu;%lum\"" \
"set nocompatible" \
"set tabstop=2" \
"set shiftwidth=2" \
"set softtabstop=2" \
"set expandtab" \
"set nobackup" \
"set nowritebackup" \
"set noswapfile" \
"set smartindent" \
"set cursorline" \
"set scrolloff=8" \
"set laststatus=2" \
"set number" \
"nnoremap <leader>n :NERDTreeFocus<CR>" \
"nnoremap <C-n> :NERDTree<CR>" \
"nnoremap <C-t> :NERDTreeToggle<CR>" \
"nnoremap <C-f> :NERDTreeFind<CR>" \
"let g:lightline = { \"colorscheme\": \"gruvbox\", \"active\": { \"left\": [ [ \"mode\", \"paste\" ], [ \"gitbranch\", \"readonly\", \"filename\", \"modified\" ] ] } }" \
"syntax on" > "$NVIM_DIR/init.vim"; \
debug_message "Finished Neovim configuration."; }; \
install_neovim_plugins() { debug_message "Starting installation of Neovim plugins..."; \
nvim --headless -c "PlugInstall" -c "qa" || { echo "Error: Failed to install Neovim plugins." >&2; exit 1; }; \
debug_message "Finished installation of Neovim plugins."; }; \
verify_installations() { debug_message "Verifying installations..."; \
echo -e "\n\033[1;32mInstallation complete!\033[0m"; \
echo -e "\nVersions:"; \
git --version | head -n 1 || { echo "Error: Git version check failed." >&2; exit 1; }; \
node --version || { echo "Error: Node.js version check failed." >&2; exit 1; }; \
nvim --version | head -n 1 || { echo "Error: Neovim version check failed." >&2; exit 1; }; \
zsh --version || { echo "Error: Zsh version check failed." >&2; exit 1; }; \
echo -e "\n\033[38;2;255;100;100mTruecolor test:\033[0m"; \
curl -s https://gist.githubusercontent.com/lifepillar/09a44b8cf0f9397465614e622979107f/raw/24-bit-color.sh | bash || { \
echo "Error: Truecolor test failed." >&2; exit 1; }; \
debug_message "Finished verification."; }; \
display_next_steps() { debug_message "Displaying next steps..."; \
echo -e "\n\033[1;33mNext steps:\033[0m"; \
echo "1. Restart Termux session to activate Zsh"; \
echo "2. Start Neovim: nvim"; \
debug_message "Finished displaying next steps."; }; \
common_post_installation() { configure_truecolor; setup_zsh; install_vim_plug; configure_neovim; \
install_neovim_plugins; verify_installations; display_next_steps; }; \
main() { if [ -d "$PREFIX" ] && [ -d "/data/data/com.termux/files/usr" ]; then \
debug_message "Starting Termux environment setup"; \
if check_storage; then debug_message "Storage is already set up."; else setup_storage; fi; \
install_termux_core; common_post_installation; debug_message "Setup completed successfully"; \
else echo "Error: This script is intended for Termux environment only." >&2; exit 1; fi; }; \
main'
```