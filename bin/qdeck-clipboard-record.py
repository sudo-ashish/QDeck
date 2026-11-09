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

STATE_DIR = os.path.expanduser("~/.local/state/quickshell")
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
