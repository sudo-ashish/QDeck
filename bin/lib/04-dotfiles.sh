#!/usr/bin/env bash
# QDeck: 04-dotfiles.sh: Deploys QDeck configuration suites to ~/.config/ (Hyprland, Quickshell, Kitty, etc.)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> [QDeck:04-dotfiles] Deploying QDeck configuration suites to ~/.config/..."
mkdir -p "$HOME/.config"

# 1. Hyprland configuration
if [[ -d "$REPO_ROOT/hypr" ]]; then
  echo "    Deploying Hyprland configuration..."
  mkdir -p "$HOME/.config/hypr"
  cp -rf "$REPO_ROOT/hypr/." "$HOME/.config/hypr/"
fi

# 2. QDeck Quickshell configuration & components
if [[ -d "$REPO_ROOT/quickshell" ]]; then
  echo "    Deploying QDeck Quickshell configuration..."
  mkdir -p "$HOME/.config/quickshell"
  cp -rf "$REPO_ROOT/quickshell/." "$HOME/.config/quickshell/"
fi

# 3. Kitty terminal configuration (if present in repo)
if [[ -d "$REPO_ROOT/kitty" && -n "$(ls -A "$REPO_ROOT/kitty" 2>/dev/null)" ]]; then
  echo "    Deploying Kitty terminal configuration..."
  mkdir -p "$HOME/.config/kitty"
  cp -rf "$REPO_ROOT/kitty/." "$HOME/.config/kitty/"
fi

# 4. Zsh configuration (if present in repo)
if [[ -d "$REPO_ROOT/zsh" && -n "$(ls -A "$REPO_ROOT/zsh" 2>/dev/null)" ]]; then
  echo "    Deploying Zsh configuration..."
  mkdir -p "$HOME/.config/zsh"
  cp -rf "$REPO_ROOT/zsh/." "$HOME/.config/zsh/"
fi

# 5. VSCodium / VSCode / Antigravity IDE User settings (if present in repo)
VSCODIUM_SETTINGS="$REPO_ROOT/assets/vscodium/settings.json"
if [[ -f "$VSCODIUM_SETTINGS" ]]; then
  echo "    Deploying VSCodium user settings..."
  mkdir -p "$HOME/.config/VSCodium/User"
  cp -f "$VSCODIUM_SETTINGS" "$HOME/.config/VSCodium/User/settings.json"
  if command -v antigravity-ide >/dev/null 2>&1 || [[ -d "$HOME/.config/Antigravity IDE" ]]; then
    echo "    Deploying Antigravity IDE user settings..."
    mkdir -p "$HOME/.config/Antigravity IDE/User"
    cp -f "$VSCODIUM_SETTINGS" "$HOME/.config/Antigravity IDE/User/settings.json"
  fi
fi

# Ensure sensible permissions on deployed user configs
find "$HOME/.config/hypr" "$HOME/.config/quickshell" -type f -exec chmod 644 {} + 2>/dev/null || true
find "$HOME/.config/hypr" "$HOME/.config/quickshell" -type d -exec chmod 755 {} + 2>/dev/null || true

echo "==> [QDeck:04-dotfiles] Configurations deployed successfully for QDeck."
exit 0
