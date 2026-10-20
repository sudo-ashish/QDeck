#!/usr/bin/env bash
# QDeck: 05-nvim.sh: Installs Neovim, bootstraps LazyVim/lazy.nvim, and executes headless plugin installation for QDeck
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NVIM_DIR="$HOME/.config/nvim"

echo "==> [QDeck:05-nvim] Installing Neovim and build dependencies for QDeck..."

NVIM_PACKAGES=(
  neovim
  gcc
  make
  ripgrep
  fd
  git
  tar
  unzip
  curl
)

MISSING_NVIM=()
for pkg in "${NVIM_PACKAGES[@]}"; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    MISSING_NVIM+=("$pkg")
  fi
done

if ((${#MISSING_NVIM[@]} > 0)); then
  sudo pacman -S --needed --noconfirm "${MISSING_NVIM[@]}"
fi

# 1. Neovim configuration deployment
mkdir -p "$HOME/.config"

if [[ -d "$REPO_ROOT/nvim" && -n "$(ls -A "$REPO_ROOT/nvim" 2>/dev/null)" ]]; then
  echo "    Deploying custom Neovim configuration from repository..."
  mkdir -p "$NVIM_DIR"
  cp -rf "$REPO_ROOT/nvim/." "$NVIM_DIR/"
elif [[ ! -f "$NVIM_DIR/init.lua" ]]; then
  echo "    Cloning LazyVim starter config..."
  git clone --depth=1 https://github.com/LazyVim/starter "$NVIM_DIR" 2>/dev/null || true
  rm -rf "$NVIM_DIR/.git"
else
  echo "    Existing Neovim configuration preserved."
fi

# 2. Bootstrap lazy.nvim plugin manager if not present
LAZY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim"
if [[ ! -d "$LAZY_DIR" ]]; then
  echo "    Bootstrapping lazy.nvim plugin manager..."
  mkdir -p "$(dirname "$LAZY_DIR")"
  git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git "$LAZY_DIR" 2>/dev/null || true
fi

# 3. Headless plugin sync to preload all LazyVim plugins and theme colorschemes
if command -v nvim &>/dev/null && [[ -f "$NVIM_DIR/init.lua" ]]; then
  echo "==> [QDeck:05-nvim] Running headless Lazy.nvim sync to preload all plugins..."
  timeout 120 nvim --headless "+Lazy! sync" +qa 2>/dev/null || \
  timeout 120 nvim --headless "+Lazy! restore" +qa 2>/dev/null || true
fi

echo "==> [QDeck:05-nvim] Neovim setup completed for QDeck."
exit 0
