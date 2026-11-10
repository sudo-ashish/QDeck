import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    property bool isOpen: false
    property ListModel items: ListModel { id: clipboardModel }
    readonly property int count: items.count

    signal openRequested()

    function open() {
        if (!root.isOpen) {
            root.isOpen = true
        }
        root.openRequested()
    }

    function close() {
        root.isOpen = false
    }

    function toggle() {
        root.isOpen = !root.isOpen
        if (root.isOpen) {
            root.openRequested()
        }
    }

    function hasItem(text) {
        for (var i = 0; i < items.count; i++) {
            if (items.get(i).text === text) return i
        }
        return -1
    }

    function addItem(text, timestamp, lines, chars) {
        if (!text || !text.trim()) return
        var existingIdx = root.hasItem(text)
        if (existingIdx !== -1) {
            items.remove(existingIdx)
        }
        var now = timestamp || Math.floor(Date.now() / 1000)
        var l = lines || text.split("\n").length
        var c = chars || text.length

        items.insert(0, {
            id: String(Date.now()) + "_" + Math.floor(Math.random() * 1000),
            text: text,
            timestamp: now,
            lines: l,
            chars: c
        })

        while (items.count > 100) {
            items.remove(items.count - 1)
        }
    }

    function copyItem(index) {
        if (index < 0 || index >= items.count) return false
        var it = items.get(index)
        if (!it || !it.text) return false

        copyProc.command = ["wl-copy", "--", it.text]
        copyProc.running = true

        if (index > 0) {
            var txt = it.text
            var ts = Math.floor(Date.now() / 1000)
            var lns = it.lines
            var chs = it.chars
            items.remove(index)
            items.insert(0, {
                id: String(Date.now()),
                text: txt,
                timestamp: ts,
                lines: lns,
                chars: chs
            })
            saveTimer.restart()
        }
        return true
    }

    function removeItem(index) {
        if (index < 0 || index >= items.count) return false
        items.remove(index)
        saveTimer.restart()
        return true
    }

    function clear() {
        items.clear()
        saveStateProc.command = [
            "python3", "-c",
            "import os; r = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'); p1 = os.path.join(r, 'quickshell', 'clipboard-history.json'); p2 = os.path.expanduser('~/.local/state/quickshell/clipboard-history.json'); [os.remove(p) for p in (p1, p2) if os.path.exists(p)]"
        ]
        saveStateProc.running = true
        clearProc.command = ["wl-copy", "-c"]
        clearProc.running = true
        return true
    }

    function getItemsJson() {
        var arr = []
        for (var i = 0; i < items.count; i++) {
            var it = items.get(i)
            arr.push({
                text: it.text,
                timestamp: it.timestamp,
                lines: it.lines,
                chars: it.chars
            })
        }
        return JSON.stringify(arr)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Real-time clipboard event listener via wl-paste -t text -w
    // ─────────────────────────────────────────────────────────────────────────
    property Process clipboardWatchProc: Process {
        id: clipboardWatchProc
        command: ["qdeck-clipboard-monitor"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var clean = line.trim()
                if (!clean) return
                try {
                    var data = JSON.parse(clean)
                    if (data && data.text) {
                        root.addItem(data.text, data.timestamp, data.lines, data.chars)
                    }
                } catch (e) {}
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // IPC Handler for controlling Clipboard via CLI (qs ipc call clipboard ...)
    // ─────────────────────────────────────────────────────────────────────────
    property IpcHandler ipcHandler: IpcHandler {
        target: "clipboard"

        function toggle(): string {
            root.toggle()
            return root.isOpen ? "open" : "closed"
        }

        function open(): string {
            root.open()
            return "open"
        }

        function close(): string {
            root.close()
            return "closed"
        }

        function clear(): string {
            root.clear()
            return "cleared"
        }

        function count(): string {
            return String(root.count)
        }

        function list(): string {
            return root.getItemsJson()
        }

        function copy(indexStr: string): string {
            var idx = parseInt(indexStr, 10)
            if (isNaN(idx)) return "error"
            var ok = root.copyItem(idx)
            return ok ? "copied" : "failed"
        }

        function remove(indexStr: string): string {
            var idx = parseInt(indexStr, 10)
            if (isNaN(idx)) return "error"
            var ok = root.removeItem(idx)
            return ok ? "removed" : "failed"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Ephemeral Runtime State Persistence (tmpfs in $XDG_RUNTIME_DIR)
    // Deleted on QDeck restart and system reboot/poweroff
    // ─────────────────────────────────────────────────────────────────────────
    property Timer saveTimer: Timer {
        id: saveTimer
        interval: 300
        repeat: false
        onTriggered: root.executeSaveState()
    }

    property Process saveStateProc: Process { id: saveStateProc }
    property Process copyProc: Process { id: copyProc }
    property Process clearProc: Process { id: clearProc }

    function executeSaveState() {
        if (saveStateProc.running) {
            saveTimer.restart()
            return
        }
        var arr = []
        for (var i = 0; i < items.count; i++) {
            var it = items.get(i)
            arr.push({
                text: it.text,
                timestamp: it.timestamp,
                lines: it.lines,
                chars: it.chars
            })
        }
        var jsonStr = JSON.stringify(arr)
        saveStateProc.command = [
            "python3", "-c",
            "import sys, json, os; r = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'); d = os.path.join(r, 'quickshell') if os.path.isdir(r) else os.path.expanduser('~/.local/state/quickshell'); os.makedirs(d, exist_ok=True); p = os.path.join(d, 'clipboard-history.json'); json.dump(json.loads(sys.argv[1]), open(p, 'w'), indent=2)",
            jsonStr
        ]
        saveStateProc.running = true
    }

    Component.onCompleted: {
        // Ephemeral session-only clipboard history:
        // Starts empty on each QDeck session; cleaned up on restart and poweroff
    }
}

