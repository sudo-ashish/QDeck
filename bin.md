# QDeck `bin/` Executables and Setup Scripts

This document catalogs all executable CLI tools, helper scripts, and modular installation routines located in [`bin/`](file:///home/pear/QDeck/bin).

## Table of Contents

### Core & CLI Utilities (`bin/`)

- [`bin/default-browser`](#bindefault-browser)
- [`bin/install.sh`](#bininstallsh)
- [`bin/qdeck`](#binqdeck)
- [`bin/qdeck-backlight-monitor`](#binqdeck-backlight-monitor)
- [`bin/qdeck-bar`](#binqdeck-bar)
- [`bin/qdeck-battery-info`](#binqdeck-battery-info)
- [`bin/qdeck-bluetooth`](#binqdeck-bluetooth)
- [`bin/qdeck-blur`](#binqdeck-blur)
- [`bin/qdeck-brightness`](#binqdeck-brightness)
- [`bin/qdeck-clipboard`](#binqdeck-clipboard)
- [`bin/qdeck-clipboard-monitor`](#binqdeck-clipboard-monitor)
- [`bin/qdeck-clipboard-record.py`](#binqdeck-clipboard-recordpy)
- [`bin/qdeck-display-text-size`](#binqdeck-display-text-size)
- [`bin/qdeck-dns`](#binqdeck-dns)
- [`bin/qdeck-ipc`](#binqdeck-ipc)
- [`bin/qdeck-launch-terminal`](#binqdeck-launch-terminal)
- [`bin/qdeck-launcher`](#binqdeck-launcher)
- [`bin/qdeck-lockstate-monitor`](#binqdeck-lockstate-monitor)
- [`bin/qdeck-monitor-scaling`](#binqdeck-monitor-scaling)
- [`bin/qdeck-monitor-state`](#binqdeck-monitor-state)
- [`bin/qdeck-network-qr`](#binqdeck-network-qr)
- [`bin/qdeck-network-status`](#binqdeck-network-status)
- [`bin/qdeck-notifications`](#binqdeck-notifications)
- [`bin/qdeck-osd`](#binqdeck-osd)
- [`bin/qdeck-powermenu`](#binqdeck-powermenu)
- [`bin/qdeck-qshelf`](#binqdeck-qshelf)
- [`bin/qdeck-refresh-rate`](#binqdeck-refresh-rate)
- [`bin/qdeck-screenshot`](#binqdeck-screenshot)
- [`bin/qdeck-shelf`](#binqdeck-shelf)
- [`bin/qdeck-theme-switch`](#binqdeck-theme-switch)
- [`bin/qdeck-themeswitcher`](#binqdeck-themeswitcher)
- [`bin/qdeck-trackpad`](#binqdeck-trackpad)
- [`bin/qdeck-volume`](#binqdeck-volume)
- [`bin/qdeck-wallpaper`](#binqdeck-wallpaper)
- [`bin/qdeck-wallpaperswitcher`](#binqdeck-wallpaperswitcher)
- [`bin/tui-launch`](#bintui-launch)
- [`bin/webapp-create`](#binwebapp-create)

### Setup & Installation Modules (`bin/lib/`)

- [`bin/lib/00-backup.sh`](#binlib00backupsh)
- [`bin/lib/01-deps.sh`](#binlib01depssh)
- [`bin/lib/02-fonts.sh`](#binlib02fontssh)
- [`bin/lib/03-quickshell.sh`](#binlib03quickshellsh)
- [`bin/lib/04-dotfiles.sh`](#binlib04dotfilessh)
- [`bin/lib/05-nvim.sh`](#binlib05nvimsh)
- [`bin/lib/06-assets.sh`](#binlib06assetssh)
- [`bin/lib/07-scripts.sh`](#binlib07scriptssh)
- [`bin/lib/08-zsh.sh`](#binlib08zshsh)
- [`bin/lib/qdeck-ipc.sh`](#binlibqdeckipcsh)

---

### bin/default-browser
- **Path:** `bin/default-browser`

```bash
#!/bin/sh

desktop="$(xdg-settings get default-web-browser)"

file="$HOME/.local/share/applications/$desktop"
[ -f "$file" ] || file="/usr/share/applications/$desktop"

cmd="$(grep -m1 '^Exec=' "$file" | cut -d= -f2- | sed 's/%[uUfFdDnNickvm]//g')"

exec sh -c "$cmd"
```

---

### bin/install.sh
- **Path:** `bin/install.sh`

```bash
#!/usr/bin/env bash
# QDeck: Forwarding wrapper: invokes root QDeck install.sh orchestrator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

exec "$REPO_ROOT/install.sh" "$@"
```

---

### bin/qdeck
- **Path:** `bin/qdeck`

```bash
#!/usr/bin/env bash
# ==============================================================================
# QDeck: Unified CLI Suite & Runtime Daemon Orchestrator
# ==============================================================================
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$BIN_DIR/.." && pwd)"

QS_DIR="${QUICKSHELL_DIR:-}"
if [[ -z "$QS_DIR" ]]; then
  if [[ -d "$HOME/.config/quickshell" && -f "$HOME/.config/quickshell/shell.qml" ]]; then
    QS_DIR="$HOME/.config/quickshell"
  elif [[ -d "$REPO_ROOT/quickshell" && -f "$REPO_ROOT/quickshell/shell.qml" ]]; then
    QS_DIR="$REPO_ROOT/quickshell"
  elif [[ -d "$HOME/quickshell" ]]; then
    QS_DIR="$HOME/quickshell"
  fi
fi

export PATH="$HOME/.local/bin:$BIN_DIR:$PATH"
export QS_CONFIG_PATH="$QS_DIR"
current_icon_theme=""
if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/themes/current/icons.theme" ]]; then
  current_icon_theme="$(head -n 1 "${XDG_CONFIG_HOME:-$HOME/.config}/themes/current/icons.theme" 2>/dev/null | tr -d '\r\n' | xargs)"
elif [[ -f "$HOME/themes/current/icons.theme" ]]; then
  current_icon_theme="$(head -n 1 "$HOME/themes/current/icons.theme" 2>/dev/null | tr -d '\r\n' | xargs)"
fi
export QS_ICON_THEME="${QS_ICON_THEME:-${current_icon_theme:-$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'" || echo Adwaita)}}"

usage() {
  cat <<'EOF'
QDeck: Modern Desktop Shell Suite & System Control CLI

Usage:
  qdeck [command] [options...]

Core Commands:
  qdeck, qdeck run, qdeck start  Launch QDeck desktop shell runtime daemon
  qdeck stop, qdeck kill         Terminate running QDeck instances cleanly
  qdeck restart, qdeck reload    Restart QDeck daemon and refresh UI
  qdeck status                   Display running status, PID, and IPC connection
  qdeck help, --help, -h         Show this help information

Control Center & Widgets:
  qdeck launcher [action]        Toggle or control application launcher
  qdeck powermenu [action]       Toggle power & session menu
  qdeck wallpaper [action]       Toggle wallpaper picker or switch wallpaper
  qdeck theme [action]           Toggle theme switcher or switch active theme
  qdeck qshelf [action]          Toggle or control drag-and-drop staging QShelf (or: qdeck shelf)
  qdeck clipboard [action]       Toggle or control text clipboard manager (wl-clipboard backed)
  qdeck bar [action|mode]        Toggle, hide, show, or switch layout (floating, islands, wide, compact)
  qdeck blur [toggle|on|off]     Toggle dual-alpha compositor blur
  qdeck text-size [size]         Get or adjust system and shell font size

Hardware & System Controls:
  qdeck volume [up|down|mute]    Adjust volume or toggle audio mute
  qdeck brightness [up|down]     Adjust screen backlight
  qdeck osd [options]            Display custom On-Screen Display card
  qdeck notify [options]         Manage desktop notifications & DND mode
  qdeck trackpad [toggle|on|off] Toggle touchpad state via Hyprland IPC
  qdeck wifi-qr                  Generate ASCII QR code for current WiFi network
  qdeck refresh-rate [rate]      Query or toggle monitor refresh rate
  qdeck screenshot [options]     Capture region, window, or monitor screenshot
  qdeck terminal [args...]       Launch floating utility terminal

Examples:
  qdeck                          # Start shell daemon
  qdeck launcher                 # Open application launcher
  qdeck volume up 5              # Increase volume by 5%
  qdeck notify test              # Show test notification
EOF
}

CMD="${1:-start}"

case "$CMD" in
  -h|--help|help)
    usage
    exit 0
    ;;

  status)
    echo "=== QDeck Status ==="
    if pgrep -x qs >/dev/null 2>&1 || pgrep -x quickshell >/dev/null 2>&1; then
      pids=$(pgrep -d, -x qs 2>/dev/null || pgrep -d, -x quickshell 2>/dev/null)
      echo "  Status:  ACTIVE (running)"
      echo "  PID(s):  $pids"
      echo "  Config:  $QS_DIR"
      if command -v qs >/dev/null 2>&1; then
        if qs ipc call osd ping >/dev/null 2>&1; then
          echo "  IPC:     CONNECTED (responsive)"
        else
          echo "  IPC:     CONNECTING / BUSY"
        fi
      fi
    else
      echo "  Status:  INACTIVE (not running)"
    fi
    exit 0
    ;;

  stop|kill)
    echo "==> Terminating QDeck..."
    killall -q qs quickshell 2>/dev/null || true
    # Wipe ephemeral clipboard history on stop
    rm -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/clipboard-history.json" \
          "$HOME/.local/state/quickshell/clipboard-history.json" 2>/dev/null || true
    if command -v wl-copy >/dev/null 2>&1; then
      wl-copy -c 2>/dev/null || true
    fi
    echo "    QDeck stopped."
    exit 0
    ;;

  restart|reload)
    echo "==> Restarting QDeck..."
    killall -q qs quickshell 2>/dev/null || true
    sleep 0.4
    exec "$0" start
    ;;

  launcher)
    shift
    exec "$BIN_DIR/qdeck-launcher" "$@"
    ;;

  powermenu|power)
    shift
    exec "$BIN_DIR/qdeck-powermenu" "$@"
    ;;

  wallpaper|wallpaperswitcher)
    shift
    exec "$BIN_DIR/qdeck-wallpaperswitcher" "$@"
    ;;

  theme|themeswitcher)
    shift
    exec "$BIN_DIR/qdeck-themeswitcher" "$@"
    ;;

  qshelf|shelf|stagingshelf)
    shift
    exec "$BIN_DIR/qdeck-qshelf" "$@"
    ;;

  clipboard|clip)
    shift
    exec "$BIN_DIR/qdeck-clipboard" "$@"
    ;;

  bar|bar-style)
    shift
    exec "$BIN_DIR/qdeck-bar" "$@"
    ;;

  volume)
    shift
    exec "$BIN_DIR/qdeck-volume" "$@"
    ;;

  brightness)
    shift
    exec "$BIN_DIR/qdeck-brightness" "$@"
    ;;

  osd)
    shift
    exec "$BIN_DIR/qdeck-osd" "$@"
    ;;

  notify|notifications)
    shift
    exec "$BIN_DIR/qdeck-notifications" "$@"
    ;;

  blur)
    shift
    exec "$BIN_DIR/qdeck-blur" "$@"
    ;;

  text-size)
    shift
    exec "$BIN_DIR/qdeck-display-text-size" "$@"
    ;;

  trackpad)
    shift
    exec "$BIN_DIR/qdeck-trackpad" "$@"
    ;;

  wifi-qr|qr)
    shift
    exec "$BIN_DIR/qdeck-network-qr" "$@"
    ;;

  refresh-rate)
    shift
    exec "$BIN_DIR/qdeck-refresh-rate" "$@"
    ;;

  terminal)
    shift
    exec "$BIN_DIR/qdeck-launch-terminal" "$@"
    ;;

  screenshot|shot)
    shift
    exec "$BIN_DIR/qdeck-screenshot" "$@"
    ;;

  start|run|"")
    # Launch QDeck runtime daemon below
    ;;

  *)
    echo "Error: Unknown QDeck command '$CMD'." >&2
    echo "Run 'qdeck --help' for usage." >&2
    exit 1
    ;;
esac

# ------------------------------------------------------------------------------
# QDeck Daemon Startup
# ------------------------------------------------------------------------------
# 1. Terminate conflicting legacy bars, notification daemons, OSD servers, or polkit agents
killall -q waybar swaync swayosd-server hyprpolkitagent polkit-kde-authentication-agent-1 polkit-gnome-authentication-agent-1 2>/dev/null || true
systemctl --user stop hyprpolkitagent.service 2>/dev/null || true

# 2. Terminate any previous or stale QuickShell instances cleanly
killall -q qs quickshell 2>/dev/null || true
# Wipe ephemeral clipboard history on QDeck start/restart
rm -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/clipboard-history.json" \
      "$HOME/.local/state/quickshell/clipboard-history.json" 2>/dev/null || true
if command -v wl-copy >/dev/null 2>&1; then
  wl-copy -c 2>/dev/null || true
fi
sleep 0.3

# 3. Ensure PipeWire audio server is running
systemctl --user start pipewire pipewire-pulse wireplumber 2>/dev/null || true

# 4. Sync helper scripts into ~/.local/bin
mkdir -p "$HOME/.local/bin"
for s in "$BIN_DIR"/*; do
  [[ -f "$s" ]] || continue
  base=$(basename "$s")
  [[ "$base" == "install.sh" ]] && continue
  chmod +x "$s"
  if [[ -L "$HOME/.local/bin/$base" || ! -f "$HOME/.local/bin/$base" || "$s" -nt "$HOME/.local/bin/$base" ]]; then
    rm -f "$HOME/.local/bin/$base"
    cp -f "$s" "$HOME/.local/bin/$base"
    chmod +x "$HOME/.local/bin/$base"
  fi
done

# 5. Start Quickshell daemon attached to configuration
if [[ "$QS_DIR" == "$HOME/.config/quickshell" ]]; then
  # Standard default configuration does not require -p flag
  if command -v qs >/dev/null 2>&1; then
    qs -d
  elif [[ -x "/usr/bin/qs" ]]; then
    /usr/bin/qs -d
  else
    quickshell -d
  fi
else
  # Explicit path configuration
  if command -v qs >/dev/null 2>&1; then
    qs -d -p "$QS_DIR"
  elif [[ -x "/usr/bin/qs" ]]; then
    /usr/bin/qs -d -p "$QS_DIR"
  else
    quickshell -d -p "$QS_DIR"
  fi
fi

# 6. Bridge IPC sockets so all commands (with or without -p) seamlessly reach the instance
sleep 0.4
uid=$(id -u)
if [[ -n "$QS_DIR" && -f "$QS_DIR/shell.qml" ]]; then
  cfg_hash=$(printf '%s/shell.qml' "$QS_DIR" | md5sum 2>/dev/null | awk '{print $1}' || true)
  if [[ -n "$cfg_hash" ]]; then
    mkdir -p "/run/user/$uid/quickshell/by-shell/$cfg_hash" "/run/user/$uid/quickshell/by-path" 2>/dev/null || true
    for id_dir in "/run/user/$uid/quickshell/by-id"/*; do
      [[ -e "$id_dir" ]] || continue
      b=$(basename "$id_dir")
      ln -sf "$id_dir" "/run/user/$uid/quickshell/by-shell/$cfg_hash/$b" 2>/dev/null || true
    done
    ln -sf "/run/user/$uid/quickshell/by-shell/$cfg_hash" "/run/user/$uid/quickshell/by-path/$cfg_hash" 2>/dev/null || true
  fi
fi

# 7. Quick verification
qs ipc call osd ping >/dev/null 2>&1 || true
```

---

### bin/qdeck-backlight-monitor
- **Path:** `bin/qdeck-backlight-monitor`

```bash
#!/usr/bin/env bash
# QDeck: Event-driven backlight monitor for QDeck
set -euo pipefail

get_pct() {
  for dev in /sys/class/backlight/*; do
    if [[ -f "$dev/brightness" && -f "$dev/max_brightness" ]]; then
      cur=$(< "$dev/brightness")
      max=$(< "$dev/max_brightness")
      if [[ $max -gt 0 ]]; then
        echo $(( cur * 100 / max ))
        return 0
      fi
    fi
  done
  if command -v brightnessctl >/dev/null 2>&1; then
    val=$(brightnessctl -m 2>/dev/null | head -n1 | awk -F, '{ gsub(/%/, "", $4); print $4 }')
    [[ -n "$val" ]] && echo "$val" && return 0
  fi
  echo "100"
}

# Output initial value
get_pct

# Listen for kernel backlight change events in real time
if command -v udevadm >/dev/null 2>&1; then
  stdbuf -oL udevadm monitor --udev --subsystem-match=backlight 2>/dev/null | while read -r line; do
    if [[ "$line" == *"change"* ]]; then
      get_pct
    fi
  done
fi
```

---

### bin/qdeck-bar
- **Path:** `bin/qdeck-bar`

```bash
#!/usr/bin/env bash
# QDeck: Manage top bar layout style (qdeck-bar-style / qdeck bar)
# Modes:
#   floating - Floating top bar with left/right margins, rounded bottom corners, distributed layout (Default)
#   islands  - Three distinct floating island capsules (Left, Center, Right)
#   wide     - Wide centered floating bar (~72% screen width, distributed)
#   compact  - Centered compact notch bar (content-fitted dynamic width)

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
CONFIG_FILE="$CONFIG_DIR/bar-style"
VIS_FILE="$CONFIG_DIR/bar-visibility"
MODES=("floating" "islands" "wide" "compact")
DEFAULT_MODE="floating"

get_current_mode() {
  if [[ -f "$CONFIG_FILE" ]]; then
    local m
    m="$(tr -d '[:space:]' < "$CONFIG_FILE" | tr '[:upper:]' '[:lower:]')"
    for valid in "${MODES[@]}"; do
      if [[ "$m" == "$valid" ]]; then
        echo "$m"
        return 0
      fi
    done
  fi
  echo "$DEFAULT_MODE"
}

is_bar_visible() {
  if [[ -f "$VIS_FILE" ]]; then
    local v
    v="$(tr -d '[:space:]' < "$VIS_FILE" | tr '[:upper:]' '[:lower:]')"
    if [[ "$v" == "hidden" || "$v" == "false" || "$v" == "hide" || "$v" == "off" ]]; then
      echo "hidden"
      return 0
    fi
  fi
  echo "visible"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source shared IPC helper
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
elif command -v qdeck-ipc >/dev/null 2>&1; then
  source "$(command -v qdeck-ipc)"
fi

call_bar_ipc() {
  call_ipc "$@" >/dev/null 2>&1 || true
}

set_bar_visibility() {
  local state="$1" # "visible" or "hidden"
  mkdir -p "$CONFIG_DIR"
  echo "$state" > "$VIS_FILE"

  if [[ "$state" == "hidden" ]]; then
    call_bar_ipc bar hide
    echo "Top bar is now hidden."
  else
    call_bar_ipc bar show
    echo "Top bar is now visible."
  fi
}

toggle_bar_visibility() {
  local cur
  cur="$(is_bar_visible)"
  if [[ "$cur" == "hidden" ]]; then
    set_bar_visibility "visible"
  else
    set_bar_visibility "hidden"
  fi
}

set_mode() {
  local target="$1"
  mkdir -p "$CONFIG_DIR"
  echo "$target" > "$CONFIG_FILE"

  # Attempt dynamic update via Quickshell IPC
  call_bar_ipc barpopups setMode "$target"

  echo "QDeck bar layout mode set to: $target"
}

show_help() {
  cat <<EOF
Usage: qdeck bar [COMMAND|MODE]
       qdeck-bar [COMMAND|MODE]

Manage QDeck top bar layout styles and visibility.

Commands:
  status (default)    Show current active bar layout mode and visibility
  toggle              Toggle top bar visibility on/off
  hide                Hide the top bar
  show                Show the top bar
  list                List all available layout modes
  next                Cycle to next layout mode
  prev                Cycle to previous layout mode
  help, -h, --help    Show this help message

Modes:
  floating (default)  Floating top bar with side margins, rounded bottom corners, distributed layout
  islands             Three distinct floating island capsules (Left, Center, Right)
  wide                Wide centered floating island (~72% monitor width, distributed)
  compact             Centered compact notch bar (content-fitted dynamic width)

Examples:
  qdeck bar               # Show current mode and visibility
  qdeck bar toggle        # Toggle top bar on/off
  qdeck bar hide          # Hide top bar
  qdeck bar show          # Show top bar
  qdeck bar list          # List all modes
  qdeck bar floating      # Switch to standard floating bar
  qdeck bar islands       # Switch to 3 separate island capsules
  qdeck bar wide          # Switch to wide centered floating bar
  qdeck bar compact       # Switch to compact centered notch bar
  qdeck bar next          # Cycle to next mode
EOF
}

cmd="${1:-status}"

case "$cmd" in
  status)
    current="$(get_current_mode)"
    vis="$(is_bar_visible)"
    echo "Current bar mode: $current (status: $vis)"
    ;;

  toggle|toggle-bar)
    toggle_bar_visibility
    ;;

  hide|hide-bar)
    set_bar_visibility "hidden"
    ;;

  show|show-bar)
    set_bar_visibility "visible"
    ;;

  list)
    current="$(get_current_mode)"
    echo "Available QDeck Bar Layout Modes:"
    for m in "${MODES[@]}"; do
      if [[ "$m" == "$current" ]]; then
        echo "  * $m (active)"
      else
        echo "    $m"
      fi
    done
    ;;

  next)
    current="$(get_current_mode)"
    idx=0
    for i in "${!MODES[@]}"; do
      if [[ "${MODES[$i]}" == "$current" ]]; then
        idx=$i
        break
      fi
    done
    next_idx=$(( (idx + 1) % ${#MODES[@]} ))
    set_mode "${MODES[$next_idx]}"
    ;;

  prev)
    current="$(get_current_mode)"
    idx=0
    for i in "${!MODES[@]}"; do
      if [[ "${MODES[$i]}" == "$current" ]]; then
        idx=$i
        break
      fi
    done
    prev_idx=$(( (idx - 1 + ${#MODES[@]}) % ${#MODES[@]} ))
    set_mode "${MODES[$prev_idx]}"
    ;;

  floating|islands|wide|compact)
    set_mode "$cmd"
    ;;

  help|-h|--help)
    show_help
    ;;

  *)
    echo "Error: Unknown bar mode or command: '$cmd'" >&2
    echo "Run 'qdeck bar list' or 'qdeck bar help' to see available options." >&2
    exit 1
    ;;
esac
```

---

### bin/qdeck-battery-info
- **Path:** `bin/qdeck-battery-info`

```bash
#!/usr/bin/env bash
# QDeck: Query detailed battery metrics for QDeck
set -e

b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)

cap=100
status="Full"
cycles="-"
size="-"
time_val="-"
rate="-"
status_disp="FULLY CHARGED"
is_charging=false

if [ -n "$b" ]; then
  cap=$(cat "$b/capacity" 2>/dev/null || echo 100)
  status=$(cat "$b/status" 2>/dev/null || echo Full)
  cycles=$(cat "$b/cycle_count" 2>/dev/null || echo "-")
  
  ef=$(cat "$b/energy_full" 2>/dev/null || cat "$b/charge_full" 2>/dev/null || echo 0)
  en=$(cat "$b/energy_now" 2>/dev/null || cat "$b/charge_now" 2>/dev/null || echo 0)
  pn=$(cat "$b/power_now" 2>/dev/null || cat "$b/current_now" 2>/dev/null || echo 0)
  
  if [ "$ef" -gt 0 ]; then
    size="$(( ef / 1000000 ))Wh"
  fi
  
  case "$status" in
    Full|full)
      status_disp="FULLY CHARGED"
      is_charging=false
      ;;
    Charging|charging)
      status_disp="CHARGING"
      is_charging=true
      ;;
    Discharging|discharging)
      status_disp="DISCHARGING"
      is_charging=false
      ;;
    "Not charging"|"not charging")
      status_disp="NOT CHARGING"
      is_charging=false
      ;;
    *)
      status_disp=$(echo "$status" | tr '[:lower:]' '[:upper:]')
      is_charging=false
      ;;
  esac

  time_label="Time to full"
  if [ "$status" = "Charging" ] || [ "$status" = "charging" ]; then
    time_label="Time to full"
    if [ "$pn" -gt 0 ] && [ "$ef" -gt "$en" ]; then
      rem=$(( (ef - en) * 60 / pn ))
      if [ "$rem" -ge 60 ]; then
        time_val="$(( rem / 60 ))h $(( rem % 60 ))m"
      else
        time_val="${rem}m"
      fi
    else
      time_up=$(upower -i "$(upower -e 2>/dev/null | grep BAT | head -n1)" 2>/dev/null | awk -F: '/time to full/ {print $2}' | xargs)
      [ -n "$time_up" ] && time_val="$time_up"
    fi
    if [ "$pn" -gt 0 ]; then
      rate="$(( pn / 1000000 ))W"
    else
      rate="Active"
    fi
  elif [ "$status" = "Discharging" ] || [ "$status" = "discharging" ]; then
    time_label="Time to empty"
    if [ "$pn" -gt 0 ] && [ "$en" -gt 0 ]; then
      rem=$(( en * 60 / pn ))
      if [ "$rem" -ge 60 ]; then
        time_val="$(( rem / 60 ))h $(( rem % 60 ))m"
      else
        time_val="${rem}m"
      fi
    else
      time_up=$(upower -i "$(upower -e 2>/dev/null | grep BAT | head -n1)" 2>/dev/null | awk -F: '/time to empty/ {print $2}' | xargs)
      [ -n "$time_up" ] && time_val="$time_up"
    fi
    rate="-"
  else
    time_label="Time to full"
    time_val="-"
    rate="-"
  fi
fi

cat << JSON
{
  "capacity": $cap,
  "status": "$status",
  "statusDisplay": "$status_disp",
  "isCharging": $is_charging,
  "cycleCount": "$cycles",
  "batterySize": "$size",
  "timeLabel": "$time_label",
  "timeToFull": "$time_val",
  "chargingRate": "$rate"
}
JSON
```

---

### bin/qdeck-bluetooth
- **Path:** `bin/qdeck-bluetooth`

```bash
#!/usr/bin/env bash
# QDeck: Bluetooth CLI wrapper for QDeck

set -e

cmd="${1:-status}"
shift || true

case "$cmd" in
  status)
    powered="no"
    show_out=$(bluetoothctl show 2>/dev/null || true)
    if echo "$show_out" | grep -iq "Powered: yes"; then
      powered="yes"
    fi
    discovering="no"
    if [[ "$powered" == "yes" ]]; then
      if echo "$show_out" | grep -iq "Discovering: yes"; then
        discovering="yes"
      fi
    fi
    echo "powered: $powered"
    echo "discovering: $discovering"
    ;;

  power)
    action="${1:-toggle}"
    if [[ "$action" == "toggle" ]]; then
      if bluetoothctl show 2>/dev/null | grep -iq "Powered: yes"; then
        action="off"
      else
        action="on"
      fi
    fi

    if [[ "$action" == "on" ]]; then
      rfkill unblock bluetooth >/dev/null 2>&1 || true
      bluetoothctl power on >/dev/null 2>&1 || true
    else
      bluetoothctl power off >/dev/null 2>&1 || true
    fi
    ;;

  scan)
    timeout="${1:-5}"
    bluetoothctl --timeout "$timeout" scan on >/dev/null 2>&1 || true
    ;;

  list)
    # If bluetooth is turned off, do not query devices
    if ! bluetoothctl show 2>/dev/null | grep -iq "Powered: yes"; then
      echo "===CONNECTED==="
      echo "===PAIRED==="
      echo "===ALL==="
      exit 0
    fi

    echo "===CONNECTED==="
    while read -r line; do
      [[ -z "$line" ]] && continue
      mac=$(echo "$line" | awk '{print $2}')
      batt=""
      if [[ -n "$mac" ]]; then
        info=$(timeout 1s bluetoothctl info "$mac" 2>/dev/null || true)
        batt=$(echo "$info" | grep -i "Battery Percentage:" | head -n1 | sed -n 's/.*(\([0-9]*\)).*/\1/p')
        if [[ -z "$batt" ]]; then
          batt=$(echo "$info" | grep -i "Battery Percentage:" | head -n1 | grep -o '[0-9]\+' || true)
        fi
      fi
      if [[ -n "$batt" ]]; then
        echo "$line [battery:$batt]"
      else
        echo "$line"
      fi
    done < <(bluetoothctl devices Connected 2>/dev/null || true)

    echo "===PAIRED==="
    {
      timeout 1s bluetoothctl devices Paired 2>/dev/null || true
      timeout 1s bluetoothctl devices Bonded 2>/dev/null || true
      timeout 1s bluetoothctl devices Trusted 2>/dev/null || true
    } | awk '!seen[$2]++'
    echo "===ALL==="
    timeout 1s bluetoothctl devices 2>/dev/null || true
    ;;

  connect)
    mac="$1"
    if [[ -n "$mac" ]]; then
      (bluetoothctl trust "$mac" >/dev/null 2>&1 &)
      exec bluetoothctl connect "$mac"
    fi
    ;;

  disconnect)
    mac="$1"
    if [[ -n "$mac" ]]; then
      exec bluetoothctl disconnect "$mac"
    fi
    ;;

  forget|remove)
    mac="$1"
    if [[ -n "$mac" ]]; then
      bluetoothctl disconnect "$mac" >/dev/null 2>&1 || true
      bluetoothctl remove "$mac" >/dev/null 2>&1 || true
    fi
    ;;

  pair)
    mac="$1"
    if [[ -n "$mac" ]]; then
      bluetoothctl trust "$mac" >/dev/null 2>&1 || true
      bluetoothctl pair "$mac"
      bluetoothctl trust "$mac" >/dev/null 2>&1 || true
    fi
    ;;

  trust-all)
    {
      bluetoothctl devices Connected 2>/dev/null || true
      bluetoothctl devices Paired 2>/dev/null || true
      bluetoothctl devices Bonded 2>/dev/null || true
      bluetoothctl devices Trusted 2>/dev/null || true
    } | awk '{print $2}' | sort -u | while read -r dmac; do
      [[ -n "$dmac" ]] && bluetoothctl trust "$dmac" >/dev/null 2>&1 || true
    done
    ;;

  *)
    echo "Usage: qdeck-bluetooth [status|power|scan|list|connect|disconnect|forget|pair|trust-all]" >&2
    exit 1
    ;;
esac
```

---

### bin/qdeck-blur
- **Path:** `bin/qdeck-blur`

```bash
#!/usr/bin/env bash
# ==============================================================================
# QDeck: Dynamic Dual Alpha + Hyprland blur & opacity controller (qdeck-blur / qdeck blur)
# Toggles Quickshell dual-alpha surface transparency and Hyprland compositor
# window blur + active/inactive opacity.
# ==============================================================================
set -euo pipefail

CMD="${1:-toggle}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/blur-state"

# Source shared IPC helper
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
elif command -v qdeck-ipc >/dev/null 2>&1; then
  source "$(command -v qdeck-ipc)"
fi

apply_hyprland_blur_and_opacity() {
  local state="$1"
  if command -v hyprctl >/dev/null 2>&1; then
    if [[ "$state" == "on" ]]; then
      hyprctl eval 'hl.config({ decoration = { blur = { enabled = true }, active_opacity = 0.95, inactive_opacity = 0.88 } })' >/dev/null 2>&1 || true
      hyprctl eval 'hl.layer_rule({ name = "qdeck-blur", match = { namespace = "^quickshell-.*" }, blur = true, blur_popups = true, ignore_alpha = 0.57 })' >/dev/null 2>&1 || true
    else
      hyprctl eval 'hl.config({ decoration = { blur = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0 } })' >/dev/null 2>&1 || true
      hyprctl eval 'hl.layer_rule({ name = "qdeck-blur", match = { namespace = "^quickshell-.*" }, blur = false, blur_popups = false })' >/dev/null 2>&1 || true
    fi
  fi
}

get_current_state() {
  local ipc_res
  if ipc_res="$(call_ipc theme getBlur 2>/dev/null)" && [[ -n "$ipc_res" ]]; then
    echo "$ipc_res"
    return 0
  fi
  if [[ -f "$STATE_FILE" ]]; then
    local s
    s="$(tr -d '[:space:]' < "$STATE_FILE" | tr '[:upper:]' '[:lower:]')"
    if [[ "$s" == "off" || "$s" == "false" || "$s" == "0" ]]; then
      echo "off"
      return 0
    fi
  fi
  echo "on"
}

set_state() {
  local target_state="$1" # "on" or "off"
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s' "$target_state" > "$STATE_FILE"

  # 1. Update Quickshell theme dual alpha via IPC if running
  call_ipc theme setBlur "$target_state" >/dev/null 2>&1 || true

  # 2. Update Hyprland compositor blur & window opacity
  apply_hyprland_blur_and_opacity "$target_state"

  echo "Blur & opacity is now: $target_state"
}

case "$CMD" in
  toggle)
    cur="$(get_current_state)"
    if [[ "$cur" == "on" ]]; then
      set_state "off"
    else
      set_state "on"
    fi
    ;;
  on|enable|true|1)
    set_state "on"
    ;;
  off|disable|false|0)
    set_state "off"
    ;;
  status|get)
    cur="$(get_current_state)"
    echo "Blur & opacity is: $cur"
    ;;
  *)
    echo "Usage: qdeck-blur [toggle|on|off|status]" >&2
    exit 1
    ;;
esac
```

---

### bin/qdeck-brightness
- **Path:** `bin/qdeck-brightness`

```bash
#!/usr/bin/env bash
# QDeck: System-independent display brightness control (qdeck-brightness / qdeck brightness)

set -e

monitor=""
no_osd=0
target=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-osd)
      no_osd=1
      shift
      ;;
    --monitor)
      monitor="$2"
      shift 2
      ;;
    *)
      target="$1"
      shift
      ;;
  esac
done

get_brightness() {
  if command -v brightnessctl >/dev/null 2>&1; then
    val=$(brightnessctl -m 2>/dev/null | head -n1 | awk -F, '{ gsub("%", "", $4); print $4 }')
    if [[ -n "$val" ]]; then
      echo "$val"
      return 0
    fi
  fi

  if [[ -d /sys/class/backlight ]]; then
    for dev in /sys/class/backlight/*; do
      if [[ -f "$dev/brightness" && -f "$dev/max_brightness" ]]; then
        cur=$(cat "$dev/brightness" 2>/dev/null || echo 0)
        max=$(cat "$dev/max_brightness" 2>/dev/null || echo 1)
        if [[ $max -gt 0 ]]; then
          echo $(( cur * 100 / max ))
          return 0
        fi
      fi
    done
  fi

  echo "100"
}

if [[ -z "$target" ]]; then
  get_brightness
  exit 0
fi

# Clean target percentage
target_clean="${target%\%}"

if command -v brightnessctl >/dev/null 2>&1; then
  if [[ -n "$monitor" ]] && brightnessctl --device "$monitor" info >/dev/null 2>&1; then
    brightnessctl --device "$monitor" set "${target_clean}%" >/dev/null 2>&1 || true
  else
    brightnessctl set "${target_clean}%" >/dev/null 2>&1 || true
  fi
elif [[ -d /sys/class/backlight ]]; then
  for dev in /sys/class/backlight/*; do
    if [[ -w "$dev/brightness" && -f "$dev/max_brightness" ]]; then
      max=$(cat "$dev/max_brightness" 2>/dev/null || echo 1)
      val=$(( target_clean * max / 100 ))
      echo "$val" > "$dev/brightness" 2>/dev/null || true
    fi
  done
fi

res=$(get_brightness)
if [[ "$no_osd" -eq 0 ]]; then
  qdeck-osd -i "brightness" -p "$res" >/dev/null 2>&1 || true
fi
echo "$res"
```

---

### bin/qdeck-clipboard
- **Path:** `bin/qdeck-clipboard`

```bash
#!/usr/bin/env bash
# ==============================================================================
# QDeck: Text-Only Clipboard Manager CLI (qdeck-clipboard / qdeck clipboard)
# Backed by wl-clipboard (wl-copy, wl-paste)
# ==============================================================================
set -euo pipefail

CMD="${1:-toggle}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/clipboard-history.json"
FALLBACK_STATE_FILE="$HOME/.local/state/quickshell/clipboard-history.json"

# Source shared IPC helper
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
elif command -v qdeck-ipc >/dev/null 2>&1; then
  source "$(command -v qdeck-ipc)"
fi

invoke_clipboard() {
  local method="$1"; shift
  call_ipc clipboard "$method" "$@"
}

case "$CMD" in
  toggle)
    invoke_clipboard toggle || true
    ;;
  open|show)
    invoke_clipboard open || true
    ;;
  close|hide)
    invoke_clipboard close || true
    ;;
  clear)
    if ! invoke_clipboard clear 2>/dev/null; then
      # If quickshell IPC is not reachable, clear state file and Wayland clipboard directly
      python3 -c "
import os, json
p = os.path.expanduser('$STATE_FILE')
if os.path.exists(p):
    with open(p, 'w') as f:
        json.dump([], f)
" 2>/dev/null || true
      if command -v wl-copy >/dev/null 2>&1; then
        wl-copy -c 2>/dev/null || true
      fi
      echo "cleared"
    fi
    ;;
  list)
    if ! invoke_clipboard list 2>/dev/null; then
      if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
      else
        echo "[]"
      fi
    fi
    ;;
  count)
    if ! invoke_clipboard count 2>/dev/null; then
      python3 -c "
import os, json
p = os.path.expanduser('$STATE_FILE')
if os.path.exists(p):
    try:
        data = json.load(open(p))
        print(len(data) if isinstance(data, list) else 0)
    except Exception:
        print(0)
else:
    print(0)
" 2>/dev/null || echo "0"
    fi
    ;;
  copy)
    shift
    INDEX="${1:-0}"
    if ! invoke_clipboard copy "$INDEX" 2>/dev/null; then
      python3 -c "
import os, json, subprocess, sys
p = os.path.expanduser('$STATE_FILE')
idx = int(sys.argv[1]) if len(sys.argv) > 1 else 0
if os.path.exists(p):
    try:
        data = json.load(open(p))
        if isinstance(data, list) and 0 <= idx < len(data):
            text = data[idx].get('text', '')
            if text:
                subprocess.run(['wl-copy', '--', text], check=True)
                print(f'copied index {idx}')
                sys.exit(0)
    except Exception:
        pass
sys.exit(1)
" "$INDEX" 2>/dev/null || echo "failed to copy"
    fi
    ;;
  remove|delete)
    shift
    INDEX="${1:-0}"
    if ! invoke_clipboard remove "$INDEX" 2>/dev/null; then
      python3 -c "
import os, json, sys
p = os.path.expanduser('$STATE_FILE')
idx = int(sys.argv[1]) if len(sys.argv) > 1 else 0
if os.path.exists(p):
    try:
        data = json.load(open(p))
        if isinstance(data, list) and 0 <= idx < len(data):
            del data[idx]
            with open(p, 'w') as f:
                json.dump(data, f, indent=2)
            print(f'removed index {idx}')
    except Exception:
        pass
" "$INDEX" 2>/dev/null || echo "ok"
    fi
    ;;
  help|-h|--help)
    cat <<EOF
Usage: qdeck-clipboard [command]

Commands:
  toggle          Toggle clipboard history view (default)
  open            Open clipboard history view
  close           Close clipboard history view
  clear           Clear all text clipboard history
  list            Dump clipboard history JSON
  count           Print number of history entries
  copy <index>    Copy item at <index> to Wayland clipboard
  remove <index>  Remove item at <index> from history
EOF
    ;;
  *)
    echo "Unknown clipboard command '$CMD'. Run 'qdeck-clipboard --help' for usage." >&2
    exit 1
    ;;
esac
```

---

### bin/qdeck-clipboard-monitor
- **Path:** `bin/qdeck-clipboard-monitor`

```bash
#!/usr/bin/env bash
# ==============================================================================
# QDeck: Event-driven clipboard monitor daemon backed by wl-clipboard
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_RECORD="$SCRIPT_DIR/qdeck-clipboard-record.py"

if ! command -v wl-paste >/dev/null 2>&1; then
  echo "Error: wl-paste (wl-clipboard) not found." >&2
  exit 1
fi

if [[ ! -f "$PYTHON_RECORD" ]]; then
  echo "Error: Clipboard recorder '$PYTHON_RECORD' not found." >&2
  exit 1
fi

export PYTHONUNBUFFERED=1
exec wl-paste -t text --watch python3 "$PYTHON_RECORD"
```

---

### bin/qdeck-clipboard-record.py
- **Path:** `bin/qdeck-clipboard-record.py`

```bash
#!/usr/bin/env python3
"""
QDeck Clipboard Recorder
Event-driven recorder invoked by `wl-paste -t text --watch`.
Validates plain text, updates persistent JSON state, and emits a single JSON line to stdout.
"""
import sys
import os
import json
import time

runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
STATE_DIR = os.path.join(runtime_dir, "quickshell") if os.path.isdir(runtime_dir) else os.path.expanduser("~/.local/state/quickshell")
STATE_FILE = os.path.join(STATE_DIR, "clipboard-history.json")
MAX_ITEMS = 100
MAX_CHAR_COUNT = 150000

def main():
    try:
        raw = sys.stdin.read()
    except Exception:
        sys.exit(0)

    if not raw:
        sys.exit(0)

    # Strictly text-only: reject empty, whitespace only, or binary data (null bytes)
    if not raw.strip() or chr(0) in raw:
        sys.exit(0)

    # Cap if excessively large
    if len(raw) > MAX_CHAR_COUNT:
        raw = raw[:MAX_CHAR_COUNT]

    now = int(time.time())
    lines = raw.splitlines()
    line_count = len(lines)
    char_count = len(raw)

    os.makedirs(STATE_DIR, exist_ok=True)

    items = []
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    items = data
        except Exception:
            items = []

    # De-duplicate: remove previous entry with identical text
    items = [it for it in items if isinstance(it, dict) and it.get("text") != raw]

    entry = {
        "id": f"{int(time.time() * 1000)}",
        "text": raw,
        "timestamp": now,
        "lines": line_count,
        "chars": char_count
    }

    items.insert(0, entry)
    if len(items) > MAX_ITEMS:
        items = items[:MAX_ITEMS]

    # Write atomically
    tmp_file = STATE_FILE + ".tmp"
    try:
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(items, f, ensure_ascii=False, indent=2)
        os.replace(tmp_file, STATE_FILE)
    except Exception:
        pass

    # Emit JSON line on stdout for Quickshell SplitParser
    try:
        print(json.dumps(entry, ensure_ascii=False), flush=True)
    except Exception:
        pass

if __name__ == "__main__":
    main()
```

---

### bin/qdeck-display-text-size
- **Path:** `bin/qdeck-display-text-size`

```bash
#!/usr/bin/env bash
# QDeck: Manage QDeck + system typography and text scale (qdeck-display-text-size / qdeck text-size)
# No external dependencies beyond gsettings (gtk3) and common terminal config files.

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/text-size"
MIN=9
MAX=20
GKEY_SCHEMA="org.gnome.desktop.interface"
GKEY_NAME="text-scaling-factor"
SHELL_DEFAULT_PX=12
TERM_DEFAULT_PT=9

# Helper to get current GTK font point size
gtk_font_pt() {
  local name pt
  name="$(gsettings get "$GKEY_SCHEMA" font-name 2>/dev/null || echo "")"
  pt="${name%\'}"
  pt="${pt##* }"
  if [[ $pt =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "$pt"
  else
    echo 11
  fi
}

# Helper to update terminal font sizes
set_terminal_size() {
  local pt="$1"
  if [[ -f ~/.config/alacritty/alacritty.toml ]]; then
    sed -i -E "s/^size[[:space:]]*=.*/size = $pt/" ~/.config/alacritty/alacritty.toml
  fi
  if [[ -f ~/.config/kitty/kitty.conf ]]; then
    if grep -qE '^[[:space:]]*font_size[[:space:]]+' ~/.config/kitty/kitty.conf 2>/dev/null; then
      sed --follow-symlinks -i -E "s/^[[:space:]]*font_size[[:space:]]+.*/font_size $pt.0/" ~/.config/kitty/kitty.conf
    else
      printf '\nfont_size %s.0\n' "$pt" >>~/.config/kitty/kitty.conf
    fi
    pkill -USR1 kitty 2>/dev/null || true
  fi
  if [[ -f ~/.config/ghostty/config ]]; then
    sed -i -E "s/^font-size = .*/font-size = $pt/" ~/.config/ghostty/config
    pkill -SIGUSR2 ghostty 2>/dev/null || true
  fi
  if [[ -f ~/.config/foot/foot.ini ]]; then
    sed -i -E "s/(:size=)[0-9.]+/\1$pt/" ~/.config/foot/foot.ini
  fi
}

# --- GET current size ---
if [[ $# -eq 0 || -z "$1" ]]; then
  if [[ -f "$CONFIG_FILE" ]]; then
    size=$(cat "$CONFIG_FILE" 2>/dev/null || echo "12")
  else
    size="12"
  fi
  echo "text size: ${size} px"
  exit 0
fi

# --- SET new size ---
size="$1"

# Validate range
if ! [[ "$size" =~ ^[0-9]+$ ]] || [[ "$size" -lt "$MIN" || "$size" -gt "$MAX" ]]; then
  echo "Error: size must be an integer between $MIN and $MAX" >&2
  exit 1
fi

mkdir -p "$(dirname "$CONFIG_FILE")"
echo "$size" >"$CONFIG_FILE"

# GTK text-scaling-factor
fpt="$(gtk_font_pt)"
factor=$(awk -v s="$size" -v b="$SHELL_DEFAULT_PX" -v f="$fpt" \
  'BEGIN { printf "%.4f", int(f * s / b + 0.5) / f }')
gsettings set "$GKEY_SCHEMA" "$GKEY_NAME" "$factor" 2>/dev/null || true

# Terminal font size (proportional)
term_pt=$(awk -v s="$size" -v p="$TERM_DEFAULT_PT" -v b="$SHELL_DEFAULT_PX" \
  'BEGIN { printf "%d", int(s * p / b + 0.5) }')
set_terminal_size "$term_pt"

echo "text size: ${size} px"
```

---

### bin/qdeck-dns
- **Path:** `bin/qdeck-dns`

```bash
#!/usr/bin/env bash
# QDeck: Arch Linux DNS configuration and query utility for QDeck
# Supports: Cloudflare (IPv4+IPv6), Google (IPv4+IPv6), DHCP
#
# Optional: To allow passwordless DNS switching for wheel users without Polkit prompts,
# create /etc/polkit-1/rules.d/50-nm-dns.rules with:
#   polkit.addRule(function(action, subject) {
#       if (action.id == "org.freedesktop.NetworkManager.settings.modify.system" &&
#           subject.isInGroup("wheel")) {
#           return polkit.Result.YES;
#       }
#   });
set -euo pipefail

PROVIDER="${1:-}"
DNS_STATE_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/dns-provider}"

# ─────────────────────────────────────────────────────────────────────────────
# 1. Query Mode (zero arguments or empty string)
# ─────────────────────────────────────────────────────────────────────────────
if [[ $# -eq 0 || -z "$PROVIDER" ]]; then
  # Check cached state file first using built-in redirection (zero subshells)
  if [[ -f "$DNS_STATE_FILE" ]]; then
    saved="$(< "$DNS_STATE_FILE")"
    saved="${saved//[[:space:]]/}"
    if [[ "$saved" =~ ^(Cloudflare|Google|DHCP)$ ]]; then
      echo "$saved"
      exit 0
    fi
  fi

  # Fallback 1: Inspect systemd-resolved active DNS
  if command -v resolvectl >/dev/null 2>&1; then
    dns_servers="$(resolvectl dns 2>/dev/null)" || dns_servers=""
    if [[ "$dns_servers" == *"1.1.1.1"* || "$dns_servers" == *"2606:4700:4700::1111"* ]]; then
      echo "Cloudflare"
      exit 0
    elif [[ "$dns_servers" == *"8.8.8.8"* || "$dns_servers" == *"2001:4860:4860::8888"* ]]; then
      echo "Google"
      exit 0
    fi
  fi

  # Fallback 2: Inspect NetworkManager active DNS
  if command -v nmcli >/dev/null 2>&1; then
    nm_dns="$(nmcli -t -f IP4.DNS,IP6.DNS dev show 2>/dev/null)" || nm_dns=""
    if [[ "$nm_dns" == *"1.1.1.1"* || "$nm_dns" == *"2606:4700:4700::1111"* ]]; then
      echo "Cloudflare"
      exit 0
    elif [[ "$nm_dns" == *"8.8.8.8"* || "$nm_dns" == *"2001:4860:4860::8888"* ]]; then
      echo "Google"
      exit 0
    fi
  fi

  echo "DHCP"
  exit 0
fi

if [[ "$PROVIDER" == "-h" || "$PROVIDER" == "--help" ]]; then
  echo "Usage: qdeck-dns [Cloudflare|Google|DHCP] [STATE_FILE]"
  echo "       qdeck-dns                    (Query active provider)"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. Validate Provider & Define IPv4 + IPv6 Targets
# ─────────────────────────────────────────────────────────────────────────────
case "$PROVIDER" in
  Cloudflare)
    IPV4_DNS="1.1.1.1 1.0.0.1"
    IPV6_DNS="2606:4700:4700::1111 2606:4700:4700::1001"
    IGNORE_AUTO_DNS="yes"
    ;;
  Google)
    IPV4_DNS="8.8.8.8 8.8.4.4"
    IPV6_DNS="2001:4860:4860::8888 2001:4860:4860::8844"
    IGNORE_AUTO_DNS="yes"
    ;;
  DHCP)
    IPV4_DNS=""
    IPV6_DNS=""
    IGNORE_AUTO_DNS="no"
    ;;
  *)
    echo "Error: Unknown DNS provider '$PROVIDER'. Expected 'Cloudflare', 'Google', or 'DHCP'." >&2
    exit 1
    ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
# 3. Conditional Polkit Elevation Helper
# ─────────────────────────────────────────────────────────────────────────────
# Returns 0 if current process can modify NetworkManager without interactive prompt
can_modify_nm() {
  if [[ $EUID -eq 0 ]]; then
    return 0
  fi

  # Check via pkcheck for passwordless authorization
  if command -v pkcheck >/dev/null 2>&1; then
    if pkcheck -a "org.freedesktop.NetworkManager.settings.modify.system" -p "$$" >/dev/null 2>&1; then
      return 0
    fi
  fi

  # Fallback: check nmcli cached permissions table
  if command -v nmcli >/dev/null 2>&1; then
    local perm
    perm="$(nmcli general permissions 2>/dev/null | awk '$1 == "org.freedesktop.NetworkManager.settings.modify.system" {print $2}')" || perm=""
    if [[ "$perm" == "yes" ]]; then
      return 0
    fi
  fi

  return 1
}

# Returns 0 if current process can modify systemd-resolved without interactive prompt
can_modify_resolved() {
  if [[ $EUID -eq 0 ]]; then
    return 0
  fi

  if command -v pkcheck >/dev/null 2>&1; then
    if pkcheck -a "org.freedesktop.resolve1.set-dns-servers" -p "$$" >/dev/null 2>&1; then
      return 0
    fi
  fi

  return 1
}

# Elevate via pkexec only if required
elevate_if_needed() {
  local check_fn="$1"
  if ! "$check_fn"; then
    if command -v pkexec >/dev/null 2>&1; then
      exec pkexec --disable-internal-agent env \
        PATH="$PATH" \
        PKEXEC_CALLER_UID="${UID:-1000}" \
        "$0" "$PROVIDER" "$DNS_STATE_FILE"
    else
      echo "Error: Modifying network settings requires root privileges or pkexec." >&2
      exit 1
    fi
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Apply DNS Settings
# ─────────────────────────────────────────────────────────────────────────────
modified_count=0

# Primary Path: NetworkManager (nmcli)
if command -v nmcli >/dev/null 2>&1; then
  # Ensure we have required privileges before starting batch operations
  elevate_if_needed can_modify_nm

  # Parse active Wi-Fi and Ethernet connections
  while IFS=: read -r uuid type dev; do
    [[ -z "$uuid" || -z "$dev" ]] && continue
    case "$type" in
      802-11-wireless|wifi|ethernet|802-3-ethernet)
        # Apply IPv4 and IPv6 resolvers simultaneously to prevent IPv6 DNS leaks
        if ! nmcli con mod "$uuid" \
             ipv4.ignore-auto-dns "$IGNORE_AUTO_DNS" \
             ipv4.dns "$IPV4_DNS" \
             ipv6.ignore-auto-dns "$IGNORE_AUTO_DNS" \
             ipv6.dns "$IPV6_DNS"; then
          echo "Error: Failed to modify DNS settings on connection $uuid ($dev)" >&2
          continue
        fi

        # Dynamically reapply settings; fallback to con up if reapply is unsupported
        if ! nmcli dev reapply "$dev" >/dev/null 2>&1; then
          if ! nmcli con up "$uuid" >/dev/null 2>&1; then
            echo "Warning: Reapplication failed for device '$dev' (connection '$uuid')" >&2
          fi
        fi

        ((modified_count++)) || true
        ;;
    esac
  done < <(nmcli -t -f UUID,TYPE,DEVICE con show --active 2>/dev/null || true)
fi

# Fallback Path: Pure systemd-resolved (resolvectl)
if [[ $modified_count -eq 0 ]] && command -v resolvectl >/dev/null 2>&1; then
  dev="$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1)" || dev=""
  if [[ -n "$dev" ]]; then
    elevate_if_needed can_modify_resolved

    case "$PROVIDER" in
      Cloudflare)
        resolvectl dns "$dev" 1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001
        ;;
      Google)
        resolvectl dns "$dev" 8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
        ;;
      DHCP)
        resolvectl revert "$dev"
        ;;
    esac

    ((modified_count++)) || true
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. Finalize State File & Exit
# ─────────────────────────────────────────────────────────────────────────────
if [[ $modified_count -gt 0 ]]; then
  mkdir -p "$(dirname "$DNS_STATE_FILE")" 2>/dev/null || true
  echo "$PROVIDER" > "$DNS_STATE_FILE"

  # If running under pkexec, restore ownership of the state file to calling user
  if [[ -n "${PKEXEC_CALLER_UID:-}" && $EUID -eq 0 ]]; then
    chown "$PKEXEC_CALLER_UID" "$DNS_STATE_FILE" 2>/dev/null || true
  fi

  echo "$PROVIDER"
  exit 0
else
  echo "Error: No active network connections or interfaces found to apply DNS." >&2
  exit 1
fi
```

---

### bin/qdeck-ipc
- **Path:** `bin/qdeck-ipc`

```bash
#!/usr/bin/env bash
# QDeck: Centralized QuickShell IPC Dispatcher & Shared Library (qdeck-ipc)
# Provides fallback socket resolution and uniform IPC dispatching across CLI tools.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared IPC caller
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
fi

# If executed directly as a standalone binary
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 2 ]]; then
    echo "Usage: qdeck-ipc <target> <method> [args...]" >&2
    exit 1
  fi
  call_ipc "$@"
fi
```

---

### bin/qdeck-launch-terminal
- **Path:** `bin/qdeck-launch-terminal`

```bash
#!/usr/bin/env bash
# QDeck: System-independent floating terminal launcher (qdeck-launch-terminal / qdeck terminal)

TERM_BIN=""
for t in "$TERMINAL" foot kitty alacritty ghostty wezterm gnome-terminal xfce4-terminal xterm; do
  if [[ -n "$t" ]] && command -v "$t" >/dev/null 2>&1; then
    TERM_BIN="$t"
    break
  fi
done

if [[ -z "$TERM_BIN" ]]; then
  echo "No terminal emulator found" >&2
  exit 1
fi

case "$TERM_BIN" in
  foot)
    exec foot --app-id=floating-terminal "$@"
    ;;
  kitty)
    exec kitty --class=floating-terminal "$@"
    ;;
  alacritty)
    exec alacritty --class=floating-terminal -e "$@"
    ;;
  ghostty)
    exec ghostty --class=floating-terminal -e "$@"
    ;;
  wezterm)
    exec wezterm start --class=floating-terminal -- "$@"
    ;;
  *)
    exec "$TERM_BIN" -e "$@"
    ;;
esac
```

---

### bin/qdeck-launcher
- **Path:** `bin/qdeck-launcher`

```bash
#!/usr/bin/env bash
# QDeck: Application and command launcher controller (qdeck-launcher / qdeck launcher)
set -euo pipefail

CMD="${1:-toggle}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source shared IPC helper
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
elif command -v qdeck-ipc >/dev/null 2>&1; then
  source "$(command -v qdeck-ipc)"
fi

case "$CMD" in
  toggle)
    call_ipc launcher toggle
    ;;
  open)
    call_ipc launcher open
    ;;
  close)
    call_ipc launcher close
    ;;
  apps|run|files|windows)
    call_ipc launcher setMode "$CMD"
    call_ipc launcher open
    ;;
  search)
    QUERY="${2:-}"
    call_ipc launcher search "$QUERY"
    ;;
  *)
    call_ipc launcher toggle
    ;;
esac
```

---

### bin/qdeck-lockstate-monitor
- **Path:** `bin/qdeck-lockstate-monitor`

```bash
ELF          >    P      @       �8          @ 8  @         @       @       @       H      H                   �      �      �                                                         x      x                                        U      U                                           h      h                   �-      �=      �=      �      �                   �-      �=      �=      �      �                   �      �      �      $       $                    "      "      "      @       @                    H"      H"      H"                             S�td   "      "      "      @       @              P�td   x       x       x       4       4              T�td   �!      �!      �!      �       �              Q�td                                                  R�td   �-      �=      �=      0      0                      GNU zN�Y�Gu���B��Nz�Z
/lib64/ld-linux-x86-64.so.2                          )�                                                  8                      �                       
                      ^                      e                      '                      �                                             "                      3                      J                      �                       O   "                   ,     X@              globfree __stack_chk_fail fflush poll read stdout open __libc_start_main glob __cxa_finalize printf lseek libc.so.6 GLIBC_2.27 GLIBC_2.4 GLIBC_2.34 GLIBC_2.2.5 _ITM_deregisterTMCloneTable __gmon_start__ _ITM_registerTMCloneTable                         k          ���   u      ii
   �      ���   �      ui	   �       �=             @      �=             �      P@             P@      �?                    �?                    �?                    �?         
           �?                    X@                     @                    @                    @                    @                     @                    (@         	           0@         
           8@                    @@                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ��H��H��/  H��t��H���     �5�/  �%�/  @ �%�/  h    ������%�/  h   ������%�/  h   ������%�/  h   �����%�/  h   �����%�/  h   �����%�/  h   �����%�/  h   �p����%�/  h   �`���AWAVAUATUSH��HdH�<%(   H�|$8H�=E  �h  H�=a  ���Z  �����  �߉D$�  A�ą�x9A�
   �l$ D�t$$����  H��  L�|$ H�D$H��  H�D$�   H��  A�
   L�|$ H�D$H��  H�D$ H�=�  ��  �ǉ��;  �D$���"  �<   �   L���\$ D�t$$�������yl���	  ���t4D9�t/��H�5=  A��H�|$H�+  HE�1��l���H�=m.  �������x����l$ D�t$$�<   �   L���\$(D�t$,�t������  A�Ń��t�;D$�{���E��H��
  H�|$H�5�
  HE�1������H�=�-  ��������   H�=�
  �l$ D�t$$��  �ǉ��8  �<   �   L��A����������  ���t�D9�t�A���E1��,�     �������H�=Y
  E1��y  �ǉ���  �D$H�=e
  �`  �ǉ���  D��<   L��A��������x�D�l$�H��  A�   L�|$ H�D$H��  H�D$�D�l$�j���f.�     ��1�I��^H��H���PTE1�1�H�=Q����K,  �f.�     H�=�,  H��,  H9�tH�.,  H��t	���    ��    H�=�,  H�5�,  H)�H��H��?H��H�H��tH��+  H��t��fD  ��    ���=e,   u3UH�=�+   H��t
H�=>,  ��+  �c����<,  ]�f.�     �@ ff.�     ���g����    S1�1�H��PdH�%(   H�L$HH���A�����u=H�<$ t6H�D$1�H�81�������H������H�D$HdH+%(   uH��P��[� �����������@ H��8dH�%(   H�D$(1���xP1�1��|$�{���H���t=�|$H�t$�   �r����������~&�T$�   ��1t1���0�����fD  �����H�T$(dH+%(   uH��8������ ��H��H���                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             ON OFF NUMLOCK:%s
 CAPSLOCK:%s
     /sys/class/leds/*numlock*/brightness    /sys/class/leds/*capslock*/brightness   ;4      ����h   H����   ����P   �����   H����              zR x�        ����&    D    $   4   8����    FJw� ?;*3$"        \   @���l    A�H`P
CD    �   �����    D@}
A 0   �   p����   B�B�B �B(�A0�A8�D�     �� �               0   ��������   
   ���������      ��������&                                     0      GNU � �           �           �                   GNU                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       @      �             k                     
       H             �=                           �=                    ���o    �             p             �      
       �                                           �?             �                            �             �             �       	              ���o           ���o    x      ���o           ���o    V      ���o                                                                                                                                   �=                      6      F      V      f      v      �      �      �      �              P@      GCC: (GNU) 16.2.1 20260810                                  ��                	     H"                  ��                -     P      l       6     �      �       C    ��                O     �              Q     �              d     �              z     `@             �     �=              �     @              �     �=              �    ��                �     |!                   ��                �     �=              �      x                   �?              "                     7                     T                      p    X@             �     H@              �    X@              �  
 H              �                     �                     �                     �                     �    H@              �                      �   P@              
                                        ,    h@              �    P      &       1    X@              =    �      �      B                     S                     d                     t   X@              �                      �  "                   �  
                 Scrt1.o __abi_tag qdeck-lockstate-monitor.c open_led read_led_val crtbeginS.o deregister_tm_clones __do_global_dtors_aux completed.0 __do_global_dtors_aux_fini_array_entry frame_dummy __frame_dummy_init_array_entry crtendS.o __FRAME_END__ _DYNAMIC __GNU_EH_FRAME_HDR _GLOBAL_OFFSET_TABLE_ globfree@GLIBC_2.2.5 __libc_start_main@GLIBC_2.34 _ITM_deregisterTMCloneTable stdout@GLIBC_2.2.5 _edata _fini __stack_chk_fail@GLIBC_2.4 printf@GLIBC_2.2.5 lseek@GLIBC_2.2.5 read@GLIBC_2.2.5 __data_start __gmon_start__ __dso_handle _IO_stdin_used fflush@GLIBC_2.2.5 _end __bss_start main poll@GLIBC_2.2.5 open@GLIBC_2.2.5 glob@GLIBC_2.27 __TMC_END__ _ITM_registerTMCloneTable __cxa_finalize@GLIBC_2.2.5 _init  .symtab .strtab .shstrtab .note.gnu.build-id .interp .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn .rela.plt .init .text .fini .rodata .eh_frame_hdr .eh_frame .sframe .note.gnu.property .note.ABI-tag .init_array .fini_array .dynamic .got .got.plt .data .bss .comment                                                                                     �      �      $                              .             �      �                                    6   ���o       �      �      $                             @             �      �      �                          H             p      p      �                              P   ���o       V      V                                   ]   ���o       x      x      P                            l             �      �      �                            v      B       �      �      �                           �                                                         {                           �                             �             �      �      �                             �             H      H      
                              �                             v                              �             x       x       4                              �             �       �       �                              �   ���o       �!      �!      l                              �             "      "      @                              �             H"      H"                                     �             �=      �-                                   �             �=      �-                                   �             �=      �-      �                           �             �?      �/      (                                         �?      �/      `                             
            H@      H0                                                X@      X0                                         0               X0                                                         x0      h                          	                      �4      �                                                   �7                                   
```

---

### bin/qdeck-monitor-scaling
- **Path:** `bin/qdeck-monitor-scaling`

```bash
#!/usr/bin/env bash
# QDeck: Hyprland monitor scaling query and adjustment for QDeck

set -e

# Print current scale of the focused monitor (or first monitor)
focused_scale() {
  hyprctl monitors -j 2>/dev/null \
    | jq -r '([.[] | select(.focused == true)][0] // .[0]).scale // 1' 2>/dev/null \
    || echo "1"
}

if [[ $# -eq 0 || -z "$1" ]]; then
  focused_scale
  exit 0
fi

scale="$1"

# Get focused (or first) monitor info
monitor_info=$(hyprctl monitors -j 2>/dev/null \
  | jq -e -c '([.[] | select(.focused == true)][0] // .[0])' 2>/dev/null || true)

if [[ -z "$monitor_info" || "$monitor_info" == "null" ]]; then
  echo "Error: could not get monitor info from hyprctl" >&2
  exit 1
fi

active_monitor=$(echo "$monitor_info" | jq -r '.name')
width=$(echo "$monitor_info" | jq -r '.width')
height=$(echo "$monitor_info" | jq -r '.height')
refresh=$(echo "$monitor_info" | jq -r '.refreshRate')

# Apply via hyprctl eval in Lua mode or keyword in legacy mode
hyprctl eval "hl.monitor({ output = '${active_monitor}', mode = '${width}x${height}@${refresh}', position = 'auto', scale = ${scale} })" \
  >/dev/null 2>&1 || \
hyprctl keyword monitor "${active_monitor},${width}x${height}@${refresh},auto,${scale}" \
  >/dev/null 2>&1 || \
hyprctl keyword monitor "${active_monitor},preferred,auto,${scale}" \
  >/dev/null 2>&1 || true

# Persist to ~/.config/hypr/monitors.conf if it exists
monitor_conf="$HOME/.config/hypr/monitors.conf"
if [[ -f "$monitor_conf" ]]; then
  # Update any line matching: monitor=<name>,...,<scale>
  sed -i -E "s|(monitor\s*=\s*${active_monitor}\s*,[^,]+,[^,]+,)[0-9.]+|\1${scale}|" \
    "$monitor_conf" 2>/dev/null || true
fi

# Also update ~/.config/hypr/hyprland.conf if it contains monitor lines
hypr_conf="$HOME/.config/hypr/hyprland.conf"
if [[ -f "$hypr_conf" ]] && grep -q "^monitor\s*=" "$hypr_conf" 2>/dev/null; then
  sed -i -E "s|(monitor\s*=\s*${active_monitor}\s*,[^,]+,[^,]+,)[0-9.]+|\1${scale}|" \
    "$hypr_conf" 2>/dev/null || true
fi

# Update GDK scale for fractional: round to nearest integer
new_gdk_scale=$(awk -v s="$scale" 'BEGIN { printf "%d", int(s + 0.5) }')
if [[ "$new_gdk_scale" -ge 1 ]]; then
  gsettings set org.gnome.desktop.interface scaling-factor "$new_gdk_scale" 2>/dev/null || true
  export GDK_SCALE="$new_gdk_scale"
fi

echo "$scale"
```

---

### bin/qdeck-monitor-state
- **Path:** `bin/qdeck-monitor-state`

```bash
#!/usr/bin/env bash
# QDeck: System-independent monitor state query for QDeck

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATH="$SCRIPT_DIR:$HOME/.local/bin:$PATH"

monitors_json=$(hyprctl monitors all -j 2>/dev/null || echo "[]")
if [[ "$monitors_json" == "[]" || -z "$monitors_json" ]]; then
  # Fallback if hyprctl is not running
  echo "100"
  echo "default"
  echo ""
  echo "default"
  echo ""
  echo "default"
  echo "1"
  echo '[{"name":"default","enabled":true,"focused":true,"width":1920,"height":1080}]'
  exit 0
fi

focused_monitor=$(echo "$monitors_json" | jq -r '[.[] | select(.focused == true)][0].name // ""' 2>/dev/null || echo "")
if [[ -z "$focused_monitor" ]]; then
  focused_monitor=$(echo "$monitors_json" | jq -r '.[0].name // "eDP-1"' 2>/dev/null || echo "eDP-1")
fi

# Line 0: brightness
brightness=$(qdeck-brightness 2>/dev/null || echo "100")
echo "$brightness"

# Lines 1-4: internal, external, active internal, mirrorOf
echo "$monitors_json" | jq -r '
  def internal: test("^(eDP|LVDS|DSI)-");
  ([.[] | select(.name | internal)][0].name // ""),
  ([.[] | select((.name | internal) | not)][0].name // ""),
  ([.[] | select((.name | internal) and .disabled != true)][0].name // ""),
  ([.[] | select(.mirrorOf != "none") | if (.name | internal) then .mirrorOf else .name end][0] // "")
' 2>/dev/null || printf "\n\n\n\n"

# Line 5: focused monitor
echo "$focused_monitor"

# Line 6: scale
scale=$(echo "$monitors_json" | jq -r --arg f "$focused_monitor" '[.[] | select(.name == $f)][0].scale // 1' 2>/dev/null || echo "1")
echo "$scale"

# Line 7: displays json
echo "$monitors_json" | jq -c '[.[] | {name, enabled:(.disabled != true), focused:(.focused == true), width, height}]' 2>/dev/null || echo "[]"
```

---

### bin/qdeck-network-qr
- **Path:** `bin/qdeck-network-qr`

```bash
#!/usr/bin/env bash
# QDeck: Generate WiFi QR Code ASCII matrix (qdeck-network-qr / qdeck wifi-qr)

set -euo pipefail

emit_meta=false
interface=""

for arg in "$@"; do
  case "$arg" in
    --meta) emit_meta=true ;;
    *) interface="$arg" ;;
  esac
done

if [[ -z "$interface" ]]; then
  route_device=$(ip route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
  if [[ -n "$route_device" && -d "/sys/class/net/$route_device/wireless" ]]; then
    interface="$route_device"
  else
    interface=$(LC_ALL=C nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2 == "wifi" && $3 ~ /^connected/ { print $1; exit }')
  fi
fi

if [[ -z "$interface" ]]; then
  echo "No active Wi-Fi connection" >&2
  exit 1
fi

uuid=$(nmcli --get-values GENERAL.CON-UUID device show "$interface" 2>/dev/null | head -n 1)
if [[ -z "$uuid" || "$uuid" == "--" ]]; then
  echo "No active Wi-Fi connection" >&2
  exit 1
fi

mapfile -t fields < <(nmcli --show-secrets --escape no --get-values \
  802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,802-11-wireless.hidden,802-11-wireless-security.wep-key0 \
  connection show uuid "$uuid" 2>/dev/null || true)

ssid="${fields[0]:-}"
key_mgmt="${fields[1]:-}"
password="${fields[2]:-}"
hidden="${fields[3]:-no}"
wep_key="${fields[4]:-}"

if [[ -z "$ssid" ]]; then
  echo "Could not read Wi-Fi name" >&2
  exit 1
fi

escape_wifi_qr() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//;/\\;}"
  value="${value//,/\\,}"
  value="${value//:/\\:}"
  printf '%s' "$value"
}

if [[ -n "$key_mgmt" && "$key_mgmt" != "none" ]]; then
  security="WPA"
elif [[ -n "$wep_key" ]]; then
  password="$wep_key"
  security="WEP"
else
  security="nopass"
fi

payload="WIFI:T:$security;S:$(escape_wifi_qr "$ssid");P:$(escape_wifi_qr "$password");"
[[ "$hidden" == "yes" ]] && payload+="H:true;"
payload+=";"

if [[ "$emit_meta" == "true" ]]; then
  printf 'meta\t%s\t%s\t%s\n' "$interface" "$security" "$ssid"
fi

if ! command -v qrencode >/dev/null 2>&1; then
  echo "qrencode not installed" >&2
  exit 1
fi

ascii=$(printf '%s' "$payload" | qrencode --type ASCII --margin 4 --output - 2>/dev/null)
while IFS= read -r line; do
  row=""
  for ((column = 0; column < ${#line}; column += 2)); do
    [[ "${line:column:2}" == *#* ]] && row+=1 || row+=0
  done
  printf '%s\n' "$row"
done <<<"$ascii"
```

---

### bin/qdeck-network-status
- **Path:** `bin/qdeck-network-status`

```bash
#!/usr/bin/env bash
# QDeck: System-independent network telemetry for QDeck

set -e

# Default interface and route
route_info=$(ip -j route show default 2>/dev/null || echo "[]")
iface=$(echo "$route_info" | jq -r '.[0].dev // ""' 2>/dev/null || echo "")
gateway=$(echo "$route_info" | jq -r '.[0].gateway // ""' 2>/dev/null || echo "")

if [[ -z "$iface" ]]; then
  iface=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')
  gateway=$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')
fi

# IP address
ip_addr=$(ip -j addr show dev "$iface" 2>/dev/null | jq -r '.[0].addr_info[]? | select(.family == "inet") | .local' 2>/dev/null | head -n1 || echo "")
[[ -z "$ip_addr" && -n "$iface" ]] && ip_addr=$(ip -4 addr show dev "$iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1 || echo "")

# Traffic Statistics
rx_bytes=0
tx_bytes=0
if [[ -n "$iface" && -r "/sys/class/net/$iface/statistics/rx_bytes" ]]; then
  rx_bytes=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
  tx_bytes=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
fi

# Connection Type & WiFi Details
conn_type="none"
ssid=""
signal_dbm=""
if [[ -n "$iface" && -d "/sys/class/net/$iface/wireless" ]] || (command -v nmcli >/dev/null 2>&1 && nmcli -t -f DEVICE,TYPE device 2>/dev/null | grep -q "^$iface:wifi"); then
  conn_type="wifi"
  if command -v nmcli >/dev/null 2>&1; then
    wifi_data=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2"\t"$3; exit}')
    ssid=$(echo "$wifi_data" | cut -f1)
    sig_pct=$(echo "$wifi_data" | cut -f2)
    if [[ -n "$sig_pct" ]]; then
      signal_dbm=$(( (sig_pct / 2) - 100 ))
    fi
  fi
elif [[ -n "$iface" && -n "$ip_addr" ]]; then
  conn_type="ethernet"
else
  # Default to wifi type if machine has wireless device
  if [[ -d "/sys/class/net/wlo1" || -d "/sys/class/net/wlan0" ]] || (command -v nmcli >/dev/null 2>&1 && nmcli -t -f TYPE device 2>/dev/null | grep -q "^wifi"); then
    conn_type="wifi"
  else
    conn_type="ethernet"
  fi
fi

# Non-blocking parallel ping checks
router_ping_ms=""
internet_ping_ms=""

tmp_dir="/tmp/qdeck-ping-$UID"
mkdir -p "$tmp_dir" 2>/dev/null || tmp_dir="/tmp"

if [[ -n "$gateway" ]]; then
  (ping -c 1 -W 1 "$gateway" 2>/dev/null | awk -F'/' '/rtt|round-trip/ {print $5}' > "$tmp_dir/gw_$$" 2>/dev/null || true) &
fi
(ping -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F'/' '/rtt|round-trip/ {print $5}' > "$tmp_dir/net_$$" 2>/dev/null || true) &

timeout 0.35s wait 2>/dev/null || true

[[ -f "$tmp_dir/gw_$$" ]] && router_ping_ms=$(cat "$tmp_dir/gw_$$" 2>/dev/null || true) && rm -f "$tmp_dir/gw_$$" 2>/dev/null
[[ -f "$tmp_dir/net_$$" ]] && internet_ping_ms=$(cat "$tmp_dir/net_$$" 2>/dev/null || true) && rm -f "$tmp_dir/net_$$" 2>/dev/null

wifi_radio="enabled"
if command -v nmcli >/dev/null 2>&1; then
  wifi_radio=$(nmcli -t -f WIFI general status 2>/dev/null || echo "enabled")
fi

printf "iface\t%s\n" "${iface:-none}"
printf "ip\t%s\n" "${ip_addr:-}"
printf "gateway\t%s\n" "${gateway:-}"
printf "rx_bytes\t%s\n" "${rx_bytes:-0}"
printf "tx_bytes\t%s\n" "${tx_bytes:-0}"
printf "type\t%s\n" "${conn_type:-wifi}"
printf "ssid\t%s\n" "${ssid:-}"
printf "signal_dbm\t%s\n" "${signal_dbm:--50}"
printf "router_ping_ms\t%s\n" "${router_ping_ms:-0}"
printf "internet_ping_ms\t%s\n" "${internet_ping_ms:-0}"
printf "wifi_radio\t%s\n" "${wifi_radio:-enabled}"
```

---

### bin/qdeck-notifications
- **Path:** `bin/qdeck-notifications`

```bash
#!/usr/bin/env bash
# QDeck: Desktop Notification Manager & IPC CLI (qdeck-notifications / qdeck notify)
# Supports DND toggling, dismissal, test toasts, and drop-in compatibility
set -euo pipefail

CMD="${1:-help}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
QS_DIR="${QUICKSHELL_DIR:-$HOME/quickshell}"

# Source shared IPC helper
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
elif command -v qdeck-ipc >/dev/null 2>&1; then
  source "$(command -v qdeck-ipc)"
fi

case "$CMD" in
  toggle-dnd|toggle-silence|dnd)
    call_ipc notifications toggleDnd
    ;;

  dnd-status|status)
    call_ipc notifications dndState
    ;;

  set-dnd)
    VAL="${2:-on}"
    call_ipc notifications setDnd "$VAL"
    ;;

  dismiss-all|clear)
    call_ipc notifications dismissAll
    ;;

  dismiss-one)
    call_ipc notifications dismissOne
    ;;

  dismiss)
    SUMMARY="${2:-}"
    if [[ -z "$SUMMARY" ]]; then
      echo "Usage: qdeck-notifications dismiss <summary>" >&2
      exit 1
    fi
    call_ipc notifications dismiss "$SUMMARY"
    ;;

  invoke-last)
    call_ipc notifications invokeLast
    ;;

  count)
    call_ipc notifications count
    ;;

  ping)
    call_ipc notifications ping
    ;;

  test)
    TITLE="${2:-QDeck Notification}"
    BODY="${3:-Your QDeck desktop notification service is operating properly!}"
    URGENCY="${4:-normal}"
    ICON="${5:-}"
    
    # Try sending via IPC directly first
    PAYLOAD=$(jq -cn \
      --arg summary "$TITLE" \
      --arg body "$BODY" \
      --arg urgency "$URGENCY" \
      --arg icon "$ICON" \
      '{summary:$summary, body:$body, urgency:$urgency, icon:$icon, app:"QDeck", timeout:6000}')
    
    call_ipc notifications show "$PAYLOAD" >/dev/null 2>&1 || true
    ;;

  send)
    shift
    notify-send "$@"
    ;;

  help|--help|-h)
    cat <<EOF
Usage: qdeck-notifications <command> [args...]

Commands:
  toggle-dnd          Toggle Do Not Disturb mode
  dnd-status          Print current DND status (on/off)
  set-dnd <on|off>    Set Do Not Disturb state
  dismiss-all         Dismiss all active notification popups
  dismiss-one         Dismiss the newest notification popup
  dismiss <summary>   Dismiss notifications matching summary text
  invoke-last         Activate default action of newest notification
  count               Print active notification count
  test [title] [body] Show a test notification toast
  send [args...]      Send notification via notify-send
EOF
    ;;

  *)
    echo "Unknown command: $CMD. Run 'qdeck-notifications help' for usage." >&2
    exit 1
    ;;
esac
```

---

### bin/qdeck-osd
- **Path:** `bin/qdeck-osd`

```bash
#!/usr/bin/env bash
# QDeck: On-Screen Display CLI (qdeck-osd / qdeck osd)
set -euo pipefail

icon=""
message=""
progress=""
progress_text=""
max="100"
duration=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared IPC helper
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
elif command -v qdeck-ipc >/dev/null 2>&1; then
  source "$(command -v qdeck-ipc)"
fi

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

while (($#)); do
  case $1 in
    -i|--icon)
      if [[ $# -lt 2 ]]; then
        echo "Error: $1 requires an argument" >&2
        exit 1
      fi
      icon="$2"
      shift 2
      ;;
    -m|--message)
      if [[ $# -lt 2 ]]; then
        echo "Error: $1 requires an argument" >&2
        exit 1
      fi
      message="$2"
      shift 2
      ;;
    -p|--progress)
      if [[ $# -lt 2 ]]; then
        echo "Error: $1 requires an argument" >&2
        exit 1
      fi
      progress="$2"
      shift 2
      ;;
    --max)
      if [[ $# -lt 2 ]]; then
        echo "Error: $1 requires an argument" >&2
        exit 1
      fi
      max="$2"
      shift 2
      ;;
    -d|--duration)
      if [[ $# -lt 2 ]]; then
        echo "Error: $1 requires an argument" >&2
        exit 1
      fi
      duration="$2"
      shift 2
      ;;
    --close)
      call_ipc osd close
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -n $progress ]]; then
  progress_text="${progress}%"
fi

payload=$(printf '{"icon":"%s","message":"%s","value":"%s","progressText":"%s","max":"%s","duration":"%s"}' \
  "$(json_escape "$icon")" \
  "$(json_escape "$message")" \
  "$(json_escape "$progress")" \
  "$(json_escape "$progress_text")" \
  "$(json_escape "$max")" \
  "$(json_escape "$duration")")

call_ipc osd display "$payload" 2>/dev/null || \
call_ipc osd trigger "$icon" "$message" 2>/dev/null || true
```

---

### bin/qdeck-powermenu
- **Path:** `bin/qdeck-powermenu`

```bash
#!/usr/bin/env bash
# QDeck: Power & Session Menu controller (qdeck-powermenu / qdeck powermenu)
set -euo pipefail

CMD="${1:-toggle}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source shared IPC helper
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
elif command -v qdeck-ipc >/dev/null 2>&1; then
  source "$(command -v qdeck-ipc)"
fi

case "$CMD" in
  toggle)
    call_ipc powermenu toggle
    ;;
  open)
    call_ipc powermenu open
    ;;
  close)
    call_ipc powermenu close
    ;;
  next)
    call_ipc powermenu next
    ;;
  prev)
    call_ipc powermenu prev
    ;;
  select)
    call_ipc powermenu select "${2:-0}"
    ;;
  state|getState|status)
    call_ipc powermenu getState
    ;;
  *)
    call_ipc powermenu toggle
    ;;
esac
```

---

### bin/qdeck-qshelf
- **Path:** `bin/qdeck-qshelf`

```bash
#!/usr/bin/env bash
# QDeck: Drag-and-Drop Staging QShelf controller (qdeck-qshelf / qdeck qshelf / qdeck shelf)
set -euo pipefail

CMD="${1:-toggle}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source shared IPC helper
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
elif command -v qdeck-ipc >/dev/null 2>&1; then
  source "$(command -v qdeck-ipc)"
fi

# Wrapper that tries 'qshelf' first and falls back to 'shelf'
invoke_qshelf() {
  local method="$1"; shift
  call_ipc qshelf "$method" "$@" 2>/dev/null || call_ipc shelf "$method" "$@"
}

case "$CMD" in
  toggle)
    invoke_qshelf toggle
    ;;
  open|show)
    invoke_qshelf open
    ;;
  close|hide)
    invoke_qshelf close
    ;;
  clear)
    invoke_qshelf clear
    ;;
  list)
    invoke_qshelf list
    ;;
  count)
    invoke_qshelf count
    ;;
  add)
    shift
    for file in "$@"; do
      if ! invoke_qshelf add "$file" 2>/dev/null; then
        # QuickShell not reachable; write directly to state file so it loads on start
        python3 -c "
import json, os, sys
p = os.path.expanduser('~/.local/state/quickshell/qshelf-items.json')
os.makedirs(os.path.dirname(p), exist_ok=True)
raw = sys.argv[1]
abs_p = os.path.abspath(raw)
uri = 'file://' + abs_p
try:
    data = json.load(open(p)) if os.path.exists(p) else []
except Exception:
    data = []
if uri not in data:
    data.insert(0, uri)
    with open(p, 'w') as f:
        json.dump(data, f, indent=2)
" "$file" 2>/dev/null || true
        echo "added (persisted)"
      fi
    done
    ;;
  remove|delete)
    shift
    invoke_qshelf remove "$1"
    ;;
  select-all)
    invoke_qshelf selectAll
    ;;
  toggle-item|toggle-select)
    shift
    invoke_qshelf toggleItem "$1"
    ;;
  deselect|clear-selection)
    invoke_qshelf clearSelection
    ;;
  remove-selected)
    invoke_qshelf removeSelected
    ;;
  selected-count)
    invoke_qshelf selectedCount
    ;;
  *)
    invoke_qshelf "$CMD" "${@:2}"
    ;;
esac
```

---

### bin/qdeck-refresh-rate
- **Path:** `bin/qdeck-refresh-rate`

```bash
#!/usr/bin/env bash
# QDeck: Query, toggle or set monitor refresh rate (qdeck-refresh-rate / qdeck refresh-rate)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$SCRIPT_DIR:$PATH"

cmd="${1:-toggle}"

monitors_json=$(hyprctl monitors -j 2>/dev/null || echo "[]")
if [[ "$monitors_json" == "[]" || -z "$monitors_json" ]]; then
  echo "Error: hyprctl not running or no monitors found" >&2
  exit 1
fi

mon_info=$(echo "$monitors_json" | jq -e -c '([.[] | select(.focused == true)][0] // .[0])' 2>/dev/null)
name=$(echo "$mon_info" | jq -r '.name')
width=$(echo "$mon_info" | jq -r '.width')
height=$(echo "$mon_info" | jq -r '.height')
scale=$(echo "$mon_info" | jq -r '.scale // 1')
current_hz=$(echo "$mon_info" | jq -r '(.refreshRate // 60) | round')

# Parse available modes for this monitor
available_modes=$(echo "$mon_info" | jq -r '.availableModes[]?' 2>/dev/null || true)
max_hz=60
if [[ -n "$available_modes" ]]; then
  for m in $available_modes; do
    if [[ "$m" =~ @([0-9.]+)Hz ]]; then
      hz_float="${BASH_REMATCH[1]}"
      hz_round=$(printf "%.0f" "$hz_float")
      if (( hz_round > max_hz )); then
        max_hz="$hz_round"
      fi
    fi
  done
fi

case "$cmd" in
  get|status)
    echo "${current_hz}Hz"
    exit 0
    ;;
  toggle)
    if (( current_hz <= 60 )); then
      target_hz="$max_hz"
    else
      target_hz=60
    fi
    ;;
  [0-9]*)
    target_hz="$cmd"
    ;;
  max)
    target_hz="$max_hz"
    ;;
  *)
    echo "Usage: qdeck-refresh-rate {toggle|get|<rate>|max}"
    exit 1
    ;;
esac

# Apply to Hyprland
hyprctl eval "hl.monitor({ output = '${name}', mode = '${width}x${height}@${target_hz}', position = 'auto', scale = ${scale} })" >/dev/null 2>&1 || \
hyprctl keyword monitor "${name},${width}x${height}@${target_hz},auto,${scale}" >/dev/null 2>&1 || true

# Allow physical display modeset to complete before popping OSD
sleep 0.35

# Trigger OSD
msg="${width}x${height} @ ${target_hz}Hz"
qs ipc call osd refreshRate "$msg" >/dev/null 2>&1 || true

echo "$msg"
```

---

### bin/qdeck-screenshot
- **Path:** `bin/qdeck-screenshot`

```bash
#!/usr/bin/env bash
#
# screenshot - Fast Wayland screenshot utility powered by grim & slurp
# Supports: Hyprland, Sway, and wlroots-based compositors
#
# Features:
#   - Parameters: output, window, region, active
#   - Clipboard-only mode: 'clipboard' command or -c/--clipboard flag
#   - Single-instance limit: Kills any active screenshot/slurp instance when a new one arrives
#

set -euo pipefail

# --- Configuration & Defaults ---
APP_NAME="QDeck Screenshot"
CLIPBOARD_ONLY=0
SAVE_ONLY=0
STAGE_QSHELF=1
INCLUDE_CURSOR=0
SEND_NOTIFY=1
DELAY=0
CUSTOM_FILE=""
EXTRA_ARG=""
MODE=""
TMP_SHOT=""

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/screenshot.pid"

# Resolve default screenshot directory
if [[ -n "${XDG_SCREENSHOTS_DIR:-}" ]]; then
    SCREENSHOT_DIR="$XDG_SCREENSHOTS_DIR"
elif [[ -d "$HOME/Pictures/Screenshot" ]]; then
    SCREENSHOT_DIR="$HOME/Pictures/Screenshot"
elif [[ -d "$HOME/Pictures/Screenshots" ]]; then
    SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
elif [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs" ]]; then
    # shellcheck disable=SC1090
    source "${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs" 2>/dev/null || true
    SCREENSHOT_DIR="${XDG_SCREENSHOTS_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshot}"
else
    SCREENSHOT_DIR="$HOME/Pictures/Screenshot"
fi

# --- Process & Instance Management ---
cleanup() {
    local exit_code=$?
    # Terminate any child processes of this script (subshells, slurp, sleep)
    pkill -P "$BASHPID" 2>/dev/null || true

    # Clean up PID file if it still belongs to this process
    if [[ -f "$PID_FILE" ]]; then
        local current_pid
        current_pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ "$current_pid" == "$BASHPID" ]]; then
            rm -f "$PID_FILE"
        fi
    fi

    # Clean up temporary clipboard file if still lingering
    if [[ -n "$TMP_SHOT" && -f "$TMP_SHOT" ]]; then
        rm -f "$TMP_SHOT" 2>/dev/null || true
    fi

    exit "$exit_code"
}

kill_previous_instance() {
    # If another screenshot process is running, terminate it so the new one takes over
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ -n "$old_pid" && "$old_pid" =~ ^[0-9]+$ ]] && kill -0 "$old_pid" 2>/dev/null; then
            # Kill children of the old instance first (e.g. active slurp session or sleep)
            pkill -P "$old_pid" 2>/dev/null || true
            kill -TERM "$old_pid" 2>/dev/null || true
            sleep 0.05
            if kill -0 "$old_pid" 2>/dev/null; then
                pkill -9 -P "$old_pid" 2>/dev/null || true
                kill -9 "$old_pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi

    # Kill any lingering slurp processes to ensure the screen is clean
    pkill -x slurp 2>/dev/null || true

    # Record current instance PID
    echo "$BASHPID" > "$PID_FILE"
}

# --- Helper Functions ---
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [MODE] [EXTRA]

Parameters (Modes):
  output [MONITOR|select]  Take screenshot of an entire monitor
                           - Default: captures currently focused monitor
                           - Specific: name of monitor (e.g. eDP-1, HDMI-A-1)
                           - 'select': interactive monitor picker via slurp
  window                   Take screenshot of an open window (interactive click)
  region                   Take screenshot of selected region (click & drag)
  active                   Take screenshot of active window | output fallback

Clipboard-Only Modes & Actions:
  clipboard [MODE]         Capture directly to clipboard (default mode: region)
  copy [MODE]              Alias for clipboard mode
  -c, --clipboard          Copy to clipboard only (do not save to file)
      --clipboard-only     Copy to clipboard only

Options:
  -s, --save               Save to file only (do not copy to clipboard)
  -f, --file PATH          Specify custom save path for the screenshot image
  -d, --delay SECONDS      Wait N seconds before taking screenshot
      --cursor             Include mouse cursor in screenshot
      --shelf, --qshelf    Stage screenshot into QShelf (default: enabled)
      --no-shelf, --no-qshelf Do not stage screenshot into QShelf
  -n, --no-notify          Disable desktop notifications
  -h, --help               Display this help message and exit

Single-Instance Limit:
  If a screenshot tool request is already active (e.g. slurp waiting for selection),
  triggering this script again will automatically kill the first instance and
  start the second request immediately.

Default Behavior:
  Saves image to: $SCREENSHOT_DIR
  Stages image into QShelf
  Copies to clipboard (if wl-copy is installed)
  Sends desktop notification (if notify-send is installed)

Examples:
  $(basename "$0") region                 # Select region, save file & copy to clipboard
  $(basename "$0") clipboard              # Select region, copy to clipboard ONLY
  $(basename "$0") clipboard active       # Active window to clipboard ONLY
  $(basename "$0") -c window              # Click window to clipboard ONLY
  $(basename "$0") -c output              # Full monitor to clipboard ONLY
  $(basename "$0") active                 # Active window (or monitor fallback)
  $(basename "$0") output select          # Pick monitor interactively
  $(basename "$0") --delay 3 active       # 3-second delay before active capture
EOF
}

notify() {
    local title="$1"
    local message="$2"
    local icon="${3:-camera-photo}"

    if [[ $SEND_NOTIFY -eq 1 ]] && command -v notify-send >/dev/null 2>&1; then
        notify-send -a "$APP_NAME" -i "$icon" "$title" "$message" || true
    fi
}

add_to_qshelf() {
    local img="$1"
    [[ -f "$img" ]] || return 0

    local abs_path
    abs_path=$(realpath "$img" 2>/dev/null || readlink -f "$img" 2>/dev/null || echo "$img")
    local bin_dir
    bin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -x "$bin_dir/qdeck-qshelf" ]]; then
        "$bin_dir/qdeck-qshelf" add "$abs_path" >/dev/null 2>&1 || true
    elif command -v qdeck >/dev/null 2>&1; then
        qdeck qshelf add "$abs_path" >/dev/null 2>&1 || true
    elif command -v qs >/dev/null 2>&1; then
        qs ipc call qshelf add "$abs_path" >/dev/null 2>&1 || qs ipc call shelf add "$abs_path" >/dev/null 2>&1 || true
    fi
}

error_exit() {
    local msg="$1"
    local code="${2:-1}"
    echo "Error: $msg" >&2
    notify "$APP_NAME Error" "$msg" "dialog-error"
    exit "$code"
}

check_dependencies() {
    local missing=()
    for cmd in grim slurp; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error_exit "Missing required dependencies: ${missing[*]}" 1
    fi
}

get_active_geometry() {
    # Check Hyprland active window
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local win
        win=$(hyprctl activewindow -j 2>/dev/null || true)
        if [[ -n "$win" ]] && \
           [[ "$(echo "$win" | jq -r '.address // empty' 2>/dev/null)" != "" ]] && \
           [[ "$(echo "$win" | jq -r '.mapped // false' 2>/dev/null)" == "true" ]] && \
           [[ "$(echo "$win" | jq -r '.size[0] // 0' 2>/dev/null)" -gt 0 ]]; then
            echo "$win" | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
            return 0
        fi
    fi

    # Check Sway active window
    if command -v swaymsg >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local win
        win=$(swaymsg -t get_tree 2>/dev/null | jq -r '
            recurse(.nodes[], .floating_nodes[]) |
            select(.focused and .pid) |
            "\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)"
        ' 2>/dev/null || true)
        if [[ -n "$win" ]]; then
            echo "$win"
            return 0
        fi
    fi

    return 1
}

get_active_output() {
    # Check Hyprland focused monitor
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local out
        out=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null | head -n1 || true)
        if [[ -n "$out" ]]; then
            echo "$out"
            return 0
        fi
        # Fallback to first monitor if none explicitly focused
        out=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name // empty' 2>/dev/null || true)
        if [[ -n "$out" ]]; then
            echo "$out"
            return 0
        fi
    fi

    # Check Sway focused output
    if command -v swaymsg >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local out
        out=$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null | head -n1 || true)
        if [[ -n "$out" ]]; then
            echo "$out"
            return 0
        fi
    fi

    return 1
}

get_window_boxes() {
    # Query visible open windows in Hyprland
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local active_ws
        active_ws=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].activeWorkspace.id' 2>/dev/null || true)
        if [[ -n "$active_ws" ]]; then
            local boxes
            boxes=$(hyprctl clients -j 2>/dev/null | jq -r --arg ws "$active_ws" '
                ($ws | split("\n") | map(tonumber? // .)) as $visible |
                .[] | select(.mapped == true and .hidden == false and (.workspace.id as $wid | $visible | index($wid))) |
                "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1]) \((.title // .class // "") | gsub("[\r\n]"; " ") | .[0:40])"
            ' 2>/dev/null || true)
            if [[ -n "$boxes" ]]; then
                echo "$boxes"
                return 0
            fi
        fi

        # Fallback to all mapped windows
        hyprctl clients -j 2>/dev/null | jq -r '
            .[] | select(.mapped == true and .hidden == false) |
            "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1]) \((.title // .class // "") | gsub("[\r\n]"; " ") | .[0:40])"
        ' 2>/dev/null || true
        return 0
    fi

    # Query windows in Sway
    if command -v swaymsg >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        swaymsg -t get_tree 2>/dev/null | jq -r '
            recurse(.nodes[], .floating_nodes[]) |
            select(.visible == true and .pid) |
            "\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height) \((.name // .app_id // "") | gsub("[\r\n]"; " ") | .[0:40])"
        ' 2>/dev/null || true
        return 0
    fi

    return 1
}

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--clipboard|--clipboard-only)
            CLIPBOARD_ONLY=1
            shift
            ;;
        -s|--save)
            SAVE_ONLY=1
            shift
            ;;
        -f|--file)
            CUSTOM_FILE="$2"
            shift 2
            ;;
        -d|--delay)
            DELAY="$2"
            shift 2
            ;;
        --cursor)
            INCLUDE_CURSOR=1
            shift
            ;;
        -n|--no-notify)
            SEND_NOTIFY=0
            shift
            ;;
        --shelf|--qshelf)
            STAGE_QSHELF=1
            shift
            ;;
        --no-shelf|--no-qshelf)
            STAGE_QSHELF=0
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        clipboard|copy)
            CLIPBOARD_ONLY=1
            shift
            ;;
        save)
            SAVE_ONLY=1
            shift
            ;;
        output|window|region|active)
            MODE="$1"
            shift
            ;;
        select)
            EXTRA_ARG="select"
            shift
            ;;
        *)
            if [[ -z "$EXTRA_ARG" ]]; then
                EXTRA_ARG="$1"
            fi
            shift
            ;;
    esac
done

# If only clipboard or save action was passed without explicit mode, default to 'region'
if [[ -z "$MODE" ]]; then
    if [[ $CLIPBOARD_ONLY -eq 1 || $SAVE_ONLY -eq 1 ]]; then
        MODE="region"
    else
        show_help >&2
        exit 1
    fi
fi

check_dependencies

# Enforce single instance: kill previous running instance and claim PID
kill_previous_instance
trap cleanup EXIT INT TERM HUP

# If extra arg looks like a file path and CUSTOM_FILE wasn't given, use it
if [[ -n "$EXTRA_ARG" && "$EXTRA_ARG" =~ \.(png|jpg|jpeg|webp)$ && -z "$CUSTOM_FILE" ]]; then
    CUSTOM_FILE="$EXTRA_ARG"
    EXTRA_ARG=""
fi

# Determine target file path
if [[ $CLIPBOARD_ONLY -eq 0 || $STAGE_QSHELF -eq 1 ]]; then
    if [[ -n "$CUSTOM_FILE" ]]; then
        TARGET_FILE="$CUSTOM_FILE"
    else
        mkdir -p "$SCREENSHOT_DIR"
        TIMESTAMP=$(date +'%Y%m%d-%H%M%S')
        TARGET_FILE="${SCREENSHOT_DIR}/screenshot-${TIMESTAMP}.png"
    fi
    mkdir -p "$(dirname "$TARGET_FILE")"
fi

# Delay if requested
if (( DELAY > 0 )); then
    sleep "$DELAY"
fi

# Prepare grim target parameters
GRIM_TARGET_ARGS=()

case "$MODE" in
    output)
        # Capture an entire monitor
        if [[ -n "$EXTRA_ARG" && "$EXTRA_ARG" == "select" ]]; then
            # Interactively select a monitor display output
            GEOM=$(slurp -o 2>/dev/null) || exit 0
            [[ -z "$GEOM" ]] && exit 0
            GRIM_TARGET_ARGS=(-g "$GEOM")
        elif [[ -n "$EXTRA_ARG" ]]; then
            # Specific monitor output name passed (e.g. eDP-1, HDMI-A-1)
            GRIM_TARGET_ARGS=(-o "$EXTRA_ARG")
        else
            # Default: capture currently active/focused monitor
            ACTIVE_OUT=$(get_active_output || true)
            if [[ -n "$ACTIVE_OUT" ]]; then
                GRIM_TARGET_ARGS=(-o "$ACTIVE_OUT")
            fi
        fi
        ;;

    window)
        # Take screenshot of an open window (interactive click)
        BOXES=$(get_window_boxes || true)
        if [[ -n "$BOXES" ]]; then
            # Pass candidate open window boxes to slurp
            GEOM=$(echo "$BOXES" | slurp 2>/dev/null) || exit 0
        else
            # Fallback to standard slurp
            GEOM=$(slurp -d 2>/dev/null) || exit 0
        fi
        [[ -z "$GEOM" ]] && exit 0
        GRIM_TARGET_ARGS=(-g "$GEOM")
        ;;

    region)
        # Take screenshot of selected region (click & drag)
        GEOM=$(slurp -d 2>/dev/null) || exit 0
        [[ -z "$GEOM" ]] && exit 0
        GRIM_TARGET_ARGS=(-g "$GEOM")
        ;;

    active)
        # Take screenshot of active window, with active output as fallback
        GEOM=$(get_active_geometry || true)
        if [[ -n "$GEOM" ]]; then
            # Active window exists
            GRIM_TARGET_ARGS=(-g "$GEOM")
        else
            # No active window focused -> fallback to active monitor output
            ACTIVE_OUT=$(get_active_output || true)
            if [[ -n "$ACTIVE_OUT" ]]; then
                GRIM_TARGET_ARGS=(-o "$ACTIVE_OUT")
            fi
        fi
        ;;
esac

# Build final grim command
GRIM_CMD=(grim)
if [[ $INCLUDE_CURSOR -eq 1 ]]; then
    GRIM_CMD+=(-c)
fi
if [[ ${#GRIM_TARGET_ARGS[@]} -gt 0 ]]; then
    GRIM_CMD+=("${GRIM_TARGET_ARGS[@]}")
fi

# Execute capture
if [[ -n "${TARGET_FILE:-}" ]]; then
    if "${GRIM_CMD[@]}" "$TARGET_FILE"; then
        # Copy to clipboard unless explicitly told save-only
        if [[ $SAVE_ONLY -eq 0 ]] && command -v wl-copy >/dev/null 2>&1; then
            wl-copy --type image/png < "$TARGET_FILE" || true
        fi

        # Automatically stage into QShelf
        if [[ $STAGE_QSHELF -eq 1 ]]; then
            add_to_qshelf "$TARGET_FILE"
        fi

        NOTIFY_DESC="Mode: ${MODE}\nSaved to $(basename "$TARGET_FILE")"
        if [[ $STAGE_QSHELF -eq 1 ]]; then
            NOTIFY_DESC+="\nStaged in QShelf"
        fi
        if [[ $SAVE_ONLY -eq 0 ]]; then
            NOTIFY_DESC+="\nCopied to clipboard"
        fi
        notify "Screenshot Saved" "$NOTIFY_DESC" "$TARGET_FILE"

        echo "$TARGET_FILE"
    else
        error_exit "Failed to save screenshot to '$TARGET_FILE'." 1
    fi
else
    if ! command -v wl-copy >/dev/null 2>&1; then
        error_exit "wl-copy is required for clipboard mode." 1
    fi

    # Create temporary file in secure runtime ramfs for fast clipboard pipe & notification thumbnail
    TMP_SHOT="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/screenshot-clip.XXXXXX.png")"
    if "${GRIM_CMD[@]}" "$TMP_SHOT"; then
        wl-copy --type image/png < "$TMP_SHOT"
        notify "Screenshot Copied" "Captured ${MODE} directly to clipboard" "$TMP_SHOT"
        # Schedule cleanup of temp thumbnail in background after notification preview renders
        ( sleep 4 && rm -f "$TMP_SHOT" ) >/dev/null 2>&1 &
    else
        error_exit "Failed to capture screenshot to clipboard." 1
    fi
fi
```

---

### bin/qdeck-shelf
- **Path:** `bin/qdeck-shelf`
- **Type:** Symbolic Link -> `qdeck-qshelf`

```bash
#!/usr/bin/env bash
# QDeck: Drag-and-Drop Staging QShelf controller (qdeck-qshelf / qdeck qshelf / qdeck shelf)
set -euo pipefail

CMD="${1:-toggle}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source shared IPC helper
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
elif command -v qdeck-ipc >/dev/null 2>&1; then
  source "$(command -v qdeck-ipc)"
fi

# Wrapper that tries 'qshelf' first and falls back to 'shelf'
invoke_qshelf() {
  local method="$1"; shift
  call_ipc qshelf "$method" "$@" 2>/dev/null || call_ipc shelf "$method" "$@"
}

case "$CMD" in
  toggle)
    invoke_qshelf toggle
    ;;
  open|show)
    invoke_qshelf open
    ;;
  close|hide)
    invoke_qshelf close
    ;;
  clear)
    invoke_qshelf clear
    ;;
  list)
    invoke_qshelf list
    ;;
  count)
    invoke_qshelf count
    ;;
  add)
    shift
    for file in "$@"; do
      if ! invoke_qshelf add "$file" 2>/dev/null; then
        # QuickShell not reachable; write directly to state file so it loads on start
        python3 -c "
import json, os, sys
p = os.path.expanduser('~/.local/state/quickshell/qshelf-items.json')
os.makedirs(os.path.dirname(p), exist_ok=True)
raw = sys.argv[1]
abs_p = os.path.abspath(raw)
uri = 'file://' + abs_p
try:
    data = json.load(open(p)) if os.path.exists(p) else []
except Exception:
    data = []
if uri not in data:
    data.insert(0, uri)
    with open(p, 'w') as f:
        json.dump(data, f, indent=2)
" "$file" 2>/dev/null || true
        echo "added (persisted)"
      fi
    done
    ;;
  remove|delete)
    shift
    invoke_qshelf remove "$1"
    ;;
  select-all)
    invoke_qshelf selectAll
    ;;
  toggle-item|toggle-select)
    shift
    invoke_qshelf toggleItem "$1"
    ;;
  deselect|clear-selection)
    invoke_qshelf clearSelection
    ;;
  remove-selected)
    invoke_qshelf removeSelected
    ;;
  selected-count)
    invoke_qshelf selectedCount
    ;;
  *)
    invoke_qshelf "$CMD" "${@:2}"
    ;;
esac
```

---

### bin/qdeck-theme-switch
- **Path:** `bin/qdeck-theme-switch`

```bash
#!/usr/bin/env bash
# ==============================================================================
# QDeck: Unified Theme Discovery, Listing, Setup & Switching Engine
# Self-contained CLI: qdeck-theme-switch / qdeck theme
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
THEMES_DIR="$CONFIG_HOME/themes"
CURRENT_LINK="$THEMES_DIR/current"

# Ensure local bin is in PATH
if [[ -d "$HOME/.local/bin" ]] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

get_current_theme() {
    if [[ -L "$CURRENT_LINK" ]]; then
        basename "$(readlink -f "$CURRENT_LINK")"
    else
        echo ""
    fi
}

list_themes_json() {
    local cur
    cur="$(get_current_theme)"

    if [[ ! -d "$THEMES_DIR" ]]; then
        echo "[]"
        return 0
    fi

    local items=()
    shopt -s nullglob
    for dir in "$THEMES_DIR"/*; do
        [[ -d "$dir" && ! -L "$dir" ]] || continue
        local id
        id="$(basename "$dir")"
        [[ "$id" == .* || "$id" == "current" ]] && continue
        [[ ! -f "$dir/colors.toml" && ! -d "$dir/backgrounds" && ! -f "$dir/default.png" ]] && continue

        # Find first wallpaper matching standard formats
        local wallpaper=""
        if [[ -d "$dir/backgrounds" ]]; then
            for img in "$dir/backgrounds"/*; do
                [[ -f "$img" ]] || continue
                case "${img,,}" in
                    *.png|*.jpg|*.jpeg|*.webp|*.avif|*.bmp)
                        wallpaper="$img"
                        break
                        ;;
                esac
            done
        fi

        # Fallback to default.png or any direct image if backgrounds is empty
        if [[ -z "$wallpaper" && -f "$dir/default.png" ]]; then
            wallpaper="$(readlink -f "$dir/default.png" 2>/dev/null || echo "$dir/default.png")"
        fi

        # Human-readable display name
        local name
        name="$(echo "$id" | sed -E 's/[-_]+/ /g; s/\b([a-z])/\U\1/g')"

        local is_current=false
        if [[ "$id" == "$cur" ]]; then
            is_current=true
        fi

        # Extract icon theme from icons.theme
        local icon_theme=""
        if [[ -f "$dir/icons.theme" ]]; then
            icon_theme="$(head -n 1 "$dir/icons.theme" 2>/dev/null | tr -d '\r\n' | xargs)"
        fi

        # Extract colors from colors.toml
        get_color() {
            local k1="$1"
            local k2="${2:-}"
            local def="${3:-}"
            local v
            v="$(grep -E "^[[:space:]]*$k1[[:space:]]*=" "$dir/colors.toml" 2>/dev/null | head -n1 | sed -E 's/^[[:space:]]*[^=]+=[[:space:]]*["\x27]?([^"\x27[:space:]]+).*/\1/' | xargs)"
            if [[ -z "$v" && -n "$k2" ]]; then
                v="$(grep -E "^[[:space:]]*$k2[[:space:]]*=" "$dir/colors.toml" 2>/dev/null | head -n1 | sed -E 's/^[[:space:]]*[^=]+=[[:space:]]*["\x27]?([^"\x27[:space:]]+).*/\1/' | xargs)"
            fi
            if [[ -n "$v" ]]; then
                [[ "$v" != \#* ]] && v="#$v"
                echo "$v"
            else
                echo "$def"
            fi
        }

        local accent background foreground p_red p_green p_yellow p_blue p_magenta p_cyan
        accent="$(get_color accent "" "#7daea3")"
        background="$(get_color background "" "#282828")"
        foreground="$(get_color foreground "" "#ebdbb2")"
        p_red="$(get_color red color1 "#ea6962")"
        p_green="$(get_color green color2 "#a9b665")"
        p_yellow="$(get_color yellow color3 "#d8a657")"
        p_blue="$(get_color blue color4 "$accent")"
        p_magenta="$(get_color magenta color5 "#d3869b")"
        p_cyan="$(get_color cyan color6 "#89b482")"

        local palette_json
        palette_json="$(jq -nc \
            --arg c0 "$p_red" \
            --arg c1 "$p_green" \
            --arg c2 "$p_yellow" \
            --arg c3 "$p_blue" \
            --arg c4 "$p_magenta" \
            --arg c5 "$p_cyan" \
            '[$c0, $c1, $c2, $c3, $c4, $c5]')"

        items+=( "$(jq -n \
            --arg id "$id" \
            --arg name "$name" \
            --arg wallpaper "$wallpaper" \
            --arg iconTheme "$icon_theme" \
            --arg accent "$accent" \
            --arg background "$background" \
            --arg foreground "$foreground" \
            --argjson palette "$palette_json" \
            --argjson isCurrent "$is_current" \
            '{id: $id, name: $name, wallpaper: $wallpaper, iconTheme: $iconTheme, accent: $accent, background: $background, foreground: $foreground, palette: $palette, isCurrent: $isCurrent}')" )
    done
    shopt -u nullglob

    if [[ ${#items[@]} -eq 0 ]]; then
        echo "[]"
    else
        printf "%s\n" "${items[@]}" | jq -s .
    fi
}

apply_icon_theme() {
    local target_dir="${1:-$CURRENT_LINK}"
    local icon_file=""

    if [[ -f "$target_dir/icons.theme" ]]; then
        icon_file="$target_dir/icons.theme"
    elif [[ -f "$CURRENT_LINK/icons.theme" ]]; then
        icon_file="$CURRENT_LINK/icons.theme"
    fi

    [[ -n "$icon_file" ]] || return 0

    local icon_theme
    icon_theme="$(head -n 1 "$icon_file" 2>/dev/null | tr -d '\r\n' | xargs)"
    [[ -n "$icon_theme" ]] || return 0

    # 1. Update GSettings (GNOME / XDG desktop portal interface)
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" 2>/dev/null || true
    fi

    # 2. Update nwg-look persistent state if present
    local nwg_gsettings="$HOME/.local/share/nwg-look/gsettings"
    if [[ -f "$nwg_gsettings" ]]; then
        sed -i -E "s/^[[:space:]]*icon-theme=.*/icon-theme=$icon_theme/" "$nwg_gsettings" 2>/dev/null || true
    fi

    # 3. Synchronize via nwg-look export in background
    if command -v nwg-look >/dev/null 2>&1; then
        nwg-look -x >/dev/null 2>&1 &
    fi

    # 4. Explicitly update GTK 3.0 configuration
    local gtk3_dir="$CONFIG_HOME/gtk-3.0"
    local gtk3_file="$gtk3_dir/settings.ini"
    mkdir -p "$gtk3_dir" 2>/dev/null || true
    if [[ -f "$gtk3_file" ]]; then
        if grep -q "^[[:space:]]*gtk-icon-theme-name" "$gtk3_file"; then
            sed -i -E "s|^[[:space:]]*gtk-icon-theme-name[[:space:]]*=.*|gtk-icon-theme-name=$icon_theme|" "$gtk3_file" 2>/dev/null || true
        else
            if grep -q "^\[Settings\]" "$gtk3_file"; then
                sed -i "/^\[Settings\]/a gtk-icon-theme-name=$icon_theme" "$gtk3_file" 2>/dev/null || true
            else
                printf '[Settings]\ngtk-icon-theme-name=%s\n' "$icon_theme" >> "$gtk3_file"
            fi
        fi
    else
        printf '[Settings]\ngtk-icon-theme-name=%s\n' "$icon_theme" > "$gtk3_file"
    fi

    # 5. Explicitly update GTK 4.0 configuration
    local gtk4_dir="$CONFIG_HOME/gtk-4.0"
    local gtk4_file="$gtk4_dir/settings.ini"
    mkdir -p "$gtk4_dir" 2>/dev/null || true
    if [[ -f "$gtk4_file" ]]; then
        if grep -q "^[[:space:]]*gtk-icon-theme-name" "$gtk4_file"; then
            sed -i -E "s|^[[:space:]]*gtk-icon-theme-name[[:space:]]*=.*|gtk-icon-theme-name=$icon_theme|" "$gtk4_file" 2>/dev/null || true
        else
            if grep -q "^\[Settings\]" "$gtk4_file"; then
                sed -i "/^\[Settings\]/a gtk-icon-theme-name=$icon_theme" "$gtk4_file" 2>/dev/null || true
            else
                printf '[Settings]\ngtk-icon-theme-name=%s\n' "$icon_theme" >> "$gtk4_file"
            fi
        fi
    else
        printf '[Settings]\ngtk-icon-theme-name=%s\n' "$icon_theme" > "$gtk4_file"
    fi

    # 6. Explicitly update GTK 2.0 configuration
    local gtk2_file="$HOME/.gtkrc-2.0"
    if [[ -f "$gtk2_file" ]]; then
        if grep -q "^[[:space:]]*gtk-icon-theme-name" "$gtk2_file"; then
            sed -i -E "s|^[[:space:]]*gtk-icon-theme-name[[:space:]]*=.*|gtk-icon-theme-name=\"$icon_theme\"|" "$gtk2_file" 2>/dev/null || true
        fi
    fi

    # 7. Update xsettingsd configuration and notify daemon
    local xsettings_dir="$CONFIG_HOME/xsettingsd"
    local xsettings_file="$xsettings_dir/xsettingsd.conf"
    if [[ -f "$xsettings_file" ]]; then
        if grep -q "^[[:space:]]*Net/IconThemeName" "$xsettings_file"; then
            sed -i -E "s|^[[:space:]]*Net/IconThemeName.*|Net/IconThemeName \"$icon_theme\"|" "$xsettings_file" 2>/dev/null || true
        else
            echo "Net/IconThemeName \"$icon_theme\"" >> "$xsettings_file"
        fi
    fi
    if pgrep -u "$UID" -x xsettingsd >/dev/null 2>&1; then
        pkill -HUP -u "$UID" -x xsettingsd 2>/dev/null || true
    fi

    # 8. Update xfconf if present
    if command -v xfconf-query >/dev/null 2>&1; then
        xfconf-query -c xsettings -p /Net/IconThemeName -s "$icon_theme" >/dev/null 2>&1 || true
    fi

    # 9. Update Quickshell icon pragma in shell.qml
    local qmldir="$CONFIG_HOME/quickshell"
    local repo_root
    repo_root="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
    for shell_qml in "$qmldir/shell.qml" "$repo_root/quickshell/shell.qml"; do
        if [[ -f "$shell_qml" ]]; then
            sed -i -E "1s|^//@ pragma IconTheme .*|//@ pragma IconTheme $icon_theme|" "$shell_qml" 2>/dev/null || true
        fi
    done
}

apply_wallpaper() {
    local backgrounds_dir="$CURRENT_LINK/backgrounds"
    local first_wallpaper=""

    if [[ -d "$backgrounds_dir" ]]; then
        shopt -s nullglob
        for cand in "$backgrounds_dir"/*; do
            [[ -f "$cand" ]] || continue
            case "${cand,,}" in
                *.png|*.jpg|*.jpeg|*.webp|*.gif|*.bmp|*.avif)
                    first_wallpaper="$cand"
                    break
                    ;;
            esac
        done
        shopt -u nullglob
    fi

    if [[ -z "$first_wallpaper" && -f "$CURRENT_LINK/default.png" ]]; then
        first_wallpaper="$CURRENT_LINK/default.png"
    fi

    if [[ -n "$first_wallpaper" ]]; then
        if [[ -x "$SCRIPT_DIR/qdeck-wallpaper" ]]; then
            "$SCRIPT_DIR/qdeck-wallpaper" switch "$first_wallpaper" >/dev/null 2>&1 || true
        elif command -v qdeck-wallpaper >/dev/null 2>&1; then
            qdeck-wallpaper switch "$first_wallpaper" >/dev/null 2>&1 || true
        elif command -v awww >/dev/null 2>&1; then
            awww img "$first_wallpaper" >/dev/null 2>&1 || true
        fi
    fi
}

reload_kitty() {
    if pgrep -u "$UID" -x kitty >/dev/null 2>&1; then
        pkill -SIGUSR1 -u "$UID" -x kitty 2>/dev/null || true
    fi
}

reload_neovim() {
    # 1. Send SIGUSR1 signal for native reload in listening Neovim instances
    pkill -SIGUSR1 -u "$UID" -x nvim 2>/dev/null || true

    # 2. Remote RPC command to active Neovim server sockets
    local -a sockets=()
    shopt -s nullglob
    sockets=(
        "${XDG_RUNTIME_DIR:-/run/user/$UID}"/nvim.*
        /tmp/nvim*/*
        /tmp/nvim.*
    )
    shopt -u nullglob

    if (( ${#sockets[@]} > 0 )) && command -v nvim >/dev/null 2>&1; then
        local remote_cmd='<Cmd>lua pcall(function() local p = vim.fn.expand("~/.config/themes/current/neovim.lua"); local ok, spec = pcall(dofile, p); if ok and type(spec) == "table" then for _, item in ipairs(spec) do if type(item) == "table" and item[1] and item[1] ~= "LazyVim/LazyVim" then local name = item.name or item[1]:match("/([^/]+)$") or item[1]; pcall(function() if package.loaded["lazy"] then require("lazy").load({ plugins = { name } }) end end) end; if item.opts and item.opts.colorscheme then if item.opts.background then if item.opts.background == "dark" or item.opts.background == "light" then pcall(function() vim.o.background = item.opts.background end) else pcall(function() vim.g.everforest_background = item.opts.background end) pcall(function() vim.g.gruvbox_material_background = item.opts.background end) end end; pcall(vim.cmd.colorscheme, item.opts.colorscheme) end end; pcall(vim.cmd, "redraw!") end end)<CR>'
        for sock in "${sockets[@]}"; do
            [[ -S "$sock" ]] || continue
            nvim --server "$sock" --remote-send "$remote_cmd" >/dev/null 2>&1 &
        done
    fi
}

reload_quickshell() {
    local qs_bin="qs"
    command -v qs >/dev/null 2>&1 || qs_bin="quickshell"
    if command -v "$qs_bin" >/dev/null 2>&1; then
        "$qs_bin" ipc call theme reload >/dev/null 2>&1 || true
    fi
}

reload_hyprland() {
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
}

update_editor_themes() {
    local theme_dir="$1"
    [[ -f "$theme_dir/vscode.json" ]] || return 0

    local vscode_metadata
    vscode_metadata="$(jq -er 'if ((.name | type) == "string" and (.name | length) > 0) then .name else error("invalid name") end' "$theme_dir/vscode.json" 2>/dev/null || echo "")"
    [[ -n "$vscode_metadata" ]] || return 0

    local editor_settings=(
        "$CONFIG_HOME/VSCodium/User/settings.json"
        "$CONFIG_HOME/Code/User/settings.json"
        "$CONFIG_HOME/Code - OSS/User/settings.json"
        "$CONFIG_HOME/Antigravity IDE/User/settings.json"
    )

    for sp in "${editor_settings[@]}"; do
        if [[ -f "$sp" ]] && jq empty "$sp" >/dev/null 2>&1; then
            local tmp_s="${sp}.tmp.$$"
            jq --arg t "$vscode_metadata" '."workbench.colorTheme" = $t | del(."workbench.colorCustomizations", ."editor.tokenColorCustomizations")' "$sp" > "$tmp_s" 2>/dev/null && mv -f "$tmp_s" "$sp"
        fi
    done
}

switch_theme() {
    local theme="${1:-}"
    if [[ -z "$theme" ]]; then
        echo "error: theme argument missing" >&2
        exit 1
    fi

    local target_dir="$THEMES_DIR/$theme"
    if [[ ! -d "$target_dir" ]]; then
        echo "error: theme '$theme' does not exist in $THEMES_DIR" >&2
        exit 1
    fi

    mkdir -p "$THEMES_DIR"

    # 1. Update current symlink atomically
    local tmp_link="$THEMES_DIR/.current_tmp_$$"
    ln -sfn "$target_dir" "$tmp_link"
    mv -fT "$tmp_link" "$CURRENT_LINK"

    # 2. Update Kitty color.conf symlink if present
    if [[ -f "$target_dir/color.conf" ]]; then
        mkdir -p "$CONFIG_HOME/kitty"
        ln -sfn "$target_dir/color.conf" "$CONFIG_HOME/kitty/color.conf"
    fi

    # 3. Update editor themes (VSCodium, Code, Antigravity IDE)
    update_editor_themes "$target_dir"

    # 4. Apply icon theme
    apply_icon_theme "$target_dir"

    # 5. Apply wallpaper
    apply_wallpaper

    # 6. Live reloads
    reload_kitty
    reload_neovim
    reload_hyprland
    reload_quickshell

    echo "Switched to theme: $theme"
}

run_setup() {
    echo "==> Configuring QDeck theme integration..."

    # 1. btop theme symlink and config
    local btop_themes_dir="$CONFIG_HOME/btop/themes"
    mkdir -p "$btop_themes_dir"
    ln -sfn "$CURRENT_LINK/btop.theme" "$btop_themes_dir/current.theme"

    local btop_conf="$CONFIG_HOME/btop/btop.conf"
    if [[ -f "$btop_conf" ]]; then
        if grep -q '^[[:space:]]*color_theme[[:space:]]*=' "$btop_conf"; then
            sed -i -E 's|^[[:space:]]*color_theme[[:space:]]*=.*|color_theme = "current"|' "$btop_conf"
        else
            echo 'color_theme = "current"' >> "$btop_conf"
        fi
    else
        mkdir -p "$CONFIG_HOME/btop"
        echo 'color_theme = "current"' > "$btop_conf"
    fi

    # 2. Neovim LazyVim theme loader
    local nvim_plugins_dir="$CONFIG_HOME/nvim/lua/plugins"
    mkdir -p "$nvim_plugins_dir"
    local nvim_loader="$nvim_plugins_dir/theme.lua"

    cat <<'EOF' > "$nvim_loader"
local function reload_current_theme()
  local theme_path = vim.fn.expand("~/.config/themes/current/neovim.lua")
  local ok, spec = pcall(dofile, theme_path)
  if not ok or type(spec) ~= "table" then return end
  for _, item in ipairs(spec) do
    if type(item) == "table" and item[1] and item[1] ~= "LazyVim/LazyVim" then
      local name = item.name or item[1]:match("/([^/]+)$") or item[1]
      pcall(function()
        if package.loaded["lazy"] then
          require("lazy").load({ plugins = { name } })
        end
      end)
    end
    if item.opts and item.opts.colorscheme then
      if item.opts.background then
        if item.opts.background == "dark" or item.opts.background == "light" then
          pcall(function() vim.o.background = item.opts.background end)
        else
          pcall(function() vim.g.everforest_background = item.opts.background end)
          pcall(function() vim.g.gruvbox_material_background = item.opts.background end)
        end
      end
      pcall(vim.cmd.colorscheme, item.opts.colorscheme)
    end
  end
  pcall(vim.cmd, "redraw!")
end

_G.reload_qdeck_theme = reload_current_theme

pcall(vim.api.nvim_create_user_command, "ReloadTheme", function()
  reload_current_theme()
  vim.notify("QDeck theme reloaded", vim.log.levels.INFO)
end, { desc = "Reload QDeck active theme in LazyVim" })

pcall(vim.api.nvim_create_autocmd, "FocusGained", {
  callback = reload_current_theme,
  desc = "Reload QDeck theme on focus gained",
})

if vim.uv and vim.uv.new_signal then
  local sig = vim.uv.new_signal()
  sig:start("sigusr1", function()
    vim.schedule(reload_current_theme)
  end)
end

local theme_path = vim.fn.expand("~/.config/themes/current/neovim.lua")
local ok, spec = pcall(dofile, theme_path)

if not ok or type(spec) ~= "table" then
  return {}
end

return spec
EOF

    # Ensure nvim config imports plugins
    local nvim_lazy_config="$CONFIG_HOME/nvim/lua/config/lazy.lua"
    if [[ ! -f "$nvim_lazy_config" ]]; then
        mkdir -p "$CONFIG_HOME/nvim/lua/config"
        local repo_lazy="$SCRIPT_DIR/../nvim/lua/config/lazy.lua"
        if [[ -f "$repo_lazy" ]]; then
            cp -f "$repo_lazy" "$nvim_lazy_config"
        else
            cat <<'EOF' > "$nvim_lazy_config"
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
  defaults = { lazy = false, version = false },
})
EOF
        fi
    fi

    echo "    Theme setup complete."
}

CMD="${1:-list}"
case "$CMD" in
    list|get)
        list_themes_json
        ;;
    current)
        get_current_theme
        ;;
    switch|apply)
        shift
        switch_theme "$@"
        ;;
    setup)
        run_setup
        ;;
    *)
        echo "Usage: $0 {list|current|switch <theme>|setup}" >&2
        exit 1
        ;;
esac
```

---

### bin/qdeck-themeswitcher
- **Path:** `bin/qdeck-themeswitcher`

```bash
#!/usr/bin/env bash
# QDeck: Theme Switcher IPC controller (qdeck-themeswitcher / qdeck theme)
set -euo pipefail

CMD="${1:-toggle}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared IPC helper
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
elif command -v qdeck-ipc >/dev/null 2>&1; then
  source "$(command -v qdeck-ipc)"
fi

case "$CMD" in
  toggle)
    call_ipc themeswitcher toggle
    ;;
  open)
    call_ipc themeswitcher open
    ;;
  close)
    call_ipc themeswitcher close
    ;;
  next)
    call_ipc themeswitcher next
    ;;
  prev)
    call_ipc themeswitcher prev
    ;;
  select)
    call_ipc themeswitcher select "${2:-0}"
    ;;
  apply|switch|set)
    if ! call_ipc themeswitcher apply "${2:-}"; then
      qdeck-theme-switch switch "${2:-}"
    fi
    ;;
  list)
    qdeck-theme-switch list
    ;;
  current)
    qdeck-theme-switch current
    ;;
  state|getState|status)
    call_ipc themeswitcher getState
    ;;
  setup)
    qdeck-theme-switch setup
    ;;
  *)
    call_ipc themeswitcher toggle
    ;;
esac
```

---

### bin/qdeck-trackpad
- **Path:** `bin/qdeck-trackpad`

```bash
#!/bin/sh
# QDeck: Minimal POSIX shell helper to toggle or set touchpad state (qdeck-trackpad / qdeck trackpad)
# Zero Python, zero cache files, zero interpreter overhead.

CMD="${1:-toggle}"

DEV=$(hyprctl devices -j 2>/dev/null | jq -r '.mice[]? | select(.name | test("touchpad|trackpad"; "i")) | .name' 2>/dev/null | head -n1)
[ -z "$DEV" ] && DEV="elan0788:00-04f3:321a-touchpad"

case "$CMD" in
    on|enable|1|true)
        STATE=$(hyprctl repl "_G.touchpad_enabled = true; hl.device({ name = '$DEV', enabled = true }); return 'ON'")
        ;;
    off|disable|0|false)
        STATE=$(hyprctl repl "_G.touchpad_enabled = false; hl.device({ name = '$DEV', enabled = false }); return 'OFF'")
        ;;
    status)
        STATE=$(hyprctl repl "return (_G.touchpad_enabled ~= false) and 'ON' or 'OFF'")
        STATE=$(echo "$STATE" | tr -d '[:space:]')
        echo "$STATE"
        exit 0
        ;;
    *)
        STATE=$(hyprctl repl "
            if _G.touchpad_enabled == nil then _G.touchpad_enabled = true end
            _G.touchpad_enabled = not _G.touchpad_enabled
            hl.device({ name = '$DEV', enabled = _G.touchpad_enabled })
            return _G.touchpad_enabled and 'ON' or 'OFF'
        ")
        ;;
esac

STATE=$(echo "$STATE" | tr -d '[:space:]')

if [ "$STATE" = "ON" ]; then
    qdeck-osd -i trackpad-on -m "Trackpad: ON" -d 1600 >/dev/null 2>&1 &
    echo "Trackpad enabled"
else
    qdeck-osd -i trackpad-off -m "Trackpad: OFF" -d 1600 >/dev/null 2>&1 &
    echo "Trackpad disabled"
fi
```

---

### bin/qdeck-volume
- **Path:** `bin/qdeck-volume`

```bash
#!/usr/bin/env bash
# QDeck: Audio volume & mute control (qdeck-volume / qdeck volume)
set -euo pipefail

get_vol() {
  local target="${1:-@DEFAULT_AUDIO_SINK@}"
  local out
  out=$(wpctl get-volume "$target" 2>/dev/null || echo "Volume: 0.00")
  local val
  val=$(awk '{print $2}' <<< "$out")
  local pct
  pct=$(awk -v v="$val" 'BEGIN { printf "%d", (v * 100) + 0.5 }')
  echo "$pct"
}

get_muted() {
  local target="${1:-@DEFAULT_AUDIO_SINK@}"
  local out
  out=$(wpctl get-volume "$target" 2>/dev/null || echo "")
  if [[ "$out" == *"[MUTED]"* ]]; then
    echo "1"
  else
    echo "0"
  fi
}

cmd="${1:-get}"
shift || true

case "$cmd" in
  up)
    step="${1:-5}"
    wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${step}%+"
    ;;
  down)
    step="${1:-5}"
    wpctl set-volume @DEFAULT_AUDIO_SINK@ "${step}%-"
    ;;
  mute|toggle-mute)
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    ;;
  mic-mute|toggle-mic-mute)
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    ;;
  set)
    val="${1:-50}"
    val_clean="${val%\%}"
    dec=$(awk -v p="$val_clean" 'BEGIN { printf "%.2f", p / 100 }')
    wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "$dec"
    ;;
  get)
    get_vol "@DEFAULT_AUDIO_SINK@"
    ;;
  is-muted)
    get_muted "@DEFAULT_AUDIO_SINK@"
    ;;
  *)
    echo "Usage: qdeck-volume {up|down|mute|mic-mute|set|get|is-muted} [args]"
    exit 1
    ;;
esac
```

---

### bin/qdeck-wallpaper
- **Path:** `bin/qdeck-wallpaper`

```bash
#!/usr/bin/env bash
# ==============================================================================
# QDeck: Wallpaper discovery, listing, and switching helper (qdeck-wallpaper / qdeck wallpaper)
# ==============================================================================
set -euo pipefail

CURRENT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/themes/current"
if [[ ! -d "$CURRENT_DIR" && -d "$HOME/themes/current" ]]; then
    CURRENT_DIR="$HOME/themes/current"
fi

get_active_wallpaper() {
    # 1. First check awww if running
    if command -v awww >/dev/null 2>&1 && (pgrep -x awww-daemon >/dev/null 2>&1); then
        local awww_cur
        awww_cur="$(awww query 2>/dev/null | grep -oP 'currently displaying: image: \K.*' | head -n1 || true)"
        if [[ -n "$awww_cur" && -f "$awww_cur" ]]; then
            readlink -f "$awww_cur" 2>/dev/null || echo "$awww_cur"
            return 0
        fi
    fi

    # 2. Check default.png symlink
    local default_link="$CURRENT_DIR/default.png"
    if [[ -L "$default_link" || -f "$default_link" ]]; then
        readlink -f "$default_link" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

CACHE_THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/qdeck/wallpaper-thumbnails"

get_thumbnail() {
    local img="$1"
    local base="${img##*/}"
    local hash
    hash="$(echo -n "$img" | md5sum | cut -d' ' -f1)"
    local thumb="$CACHE_THUMB_DIR/${hash}_${base}.jpg"
    if [[ -f "$thumb" ]]; then
        echo "$thumb"
        return 0
    fi
    mkdir -p "$CACHE_THUMB_DIR"
    if command -v magick >/dev/null 2>&1; then
        magick "$img" -thumbnail 320x196^ -gravity center -extent 320x196 -quality 82 "$thumb" 2>/dev/null &
    elif command -v convert >/dev/null 2>&1; then
        convert "$img" -thumbnail 320x196^ -gravity center -extent 320x196 -quality 82 "$thumb" 2>/dev/null &
    fi
    echo "$thumb"
}

list_wallpapers_json() {
    local bg_dir="$CURRENT_DIR/backgrounds"
    local active_target
    active_target="$(get_active_wallpaper)"

    if [[ ! -d "$bg_dir" ]]; then
        echo "[]"
        return 0
    fi

    local items=()
    shopt -s nullglob
    for file in "$bg_dir"/*; do
        [[ -f "$file" ]] || continue
        case "${file,,}" in
            *.png|*.jpg|*.jpeg|*.webp|*.avif|*.bmp)
                local filename="${file##*/}"
                local stem="${filename%.*}"
                local raw_name="${stem#[0-9]*-}"
                raw_name="${raw_name#[0-9]*_}"
                raw_name="${raw_name//[-_]/ }"
                local clean_name
                clean_name="$(echo "$raw_name" | sed -E 's/\b([a-z])/\U\1/g')"

                local canon_file
                canon_file="$(readlink -f "$file" 2>/dev/null || echo "$file")"

                local is_active=false
                if [[ -n "$active_target" && "$canon_file" == "$active_target" ]]; then
                    is_active=true
                fi

                local thumb
                thumb="$(get_thumbnail "$file")"

                items+=( "$(jq -n \
                    --arg path "$file" \
                    --arg thumb "$thumb" \
                    --arg name "$clean_name" \
                    --arg filename "$filename" \
                    --argjson isActive "$is_active" \
                    '{path: $path, thumb: $thumb, name: $name, filename: $filename, isActive: $isActive}')" )
                ;;
        esac
    done
    shopt -u nullglob

    if [[ ${#items[@]} -eq 0 ]]; then
        echo "[]"
    else
        printf "%s\n" "${items[@]}" | jq -s .
    fi
}

switch_wallpaper() {
    local img="${1:-}"
    if [[ -z "$img" ]]; then
        echo "error: missing wallpaper path" >&2
        exit 1
    fi

    if [[ "$img" != /* ]]; then
        # If relative or just filename, resolve inside current theme backgrounds
        if [[ -f "$CURRENT_DIR/backgrounds/$img" ]]; then
            img="$CURRENT_DIR/backgrounds/$img"
        elif [[ -f "$PWD/$img" ]]; then
            img="$PWD/$img"
        fi
    fi

    if [[ ! -f "$img" ]]; then
        echo "error: wallpaper file '$img' does not exist" >&2
        exit 1
    fi

    local canon_path
    canon_path="$(readlink -f "$img" 2>/dev/null || echo "$img")"

    # 1. Update active theme default.png symlink
    if [[ -d "$CURRENT_DIR" ]]; then
        ln -sfn "$canon_path" "$CURRENT_DIR/default.png"
    fi

    # 2. Primary backend: awww
    if command -v awww >/dev/null 2>&1; then
        if ! pgrep -x awww-daemon >/dev/null 2>&1; then
            awww-daemon &
            sleep 0.2
        fi
        if awww img "$canon_path" >/dev/null 2>&1; then
            echo "Wallpaper changed to: $(basename "$canon_path")"
            return 0
        fi
    fi

    # 3. Secondary backend: swww
    if command -v swww >/dev/null 2>&1; then
        if ! pgrep -x swww-daemon >/dev/null 2>&1; then
            swww init >/dev/null 2>&1 || true
            sleep 0.2
        fi
        if swww img "$canon_path" >/dev/null 2>&1; then
            echo "Wallpaper changed to: $(basename "$canon_path")"
            return 0
        fi
    fi

    # 4. Tertiary backend: hyprpaper
    if command -v hyprpaper >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1; then
        hyprctl hyprpaper preload "$canon_path" >/dev/null 2>&1 || true
        hyprctl hyprpaper wallpaper ",$canon_path" >/dev/null 2>&1 || true
        echo "Wallpaper changed to: $(basename "$canon_path")"
        return 0
    fi

    echo "error: no wallpaper backend available" >&2
    exit 1
}

CMD="${1:-list}"
case "$CMD" in
    list|get)
        list_wallpapers_json
        ;;
    current)
        get_active_wallpaper
        ;;
    switch|apply)
        shift
        switch_wallpaper "$@"
        ;;
    *)
        echo "Usage: $0 {list|current|switch <path>}" >&2
        exit 1
        ;;
esac
```

---

### bin/qdeck-wallpaperswitcher
- **Path:** `bin/qdeck-wallpaperswitcher`

```bash
#!/usr/bin/env bash
# QDeck: Wallpaper Switcher launcher controller (qdeck-wallpaperswitcher / qdeck wallpaper)
set -euo pipefail

CMD="${1:-toggle}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared IPC helper
if [[ -f "$SCRIPT_DIR/lib/qdeck-ipc.sh" ]]; then
  source "$SCRIPT_DIR/lib/qdeck-ipc.sh"
elif [[ -f "$HOME/.local/bin/lib/qdeck-ipc.sh" ]]; then
  source "$HOME/.local/bin/lib/qdeck-ipc.sh"
elif command -v qdeck-ipc >/dev/null 2>&1; then
  source "$(command -v qdeck-ipc)"
fi

case "$CMD" in
  toggle)
    call_ipc wallpaperswitcher toggle
    ;;
  open)
    call_ipc wallpaperswitcher open
    ;;
  close)
    call_ipc wallpaperswitcher close
    ;;
  next)
    call_ipc wallpaperswitcher next
    ;;
  prev)
    call_ipc wallpaperswitcher prev
    ;;
  select)
    call_ipc wallpaperswitcher select "${2:-0}"
    ;;
  apply|switch|set)
    if ! call_ipc wallpaperswitcher apply "${2:-}"; then
      qdeck-wallpaper switch "${2:-}"
    fi
    ;;
  list)
    qdeck-wallpaper list
    ;;
  current)
    qdeck-wallpaper current
    ;;
  state|getState|status)
    call_ipc wallpaperswitcher getState
    ;;
  *)
    call_ipc wallpaperswitcher toggle
    ;;
esac
```

---

### bin/tui-launch
- **Path:** `bin/tui-launch`

```bash
#!/usr/bin/env bash

tui="$1"

if [[ -z "$tui" ]]; then
  echo "Usage: $0 <tui-command>"
  exit 1
fi

class="tui-$tui"

address=$(
  hyprctl clients -j |
    jq -r --arg class "$class" \
      '.[] | select(.class == $class) | .address' |
    head -n1
)

if [[ -n "$address" ]]; then
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$address\" })"
else
  kitty \
    --class "$class" \
    --title "$tui" \
    -e "$tui"
fi
```

---

### bin/webapp-create
- **Path:** `bin/webapp-create`

```bash
#!/usr/bin/env bash

set -euo pipefail

ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
DESKTOP_DIR="$HOME/.local/share/applications"

# Change this if your brave-origin binary has a different name.
BROWSER="${WEBAPP_BROWSER:-brave-origin}"

safe_icon_name() {
  printf '%s\n' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed 's/[^[:alnum:]]\+/-/g; s/^-//; s/-$//'
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Error: required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_plain_name() {
  local name="$1"

  if [[ -z "$name" ]]; then
    echo "Error: app name cannot be empty." >&2
    exit 1
  fi

  if [[ "$name" == */* ]]; then
    echo "Error: app name cannot contain '/': $name" >&2
    exit 1
  fi
}

normalize_url() {
  local url="$1"

  if [[ ! "$url" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*: ]]; then
    url="https://$url"
  fi

  printf '%s\n' "$url"
}

require_http_url() {
  local url="$1"

  if [[ "$url" =~ [[:space:]] ]]; then
    echo "Error: URL must not contain whitespace." >&2
    exit 1
  fi

  if [[ ! "${url,,}" =~ ^https?:// ]]; then
    echo "Error: only http:// and https:// URLs are allowed." >&2
    exit 1
  fi
}

download_icon() {
  local url="$1"
  local destination="$2"

  curl \
    -fsSL \
    --max-time 10 \
    -o "$destination" \
    "$url" 2>/dev/null || return 1

  [[ -s "$destination" ]] || return 1

  local mime
  mime=$(file -b --mime-type "$destination")

  [[ "$mime" == image/* ]]
}

fetch_site_icon() {
  local site_url="$1"
  local destination="$2"

  local origin
  local page
  local icon_url=""

  origin=$(sed -E 's|^(https?://[^/]+).*|\1|' <<<"$site_url")

  page=$(
    curl -fsSL --max-time 5 "$site_url" 2>/dev/null |
      head -c 150000 |
      tr '\n' ' ' ||
      true
  )

  # Prefer high-resolution Apple touch icon.
  icon_url=$(
    grep -oiE \
      "<link[^>]*rel=[\"'][^\"']*apple-touch-icon[^\"']*[\"'][^>]*>" \
      <<<"$page" |
      grep -oiE "href=[\"'][^\"']+" |
      head -1 |
      sed -E "s/^href=[\"']//" ||
      true
  )

  # If none exists, try a normal favicon declaration.
  if [[ -z "$icon_url" ]]; then
    icon_url=$(
      grep -oiE \
        "<link[^>]*rel=[\"'][^\"']*(shortcut )?icon[^\"']*[\"'][^>]*>" \
        <<<"$page" |
        grep -oiE "href=[\"'][^\"']+" |
        head -1 |
        sed -E "s/^href=[\"']//" ||
        true
    )
  fi

  case "$icon_url" in
  http://* | https://*)
    ;;
  //*)
    icon_url="https:$icon_url"
    ;;
  /*)
    icon_url="$origin$icon_url"
    ;;
  ?*)
    icon_url="$origin/$icon_url"
    ;;
  esac

  # Try the discovered icon.
  if [[ -n "$icon_url" ]] &&
    download_icon "$icon_url" "$destination"; then
    return 0
  fi

  # Common fallback.
  if download_icon \
    "$origin/apple-touch-icon.png" \
    "$destination"; then
    return 0
  fi

  # Traditional favicon.
  if download_icon \
    "$origin/favicon.ico" \
    "$destination"; then
    return 0
  fi

  # Last resort: Google's favicon service.
  if download_icon \
    "https://www.google.com/s2/favicons?domain_url=$site_url&sz=256" \
    "$destination"; then
    return 0
  fi

  return 1
}

install_local_icon() {
  local source="$1"
  local name="$2"

  local mime
  local extension

  mime=$(file -b --mime-type "$source")

  case "$mime" in
  image/png)
    extension="png"
    ;;
  image/jpeg)
    extension="jpg"
    ;;
  image/svg+xml)
    extension="svg"
    ;;
  image/webp)
    extension="webp"
    ;;
  image/x-icon | image/vnd.microsoft.icon)
    extension="ico"
    ;;
  *)
    echo "Error: unsupported icon type: $mime" >&2
    exit 1
    ;;
  esac

  mkdir -p "$ICON_DIR"

  cp "$source" "$ICON_DIR/$name.$extension"

  printf '%s\n' "$name"
}

desktop_escape() {
  local value="$1"

  value=${value//\\/\\\\}
  value=${value//$'\t'/\\t}
  value=${value//$'\r'/\\r}
  value=${value//$'\n'/\\n}

  [[ "$value" == " "* ]] &&
    value="\\s${value# }"

  printf '%s' "$value"
}

exec_escape_arg() {
  local value="$1"

  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//\`/\\\`}
  value=${value//\$/\\\$}
  value=${value//%/%%}

  printf '"%s"' "$value"
}

update_icon_cache() {
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache \
      "$HOME/.local/share/icons/hicolor" \
      >/dev/null 2>&1 || true
  fi
}

create_webapp() {
  local app_name="$1"
  local app_url="$2"
  local icon_ref="${3:-}"

  require_plain_name "$app_name"

  app_url=$(normalize_url "$app_url")
  require_http_url "$app_url"

  mkdir -p "$ICON_DIR" "$DESKTOP_DIR"

  local icon_name
  icon_name=$(safe_icon_name "$app_name")

  #
  # Icon handling
  #

  if [[ -z "$icon_ref" ]]; then

    printf 'Fetching icon for %s...\n' "$app_name"

    if ! fetch_site_icon \
      "$app_url" \
      "$ICON_DIR/$icon_name.png"; then

      echo "Error: failed to fetch website icon." >&2
      exit 1
    fi

  elif [[ "$icon_ref" =~ ^https?:// ]]; then

    if ! download_icon \
      "$icon_ref" \
      "$ICON_DIR/$icon_name.png"; then

      echo "Error: failed to download icon." >&2
      exit 1
    fi

  elif [[ -f "$icon_ref" ]]; then

    icon_name=$(
      install_local_icon \
        "$icon_ref" \
        "$icon_name"
    )

  else
    # Assume it's already an installed icon theme name.
    icon_name="${icon_ref%.*}"
  fi

  update_icon_cache

  #
  # Desktop launcher
  #

  local desktop_file
  desktop_file="$DESKTOP_DIR/$app_name.desktop"

  local exec_command

  exec_command="$BROWSER --app=$(exec_escape_arg "$app_url")"

  local name_field
  local exec_field
  local icon_field

  name_field=$(desktop_escape "$app_name")
  exec_field=$(desktop_escape "$exec_command")
  icon_field=$(desktop_escape "$icon_name")

  cat >"$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name_field
Comment=$name_field
Exec=$exec_field
Icon=$icon_field
Terminal=false
StartupNotify=true
Categories=Network;WebBrowser;
EOF

  chmod +x "$desktop_file"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi

  echo
  echo "Created web app:"
  echo "  $desktop_file"
  echo
  echo "URL:"
  echo "  $app_url"
}

interactive_mode() {

  require_command gum

  echo
  echo "Create Web App"
  echo

  local app_name
  local app_url
  local icon_ref

  app_name=$(
    gum input \
      --prompt "Name> " \
      --placeholder "YouTube"
  )

  app_url=$(
    gum input \
      --prompt "URL> " \
      --placeholder "youtube.com"
  )

  icon_ref=$(
    gum input \
      --prompt "Icon> " \
      --placeholder "Leave empty to fetch automatically"
  )

  create_webapp \
    "$app_name" \
    "$app_url" \
    "$icon_ref"
}

main() {

  require_command curl
  require_command file
  require_command sed
  require_command grep
  require_command "$BROWSER"

  if (($# >= 2)); then

    create_webapp \
      "$1" \
      "$2" \
      "${3:-}"

  else
    interactive_mode
  fi
}

main "$@"
```

---

### bin/lib/00-backup.sh
- **Path:** `bin/lib/00-backup.sh`

```bash
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
```

---

### bin/lib/01-deps.sh
- **Path:** `bin/lib/01-deps.sh`

```bash
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
  imv
  pinta
  nwg-look

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
  if git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$BUILD_DIR/yay" 2>/dev/null ||
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
    pokemon-colorscripts-git
    yaru-icon-theme
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
```

---

### bin/lib/02-fonts.sh
- **Path:** `bin/lib/02-fonts.sh`

```bash
#!/usr/bin/env bash
# QDeck: 02-fonts.sh: Installs required Nerd Fonts, Material Symbols/Icons, CJK/emoji sets, and font cache for QDeck
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
USER_FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$USER_FONT_DIR"

echo "==> [QDeck:02-fonts] Installing official repository fonts for QDeck..."

PACMAN_FONTS=(
  ttf-jetbrains-mono-nerd
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
```

---

### bin/lib/03-quickshell.sh
- **Path:** `bin/lib/03-quickshell.sh`

```bash
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
LOCKSTATE_SRC="$REPO_ROOT/src/qdeck-lockstate-monitor.c"
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
```

---

### bin/lib/04-dotfiles.sh
- **Path:** `bin/lib/04-dotfiles.sh`

```bash
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
  if [[ ! -e "$HOME/.config/themes/current" ]]; then
    for t in catppuccin gruvbox everforest nord tokyo-night; do
      if [[ -d "$HOME/.config/themes/$t" ]]; then
        ln -sfn "$HOME/.config/themes/$t" "$HOME/.config/themes/current"
        echo "    Initialized active theme symlink -> $t"
        break
      fi
    done
  fi
fi

# Ensure sensible permissions on deployed user configs
find "$HOME/.config/hypr" "$HOME/.config/quickshell" "$HOME/.config/themes" -type f -exec chmod 644 {} + 2>/dev/null || true
find "$HOME/.config/hypr" "$HOME/.config/quickshell" "$HOME/.config/themes" -type d -exec chmod 755 {} + 2>/dev/null || true

echo "==> [QDeck:04-dotfiles] Configurations deployed successfully for QDeck."
exit 0
```

---

### bin/lib/05-nvim.sh
- **Path:** `bin/lib/05-nvim.sh`

```bash
#!/usr/bin/env bash
# QDeck: 05-nvim.sh: Installs Neovim, bootstraps LazyVim/lazy.nvim, and executes headless plugin installation for QDeck
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NVIM_DIR="$HOME/.config/nvim"

echo "==> [QDeck:05-nvim] Installing Neovim and build dependencies for QDeck..."

NVIM_PACKAGES=(
  neovim
  gcc
  make
  ripgrep
  fd
  git
  tar
  unzip
  curl
)

MISSING_NVIM=()
for pkg in "${NVIM_PACKAGES[@]}"; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    MISSING_NVIM+=("$pkg")
  fi
done

if ((${#MISSING_NVIM[@]} > 0)); then
  sudo pacman -S --needed --noconfirm "${MISSING_NVIM[@]}"
fi

# 1. Neovim configuration deployment
mkdir -p "$HOME/.config"

if [[ -d "$REPO_ROOT/nvim" && -n "$(ls -A "$REPO_ROOT/nvim" 2>/dev/null)" ]]; then
  echo "    Deploying custom Neovim configuration from repository..."
  mkdir -p "$NVIM_DIR"
  cp -rf "$REPO_ROOT/nvim/." "$NVIM_DIR/"
elif [[ ! -f "$NVIM_DIR/init.lua" ]]; then
  echo "    Cloning LazyVim starter config..."
  git clone --depth=1 https://github.com/LazyVim/starter "$NVIM_DIR" 2>/dev/null || true
  rm -rf "$NVIM_DIR/.git"
else
  echo "    Existing Neovim configuration preserved."
fi

# 2. Bootstrap lazy.nvim plugin manager if not present
LAZY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim"
if [[ ! -d "$LAZY_DIR" ]]; then
  echo "    Bootstrapping lazy.nvim plugin manager..."
  mkdir -p "$(dirname "$LAZY_DIR")"
  git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git "$LAZY_DIR" 2>/dev/null || true
fi

# 3. Headless plugin sync to preload all LazyVim plugins and theme colorschemes
if command -v nvim &>/dev/null && [[ -f "$NVIM_DIR/init.lua" ]]; then
  echo "==> [QDeck:05-nvim] Running headless Lazy.nvim sync to preload all plugins..."
  timeout 120 nvim --headless "+Lazy! sync" +qa 2>/dev/null || \
  timeout 120 nvim --headless "+Lazy! restore" +qa 2>/dev/null || true
fi

echo "==> [QDeck:05-nvim] Neovim setup completed for QDeck."
exit 0
```

---

### bin/lib/06-assets.sh
- **Path:** `bin/lib/06-assets.sh`

```bash
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
```

---

### bin/lib/07-scripts.sh
- **Path:** `bin/lib/07-scripts.sh`

```bash
#!/usr/bin/env bash
# QDeck: 07-scripts.sh: Installs QDeck helper scripts to ~/.local/bin and verifies PATH idempotency
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_BIN_DIR="$HOME/.local/bin"

echo "==> [QDeck:07-scripts] Installing QDeck system utilities and scripts to $TARGET_BIN_DIR..."
mkdir -p "$TARGET_BIN_DIR"

installed_count=0
for script in "$REPO_ROOT/bin"/*; do
  [[ -f "$script" ]] || continue
  base="$(basename "$script")"
  
  # Skip installer orchestrators and subdirectories
  [[ "$base" == "install.sh" ]] && continue
  
  rm -f "$TARGET_BIN_DIR/$base"
  if [[ -L "$script" ]]; then
    cp -P "$script" "$TARGET_BIN_DIR/$base"
  else
    cp -f "$script" "$TARGET_BIN_DIR/$base"
    chmod +x "$TARGET_BIN_DIR/$base"
  fi
  echo "    Installed: $base"
  ((installed_count++)) || true
done

# Deploy internal script libraries
mkdir -p "$TARGET_BIN_DIR/lib"
if [[ -d "$REPO_ROOT/bin/lib" ]]; then
  cp -rf "$REPO_ROOT/bin/lib/." "$TARGET_BIN_DIR/lib/"
  chmod +x "$TARGET_BIN_DIR/lib"/*.sh 2>/dev/null || true
  echo "    Deployed libraries to $TARGET_BIN_DIR/lib"
fi

echo "    Successfully deployed $installed_count QDeck scripts to $TARGET_BIN_DIR."

# Register system-wide symlinks in /usr/local/bin if administrative privileges exist
if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  echo "==> [QDeck:07-scripts] Registering system-wide symlinks in /usr/local/bin..."
  sudo mkdir -p /usr/local/bin
  for script in "$REPO_ROOT/bin"/*; do
    [[ -f "$script" ]] || continue
    base="$(basename "$script")"
    [[ "$base" == "install.sh" ]] && continue
    sudo ln -sf "$TARGET_BIN_DIR/$base" "/usr/local/bin/$base" 2>/dev/null || true
  done
  
  # Register profile.d drop-in for universal login environment PATH
  sudo tee /etc/profile.d/qdeck-path.sh >/dev/null <<'EOF'
# QDeck universal user PATH configuration
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
EOF
  sudo chmod 644 /etc/profile.d/qdeck-path.sh 2>/dev/null || true
fi

# Verify and ensure ~/.local/bin is in PATH for bash, zsh, and profile
echo "==> [QDeck:07-scripts] Checking shell PATH configuration..."

PATH_SNIPPET='
# QDeck CLI & helper scripts
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi'

for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  if [[ -f "$rc" ]]; then
    if ! grep -q 'HOME/.local/bin' "$rc"; then
      printf '%s\n' "$PATH_SNIPPET" >> "$rc"
      echo "    Added ~/.local/bin to PATH in $rc"
    else
      echo "    ~/.local/bin already present in $rc"
    fi
  fi
done

# ------------------------------------------------------------------------------
# Copy zsh configuration folder to ~/.local/bin/zsh
# ------------------------------------------------------------------------------
copy_zsh() {
  local zsh_src="$REPO_ROOT/zsh"
  local zsh_target="$TARGET_BIN_DIR/zsh"

  if [[ -d "$zsh_src" ]]; then
    echo "==> [QDeck:07-scripts] Copying zsh folder to $zsh_target..."
    mkdir -p "$zsh_target"
    cp -rf "$zsh_src/." "$zsh_target/"
    find "$zsh_target" -type f -exec chmod 644 {} + 2>/dev/null || true
    find "$zsh_target" -type d -exec chmod 755 {} + 2>/dev/null || true
    echo "    Successfully deployed zsh folder to $zsh_target."
  else
    echo "    Warning: zsh folder not found at $zsh_src" >&2
  fi
}

copy_zsh

# Ensure ~/.zshrc sources QDeck zsh configurations if zsh is used
if [[ -f "$HOME/.zshrc" ]]; then
  if ! grep -q 'QDeck Zsh Configuration' "$HOME/.zshrc" && ! grep -q 'ZSH_CONFIG_DIR' "$HOME/.zshrc"; then
    cat <<'EOF' >> "$HOME/.zshrc"

# QDeck Zsh Configuration
[[ -f "$HOME/.local/bin/zsh/aliases.zsh" ]] && source "$HOME/.local/bin/zsh/aliases.zsh"
[[ -f "$HOME/.local/bin/zsh/functions.zsh" ]] && source "$HOME/.local/bin/zsh/functions.zsh"
[[ -f "$HOME/.config/zsh/aliases.zsh" ]] && source "$HOME/.config/zsh/aliases.zsh"
[[ -f "$HOME/.config/zsh/functions.zsh" ]] && source "$HOME/.config/zsh/functions.zsh"
EOF
    echo "    Integrated QDeck aliases and functions into ~/.zshrc"
  fi
fi

# Ensure current execution environment has updated PATH
export PATH="$TARGET_BIN_DIR:$PATH"

# Run initial theme switcher setup if available
if command -v qdeck-theme-switch &>/dev/null; then
  echo "==> [QDeck:07-scripts] Running initial theme setup via qdeck-theme-switch..."
  qdeck-theme-switch setup 2>/dev/null || true
fi

echo "==> [QDeck:07-scripts] Scripts deployment and PATH verification complete for QDeck."
exit 0
```

---

### bin/lib/08-zsh.sh
- **Path:** `bin/lib/08-zsh.sh`

```bash
#!/usr/bin/env bash
# QDeck: 08-zsh.sh: Zsh installation, plugins, configuration, and default shell bootstrap
set -Eeuo pipefail

# Run as your normal user, not direct root
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "Error: Run this script as your normal user (not with sudo or root)." >&2
  exit 1
fi

if [[ ! -f /etc/arch-release ]] && ! command -v pacman &>/dev/null; then
  echo "Error: This script is intended for Arch Linux." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$HOME/.local/bin/zsh"
ZSHRC="$HOME/.zshrc"
ZSH_PATH="/usr/bin/zsh"

echo "==> [QDeck:08-zsh] Auditing and configuring Zsh environment..."

# 1. Install required packages
echo "    Ensuring Zsh and plugin packages are installed..."
ZSH_PKGS=(zsh zoxide zsh-autosuggestions zsh-syntax-highlighting)
MISSING_PKGS=()
for pkg in "${ZSH_PKGS[@]}"; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    MISSING_PKGS+=("$pkg")
  fi
done

if ((${#MISSING_PKGS[@]} > 0)); then
  echo "    Installing missing packages: ${MISSING_PKGS[*]}"
  sudo pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
else
  echo "    All required Zsh packages and plugins are installed."
fi

# 2. Validate Zsh executable & /etc/shells registration
if [[ ! -x "$ZSH_PATH" ]]; then
  echo "Error: Zsh binary not found at $ZSH_PATH." >&2
  exit 1
fi

if ! grep -Fxq "$ZSH_PATH" /etc/shells; then
  echo "==> Registering $ZSH_PATH in /etc/shells..."
  echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

# 3. Ensure custom aliases and functions exist in $CONFIG_DIR
if [[ ! -f "$CONFIG_DIR/aliases.zsh" || ! -f "$CONFIG_DIR/functions.zsh" ]]; then
  echo "==> Deploying zsh configuration files to $CONFIG_DIR..."
  mkdir -p "$CONFIG_DIR"
  if [[ -d "$REPO_ROOT/zsh" ]]; then
    cp -rf "$REPO_ROOT/zsh/." "$CONFIG_DIR/"
  fi
  chmod 644 "$CONFIG_DIR"/* 2>/dev/null || true
fi

# Validate custom configuration files
for file in aliases.zsh functions.zsh; do
  if [[ ! -f "$CONFIG_DIR/$file" ]]; then
    echo "Error: Missing $CONFIG_DIR/$file" >&2
    exit 1
  fi
done

# 4. Back up existing .zshrc
if [[ -e "$ZSHRC" ]]; then
  BACKUP="$ZSHRC.backup.$(date +%Y%m%d-%H%M%S)"
  cp -p -- "$ZSHRC" "$BACKUP"
  echo "    Backup created: $BACKUP"
fi

# 5. Generate minimal .zshrc
echo "    Generating minimal $ZSHRC..."
cat >"$ZSHRC" <<'EOF'
pokemon-colorscripts -rn bulbasaur,charmander,squirtle,pikachu,mew,gengar,psyduck,lapras,giratina,darkrai --no-title

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
setopt CORRECT

# Completion
autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Custom aliases and functions
ZSH_CONFIG_DIR="$HOME/.local/bin/zsh"

source "$ZSH_CONFIG_DIR/aliases.zsh"
source "$ZSH_CONFIG_DIR/functions.zsh"

# Zoxide
eval "$(zoxide init zsh)"

# Autosuggestions
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Syntax highlighting (keep near the end)
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Minimal prompt
PROMPT='%F{green}>%f '
EOF

# 6. Set default login shell
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"

if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
  echo "==> Setting default login shell to $ZSH_PATH..."
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo usermod -s "$ZSH_PATH" "$USER" || sudo chsh -s "$ZSH_PATH" "$USER" || chsh -s "$ZSH_PATH"
  else
    chsh -s "$ZSH_PATH"
  fi
  echo "    Default shell changed to Zsh."
else
  echo "    Zsh is already the default shell."
fi

echo ""
echo "==> [QDeck:08-zsh] Zsh setup completed."
echo "    Config: $ZSHRC"
echo "    Aliases: $CONFIG_DIR/aliases.zsh"
echo "    Functions: $CONFIG_DIR/functions.zsh"
echo "    Prompt: >"
echo ""
echo "Apply now with: exec zsh"
exit 0
```

---

### bin/lib/qdeck-ipc.sh
- **Path:** `bin/lib/qdeck-ipc.sh`

```bash
#!/usr/bin/env bash
# QDeck: Shared IPC caller for QDeck CLI scripts

call_ipc() {
  local target="$1"; shift
  local method="$1"; shift
  local out=""
  local qs_bin="qs"
  command -v qs >/dev/null 2>&1 || qs_bin="quickshell"

  # 1. Direct IPC call
  if out=$("$qs_bin" ipc call "$target" "$method" "$@" 2>&1); then
    printf '%s\n' "$out"
    return 0
  fi

  # 2. Config path fallback
  local cfg_dir="${QUICKSHELL_DIR:-$HOME/.config/quickshell}"
  if [[ -d "$cfg_dir" ]]; then
    if out=$("$qs_bin" -p "$cfg_dir" ipc call "$target" "$method" "$@" 2>&1); then
      printf '%s\n' "$out"
      return 0
    fi
  fi

  return 1
}
```

---

