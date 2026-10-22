#!/usr/bin/env bash
# QDeck: 01-deps.sh: Core dependencies, icon fonts, and system packages installation for QDeck
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> [QDeck:01-deps] Auditing and installing core Arch Linux system packages for QDeck..."

# 1. Base packages from official Arch Linux repositories
CORE_PACKAGES=(
  # Build tools & VCS
  base-devel
  git
  curl
  wget
  unzip
  file
  jq
  desktop-file-utils

  # Wayland compositor, display manager & tools
  hyprland
  hyprlock
  hypridle
  sddm
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
  xdg-utils
  grim 
  slurp
  libnotify
  nautilus
  wl-clipboard

  # Terminal, shell & monitor
  kitty
  zsh
  zsh-autosuggestions
  zsh-syntax-highlighting
  btop
  awww
  eza 
  fzf
  zoxide
  
  # Icon Fonts & Material Symbols for QDeck
  ttf-material-symbols-variable
  ttf-material-icons

  # Audio stack (PulseAudio emulation required for pactl/wpctl)
  pipewire
  pipewire-pulse
  wireplumber
  pavucontrol

  # Bluetooth stack
  bluez
  bluez-utils

  # Hardware control & metrics
  brightnessctl
  upower
  power-profiles-daemon
  networkmanager
  qrencode
)

MISSING_CORE=()
for pkg in "${CORE_PACKAGES[@]}"; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    MISSING_CORE+=("$pkg")
  fi
done

if ((${#MISSING_CORE[@]} > 0)); then
  echo "    Installing missing pacman packages: ${MISSING_CORE[*]}"
  sudo pacman -S --needed --noconfirm "${MISSING_CORE[@]}"
else
  echo "    All core system packages are already installed."
fi

# 2. AUR Helper Setup (unattended yay/paru)
AUR_HELPER=""
if command -v paru &>/dev/null; then
  AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
  AUR_HELPER="yay"
fi

if [[ -z "$AUR_HELPER" ]]; then
  echo "==> [01-deps] Neither yay nor paru found. Setting up yay from AUR unattended..."
  
  # Ensure base-devel and git are present
  sudo pacman -S --needed --noconfirm base-devel git

  BUILD_DIR="$(mktemp -d /tmp/aur-yay.XXXXXX)"
  trap 'rm -rf "$BUILD_DIR" 2>/dev/null || true' EXIT

  echo "    Cloning yay-bin from AUR..."
  if git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$BUILD_DIR/yay" 2>/dev/null || \
     git clone --depth=1 https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"; then
    (
      cd "$BUILD_DIR/yay"
      makepkg -si --noconfirm --needed
    )
    AUR_HELPER="yay"
    echo "    Successfully installed yay."
  else
    echo "Warning: Failed to clone yay from AUR. Continuing without AUR helper." >&2
  fi
  rm -rf "$BUILD_DIR"
  trap - EXIT
else
  echo "    AUR helper found: $AUR_HELPER"
fi

# 3. Optional AUR packages
if [[ -n "$AUR_HELPER" ]]; then
  AUR_PACKAGES=(
    localsend-bin
    bibata-cursor-theme-bin
    brave-origin-bin
    vscodium-bin
  )
  for pkg in "${AUR_PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
      echo "    Installing AUR package: $pkg"
      "$AUR_HELPER" -S --needed --noconfirm "$pkg" || echo "    (Skipping optional AUR package $pkg)"
    fi
  done
fi

# 4. Enable essential system & user services non-interactively
echo "==> [01-deps] Enabling system services..."
sudo systemctl enable --now bluetooth NetworkManager power-profiles-daemon 2>/dev/null || true

# Display manager (SDDM)
if command -v sddm &>/dev/null || pacman -Qi sddm &>/dev/null; then
  echo "    Enabling sddm display manager..."
  sudo systemctl enable sddm 2>/dev/null || true
fi

echo "==> [01-deps] Enabling user services..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
systemctl --user mask hyprpolkitagent.service 2>/dev/null || true

echo "==> [QDeck:01-deps] Dependencies and system services configured successfully for QDeck."
exit 0
