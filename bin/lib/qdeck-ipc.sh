#!/usr/bin/env bash
# QDeck: Shared IPC caller for QDeck CLI scripts
export QS_NO_RELOAD_POPUP=1

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

