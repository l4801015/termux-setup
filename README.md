```
#!/data/data/com.termux/files/usr/bin/bash
# ------------------------------------------------------------------
# Termux full environment bootstrap (Lua / lazy.nvim edition)
# ------------------------------------------------------------------
set -e

# ------------------------------------------------------- helpers
log() {
  local G="\033[0;32m"; local Y="\033[1;33m"; local R="\033[0m"
  echo -e "${G}[${Y}$(date "+%F %T")${G}]${R} $1"
}

wait_storage() {
  [[ -d ~/storage/downloads && -w ~/storage/downloads ]] && return 0
  log "Requesting storage permission…"
  termux-setup-storage
  for i in {1..60}; do
    [[ -d ~/storage/downloads ]] && { log "Storage OK"; return 0; }
    sleep 1
  done
  echo "Storage timeout" >&2; exit 1
}

# ------------------------------------------------------- packages
install_pkgs() {
  log "Updating & installing core packages…"
  pkg upgrade -y
  pkg install -y git nodejs-lts neovim zsh curl wget openssh clang make
}

# ------------------------------------------------------- Neovim (modular)
configure_nvim_lua() {
  log "Writing modular Lua Neovim config…"
  mkdir -p ~/.config/nvim/{lua/{plugins,options},after/plugin}

  # init.lua
  cat > ~/.config/nvim/init.lua <<'EOF'
-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system {
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

-- load the rest of the config
require("options")
require("lazy").setup("plugins")
EOF

  # lua/options.lua
  cat > ~/.config/nvim/lua/options.lua <<'EOF'
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.termguicolors = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.swapfile = false
vim.opt.backup = false
EOF

  # lua/plugins.lua
  cat > ~/.config/nvim/lua/plugins.lua <<'EOF'
return {
  {
    "preservim/nerdtree",
    keys = {
      { "<leader>n", "<cmd>NERDTreeFocus<cr>" },
      { "<C-n>",     "<cmd>NERDTree<cr>" },
      { "<C-t>",     "<cmd>NERDTreeToggle<cr>" },
      { "<C-f>",     "<cmd>NERDTreeFind<cr>" },
    },
  },
  { "itchyny/lightline.vim" },
  {
    "morhetz/gruvbox",
    config = function()
      vim.cmd.colorscheme("gruvbox")
      vim.g.gruvbox_contrast_dark = "medium"
      vim.g.gruvbox_italic = 1
    end,
  },
  {
    "Yggdroot/indentLine",
    config = function()
      vim.g.indentLine_char = "│"
    end,
  },
  { "github/copilot.vim", event = "InsertEnter" },
}
EOF
}

# ------------------------------------------------------- Zsh
setup_omz() {
  log "Installing Oh-My-Zsh…"
  [[ -d ~/.oh-my-zsh ]] || {
    RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  }

  sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="af-magic"/' ~/.zshrc

  for repo in zsh-autosuggestions zsh-syntax-highlighting; do
    [[ -d ~/.oh-my-zsh/custom/plugins/$repo ]] ||
      git clone https://github.com/zsh-users/${repo}.git \
        ~/.oh-my-zsh/custom/plugins/$repo 2>/dev/null || true
  done

  sed -i '/^plugins=(/c\plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' ~/.zshrc

  cat >> ~/.zshrc <<'EOF'

# extras
export TERM=xterm-256color
EOF

  echo 'exec zsh' >> ~/.profile
}

# ------------------------------------------------------- final checks
finish() {
  clear
  echo -e "\n\033[1;32m✅ Setup finished\033[0m\n"
  git --version
  node --version
  nvim --version | head -n1
  zsh --version
  echo
  echo -e "\033[1;33mNext steps:\033[0m"
  echo "1. Restart Termux (or exec zsh)"
  echo "2. Run 'nvim' then ':Copilot setup'"
}

# ------------------------------------------------------- main
main() {
  [[ -n "$PREFIX" ]] || { echo "Run this script only inside Termux." >&2; exit 1; }
  wait_storage
  install_pkgs
  configure_nvim_lua
  setup_omz
  nvim --headless "+Lazy! sync" +qa
  finish
}

main "$@"

```