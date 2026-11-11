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
  ANTIGRAVITY_SETTINGS="$REPO_ROOT/assets/antigravity/settings.json"
  [[ -f "$ANTIGRAVITY_SETTINGS" ]] || ANTIGRAVITY_SETTINGS="$VSCODIUM_SETTINGS"
  if command -v antigravity-ide >/dev/null 2>&1 || [[ -d "$HOME/.config/Antigravity IDE" ]]; then
    echo "    Deploying Antigravity IDE user settings..."
    mkdir -p "$HOME/.config/Antigravity IDE/User"
    cp -f "$ANTIGRAVITY_SETTINGS" "$HOME/.config/Antigravity IDE/User/settings.json"
  fi
fi

# Sync / copy extensions from VSCodium to Antigravity IDE
if [[ -d "$HOME/.vscode-oss/extensions" ]] && (command -v antigravity-ide >/dev/null 2>&1 || [[ -d "$HOME/.config/Antigravity IDE" ]]); then
  echo "    Syncing VSCodium extensions to Antigravity IDE..."
  mkdir -p "$HOME/.antigravity-ide/extensions"
  cp -rn "$HOME/.vscode-oss/extensions"/* "$HOME/.antigravity-ide/extensions/" 2>/dev/null || true
  if [[ -f "$HOME/.vscode-oss/extensions/extensions.json" ]]; then
    sed 's|/\.vscode-oss/extensions|/\.antigravity-ide/extensions|g' \
      "$HOME/.vscode-oss/extensions/extensions.json" > "$HOME/.antigravity-ide/extensions/extensions.json" 2>/dev/null || true
  fi
fi

# 6. Themes configuration (~/.config/themes)
THEMES_SRC=""
if [[ -d "$REPO_ROOT/themes" && -n "$(ls -A "$REPO_ROOT/themes" 2>/dev/null)" ]]; then
  THEMES_SRC="$REPO_ROOT/themes"
fi

if [[ -n "$THEMES_SRC" ]]; then
  echo "    Deploying themes suite to ~/.config/themes..."
  mkdir -p "$HOME/.config/themes"
  cp -rf "$THEMES_SRC/." "$HOME/.config/themes/"

  # Initialize active theme symlink if missing
  if [[ ! -L "$HOME/.config/themes/current" && ! -e "$HOME/.config/themes/current" ]]; then
    for t in kanagawa tokyo-night catppuccin gruvbox everforest nord; do
      if [[ -d "$HOME/.config/themes/$t" ]]; then
        ln -sfn "$HOME/.config/themes/$t" "$HOME/.config/themes/current"
        echo "    Initialized active theme symlink -> $t"
        break
      fi
    done
  fi

  # Dynamically compile runtime configs (color.conf, btop.theme, gtk-3.0.css, gtk-4.0.css) from colors.toml
  if [[ -f "$HOME/.config/themes/current/colors.toml" ]]; then
    if command -v qdeck-theme-gen &>/dev/null; then
      qdeck-theme-gen "$HOME/.config/themes/current" 2>/dev/null || true
    elif [[ -x "$REPO_ROOT/bin/qdeck-theme-gen" ]]; then
      "$REPO_ROOT/bin/qdeck-theme-gen" "$HOME/.config/themes/current" 2>/dev/null || true
    fi
  fi

  # Initialize GTK, Kitty, and btop runtime symlinks and dark mode settings
  if [[ -d "$HOME/.config/themes/current" ]]; then
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/kitty" "$HOME/.config/btop/themes"
    ln -sfn "$HOME/.config/themes/current/gtk-3.0.css" "$HOME/.config/gtk-3.0/gtk.css"
    ln -sfn "$HOME/.config/themes/current/gtk-4.0.css" "$HOME/.config/gtk-4.0/gtk.css"
    ln -sfn "$HOME/.config/themes/current/color.conf" "$HOME/.config/kitty/color.conf"
    ln -sfn "$HOME/.config/themes/current/btop.theme" "$HOME/.config/btop/themes/current.theme"

    for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
      if [[ -f "$ini" ]]; then
        if ! grep -q "gtk-application-prefer-dark-theme" "$ini"; then
          printf 'gtk-application-prefer-dark-theme=1\n' >> "$ini"
        fi
      else
        printf '[Settings]\ngtk-application-prefer-dark-theme=1\n' > "$ini"
      fi
    done
  fi
fi

# Ensure sensible permissions on deployed user configs
find "$HOME/.config/hypr" "$HOME/.config/quickshell" "$HOME/.config/themes" -type f -exec chmod 644 {} + 2>/dev/null || true
find "$HOME/.config/hypr" "$HOME/.config/quickshell" "$HOME/.config/themes" -type d -exec chmod 755 {} + 2>/dev/null || true

echo "==> [QDeck:04-dotfiles] Configurations deployed successfully for QDeck."
exit 0
