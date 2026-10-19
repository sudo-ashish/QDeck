#!/usr/bin/env bash
# QDeck: 02-fonts.sh: Installs required Nerd Fonts, Material Symbols/Icons, CJK/emoji sets, and font cache for QDeck
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
USER_FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$USER_FONT_DIR"

echo "==> [QDeck:02-fonts] Installing official repository fonts for QDeck..."

PACMAN_FONTS=(
  ttf-jetbrains-mono-nerd
  ttf-iosevka-nerd
  ttf-material-symbols-variable
  ttf-material-icons
  noto-fonts
  noto-fonts-cjk
  noto-fonts-emoji
)

MISSING_FONTS=()
for font_pkg in "${PACMAN_FONTS[@]}"; do
  if ! pacman -Qi "$font_pkg" &>/dev/null; then
    MISSING_FONTS+=("$font_pkg")
  fi
done

if ((${#MISSING_FONTS[@]} > 0)); then
  echo "    Installing missing fonts: ${MISSING_FONTS[*]}"
  sudo pacman -S --needed --noconfirm "${MISSING_FONTS[@]}"
else
  echo "    All required official fonts already installed."
fi

# Detect AUR helper for AUR fonts
AUR_HELPER=""
if command -v paru &>/dev/null; then
  AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
  AUR_HELPER="yay"
fi

if [[ -n "$AUR_HELPER" ]]; then
  AUR_FONTS=(
    ttf-rubik-vf
  )
  for af in "${AUR_FONTS[@]}"; do
    if ! pacman -Qi "$af" &>/dev/null; then
      echo "    Installing AUR font: $af"
      "$AUR_HELPER" -S --needed --noconfirm "$af" 2>/dev/null || echo "    (Skipping AUR font $af)"
    fi
  done
fi

# 4. Material Symbols Rounded font file for QDeck Icons.qml
if [[ ! -f "$USER_FONT_DIR/MaterialSymbolsRounded.ttf" ]]; then
  echo "==> [QDeck:02-fonts] Setting up MaterialSymbolsRounded.ttf for QDeck..."
  sys_sym_font=$(find /usr/share/fonts -iname '*material*symbols*rounded*.ttf' 2>/dev/null | head -n1 || true)
  if [[ -n "$sys_sym_font" && -f "$sys_sym_font" ]]; then
    cp -f "$sys_sym_font" "$USER_FONT_DIR/MaterialSymbolsRounded.ttf"
    echo "    Copied Material Symbols from system package: $sys_sym_font"
  else
    TEMP_SYM_DIR="$(mktemp -d /tmp/font-sym.XXXXXX)"
    trap 'rm -rf "$TEMP_SYM_DIR" 2>/dev/null || true' EXIT
    if curl -fsSL -o "$TEMP_SYM_DIR/MaterialSymbolsRounded.ttf" \
      "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" 2>/dev/null; then
      cp -f "$TEMP_SYM_DIR/MaterialSymbolsRounded.ttf" "$USER_FONT_DIR/MaterialSymbolsRounded.ttf"
      echo "    Downloaded MaterialSymbolsRounded.ttf to $USER_FONT_DIR"
    fi
    rm -rf "$TEMP_SYM_DIR"
    trap - EXIT
  fi
else
  echo "    MaterialSymbolsRounded.ttf is already present in $USER_FONT_DIR"
fi

# Downloaded font fallback for hyprlock: Deutschlander
font_available() {
  local family="$1"
  command -v fc-list &>/dev/null || return 1
  fc-list : family 2>/dev/null | tr ',' '\n' | grep -Fxi -- "$family" &>/dev/null
}

if ! font_available "Deutschlander"; then
  echo "==> [QDeck:02-fonts] Fetching Deutschlander font for hyprlock..."
  TEMP_FONT_DIR="$(mktemp -d /tmp/font-dl.XXXXXX)"
  trap 'rm -rf "$TEMP_FONT_DIR" 2>/dev/null || true' EXIT

  if curl -fsSL -o "$TEMP_FONT_DIR/deutschlander.zip" "https://dl.dafont.com/dl/?f=deutschlander" 2>/dev/null; then
    if unzip -q "$TEMP_FONT_DIR/deutschlander.zip" -d "$TEMP_FONT_DIR/out" 2>/dev/null; then
      find "$TEMP_FONT_DIR/out" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -exec cp -f {} "$USER_FONT_DIR/" \;
      echo "    Installed Deutschlander to $USER_FONT_DIR"
    fi
  fi
  rm -rf "$TEMP_FONT_DIR"
  trap - EXIT
else
  echo "    Deutschlander font is already present."
fi

# Copy any bundled fonts from repository if present
if [[ -d "$REPO_ROOT/fonts" ]]; then
  echo "==> [QDeck:02-fonts] Installing bundled fonts from repository..."
  find "$REPO_ROOT/fonts" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -exec cp -f {} "$USER_FONT_DIR/" \;
fi

# Refresh font cache
echo "==> [QDeck:02-fonts] Rebuilding font cache (fc-cache)..."
fc-cache -f "$USER_FONT_DIR" 2>/dev/null || true
fc-cache -f 2>/dev/null || true

echo "==> [QDeck:02-fonts] Font installation completed for QDeck."
exit 0
