#!/usr/bin/env bash
# QDeck: 03-quickshell.sh: Installs Quickshell runtime, Qt6/QML plugins, and compiles native QDeck helper utilities
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> [QDeck:03-quickshell] Ensuring Qt6 and Wayland runtime dependencies are installed..."

# 1. Qt6 / QML and Wayland runtime plugins
QT_PACKAGES=(
  qt6-base
  qt6-declarative
  qt6-wayland
  qt6-svg
  qt6-5compat
  qt6-multimedia
  qt6-shadertools
  qt5-wayland
  gcc
)

MISSING_QT=()
for pkg in "${QT_PACKAGES[@]}"; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    MISSING_QT+=("$pkg")
  fi
done

if ((${#MISSING_QT[@]} > 0)); then
  echo "    Installing Qt6/Wayland packages: ${MISSING_QT[*]}"
  sudo pacman -S --needed --noconfirm "${MISSING_QT[@]}"
else
  echo "    Qt6 and Wayland runtime libraries already installed."
fi

# 2. Quickshell installation
if command -v quickshell &>/dev/null || command -v qs &>/dev/null; then
  echo "    Quickshell binary is already installed."
else
  echo "==> [QDeck:03-quickshell] Installing Quickshell runtime..."
  if pacman -Si quickshell &>/dev/null; then
    sudo pacman -S --needed --noconfirm quickshell
  else
    # Install from AUR via helper
    AUR_HELPER=""
    if command -v paru &>/dev/null; then
      AUR_HELPER="paru"
    elif command -v yay &>/dev/null; then
      AUR_HELPER="yay"
    fi

    if [[ -n "$AUR_HELPER" ]]; then
      echo "    Installing quickshell-git via $AUR_HELPER..."
      "$AUR_HELPER" -S --needed --noconfirm quickshell-git 2>/dev/null || \
      "$AUR_HELPER" -S --needed --noconfirm quickshell
    else
      echo "Error: No AUR helper found and quickshell is not in official pacman repos." >&2
      exit 1
    fi
  fi
fi

# 3. Compile native lockstate monitor C binary
LOCKSTATE_SRC="$REPO_ROOT/quickshell/src/qdeck-lockstate-monitor.c"
LOCKSTATE_BIN="$REPO_ROOT/bin/qdeck-lockstate-monitor"

if [[ -f "$LOCKSTATE_SRC" ]]; then
  echo "==> [QDeck:03-quickshell] Compiling native qdeck-lockstate-monitor for QDeck..."
  mkdir -p "$REPO_ROOT/bin" "$HOME/.local/bin"
  gcc -O2 "$LOCKSTATE_SRC" -o "$LOCKSTATE_BIN"
  chmod +x "$LOCKSTATE_BIN"
  cp -f "$LOCKSTATE_BIN" "$HOME/.local/bin/qdeck-lockstate-monitor"
  chmod +x "$HOME/.local/bin/qdeck-lockstate-monitor"
  echo "    Compiled and installed qdeck-lockstate-monitor."
fi

# 4. Create state and runtime directories
mkdir -p "$HOME/.local/state/quickshell"
mkdir -p "$HOME/.config/quickshell"

echo "==> [QDeck:03-quickshell] QDeck Quickshell environment prepared successfully."
exit 0
