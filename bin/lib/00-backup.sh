#!/usr/bin/env bash
# QDeck: 00-backup.sh: Pre-installation configuration backup module for QDeck
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Define backup destination directory
BACKUP_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.config/qdeck_backup_${BACKUP_TIMESTAMP}}"

echo "==> [QDeck:00-backup] Checking for existing user configurations to back up..."

# Candidate targets to back up if present
TARGETS=(
  "$HOME/.config/hypr"
  "$HOME/.config/kitty"
  "$HOME/.config/nvim"
  "$HOME/.config/quickshell"
  "$HOME/.config/zsh"
  "$HOME/.local/bin/zsh"
  "$HOME/.zshrc"
  "$HOME/.config/rofi"
  "$HOME/.config/swaync"
  "$HOME/.config/waybar"
  "$HOME/.config/themes"
  "$HOME/.config/VSCodium/User/settings.json"
  "$HOME/.config/Antigravity IDE/User/settings.json"
)

backed_up_count=0

for target in "${TARGETS[@]}"; do
  # Check if target exists as a file, directory, or symlink
  if [[ -e "$target" || -L "$target" ]]; then
    # Create the backup directory if not already created
    mkdir -p "$BACKUP_DIR"

    # Relative path from HOME for structured backup
    rel_path="${target#"$HOME"/}"
    dest_path="$BACKUP_DIR/$rel_path"

    # Ensure parent directory exists inside backup directory
    mkdir -p "$(dirname "$dest_path")"

    # Copy preserving attributes and symlinks without aborting
    cp -a "$target" "$dest_path"
    echo "    Backed up: $target -> $dest_path"
    ((backed_up_count++)) || true
  fi
done

if ((backed_up_count > 0)); then
  echo "==> [QDeck:00-backup] Successfully backed up $backed_up_count items to $BACKUP_DIR"
  # Export for downstream modules or logs
  export BACKUP_DIR
else
  echo "==> [QDeck:00-backup] No pre-existing target configurations found; skipping backup."
fi

exit 0
