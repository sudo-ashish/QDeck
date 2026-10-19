#!/usr/bin/env bash
# QDeck: 06-assets.sh: Deploys wallpapers, themes, icons, cursors, and audio assets for QDeck
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> [QDeck:06-assets] Deploying visual assets, wallpapers, and themes for QDeck..."

# 1. Ensure standard XDG user directories exist
if command -v xdg-user-dirs-update &>/dev/null; then
  xdg-user-dirs-update 2>/dev/null || true
fi
mkdir -p "$HOME/Pictures" "$HOME/.local/share" "$HOME/.config"

# 2. Wallpapers and Backgrounds
BACKGROUND_DEST="$HOME/Pictures/Background"
WALLPAPER_SHARE="$HOME/.local/share/wallpapers"

# Check possible wallpaper sources in repository
for bg_src in "$REPO_ROOT/Background" "$REPO_ROOT/assets/Background" "$REPO_ROOT/assets/wallpapers"; do
  if [[ -d "$bg_src" && -n "$(ls -A "$bg_src" 2>/dev/null)" ]]; then
    echo "    Deploying wallpapers from $bg_src to $BACKGROUND_DEST..."
    mkdir -p "$BACKGROUND_DEST" "$WALLPAPER_SHARE"
    cp -rf "$bg_src/." "$BACKGROUND_DEST/"
    cp -rf "$bg_src/." "$WALLPAPER_SHARE/" 2>/dev/null || true
    break
  fi
done

# 3. Themes deployment
THEMES_DEST="$HOME/.config/themes"
for themes_src in "$REPO_ROOT/themes" "$REPO_ROOT/assets/themes"; do
  if [[ -d "$themes_src" && -n "$(ls -A "$themes_src" 2>/dev/null)" ]]; then
    echo "    Deploying themes from $themes_src to $THEMES_DEST..."
    mkdir -p "$THEMES_DEST"
    cp -rf "$themes_src/." "$THEMES_DEST/"
    break
  fi
done

# Ensure current theme link exists if themes are available
if [[ -d "$THEMES_DEST" && ! -e "$THEMES_DEST/current" ]]; then
  # Link to catppuccin, gruvbox, or first available directory
  first_theme=""
  for t in catppuccin gruvbox everforest nord tokyo-night; do
    if [[ -d "$THEMES_DEST/$t" ]]; then
      first_theme="$THEMES_DEST/$t"
      break
    fi
  done
  if [[ -z "$first_theme" ]]; then
    shopt -s nullglob
    dirs=("$THEMES_DEST"/*)
    shopt -u nullglob
    for d in "${dirs[@]}"; do
      if [[ -d "$d" && ! -L "$d" ]]; then
        first_theme="$d"
        break
      fi
    done
  fi
  if [[ -n "$first_theme" ]]; then
    ln -sf "$first_theme" "$THEMES_DEST/current"
    echo "    Initialized active theme symlink -> $(basename "$first_theme")"
  fi
fi

# 4. Icons and Cursors
ICONS_DEST="$HOME/.local/share/icons"
for icons_src in "$REPO_ROOT/assets/icons" "$REPO_ROOT/assets/cursors"; do
  if [[ -d "$icons_src" && -n "$(ls -A "$icons_src" 2>/dev/null)" ]]; then
    echo "    Deploying icons from $icons_src..."
    mkdir -p "$ICONS_DEST"
    cp -rf "$icons_src/." "$ICONS_DEST/"
  fi
done

# 5. Audio and sound effects
SOUNDS_DEST="$HOME/.local/share/sounds"
if [[ -d "$REPO_ROOT/assets/sounds" && -n "$(ls -A "$REPO_ROOT/assets/sounds" 2>/dev/null)" ]]; then
  echo "    Deploying sound assets..."
  mkdir -p "$SOUNDS_DEST"
  cp -rf "$REPO_ROOT/assets/sounds/." "$SOUNDS_DEST/"
fi

echo "==> [QDeck:06-assets] Visual assets deployed successfully for QDeck."
exit 0
