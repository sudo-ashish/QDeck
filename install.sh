#!/usr/bin/env bash
# ==============================================================================
# QDeck: Non-Interactive Arch Linux + Hyprland + Quickshell Bootstrap Suite
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT

# Ensure script is executed as a normal user, not direct root
if [[ "$EUID" -eq 0 ]]; then
  echo "Error: Do not execute ./install.sh as root or with sudo." >&2
  echo "Run as your regular user. Sudo privileges will be authenticated once up-front." >&2
  exit 1
fi

# Ensure running on Arch Linux
if [[ ! -f /etc/arch-release ]] && ! command -v pacman &>/dev/null; then
  echo "Error: This installer requires Arch Linux (pacman was not detected)." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Usage & Argument Parsing
# ------------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Modular, unattended installation & dotfiles bootstrap suite for Arch Linux.

Options
  -h, --help              Show this help message and exit.
  -s, --step <STEP>       Run only a specific module:
                          00, backup      - Pre-mutation backup
                          01, deps        - Core dependencies & AUR helper
                          02, fonts       - Nerd fonts, Material Icons & CJK packages
                          03, quickshell  - QDeck Quickshell & Qt6 runtime
                          04, dotfiles    - Hyprland & QDeck app configurations
                          05, nvim        - Neovim & headless plugin sync
                          06, assets      - Wallpapers, themes & media
                          07, scripts     - QDeck binaries & PATH setup
                          08, zsh         - Zsh shell, plugins & default shell configuration
  --skip-backup           Skip the configuration backup step.
  --skip-deps             Skip installing pacman and AUR dependencies.
  --skip-fonts            Skip font installations.
  --skip-nvim             Skip Neovim configuration and plugin sync.
  --skip-zsh              Skip Zsh configuration and default shell setup.
  --dry-run               Print steps that would be executed without running them.

Examples:
  ./install.sh            # Complete unattended bootstrap
  ./install.sh -s dotfiles# Re-deploy only ~/.config dotfiles
EOF
}

TARGET_STEP=""
SKIP_BACKUP=false
SKIP_DEPS=false
SKIP_FONTS=false
SKIP_NVIM=false
SKIP_ZSH=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -s|--step)
      if [[ $# -lt 2 ]]; then
        echo "Error: --step requires an argument." >&2
        exit 1
      fi
      TARGET_STEP="$2"
      shift 2
      ;;
    --skip-backup)
      SKIP_BACKUP=true
      shift
      ;;
    --skip-deps)
      SKIP_DEPS=true
      shift
      ;;
    --skip-fonts)
      SKIP_FONTS=true
      shift
      ;;
    --skip-nvim)
      SKIP_NVIM=true
      shift
      ;;
    --skip-zsh)
      SKIP_ZSH=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Error: Unknown option '$1'." >&2
      usage
      exit 1
      ;;
  esac
done

# ------------------------------------------------------------------------------
# Determine if target step requires administrative privileges
NEEDS_SUDO=true
if [[ -n "$TARGET_STEP" ]]; then
  case "${TARGET_STEP,,}" in
    00|backup|03|quickshell|04|dotfiles|05|nvim|06|assets|07|scripts)
      NEEDS_SUDO=false
      ;;
  esac
fi

if [[ "$DRY_RUN" == false && "$NEEDS_SUDO" == true ]]; then
  echo "=========================================================================="
  echo "  QDeck Installation Suite - Non-Interactive Bootstrap"
  echo "=========================================================================="
  echo "==> Authenticating administrative privileges..."
  sudo -v

  # Keep sudo timestamp alive in the background until this script exits
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
fi

# ------------------------------------------------------------------------------
# Module Runner
# ------------------------------------------------------------------------------
execute_module() {
  local script_path="$1"
  local step_name
  step_name="$(basename "$script_path")"

  if [[ ! -f "$script_path" ]]; then
    echo "Error: Module not found: $script_path" >&2
    exit 1
  fi

  chmod +x "$script_path"

  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] Would execute: $step_name"
    return 0
  fi

  echo ""
  echo "──────────────────────────────────────────────────────────────────────────"
  echo "  Executing: $step_name"
  echo "──────────────────────────────────────────────────────────────────────────"
  
  "$script_path"
}

# Resolve step selection if --step was specified
resolve_step_script() {
  case "${TARGET_STEP,,}" in
    00|backup) echo "$REPO_ROOT/bin/lib/00-backup.sh" ;;
    01|deps) echo "$REPO_ROOT/bin/lib/01-deps.sh" ;;
    02|fonts) echo "$REPO_ROOT/bin/lib/02-fonts.sh" ;;
    03|quickshell) echo "$REPO_ROOT/bin/lib/03-quickshell.sh" ;;
    04|dotfiles) echo "$REPO_ROOT/bin/lib/04-dotfiles.sh" ;;
    05|nvim) echo "$REPO_ROOT/bin/lib/05-nvim.sh" ;;
    06|assets) echo "$REPO_ROOT/bin/lib/06-assets.sh" ;;
    07|scripts) echo "$REPO_ROOT/bin/lib/07-scripts.sh" ;;
    08|zsh) echo "$REPO_ROOT/bin/lib/08-zsh.sh" ;;
    *)
      echo "Error: Unrecognized step '$TARGET_STEP'." >&2
      exit 1
      ;;
  esac
}

START_TIME="$(date +%s)"

if [[ -n "$TARGET_STEP" ]]; then
  selected_script="$(resolve_step_script)"
  execute_module "$selected_script"
else
  # Execute full modular suite in deterministic order
  [[ "$SKIP_BACKUP" == false ]] && execute_module "$REPO_ROOT/bin/lib/00-backup.sh"
  [[ "$SKIP_DEPS" == false ]]   && execute_module "$REPO_ROOT/bin/lib/01-deps.sh"
  [[ "$SKIP_FONTS" == false ]]  && execute_module "$REPO_ROOT/bin/lib/02-fonts.sh"
  execute_module "$REPO_ROOT/bin/lib/03-quickshell.sh"
  execute_module "$REPO_ROOT/bin/lib/04-dotfiles.sh"
  [[ "$SKIP_NVIM" == false ]]   && execute_module "$REPO_ROOT/bin/lib/05-nvim.sh"
  execute_module "$REPO_ROOT/bin/lib/06-assets.sh"
  execute_module "$REPO_ROOT/bin/lib/07-scripts.sh"
  [[ "$SKIP_ZSH" == false ]]    && execute_module "$REPO_ROOT/bin/lib/08-zsh.sh"
fi

# If Hyprland is currently active, reload its configuration and start QDeck immediately
if command -v hyprctl >/dev/null 2>&1 && (pgrep -x Hyprland >/dev/null 2>&1 || [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]); then
  echo ""
  echo "==> [QDeck] Active Hyprland session detected: reloading config and starting QDeck daemon..."
  hyprctl reload >/dev/null 2>&1 || true
  "$HOME/.local/bin/qdeck" restart >/dev/null 2>&1 || "$HOME/.local/bin/qdeck" start >/dev/null 2>&1 || true
fi

END_TIME="$(date +%s)"
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=========================================================================="
echo "  ✓ QDeck Installation Suite Completed Successfully in ${DURATION}s"
echo "=========================================================================="
echo "  • QDeck unified CLI & runner: $HOME/.local/bin/qdeck"
echo "  • Start QDeck shell: qdeck"
echo "  • Autostart in Hyprland: ~/.config/hypr/modules/autostart.lua"
echo "  • Keybindings: ~/.config/hypr/keybinds/rofi.lua"
echo "  • Zsh shell configuration: ~/.zshrc (custom modules: ~/.local/bin/zsh/)"
echo "  • QDeck CLI commands: qdeck --help"
if [[ -n "${BACKUP_DIR:-}" && -d "$BACKUP_DIR" ]]; then
  echo "  • Pre-installation backups stored at: $BACKUP_DIR"
fi
echo "=========================================================================="
exit 0
