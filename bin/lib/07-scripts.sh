#!/usr/bin/env bash
# QDeck: 07-scripts.sh: Installs QDeck helper scripts to ~/.local/bin and verifies PATH idempotency
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_BIN_DIR="$HOME/.local/bin"

echo "==> [QDeck:07-scripts] Installing QDeck system utilities and scripts to $TARGET_BIN_DIR..."
mkdir -p "$TARGET_BIN_DIR"

installed_count=0
for script in "$REPO_ROOT/bin"/*; do
  [[ -f "$script" ]] || continue
  base="$(basename "$script")"
  
  # Skip installer orchestrators and subdirectories
  [[ "$base" == "install.sh" ]] && continue
  
  rm -f "$TARGET_BIN_DIR/$base"
  cp -f "$script" "$TARGET_BIN_DIR/$base"
  chmod +x "$TARGET_BIN_DIR/$base"
  echo "    Installed: $base"
  ((installed_count++)) || true
done

echo "    Successfully deployed $installed_count QDeck scripts to $TARGET_BIN_DIR."

# Register system-wide symlinks in /usr/local/bin if administrative privileges exist
if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  echo "==> [QDeck:07-scripts] Registering system-wide symlinks in /usr/local/bin..."
  sudo mkdir -p /usr/local/bin
  for script in "$REPO_ROOT/bin"/*; do
    [[ -f "$script" ]] || continue
    base="$(basename "$script")"
    [[ "$base" == "install.sh" ]] && continue
    sudo ln -sf "$TARGET_BIN_DIR/$base" "/usr/local/bin/$base" 2>/dev/null || true
  done
  
  # Register profile.d drop-in for universal login environment PATH
  sudo tee /etc/profile.d/qdeck-path.sh >/dev/null <<'EOF'
# QDeck universal user PATH configuration
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
EOF
  sudo chmod 644 /etc/profile.d/qdeck-path.sh 2>/dev/null || true
fi

# Verify and ensure ~/.local/bin is in PATH for bash, zsh, and profile
echo "==> [QDeck:07-scripts] Checking shell PATH configuration..."

PATH_SNIPPET='
# QDeck CLI & helper scripts
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi'

for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  if [[ -f "$rc" ]]; then
    if ! grep -q 'HOME/.local/bin' "$rc"; then
      printf '%s\n' "$PATH_SNIPPET" >> "$rc"
      echo "    Added ~/.local/bin to PATH in $rc"
    else
      echo "    ~/.local/bin already present in $rc"
    fi
  fi
done

# ------------------------------------------------------------------------------
# Copy zsh configuration folder to ~/.local/bin/zsh
# ------------------------------------------------------------------------------
copy_zsh() {
  local zsh_src="$REPO_ROOT/zsh"
  local zsh_target="$TARGET_BIN_DIR/zsh"

  if [[ ! -d "$zsh_src" && -d "$REPO_ROOT/dotfiles/zsh" ]]; then
    zsh_src="$REPO_ROOT/dotfiles/zsh"
  fi

  if [[ -d "$zsh_src" ]]; then
    echo "==> [QDeck:07-scripts] Copying zsh folder to $zsh_target..."
    mkdir -p "$zsh_target"
    cp -rf "$zsh_src/." "$zsh_target/"
    find "$zsh_target" -type f -exec chmod 644 {} + 2>/dev/null || true
    find "$zsh_target" -type d -exec chmod 755 {} + 2>/dev/null || true
    echo "    Successfully deployed zsh folder to $zsh_target."
  else
    echo "    Warning: zsh folder not found at $zsh_src" >&2
  fi
}

copy_zsh

# Ensure ~/.zshrc sources QDeck zsh configurations if zsh is used
if [[ -f "$HOME/.zshrc" ]]; then
  if ! grep -q 'QDeck Zsh Configuration' "$HOME/.zshrc" && ! grep -q 'ZSH_CONFIG_DIR' "$HOME/.zshrc"; then
    cat <<'EOF' >> "$HOME/.zshrc"

# QDeck Zsh Configuration
[[ -f "$HOME/.local/bin/zsh/aliases.zsh" ]] && source "$HOME/.local/bin/zsh/aliases.zsh"
[[ -f "$HOME/.local/bin/zsh/functions.zsh" ]] && source "$HOME/.local/bin/zsh/functions.zsh"
[[ -f "$HOME/.config/zsh/aliases.zsh" ]] && source "$HOME/.config/zsh/aliases.zsh"
[[ -f "$HOME/.config/zsh/functions.zsh" ]] && source "$HOME/.config/zsh/functions.zsh"
EOF
    echo "    Integrated QDeck aliases and functions into ~/.zshrc"
  fi
fi

# Ensure current execution environment has updated PATH
export PATH="$TARGET_BIN_DIR:$PATH"

# Run initial theme switcher setup if available
if command -v qdeck-theme-switch &>/dev/null; then
  echo "==> [QDeck:07-scripts] Running initial theme setup via qdeck-theme-switch..."
  qdeck-theme-switch setup 2>/dev/null || true
fi

echo "==> [QDeck:07-scripts] Scripts deployment and PATH verification complete for QDeck."
exit 0
