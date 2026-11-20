# QDeck Agent Guidelines & Automation Rules

## 1. System Deployment Rule (Always Active)
Whenever modifying or adding files in this repository, always deploy the changes to the user's active system environment:
- **Quickshell UI / QML changes (`quickshell/`):**
  Sync all changes to `~/.config/quickshell/` (e.g. via `./bin/lib/04-dotfiles.sh` or `cp -rf "$REPO_ROOT/quickshell/." "$HOME/.config/quickshell/"`).
  Ensure proper file permissions (`chmod 644` for files, `chmod 755` for directories).
- **Scripts and Binaries (`bin/`):**
  Sync executable scripts to `~/.local/bin/` (and ensure permissions `chmod +x`). Use `./bin/lib/07-scripts.sh` when appropriate.
- **Theme & Asset changes (`themes/`, `assets/`, `hypr/`):**
  Sync relevant configurations to `~/.config/themes/`, `~/.config/hypr/`, etc.
- **Active Daemon Restart:**
  If the `qdeck` quickshell daemon is running (`qdeck status` or `pgrep -x quickshell`), restart it cleanly with `qdeck restart` so changes take effect immediately on the user's desktop.

## 2. Cleanup of Deprecated / Old Files
- Clean up any superseded temporary files, old caches, or deprecated processes/dependencies whenever refactoring components.
- Never leave residual files outside `${XDG_CACHE_HOME:-$HOME/.cache}/qdeck` or `$XDG_RUNTIME_DIR`.
