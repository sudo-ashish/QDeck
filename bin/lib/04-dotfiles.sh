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

  # Initialize GTK, Kitty, and btop runtime symlinks
  if [[ -d "$HOME/.config/themes/current" ]]; then
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/kitty" "$HOME/.config/btop/themes"
    rm -f "$HOME/.config/gtk-4.0/gtk-dark.css" "$HOME/.config/gtk-4.0/assets" 2>/dev/null || true
    ln -sfn "$HOME/.config/themes/current/gtk-3.0.css" "$HOME/.config/gtk-3.0/gtk.css"
    ln -sfn "$HOME/.config/themes/current/gtk-4.0.css" "$HOME/.config/gtk-4.0/gtk.css"
    ln -sfn "$HOME/.config/themes/current/color.conf" "$HOME/.config/kitty/color.conf"
    ln -sfn "$HOME/.config/themes/current/btop.theme" "$HOME/.config/btop/themes/current.theme"
  fi
fi

# 7. GTK Suite & Global Appearance Settings (GTK 2.0, 3.0, 4.0, xsettingsd, gsettings, dconf)
echo "    Deploying GTK appearance settings (font, cursor, theme, prefer-dark)..."
GTK_ASSETS="$REPO_ROOT/assets/gtk"
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/xsettingsd"

# Determine active/default icon theme
DEFAULT_ICON="Yaru-blue"
if [[ -f "$HOME/.config/themes/current/icons.theme" ]]; then
  DEFAULT_ICON="$(head -n 1 "$HOME/.config/themes/current/icons.theme" 2>/dev/null | tr -d '\r\n' | xargs)"
  [[ -z "$DEFAULT_ICON" ]] && DEFAULT_ICON="Yaru-blue"
fi

# Determine preferred GTK theme (prefer adw-gtk3-dark for perfect libadwaita parity, fallback to Adwaita-dark)
DEFAULT_GTK_THEME="Adwaita-dark"
if [[ -d "/usr/share/themes/adw-gtk3-dark" || -d "$HOME/.themes/adw-gtk3-dark" || -d "$HOME/.local/share/themes/adw-gtk3-dark" ]]; then
  DEFAULT_GTK_THEME="adw-gtk3-dark"
fi

# Deploy GTK 3.0 settings.ini
if [[ ! -f "$HOME/.config/gtk-3.0/settings.ini" && -f "$GTK_ASSETS/gtk-3.0/settings.ini" ]]; then
  cp -f "$GTK_ASSETS/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
elif [[ -f "$GTK_ASSETS/gtk-3.0/settings.ini" ]]; then
  for key in "gtk-application-prefer-dark-theme=1" "gtk-theme-name=$DEFAULT_GTK_THEME" "gtk-font-name=JetBrainsMono Nerd Font 11" "gtk-cursor-theme-name=Bibata-Modern-Ice" "gtk-cursor-theme-size=18"; do
    kname="${key%%=*}"
    if ! grep -q "^[[:space:]]*$kname" "$HOME/.config/gtk-3.0/settings.ini"; then
      if grep -q "^\[Settings\]" "$HOME/.config/gtk-3.0/settings.ini"; then
        sed -i "/^\[Settings\]/a $key" "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || echo "$key" >> "$HOME/.config/gtk-3.0/settings.ini"
      else
        printf '[Settings]\n%s\n' "$key" >> "$HOME/.config/gtk-3.0/settings.ini"
      fi
    fi
  done
fi

# Deploy GTK 4.0 settings.ini
if [[ ! -f "$HOME/.config/gtk-4.0/settings.ini" && -f "$GTK_ASSETS/gtk-4.0/settings.ini" ]]; then
  cp -f "$GTK_ASSETS/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
elif [[ -f "$GTK_ASSETS/gtk-4.0/settings.ini" ]]; then
  for key in "gtk-application-prefer-dark-theme=1" "gtk-theme-name=$DEFAULT_GTK_THEME" "gtk-font-name=JetBrainsMono Nerd Font 11" "gtk-cursor-theme-name=Bibata-Modern-Ice" "gtk-cursor-theme-size=18"; do
    kname="${key%%=*}"
    if ! grep -q "^[[:space:]]*$kname" "$HOME/.config/gtk-4.0/settings.ini"; then
      if grep -q "^\[Settings\]" "$HOME/.config/gtk-4.0/settings.ini"; then
        sed -i "/^\[Settings\]/a $key" "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null || echo "$key" >> "$HOME/.config/gtk-4.0/settings.ini"
      else
        printf '[Settings]\n%s\n' "$key" >> "$HOME/.config/gtk-4.0/settings.ini"
      fi
    fi
  done
fi

# Deploy xsettingsd.conf
if [[ ! -f "$HOME/.config/xsettingsd/xsettingsd.conf" && -f "$GTK_ASSETS/xsettingsd.conf" ]]; then
  cp -f "$GTK_ASSETS/xsettingsd.conf" "$HOME/.config/xsettingsd/xsettingsd.conf"
fi

# Deploy ~/.gtkrc-2.0
if [[ ! -f "$HOME/.gtkrc-2.0" && -f "$GTK_ASSETS/gtkrc-2.0" ]]; then
  cp -f "$GTK_ASSETS/gtkrc-2.0" "$HOME/.gtkrc-2.0"
fi

# Synchronize active icon theme into ini/conf files
for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
  if [[ -f "$ini" ]]; then
    if grep -q "^[[:space:]]*gtk-icon-theme-name" "$ini"; then
      sed -i -E "s|^[[:space:]]*gtk-icon-theme-name[[:space:]]*=.*|gtk-icon-theme-name=$DEFAULT_ICON|" "$ini" 2>/dev/null || true
    else
      if grep -q "^\[Settings\]" "$ini"; then
        sed -i "/^\[Settings\]/a gtk-icon-theme-name=$DEFAULT_ICON" "$ini" 2>/dev/null || true
      else
        printf '[Settings]\ngtk-icon-theme-name=%s\n' "$DEFAULT_ICON" >> "$ini"
      fi
    fi
  fi
done

if [[ -f "$HOME/.config/xsettingsd/xsettingsd.conf" ]]; then
  sed -i -E "s|^[[:space:]]*Net/IconThemeName.*|Net/IconThemeName \"$DEFAULT_ICON\"|" "$HOME/.config/xsettingsd/xsettingsd.conf" 2>/dev/null || true
fi

if [[ -f "$HOME/.gtkrc-2.0" ]]; then
  sed -i -E "s|^[[:space:]]*gtk-icon-theme-name[[:space:]]*=.*|gtk-icon-theme-name=\"$DEFAULT_ICON\"|" "$HOME/.gtkrc-2.0" 2>/dev/null || true
fi

# Apply system appearance via gsettings
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme "$DEFAULT_GTK_THEME" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 11' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface document-font-name 'JetBrainsMono Nerd Font 11' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface cursor-size 18 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme "$DEFAULT_ICON" 2>/dev/null || true
  gsettings set org.gnome.desktop.sound theme-name 'freedesktop' 2>/dev/null || true
  gsettings set org.gnome.desktop.sound event-sounds true 2>/dev/null || true
fi

# Apply system appearance via dconf
if command -v dconf >/dev/null 2>&1; then
  dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true
  dconf write /org/gnome/desktop/interface/gtk-theme "'$DEFAULT_GTK_THEME'" 2>/dev/null || true
  dconf write /org/gnome/desktop/interface/font-name "'JetBrainsMono Nerd Font 11'" 2>/dev/null || true
  dconf write /org/gnome/desktop/interface/document-font-name "'JetBrainsMono Nerd Font 11'" 2>/dev/null || true
  dconf write /org/gnome/desktop/interface/monospace-font-name "'JetBrainsMono Nerd Font 11'" 2>/dev/null || true
  dconf write /org/gnome/desktop/interface/cursor-theme "'Bibata-Modern-Ice'" 2>/dev/null || true
  dconf write /org/gnome/desktop/interface/cursor-size 18 2>/dev/null || true
  dconf write /org/gnome/desktop/interface/icon-theme "'$DEFAULT_ICON'" 2>/dev/null || true
fi

# Ensure sensible permissions on deployed user configs
find "$HOME/.config/hypr" "$HOME/.config/quickshell" "$HOME/.config/themes" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/xsettingsd" -type f -exec chmod 644 {} + 2>/dev/null || true
find "$HOME/.config/hypr" "$HOME/.config/quickshell" "$HOME/.config/themes" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/xsettingsd" -type d -exec chmod 755 {} + 2>/dev/null || true

echo "==> [QDeck:04-dotfiles] Configurations deployed successfully for QDeck."
exit 0
