#!/usr/bin/env bash
# QDeck: 08-zsh.sh: Zsh installation, plugins, configuration, and default shell bootstrap
set -Eeuo pipefail

# Run as your normal user, not direct root
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "Error: Run this script as your normal user (not with sudo or root)." >&2
  exit 1
fi

if [[ ! -f /etc/arch-release ]] && ! command -v pacman &>/dev/null; then
  echo "Error: This script is intended for Arch Linux." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$HOME/.local/bin/zsh"
ZSHRC="$HOME/.zshrc"
ZSH_PATH="/usr/bin/zsh"

echo "==> [QDeck:08-zsh] Auditing and configuring Zsh environment..."

# 1. Install required packages
echo "    Ensuring Zsh and plugin packages are installed..."
ZSH_PKGS=(zsh zoxide zsh-autosuggestions zsh-syntax-highlighting)
MISSING_PKGS=()
for pkg in "${ZSH_PKGS[@]}"; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    MISSING_PKGS+=("$pkg")
  fi
done

if ((${#MISSING_PKGS[@]} > 0)); then
  echo "    Installing missing packages: ${MISSING_PKGS[*]}"
  sudo pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
else
  echo "    All required Zsh packages and plugins are installed."
fi

# 2. Validate Zsh executable & /etc/shells registration
if [[ ! -x "$ZSH_PATH" ]]; then
  echo "Error: Zsh binary not found at $ZSH_PATH." >&2
  exit 1
fi

if ! grep -Fxq "$ZSH_PATH" /etc/shells; then
  echo "==> Registering $ZSH_PATH in /etc/shells..."
  echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

# 3. Ensure custom aliases and functions exist in $CONFIG_DIR
if [[ ! -f "$CONFIG_DIR/aliases.zsh" || ! -f "$CONFIG_DIR/functions.zsh" ]]; then
  echo "==> Deploying zsh configuration files to $CONFIG_DIR..."
  mkdir -p "$CONFIG_DIR"
  if [[ -d "$REPO_ROOT/zsh" ]]; then
    cp -rf "$REPO_ROOT/zsh/." "$CONFIG_DIR/"
  fi
  chmod 644 "$CONFIG_DIR"/* 2>/dev/null || true
fi

# Validate custom configuration files
for file in aliases.zsh functions.zsh; do
  if [[ ! -f "$CONFIG_DIR/$file" ]]; then
    echo "Error: Missing $CONFIG_DIR/$file" >&2
    exit 1
  fi
done

# 4. Back up existing .zshrc
if [[ -e "$ZSHRC" ]]; then
  BACKUP="$ZSHRC.backup.$(date +%Y%m%d-%H%M%S)"
  cp -p -- "$ZSHRC" "$BACKUP"
  echo "    Backup created: $BACKUP"
fi

# 5. Generate minimal .zshrc
echo "    Generating minimal $ZSHRC..."
cat > "$ZSHRC" <<'EOF'
# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
setopt CORRECT

# Completion
autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Custom aliases and functions
ZSH_CONFIG_DIR="$HOME/.local/bin/zsh"

source "$ZSH_CONFIG_DIR/aliases.zsh"
source "$ZSH_CONFIG_DIR/functions.zsh"

# Zoxide
eval "$(zoxide init zsh)"

# Autosuggestions
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Syntax highlighting (keep near the end)
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Minimal prompt
PROMPT='%F{green}>%f '
EOF

# 6. Set default login shell
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"

if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
  echo "==> Setting default login shell to $ZSH_PATH..."
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo usermod -s "$ZSH_PATH" "$USER" || sudo chsh -s "$ZSH_PATH" "$USER" || chsh -s "$ZSH_PATH"
  else
    chsh -s "$ZSH_PATH"
  fi
  echo "    Default shell changed to Zsh."
else
  echo "    Zsh is already the default shell."
fi

echo ""
echo "==> [QDeck:08-zsh] Zsh setup completed."
echo "    Config: $ZSHRC"
echo "    Aliases: $CONFIG_DIR/aliases.zsh"
echo "    Functions: $CONFIG_DIR/functions.zsh"
echo "    Prompt: >"
echo ""
echo "Apply now with: exec zsh"
exit 0
