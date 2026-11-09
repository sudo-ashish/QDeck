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
        saveTimer.restart()
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
    // Disk State Persistence (~/.local/state/quickshell/clipboard-history.json)
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
            "import sys, json, os; p = os.path.expanduser('~/.local/state/quickshell/clipboard-history.json'); os.makedirs(os.path.dirname(p), exist_ok=True); json.dump(json.loads(sys.argv[1]), open(p, 'w'), indent=2)",
            jsonStr
        ]
        saveStateProc.running = true
    }

    property Process loadStateProc: Process {
        id: loadStateProc
        command: ["cat", Quickshell.env("HOME") + "/.local/state/quickshell/clipboard-history.json"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var list = JSON.parse(text.trim())
                    if (Array.isArray(list)) {
                        for (var i = 0; i < list.length; i++) {
                            var it = list[i]
                            if (it && it.text && it.text.trim()) {
                                items.append({
                                    id: String(i),
                                    text: it.text,
                                    timestamp: it.timestamp || 0,
                                    lines: it.lines || it.text.split("\n").length,
                                    chars: it.chars || it.text.length
                                })
                            }
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        loadStateProc.running = true
    }
}
