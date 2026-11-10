import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"
import "LauncherModel.js" as LauncherModel

PanelWindow {
    id: root

    readonly property string fontFamily: Fonts.uiFont

    property PowerService powerService: null
    property ThemeSwitcherService themeService: null
    property WallpaperSwitcherService wallpaperService: null
    property ShelfService shelfService: null
    property ClipboardService clipboardService: null

    property bool isOpen: false
    property string currentView: "apps" // "apps" | "power" | "theme" | "wallpaper" | "shelf" | "clipboard"
    property real animProgress: 0.0

    // Transitions between views
    readonly property bool viewTransitionsEnabled: root.isOpen && !openAnim.running && !closeAnim.running

    // Selection indices for each view
    property int powerIndex: 0
    property int themeIndex: 0
    property int wallpaperIndex: 0

    // Theme service bindings
    readonly property var themes: root.themeService ? root.themeService.themes : []
    readonly property int themesCount: root.themes ? root.themes.length : 0
    readonly property string currentTheme: root.themeService ? root.themeService.currentTheme : ""

    // Wallpaper service bindings
    readonly property var wallpapers: root.wallpaperService ? root.wallpaperService.wallpapers : []
    readonly property int wallpapersCount: root.wallpapers ? root.wallpapers.length : 0
    readonly property string activeWallpaper: root.wallpaperService ? root.wallpaperService.activeWallpaper : ""

    // App launcher data
    property var allApps: []
    property var filteredItems: []
    property int filteredCount: 0
    property var historyMap: ({})

    // Theme & Wallpaper Search Filter & Palette Helpers
    property string themeFilter: ""
    property string wallpaperFilter: ""

    readonly property var filteredThemes: {
        var list = root.themes || []
        if (!root.themeFilter || root.themeFilter.trim() === "") return list
        var q = root.themeFilter.trim().toLowerCase()
        return list.filter(function(t) {
            return (t.id && t.id.toLowerCase().indexOf(q) !== -1) ||
                   (t.name && t.name.toLowerCase().indexOf(q) !== -1)
        })
    }

    readonly property var filteredWallpapers: {
        var list = root.wallpapers || []
        if (!root.wallpaperFilter || root.wallpaperFilter.trim() === "") return list
        var q = root.wallpaperFilter.trim().toLowerCase()
        return list.filter(function(w) {
            return (w.name && w.name.toLowerCase().indexOf(q) !== -1) ||
                   (w.filename && w.filename.toLowerCase().indexOf(q) !== -1)
        })
    }

    function getThemePalette(item) {
        if (item && Array.isArray(item.palette) && item.palette.length >= 6) {
            return item.palette
        }
        var acc = (item && item.accent) ? item.accent : Theme.accent
        return ["#ea6962", "#a9b665", "#d8a657", acc, "#d3869b", "#89b482"]
    }

    // Dynamic target dimensions per view
    readonly property real targetWidth: {
        if (root.currentView === "apps" || root.currentView === "shelf" || root.currentView === "clipboard") return Appearance.launcherWidth
        if (root.currentView === "power") return 500
        if (root.currentView === "theme") return 720
        if (root.currentView === "wallpaper") return 720
        return 580
    }

    readonly property real targetHeight: {
        if (root.currentView === "apps") {
            var isSearching = searchInput && searchInput.text.trim().length > 0
            var count = root.filteredCount
            if (count <= 0) {
                if (!isSearching) return Appearance.launcherHeight
                // Empty search result: compact card framing the search box + "no results" hint
                return 130
            }
            // Dynamic height based on number of items:
            // Fixed vertical chrome: 92px (top margin 14 + bottom margin 8 + search box 56 + outer margin 14)
            // Each item: 52px height (Appearance.launcherItemHeight) + 2px spacing = 54px
            var itemContentH = (count * Appearance.launcherItemHeight) + (Math.max(0, count - 1) * 2)
            var totalH = 92 + itemContentH
            return Math.min(Appearance.launcherHeight, totalH)
        }
        if (root.currentView === "clipboard") {
            var clipCount = clipboardView ? clipboardView.filteredCount : (root.clipboardService ? root.clipboardService.items.count : 0)
            var isClipSearching = clipboardView && clipboardView.isSearching
            if (clipCount <= 0) {
                return isClipSearching ? 210 : 230
            }
            // Dynamic height based on number of items:
            // Fixed vertical chrome: 136px (top margin 14 + header 32 + topMargin 10 + bottomMargin 10 + search box 56 + outer bottom 14)
            // Each item: 56px height + 4px spacing
            var clipContentH = (clipCount * 56) + (Math.max(0, clipCount - 1) * 4)
            var totalClipH = 136 + clipContentH
            return Math.min(Appearance.launcherHeight, totalClipH)
        }
        if (root.currentView === "shelf") return Appearance.launcherHeight
        if (root.currentView === "power") return 130
        if (root.currentView === "wallpaper") return 180
        if (root.currentView === "theme") return 210
        return Appearance.launcherHeight
    }

    // Material Design 3 (M3) Shared Axis Y + Z physics from bottom
    NumberAnimation {
        id: openAnim
        target: root
        property: "animProgress"
        to: 1.0
        duration: Motion.enterYDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.emphasizedDecelerateCurve
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "animProgress"
        to: 0.0
        duration: Motion.exitYDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.emphasizedAccelerateCurve
        onFinished: {
            root.animProgress = 0.0
            if (!root.isOpen) {
                if (root.powerService) root.powerService.powerMenuOpen = false
                if (root.themeService) root.themeService.isOpen = false
                if (root.wallpaperService) root.wallpaperService.isOpen = false
                if (root.shelfService) root.shelfService.isOpen = false
                if (root.clipboardService) root.clipboardService.isOpen = false
                root.currentView = "apps"
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Navigation & View Switching Helpers
    // ─────────────────────────────────────────────────────────────────────────
    function openApps(initialQuery) {
        var wasOpen = root.isOpen
        if (closeAnim.running) {
            closeAnim.stop()
            root.animProgress = 1.0
        }
        root.currentView = "apps"
        if (root.powerService) root.powerService.powerMenuOpen = false
        if (root.themeService) root.themeService.isOpen = false
        if (root.wallpaperService) root.wallpaperService.isOpen = false
        if (root.shelfService) root.shelfService.isOpen = false
        if (root.clipboardService) root.clipboardService.isOpen = false
        root.loadHistory()
        root.loadApps()
        searchInput.text = (typeof initialQuery === "string") ? initialQuery : ""
        root.filterItems()
        listView.currentIndex = 0
        root.isOpen = true
        if (!wasOpen || root.animProgress < 1.0) {
            openAnim.restart()
        }
        Qt.callLater(function() {
            searchInput.forceActiveFocus()
        })
    }

    function openPower() {
        var wasOpen = root.isOpen
        if (closeAnim.running) {
            closeAnim.stop()
            root.animProgress = 1.0
        }
        root.currentView = "power"
        if (root.themeService) root.themeService.isOpen = false
        if (root.wallpaperService) root.wallpaperService.isOpen = false
        if (root.shelfService) root.shelfService.isOpen = false
        if (root.clipboardService) root.clipboardService.isOpen = false
        root.powerIndex = 0
        if (root.powerService) root.powerService.powerMenuOpen = true
        root.isOpen = true
        if (!wasOpen || root.animProgress < 1.0) {
            openAnim.restart()
        }
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    function openTheme() {
        var wasOpen = root.isOpen
        if (closeAnim.running) {
            closeAnim.stop()
            root.animProgress = 1.0
        }
        root.currentView = "theme"
        if (root.powerService) root.powerService.powerMenuOpen = false
        if (root.wallpaperService) root.wallpaperService.isOpen = false
        if (root.shelfService) root.shelfService.isOpen = false
        if (root.clipboardService) root.clipboardService.isOpen = false
        if (root.themeService) {
            root.themeService.refresh()
            root.themeService.isOpen = true
        }
        root.themeFilter = ""
        if (themeSearchInput) themeSearchInput.text = ""
        root.themeIndex = (root.themeService && root.themeService.middleIndex !== undefined)
            ? root.themeService.middleIndex
            : Math.floor(root.themesCount / 2)
        root.isOpen = true
        if (!wasOpen || root.animProgress < 1.0) {
            openAnim.restart()
        }
        Qt.callLater(function() {
            if (themeSearchInput) themeSearchInput.forceActiveFocus()
            if (themesList) {
                themesList.currentIndex = root.themeIndex
                themesList.positionViewAtIndex(root.themeIndex, ListView.Center)
            }
        })
    }

    function openWallpaper() {
        var wasOpen = root.isOpen
        if (closeAnim.running) {
            closeAnim.stop()
            root.animProgress = 1.0
        }
        root.currentView = "wallpaper"
        if (root.powerService) root.powerService.powerMenuOpen = false
        if (root.themeService) root.themeService.isOpen = false
        if (root.shelfService) root.shelfService.isOpen = false
        if (root.clipboardService) root.clipboardService.isOpen = false
        if (root.wallpaperService) {
            root.wallpaperService.refresh()
            root.wallpaperService.isOpen = true
        }
        root.wallpaperFilter = ""
        root.wallpaperIndex = (root.wallpaperService && root.wallpaperService.middleIndex !== undefined)
            ? root.wallpaperService.middleIndex
            : Math.floor(root.wallpapersCount / 2)
        root.isOpen = true
        if (!wasOpen || root.animProgress < 1.0) {
            openAnim.restart()
        }
        Qt.callLater(function() {
            keyCatcher.forceActiveFocus()
            if (wallpapersList) {
                wallpapersList.currentIndex = root.wallpaperIndex
                wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Center)
            }
        })
    }

    function close() {
        if (!root.isOpen && !openAnim.running) return
        openAnim.stop()
        if (root.shelfService) root.shelfService.isOpen = false
        if (root.clipboardService) root.clipboardService.isOpen = false
        root.isOpen = false
        closeAnim.restart()
    }

    function toggleApps(initialQuery) {
        if (root.isOpen && root.currentView === "apps") {
            root.close()
        } else {
            root.openApps(initialQuery)
        }
    }

    function togglePower() {
        if (root.isOpen && root.currentView === "power") {
            root.close()
        } else {
            root.openPower()
        }
    }

    function toggleTheme() {
        if (root.isOpen && root.currentView === "theme") {
            root.close()
        } else {
            root.openTheme()
        }
    }

    function toggleWallpaper() {
        if (root.isOpen && root.currentView === "wallpaper") {
            root.close()
        } else {
            root.openWallpaper()
        }
    }

    function openShelf() {
        var wasOpen = root.isOpen
        if (closeAnim.running) {
            closeAnim.stop()
            root.animProgress = 1.0
        }
        root.currentView = "shelf"
        if (root.powerService) root.powerService.powerMenuOpen = false
        if (root.themeService) root.themeService.isOpen = false
        if (root.wallpaperService) root.wallpaperService.isOpen = false
        if (root.clipboardService) root.clipboardService.isOpen = false
        if (root.shelfService) {
            root.shelfService.isOpen = true
        }
        root.isOpen = true
        if (!wasOpen || root.animProgress < 1.0) {
            openAnim.restart()
        }
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    function toggleShelf() {
        if (root.isOpen && root.currentView === "shelf") {
            root.close()
        } else {
            root.openShelf()
        }
    }

    function openClipboard() {
        var wasOpen = root.isOpen
        if (closeAnim.running) {
            closeAnim.stop()
            root.animProgress = 1.0
        }
        root.currentView = "clipboard"
        if (root.powerService) root.powerService.powerMenuOpen = false
        if (root.themeService) root.themeService.isOpen = false
        if (root.wallpaperService) root.wallpaperService.isOpen = false
        if (root.shelfService) root.shelfService.isOpen = false
        if (root.clipboardService) {
            root.clipboardService.isOpen = true
        }
        root.isOpen = true
        if (!wasOpen || root.animProgress < 1.0) {
            openAnim.restart()
        }
        Qt.callLater(function() {
            if (clipboardView) clipboardView.focusSearch()
        })
    }

    function toggleClipboard() {
        if (root.isOpen && root.currentView === "clipboard") {
            root.close()
        } else {
            root.openClipboard()
        }
    }

    function switchToView(viewName) {
        if (root.currentView === viewName) {
            if (viewName === "shelf" || viewName === "clipboard") {
                root.close()
            }
            return
        }
        if (viewName === "apps") {
            root.openApps("")
        } else if (viewName === "power") {
            root.openPower()
        } else if (viewName === "theme") {
            root.openTheme()
        } else if (viewName === "wallpaper") {
            root.openWallpaper()
        } else if (viewName === "shelf") {
            root.openShelf()
        } else if (viewName === "clipboard") {
            root.openClipboard()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Power Actions
    // ─────────────────────────────────────────────────────────────────────────
    readonly property var powerActions: [
        {
            id: "lock",
            name: "Lock Screen",
            icon: Icons.lock,
            isUrgent: false,
            exec: function() {
                root.close()
                Quickshell.execDetached(["sh", "-c", "loginctl lock-session || hyprlock || swaylock"])
            }
        },
        {
            id: "suspend",
            name: "Suspend",
            icon: Icons.suspend,
            isUrgent: false,
            exec: function() {
                root.close()
                Quickshell.execDetached(["systemctl", "suspend"])
            }
        },
        {
            id: "logout",
            name: "Log Out",
            icon: Icons.logout,
            isUrgent: false,
            exec: function() {
                root.close()
                Quickshell.execDetached(["sh", "-c", "hyprctl dispatch exit || loginctl terminate-user \"$USER\""])
            }
        },
        {
            id: "restart",
            name: "Restart",
            icon: Icons.reboot,
            isUrgent: true,
            exec: function() {
                root.close()
                Quickshell.execDetached(["systemctl", "reboot"])
            }
        },
        {
            id: "shutdown",
            name: "Shut Down",
            icon: Icons.power,
            isUrgent: true,
            exec: function() {
                root.close()
                Quickshell.execDetached(["systemctl", "poweroff"])
            }
        }
    ]

    function nextPower() {
        root.powerIndex = (root.powerIndex + 1) % root.powerActions.length
    }

    function prevPower() {
        root.powerIndex = (root.powerIndex - 1 + root.powerActions.length) % root.powerActions.length
    }

    function selectPower(idx) {
        if (idx >= 0 && idx < root.powerActions.length) {
            root.powerIndex = idx
        }
    }

    function executeCurrentPower() {
        if (root.powerIndex >= 0 && root.powerIndex < root.powerActions.length) {
            root.powerActions[root.powerIndex].exec()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Theme Switcher Actions
    // ─────────────────────────────────────────────────────────────────────────
    function nextTheme() {
        var list = root.filteredThemes
        if (list.length <= 0) return
        root.themeIndex = (root.themeIndex + 1) % list.length
        if (themesList) {
            themesList.currentIndex = root.themeIndex
            themesList.positionViewAtIndex(root.themeIndex, ListView.Center)
        }
    }

    function prevTheme() {
        var list = root.filteredThemes
        if (list.length <= 0) return
        root.themeIndex = (root.themeIndex - 1 + list.length) % list.length
        if (themesList) {
            themesList.currentIndex = root.themeIndex
            themesList.positionViewAtIndex(root.themeIndex, ListView.Center)
        }
    }

    function selectTheme(idx) {
        var list = root.filteredThemes
        if (idx >= 0 && idx < list.length) {
            root.themeIndex = idx
            if (themesList) {
                themesList.currentIndex = root.themeIndex
                themesList.positionViewAtIndex(root.themeIndex, ListView.Center)
            }
        }
    }

    function applyCurrentTheme() {
        var list = root.filteredThemes
        if (root.themeIndex >= 0 && root.themeIndex < list.length) {
            root.applyTheme(list[root.themeIndex].id)
        }
    }

    function applyTheme(themeId) {
        if (!themeId) return
        if (root.themeService) {
            root.themeService.switchTheme(themeId)
        }
        themeCloseTimer.restart()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Wallpaper Switcher Actions
    // ─────────────────────────────────────────────────────────────────────────
    function nextWallpaper() {
        var list = root.filteredWallpapers
        if (list.length <= 0) return
        root.wallpaperIndex = (root.wallpaperIndex + 1) % list.length
        if (wallpapersList) {
            wallpapersList.currentIndex = root.wallpaperIndex
            wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Center)
        }
    }

    function prevWallpaper() {
        var list = root.filteredWallpapers
        if (list.length <= 0) return
        root.wallpaperIndex = (root.wallpaperIndex - 1 + list.length) % list.length
        if (wallpapersList) {
            wallpapersList.currentIndex = root.wallpaperIndex
            wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Center)
        }
    }

    function selectWallpaper(idx) {
        var list = root.filteredWallpapers
        if (idx >= 0 && idx < list.length) {
            root.wallpaperIndex = idx
            if (wallpapersList) {
                wallpapersList.currentIndex = root.wallpaperIndex
                wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Center)
            }
        }
    }

    function applyCurrentWallpaper() {
        var list = root.filteredWallpapers
        if (root.wallpaperIndex >= 0 && root.wallpaperIndex < list.length) {
            root.applyWallpaper(list[root.wallpaperIndex].path)
        }
    }

    function applyWallpaper(wallpaperPath) {
        if (!wallpaperPath) return
        if (root.wallpaperService) {
            root.wallpaperService.switchWallpaper(wallpaperPath)
        }
        themeCloseTimer.restart()
    }

    Timer {
        id: themeCloseTimer
        interval: 220
        repeat: false
        onTriggered: root.close()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Apps Launcher Helpers
    // ─────────────────────────────────────────────────────────────────────────
    function loadApps() {
        root.allApps = DesktopEntries.applications.values || []
    }

    function loadHistory() {
        historyReader.running = true
    }

    function parseHistory(raw) {
        if (!raw || raw.trim() === "") return
        try {
            var data = JSON.parse(raw)
            if (data && typeof data === "object") {
                root.historyMap = data
                root.filterItems()
            }
        } catch (e) {}
    }

    function recordLaunch(id) {
        if (!id) return
        var now = Date.now()
        var updated = Object.assign({}, root.historyMap)
        updated[id] = now
        root.historyMap = updated

        var escapedId = JSON.stringify(id)
        var cmd = "python3 -c 'import json, os; p = os.path.expanduser(\"~/.local/state/quickshell/launcher-history.json\"); os.makedirs(os.path.dirname(p), exist_ok=True); data = json.load(open(p)) if os.path.exists(p) else {}; data[" + escapedId + "] = " + now + "; json.dump(data, open(p, \"w\"), indent=2)' 2>/dev/null || true"
        Quickshell.execDetached(["bash", "-c", cmd])
    }

    function filterItems() {
        var q = searchInput.text.trim()
        root.filteredItems = LauncherModel.filterAll(root.allApps, q, root.historyMap)
        root.filteredCount = root.filteredItems ? root.filteredItems.length : 0
        if (listView.currentIndex >= root.filteredCount) {
            listView.currentIndex = 0
        }
    }

    function executeCurrentItem() {
        if (!root.filteredItems || root.filteredItems.length === 0) return

        var item = root.filteredItems[listView.currentIndex]
        if (!item) return

        root.recordLaunch(item.id)

        if (item.type === "action") {
            // Built-in view switches
            if (item.id === "act-theme") {
                root.openTheme()
                return
            } else if (item.id === "act-wallpaper") {
                root.openWallpaper()
                return
            } else if (item.id === "act-shelf") {
                root.openShelf()
                return
            } else if (item.id === "act-clipboard") {
                root.openClipboard()
                return
            } else if (item.cmd) {
                Quickshell.execDetached(["bash", "-c", item.cmd])
            }
        } else if (item.entry) {
            try {
                if (item.entry.runInTerminal) {
                    Quickshell.execDetached(["gtk-launch", item.id])
                } else if (item.entry.execute) {
                    item.entry.execute()
                } else {
                    Quickshell.execDetached(["gtk-launch", item.id])
                }
            } catch (e) {
                Quickshell.execDetached(["gtk-launch", item.id])
            }
        }

        root.close()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Window Setup
    // ─────────────────────────────────────────────────────────────────────────
    visible: root.isOpen || closeAnim.running
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    screen: {
        if (!Quickshell.screens || Quickshell.screens.length === 0) return null
        var foc = Hyprland.focusedMonitor
        if (foc && foc.name) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === foc.name) {
                    return Quickshell.screens[i]
                }
            }
        }
        return Quickshell.screens[0]
    }

    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!root.isOpen || closeAnim.running) return WlrKeyboardFocus.None
        if (root.currentView === "shelf") return WlrKeyboardFocus.OnDemand
        return WlrKeyboardFocus.Exclusive
    }
    exclusionMode: ExclusionMode.Ignore

    // Pass-through input region: When in shelf view, all mouse clicks outside launcherCard pass directly to the screen
    Region {
        id: shelfInputRegion
        x: launcherCard.x
        y: launcherCard.y
        width: launcherCard.width
        height: launcherCard.height
    }

    mask: (root.currentView === "shelf") ? shelfInputRegion : null

    onIsOpenChanged: {
        if (root.isOpen) {
            if (root.currentView === "apps") {
                Qt.callLater(function() { searchInput.forceActiveFocus() })
            } else if (root.currentView === "clipboard") {
                Qt.callLater(function() { if (clipboardView) clipboardView.focusSearch() })
            } else {
                Qt.callLater(function() { keyCatcher.forceActiveFocus() })
            }
        }
    }

    Process {
        id: historyReader
        command: ["cat", Quickshell.env("HOME") + "/.local/state/quickshell/launcher-history.json"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.parseHistory(text)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // IPC Handlers: Unified CLI compatibility
    // ─────────────────────────────────────────────────────────────────────────
    // 1. App Launcher IPC (qdeck launcher)
    IpcHandler {
        target: "launcher"
        function open() { root.openApps("") }
        function search(query: string) { root.openApps(query) }
        function close() { root.close() }
        function toggle() { root.toggleApps("") }
        function setMode(mode: string) { root.openApps("") }
    }

    // 2. Power Menu IPC (qdeck powermenu)
    IpcHandler {
        target: "powermenu"
        function open(): string { root.openPower(); return "ok" }
        function close(): string { root.close(); return "ok" }
        function toggle(): string { root.togglePower(); return (root.isOpen && root.currentView === "power") ? "open" : "closed" }
        function next(): string { root.nextPower(); return String(root.powerIndex) }
        function prev(): string { root.prevPower(); return String(root.powerIndex) }
        function select(index: string): string { root.selectPower(parseInt(index)); return "ok" }
        function getState(): string {
            return JSON.stringify({
                isOpen: root.isOpen,
                currentView: root.currentView,
                selectedIndex: root.powerIndex,
                selectedAction: root.powerActions[root.powerIndex] ? root.powerActions[root.powerIndex].id : null
            })
        }
    }

    // 3. Theme Switcher IPC (qdeck themeswitcher)
    IpcHandler {
        target: "themeswitcher"
        function open(): string { root.openTheme(); return "ok" }
        function close(): string { root.close(); return "ok" }
        function toggle(): string { root.toggleTheme(); return (root.isOpen && root.currentView === "theme") ? "open" : "closed" }
        function next(): string { root.nextTheme(); return String(root.themeIndex) }
        function prev(): string { root.prevTheme(); return String(root.themeIndex) }
        function select(index: string): string { root.selectTheme(parseInt(index)); return "ok" }
        function apply(themeId: string): string { root.applyTheme(themeId); return "ok" }
        function getState(): string {
            var sel = (root.themeIndex >= 0 && root.themeIndex < root.themesCount) ? root.themes[root.themeIndex] : null
            return JSON.stringify({
                isOpen: root.isOpen,
                currentView: root.currentView,
                selectedIndex: root.themeIndex,
                selectedTheme: sel ? sel.id : null,
                selectedThemeName: sel ? sel.name : null,
                currentTheme: root.currentTheme,
                themesCount: root.themesCount
            })
        }
    }

    // 4. Wallpaper Switcher IPC (qdeck wallpaperswitcher)
    IpcHandler {
        target: "wallpaperswitcher"
        function open(): string { root.openWallpaper(); return "ok" }
        function close(): string { root.close(); return "ok" }
        function toggle(): string { root.toggleWallpaper(); return (root.isOpen && root.currentView === "wallpaper") ? "open" : "closed" }
        function next(): string { root.nextWallpaper(); return String(root.wallpaperIndex) }
        function prev(): string { root.prevWallpaper(); return String(root.wallpaperIndex) }
        function select(index: string): string { root.selectWallpaper(parseInt(index)); return "ok" }
        function apply(wallPath: string): string { root.applyWallpaper(wallPath); return "ok" }
        function getState(): string {
            var sel = (root.wallpaperIndex >= 0 && root.wallpaperIndex < root.wallpapersCount) ? root.wallpapers[root.wallpaperIndex] : null
            return JSON.stringify({
                isOpen: root.isOpen,
                currentView: root.currentView,
                selectedIndex: root.wallpaperIndex,
                selectedWallpaper: sel ? sel.path : null,
                selectedWallpaperName: sel ? sel.name : null,
                activeWallpaper: root.activeWallpaper,
                wallpapersCount: root.wallpapersCount
            })
        }
    }

    // Backdrop Scrim (Active only on apps, power, theme, wallpaper - completely disabled on shelf)
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.darker_background, 0.45)
        opacity: (root.isOpen && root.currentView !== "shelf") ? 1.0 : 0.0
        visible: root.currentView !== "shelf"
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.currentView !== "shelf"
            onClicked: {
                if (root.currentView !== "shelf") {
                    root.close()
                }
            }
        }
    }

    HyprlandFocusGrab {
        active: false
        windows: [root]
        onCleared: root.close()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.loadApps()
            root.filterItems()
        }
    }

    Connections {
        target: root.shelfService
        function onIsOpenChanged() {
            if (root.shelfService && root.shelfService.isOpen) {
                if (root.currentView !== "shelf" || !root.isOpen) {
                    root.openShelf()
                }
            } else if (!root.shelfService || !root.shelfService.isOpen) {
                if (root.isOpen && root.currentView === "shelf") {
                    root.close()
                }
            }
        }
        function onOpenRequested() {
            root.openShelf()
        }
    }

    Connections {
        target: root.clipboardService
        function onIsOpenChanged() {
            if (root.clipboardService && root.clipboardService.isOpen) {
                if (root.currentView !== "clipboard" || !root.isOpen) {
                    root.openClipboard()
                }
            } else if (!root.clipboardService || !root.clipboardService.isOpen) {
                if (root.isOpen && root.currentView === "clipboard") {
                    root.close()
                }
            }
        }
        function onOpenRequested() {
            root.openClipboard()
        }
    }

    // Keyboard Controller for non-input views (power, theme, wallpaper, shelf)
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: root.isOpen && root.currentView !== "apps"

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (root.currentView === "shelf" && root.shelfService && root.shelfService.selectedCount > 0) {
                    root.shelfService.clearSelection()
                    event.accepted = true
                    return
                }
                root.close()
                event.accepted = true
                return
            }

            if (root.currentView === "power") {
                if (event.key === Qt.Key_Left) {
                    root.prevPower()
                    event.accepted = true
                } else if (event.key === Qt.Key_Right) {
                    root.nextPower()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.executeCurrentPower()
                    event.accepted = true
                }
            } else if (root.currentView === "theme") {
                if (event.key === Qt.Key_Left) {
                    root.prevTheme()
                    event.accepted = true
                } else if (event.key === Qt.Key_Right) {
                    root.nextTheme()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.applyCurrentTheme()
                    event.accepted = true
                }
            } else if (root.currentView === "wallpaper") {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    root.prevWallpaper()
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    root.nextWallpaper()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.applyCurrentWallpaper()
                    event.accepted = true
                }
            } else if (root.currentView === "shelf") {
                if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
                    if (root.shelfService) root.shelfService.selectAll()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                    if (root.shelfService && root.shelfService.selectedCount > 0) {
                        root.shelfService.removeSelected()
                        event.accepted = true
                        return
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main Unified Deck Card
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: launcherCard

        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 28
        }

        width: Math.min(parent.width - 32, root.targetWidth)
        height: Math.min(parent.height - 60, root.targetHeight)
        radius: Appearance.launcherRadius

        // Material Design 3 (M3) Container Transform: synchronized dimensions morph
        Behavior on width {
            enabled: root.viewTransitionsEnabled
            NumberAnimation {
                duration: Motion.medium3
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.emphasizedCurve
            }
        }
        Behavior on height {
            enabled: root.viewTransitionsEnabled
            NumberAnimation {
                duration: Motion.medium3
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.emphasizedCurve
            }
        }

        color: Theme.withAlpha(Theme.darker_background, Theme.baseOpacity)
        border.color: Theme.withAlpha(Theme.border, 0.28)
        border.width: 1
        clip: true

        // M3 Shared Axis Y (Translate) + Z (Scale)
        transform: Translate {
            y: (1.0 - root.animProgress) * (launcherCard.height + 64)
        }
        opacity: Math.min(1.0, root.animProgress * 1.5)
        scale: Motion.enterZScaleStart + (1.0 - Motion.enterZScaleStart) * Math.max(0, Math.min(1.0, root.animProgress))

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.currentView === "apps") {
                    searchInput.forceActiveFocus()
                } else {
                    keyCatcher.forceActiveFocus()
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // VIEW 1: Apps & Actions Launcher
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: appsViewContainer
            anchors.fill: parent
            visible: root.currentView === "apps"

            // Items List
            Item {
                anchors {
                    top: parent.top
                    topMargin: 14
                    left: parent.left
                    leftMargin: 10
                    right: parent.right
                    rightMargin: 10
                    bottom: searchContainer.top
                    bottomMargin: 8
                }

                ListView {
                    id: listView
                    anchors.fill: parent
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filteredItems

                    delegate: Rectangle {
                        id: itemDelegate
                        required property var modelData
                        required property int index

                        width: listView.width
                        height: Appearance.launcherItemHeight
                        radius: Appearance.launcherItemRadius

                        readonly property bool isSelected: listView.currentIndex === index
                        readonly property bool isHovered: itemMouse.containsMouse

                        color: isSelected
                            ? Theme.withAlpha(Theme.accent, 0.16)
                            : (isHovered ? Theme.withAlpha(Theme.lighter_background, 0.28) : "transparent")
                        border.width: 0
                        border.color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            // Left Icon Box (32x32)
                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter

                                // Action Icon Badge
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    visible: modelData.type === "action"
                                    color: itemDelegate.isSelected ? Theme.withAlpha(Theme.accent, 0.25) : Theme.withAlpha(Theme.lighter_background, 0.35)
                                    border.width: 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            var g = modelData.iconGlyph || ""
                                            if (g === "tune") return Icons.tune
                                            if (g === "phone") return Icons.phone
                                            if (g === "volumeHigh") return Icons.volumeHigh
                                            if (g === "bell") return Icons.bell
                                            if (g === "lock") return Icons.lock
                                            if (g === "palette") return Icons.palette
                                            if (g === "wallpaper") return Icons.wallpaper
                                            if (g === "terminal") return Icons.terminal
                                            if (g === "screenshot") return Icons.screenshot
                                            if (g === "power") return Icons.power
                                            if (g === "reboot") return Icons.reboot
                                            return Icons.apps
                                        }
                                        font.family: Icons.effectiveFont(text)
                                        font.pixelSize: 18
                                        color: itemDelegate.isSelected ? Theme.accent : Theme.foreground
                                    }
                                }

                                // App Icon Image
                                Image {
                                    id: appIconImg
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    source: (modelData.type === "app" && modelData.icon) ? modelData.icon : ""
                                    sourceSize: Qt.size(64, 64)
                                    visible: modelData.type === "app" && status === Image.Ready && (modelData.icon || "") !== ""
                                }

                                // Fallback badge for app with no icon
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    visible: modelData.type === "app" && !appIconImg.visible
                                    color: itemDelegate.isSelected ? Theme.selection : Theme.withAlpha(Theme.accent, 0.18)
                                    border.width: 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData.name && modelData.name.length > 0) ? modelData.name.charAt(0).toUpperCase() : Icons.apps
                                        font.family: root.fontFamily
                                        font.pixelSize: Fonts.sizeSmall
                                        font.weight: Fonts.weightBold
                                        color: itemDelegate.isSelected ? Theme.bright_foreground : Theme.accent
                                    }
                                }
                            }

                            // App / Action Details
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                // Line 1: Title
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Fonts.weightMedium
                                    color: itemDelegate.isSelected ? Theme.bright_foreground : Theme.foreground
                                    elide: Text.ElideRight
                                }

                                // Line 2: Subtitle
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.metaText || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.muted
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: {
                                if (listView.currentIndex !== index) {
                                    listView.currentIndex = index
                                }
                            }
                            onClicked: {
                                listView.currentIndex = index
                                root.executeCurrentItem()
                            }
                        }
                    }
                }

                // Empty search results state (subtle M3 muted hint)
                Item {
                    anchors.fill: parent
                    visible: root.filteredCount === 0 && searchInput.text.trim().length > 0

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "󰍉"
                            font.family: Icons.effectiveFont("󰍉")
                            font.pixelSize: 16
                            color: Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "No matching applications"
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            color: Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Bottom: Search Input Field (Bigger, Borderless)
            Rectangle {
                id: searchContainer

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 14
                }
                height: 56
                radius: 14

                color: Theme.withAlpha(Theme.dark_background, 0.95)
                border.width: 0
                border.color: "transparent"

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 12

                    Text {
                        anchors.left: parent.left
                        anchors.right: clipToggleBtn.left
                        anchors.rightMargin: 10
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        verticalAlignment: Text.AlignVCenter
                        text: searchInput.text.startsWith(">") ? "Search action commands..." : "Search apps or type '> ' for commands..."
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        color: Theme.muted
                        visible: searchInput.text.length === 0
                        elide: Text.ElideRight
                    }

                    TextInput {
                        id: searchInput
                        anchors.left: parent.left
                        anchors.right: clipToggleBtn.left
                        anchors.rightMargin: 10
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        color: Theme.foreground
                        selectionColor: Theme.selection
                        selectedTextColor: Theme.bright_foreground
                        clip: true
                        focus: true

                        onTextChanged: {
                            root.filterItems()
                            listView.currentIndex = 0
                        }

                        Keys.onDownPressed: {
                            if (listView.count > 0) {
                                listView.currentIndex = (listView.currentIndex + 1) % listView.count
                                listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                            }
                        }

                        Keys.onUpPressed: {
                            if (listView.count > 0) {
                                listView.currentIndex = (listView.currentIndex - 1 + listView.count) % listView.count
                                listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                            }
                        }

                        Keys.onTabPressed: {
                            if (listView.count > 0) {
                                listView.currentIndex = (listView.currentIndex + 1) % listView.count
                                listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                            }
                        }

                        Keys.onBacktabPressed: {
                            if (listView.count > 0) {
                                listView.currentIndex = (listView.currentIndex - 1 + listView.count) % listView.count
                                listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                            }
                        }

                        Keys.onReturnPressed: root.executeCurrentItem()
                        Keys.onEnterPressed: root.executeCurrentItem()
                        Keys.onEscapePressed: root.close()

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_PageDown) {
                                if (listView.count > 0) {
                                    listView.currentIndex = Math.min(listView.count - 1, listView.currentIndex + 5)
                                    listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_PageUp) {
                                if (listView.count > 0) {
                                    listView.currentIndex = Math.max(0, listView.currentIndex - 5)
                                    listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                                }
                                event.accepted = true
                            }
                        }
                    }

                    // Quick-access Clipboard Toggle Button
                    Rectangle {
                        id: clipToggleBtn
                        anchors.right: shelfToggleBtn.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        height: 34
                        width: clipToggleRow.implicitWidth + 18
                        radius: 17
                        color: (root.clipboardService && root.clipboardService.isOpen)
                            ? Theme.accent
                            : (clipMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.45) : Theme.withAlpha(Theme.lighter_background, 0.22))
                        border.width: 0

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: clipToggleRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Icons.clipboard || "󰅍"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 13
                                color: (root.clipboardService && root.clipboardService.isOpen) ? Theme.darker_background : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Clipboard"
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                font.weight: (root.clipboardService && root.clipboardService.isOpen) ? Fonts.weightBold : Fonts.weightMedium
                                color: (root.clipboardService && root.clipboardService.isOpen) ? Theme.darker_background : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: clipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.switchToView("clipboard")
                            }
                        }
                    }

                    // Quick-access Staging Shelf Toggle Button
                    Rectangle {
                        id: shelfToggleBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 34
                        width: shelfToggleRow.implicitWidth + 18
                        radius: 17
                        color: (root.shelfService && root.shelfService.isOpen)
                            ? Theme.accent
                            : (shelfMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.45) : Theme.withAlpha(Theme.lighter_background, 0.22))
                        border.width: 0

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: shelfToggleRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Icons.folder
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 14
                                color: (root.shelfService && root.shelfService.isOpen) ? Theme.darker_background : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "QShelf"
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                font.weight: (root.shelfService && root.shelfService.isOpen) ? Fonts.weightBold : Fonts.weightMedium
                                color: (root.shelfService && root.shelfService.isOpen) ? Theme.darker_background : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Live counter badge when count > 0
                            Rectangle {
                                visible: root.shelfService ? root.shelfService.count > 0 : false
                                width: Math.max(18, shelfBadgeText.implicitWidth + 8)
                                height: 18
                                radius: 9
                                color: (root.shelfService && root.shelfService.isOpen) ? Theme.darker_background : Theme.accent
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: shelfBadgeText
                                    anchors.centerIn: parent
                                    text: root.shelfService ? String(root.shelfService.count) : "0"
                                    font.family: root.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Fonts.weightBold
                                    color: (root.shelfService && root.shelfService.isOpen) ? Theme.accent : Theme.darker_background
                                }
                            }
                        }

                        MouseArea {
                            id: shelfMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.switchToView("shelf")
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Close button when in shelf view
            Rectangle {
                visible: root.currentView === "shelf"
                Layout.alignment: Qt.AlignVCenter
                width: 24
                height: 24
                radius: 12
                color: closeNavMouse.containsMouse
                    ? Theme.withAlpha(Theme.urgent, 0.22)
                    : Theme.withAlpha(Theme.lighter_background, 0.20)
                border.width: 0

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: Icons.close
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 11
                    color: closeNavMouse.containsMouse ? Theme.urgent : Theme.muted
                }

                MouseArea {
                    id: closeNavMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // VIEW 2: Power Session Menu (Google Material 3 Shape-Morphing Dock)
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: powerViewContainer
            anchors.fill: parent
            visible: root.currentView === "power"

            Row {
                anchors.centerIn: parent
                spacing: 18

                Repeater {
                    model: root.powerActions

                    Item {
                        id: powerActionBtn
                        required property var modelData
                        required property int index

                        readonly property bool isActive: (root.currentView === "power") && (root.powerIndex === index)

                        width: 68
                        height: 68

                        // Random shape from {gem, oval, pill, square, arrow, sunny} for selected, cookie4 for unselected
                        readonly property var selectedShapePool: ["gem", "oval", "pill", "square", "arrow", "sunny"]
                        property string activeRandomShape: "gem"

                        function pickNewRandomShape() {
                            var pool = selectedShapePool
                            var nextShape = pool[Math.floor(Math.random() * pool.length)]
                            if (nextShape === activeRandomShape && pool.length > 1) {
                                nextShape = pool[(pool.indexOf(nextShape) + 1 + Math.floor(Math.random() * (pool.length - 1))) % pool.length]
                            }
                            activeRandomShape = nextShape
                        }

                        onIsActiveChanged: {
                            if (isActive) {
                                pickNewRandomShape()
                                bounceAnim.restart()
                            }
                        }

                        Component.onCompleted: {
                            if (isActive) {
                                pickNewRandomShape()
                            }
                        }

                        readonly property var m3ShapePaths: ({
                            "cookie4": "M69.7 69.7C64.8 74.5 57.3 76.7 49.8 73.5C48.7 73 47.6 72.5 46.5 72.1C42.4 70.3 37.7 70.3 33.5 72.1C32.5 72.6 31.4 73 30.3 73.5C15.3 80 0 64.8 6.5 49.7C7 48.7 7.5 47.6 7.9 46.5C9.7 42.3 9.7 37.7 7.9 33.5C7.5 32.4 7 31.4 6.5 30.3C0 15.3 15.2 0 30.3 6.5C31.4 7 32.4 7.5 33.5 7.9C37.7 9.7 42.4 9.7 46.5 7.9C47.6 7.4 48.6 7 49.7 6.5C64.7 0 80 15.2 73.5 30.3C73 31.3 72.6 32.4 72.1 33.5C70.3 37.7 70.3 42.3 72.1 46.5C72.6 47.6 73 48.6 73.5 49.7C76.8 57.2 74.6 64.8 69.7 69.7Z",
                            "gem": "M40 80C39.3 80 38.7 80 38 79.9C34.8 79.6 31.8 78.2 25.7 75.4C20.8 73.1 15.9 70.9 10.9 68.6C4.2 65.5 0.3 58.4 1.4 51.1C2.5 43.5 3.6 35.9 4.7 28.3C5.4 23.4 8.1 19 12.2 16.1C18.2 11.8 24.2 7.5 30.2 3.2C33.1 1.1 36.6 0 40.1 0C43.6 0 47.1 1.1 50 3.2C56 7.5 62 11.9 68 16.2C72 19.1 74.7 23.6 75.4 28.5C76.5 36.1 77.5 43.6 78.6 51.2C79.7 58.5 75.8 65.7 69 68.7C64.1 71 59.1 73.2 54.2 75.4C48.1 78.2 45.1 79.6 41.9 79.9C41.3 80 40.6 80 40 80Z",
                            "oval": "M72.7 7.3C75.4 10 77.3 13.6 78.2 17.8C80 26.3 77.7 36.7 71.8 46.8C65.9 56.9 56.9 65.9 46.8 71.8C36.7 77.7 26.3 80 17.8 78.2C9.4 76.4 3.6 70.6 1.8 62.2C0 53.7 2.3 43.3 8.2 33.2C14.1 23.1 23.1 14.1 33.2 8.2C43.3 2.3 53.7 0 62.2 1.8C66.4 2.7 70 4.6 72.7 7.3Z",
                            "pill": "M69.9 10.1C75.2 15.5 78.8 22.7 79.6 30.7C79.8 31.9 79.9 33.1 80 34.3C79.9 43.5 76.2 52.4 69.7 58.9C66.1 62.5 62.5 66.1 58.9 69.7C52.4 76.2 43.5 79.9 34.3 80C33.1 79.9 31.9 79.8 30.7 79.6C14.7 78 2 65.3 0.4 49.3C0.2 48.1 0.1 46.9 0 45.7C0.1 36.5 3.8 27.6 10.3 21.1C13.9 17.5 17.5 13.9 21.1 10.3C27.6 3.8 36.5 0.1 45.7 0C46.9 0.1 48.1 0.2 49.3 0.4C57.3 1.2 64.5 4.8 69.9 10.1Z",
                            "square": "M73 73C68.6 77.3 62.6 80 56 80C45.3 80 34.7 80 24 80C10.7 80 0 69.3 0 56C0 45.3 0 34.7 0 24C0 10.7 10.7 0 24 0C34.7 0 45.3 0 56 0C69.3 0 80 10.7 80 24C80 34.7 80 45.3 80 56C80 62.6 77.3 68.6 73 73Z",
                            "arrow": "M40 66.9C38.3 66.9 36.7 67.1 35.1 67.5C30.8 68.4 26.5 69.4 22.2 70.3C9.8 73.1 0 59.6 6.5 48.6C8.9 44.5 11.4 40.3 13.8 36.2C25.4 16.5 31.3 6.7 39.9 6.7C48.6 6.7 54.4 16.5 66.1 36.1C68.5 40.1 70.9 44.2 73.3 48.2C80 59.5 69.9 73.3 57.1 70.4C53 69.4 48.9 68.5 44.8 67.5C43.2 67.1 41.6 67 40 66.9Z",
                            "sunny": "M79.8 40C79.8 41.4 79.3 42.9 78.3 44C76.2 46.4 74.2 48.8 72.2 51.2C71.3 52.2 70.8 53.4 70.7 54.7C70.5 57.8 70.2 60.9 70 64C69.7 67.1 67.3 69.5 64.3 69.7C61.2 70 58.1 70.2 54.9 70.5C53.6 70.6 52.4 71.1 51.4 71.9C49 74 46.7 76 44.3 78C42 80 38.5 80 36.2 78C33.8 76 31.5 74 29.1 71.9C28.1 71.1 26.9 70.6 25.5 70.5C22.4 70.2 19.3 70 16.2 69.7C13.2 69.5 10.8 67.1 10.5 64C10.3 60.9 10 57.8 9.8 54.7C9.7 53.4 9.1 52.2 8.3 51.2C6.3 48.8 4.3 46.4 2.2 44C0.2 41.7 0.2 38.3 2.2 36C4.3 33.6 6.3 31.2 8.3 28.8C9.1 27.8 9.7 26.6 9.8 25.3C10 22.2 10.3 19.1 10.5 16C10.8 12.9 13.2 10.5 16.2 10.3C19.3 10 22.4 9.8 25.5 9.5C26.9 9.4 28.1 8.9 29.1 8.1C31.5 6 33.8 4 36.2 2C38.5 0 42 0 44.3 2C46.7 4 49 6 51.4 8.1C52.4 8.9 53.6 9.4 54.9 9.5C58.1 9.8 61.2 10 64.3 10.3C67.3 10.5 69.7 12.9 70 16C70.2 19.1 70.5 22.2 70.7 25.3C70.8 26.6 71.3 27.8 72.2 28.8C74.2 31.2 76.2 33.6 78.3 36C79.3 37.1 79.8 38.6 79.8 40Z"
                        })

                        readonly property string currentSvgPath: isActive ? m3ShapePaths[activeRandomShape] : m3ShapePaths["cookie4"]

                        MouseArea {
                            id: powerBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.powerIndex = powerActionBtn.index
                            onClicked: powerActionBtn.modelData.exec()
                        }

                        Item {
                            id: buttonContent
                            width: 80
                            height: 80
                            anchors.centerIn: parent

                            scale: powerActionBtn.isActive ? 1.14 : (powerBtnMouse.containsMouse ? 1.05 : 1.00)
                            rotation: powerActionBtn.isActive ? ((powerActionBtn.index % 2 === 0) ? 5 : -5) : 0

                            Behavior on scale {
                                NumberAnimation { duration: Motion.springDuration; easing.type: Easing.OutBack; easing.overshoot: Motion.springOvershoot }
                            }
                            Behavior on rotation {
                                NumberAnimation { duration: Motion.short4; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                            }

                            SequentialAnimation {
                                id: bounceAnim
                                NumberAnimation {
                                    target: buttonContent
                                    property: "scale"
                                    from: 0.80
                                    to: 1.04
                                    duration: Motion.short3
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.emphasizedDecelerateCurve
                                }
                                NumberAnimation {
                                    target: buttonContent
                                    property: "scale"
                                    to: 0.98
                                    duration: Motion.short2
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.emphasizedCurve
                                }
                            }

                            Shape {
                                id: shapeBg
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    id: shapePath
                                    strokeWidth: 0
                                    strokeColor: "transparent"

                                    fillColor: {
                                        if (powerActionBtn.isActive) {
                                            return powerActionBtn.modelData.isUrgent ? Theme.urgent : Theme.accent
                                        }
                                        if (powerBtnMouse.containsMouse) {
                                            return powerActionBtn.modelData.isUrgent
                                                ? Theme.withAlpha(Theme.urgent, 0.36)
                                                : Theme.withAlpha(Theme.accent, 0.34)
                                        }
                                        return powerActionBtn.modelData.isUrgent
                                            ? Theme.withAlpha(Theme.urgent, 0.22)
                                            : Theme.withAlpha(Theme.accent, 0.20)
                                    }

                                    Behavior on fillColor { ColorAnimation { duration: 180 } }

                                    PathSvg {
                                        path: powerActionBtn.currentSvgPath
                                    }
                                }
                            }

                            // Centered Logo / Icon ONLY (No text)
                            Text {
                                anchors.centerIn: parent
                                text: powerActionBtn.modelData.icon
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: powerActionBtn.isActive ? 36 : 30
                                color: powerActionBtn.isActive
                                    ? Theme.darker_background
                                    : (powerActionBtn.modelData.isUrgent ? Theme.urgent : Theme.accent)

                                Behavior on font.pixelSize {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                                }
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // VIEW 3: Theme Switcher (Carousel: 3 Full + 2 Half Cards, Selected Centered)
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: themeViewContainer
            anchors {
                fill: parent
                topMargin: 12
                bottomMargin: 8
            }
            visible: root.currentView === "theme"

            // Header Search & Counter Row (matches screenshot)
            RowLayout {
                id: themeHeaderRow
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    leftMargin: 16
                    rightMargin: 16
                }
                height: 24
                spacing: 8

                Row {
                    spacing: 8
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: Icons.search
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 13
                        color: Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: themeSearchInput
                        width: 220
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        color: Theme.foreground
                        selectionColor: Theme.selection
                        selectedTextColor: Theme.bright_foreground
                        clip: true

                        Text {
                            text: "Search themes..."
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            color: Theme.withAlpha(Theme.muted, 0.6)
                            visible: !themeSearchInput.text && !themeSearchInput.activeFocus
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                        }

                        onTextChanged: {
                            root.themeFilter = text.trim()
                            root.themeIndex = 0
                            if (themesList) {
                                themesList.currentIndex = 0
                                themesList.positionViewAtIndex(0, ListView.Center)
                            }
                        }

                        Keys.onLeftPressed: root.prevTheme()
                        Keys.onRightPressed: root.nextTheme()
                        Keys.onUpPressed: root.prevTheme()
                        Keys.onDownPressed: root.nextTheme()
                        Keys.onReturnPressed: root.applyCurrentTheme()
                        Keys.onEnterPressed: root.applyCurrentTheme()
                        Keys.onEscapePressed: root.close()
                    }
                }
            }

            // The Carousel: 3 full cards + 2 half cards (selected card locked in center)
            ListView {
                id: themesList
                anchors {
                    top: themeHeaderRow.bottom
                    topMargin: 8
                    left: parent.left
                    right: parent.right
                    leftMargin: 16
                    rightMargin: 16
                }
                height: 114
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                model: root.filteredThemes
                currentIndex: root.themeIndex

                preferredHighlightBegin: (width - 160) / 2
                preferredHighlightEnd: (width - 160) / 2
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 220

                header: Item { width: (themesList.width - 160) / 2 }
                footer: Item { width: (themesList.width - 160) / 2 }

                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    target: null
                    onWheel: function(event) {
                        if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                            root.prevTheme()
                        } else if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                            root.nextTheme()
                        }
                    }
                }

                delegate: Item {
                    id: cardItem
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: (root.currentView === "theme") && (root.themeIndex === cardItem.index)
                    readonly property bool isCurrentTheme: modelData.isCurrent === true
                    readonly property color themeAccent: (modelData.accent && modelData.accent !== "") ? modelData.accent : Theme.accent
                    readonly property color themeBg: (modelData.background && modelData.background !== "") ? modelData.background : "#282828"
                    readonly property color themeFg: (modelData.foreground && modelData.foreground !== "") ? modelData.foreground : Theme.bright_foreground
                    readonly property var cardPalette: root.getThemePalette(modelData)

                    width: 160
                    height: 114

                    Rectangle {
                        id: cardRect
                        width: 160
                        height: 98
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: cardItem.isSelected ? -4 : 0
                        radius: 14

                        scale: cardItem.isSelected ? 1.05 : (cardMouse.containsMouse ? 1.02 : 1.0)

                        Behavior on scale {
                            NumberAnimation { duration: Motion.springDuration; easing.type: Easing.OutBack; easing.overshoot: Motion.springOvershoot }
                        }
                        Behavior on anchors.verticalCenterOffset {
                            NumberAnimation { duration: Motion.short4; easing.type: Easing.OutCubic }
                        }

                        color: cardItem.themeBg

                        border.color: cardItem.isSelected
                            ? cardItem.themeAccent
                            : (cardItem.isCurrentTheme ? Theme.withAlpha(cardItem.themeAccent, 0.45) : Theme.withAlpha(Theme.border, 0.22))
                        border.width: cardItem.isSelected ? 2 : 1

                        Behavior on border.color { ColorAnimation { duration: 160 } }
                        Behavior on border.width { NumberAnimation { duration: 160 } }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (cardItem.isSelected) {
                                    root.applyTheme(cardItem.modelData.id)
                                } else {
                                    root.selectTheme(cardItem.index)
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 12

                            // 6 Color dots palette row (dynamically updated from colors.toml)
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6

                                Repeater {
                                    model: cardItem.cardPalette

                                    Rectangle {
                                        required property var modelData
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: modelData
                                    }
                                }
                            }

                            // Theme name text (dynamically adapted to theme foreground)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cardItem.modelData.id ? cardItem.modelData.id.toLowerCase() : (cardItem.modelData.name || "").toLowerCase()
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                font.weight: cardItem.isSelected ? Fonts.weightBold : Fonts.weightMedium
                                color: cardItem.isSelected
                                    ? cardItem.themeFg
                                    : Theme.withAlpha(cardItem.themeFg, 0.72)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // Bottom Right: "Enter to apply" hint (matches screenshot)
            Text {
                anchors {
                    right: parent.right
                    rightMargin: 16
                    bottom: parent.bottom
                    bottomMargin: 4
                }
                text: "Enter to apply"
                font.family: root.fontFamily
                font.pixelSize: 11
                color: Theme.withAlpha(Theme.muted, 0.7)
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // VIEW 4: Wallpaper Switcher (Carousel: 3 Full + 2 Half Cards, Selected Centered)
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: wallpaperViewContainer
            anchors {
                fill: parent
                topMargin: 12
                bottomMargin: 8
            }
            visible: root.currentView === "wallpaper"

            // The Carousel: 3 full cards + 2 half cards (selected card locked in center)
            ListView {
                id: wallpapersList
                anchors {
                    top: parent.top
                    topMargin: 8
                    left: parent.left
                    right: parent.right
                    leftMargin: 16
                    rightMargin: 16
                }
                height: 114
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                model: root.wallpapers
                currentIndex: root.wallpaperIndex

                preferredHighlightBegin: (width - 160) / 2
                preferredHighlightEnd: (width - 160) / 2
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 220

                header: Item { width: (wallpapersList.width - 160) / 2 }
                footer: Item { width: (wallpapersList.width - 160) / 2 }

                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    target: null
                    onWheel: function(event) {
                        if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                            root.prevWallpaper()
                        } else if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                            root.nextWallpaper()
                        }
                    }
                }

                delegate: Item {
                    id: wallCardItem
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: (root.currentView === "wallpaper") && (root.wallpaperIndex === wallCardItem.index)
                    readonly property bool isActiveWall: modelData.isActive === true

                    width: 160
                    height: 114

                    Rectangle {
                        id: wallCardRect
                        width: 160
                        height: 98
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: wallCardItem.isSelected ? -4 : 0
                        radius: 14
                        clip: true

                        scale: wallCardItem.isSelected ? 1.05 : (wallCardMouse.containsMouse ? 1.02 : 1.0)

                        Behavior on scale {
                            NumberAnimation { duration: Motion.springDuration; easing.type: Easing.OutBack; easing.overshoot: Motion.springOvershoot }
                        }
                        Behavior on anchors.verticalCenterOffset {
                            NumberAnimation { duration: Motion.short4; easing.type: Easing.OutCubic }
                        }

                        color: Theme.withAlpha(Theme.dark_background, 0.6)

                        MouseArea {
                            id: wallCardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (wallCardItem.isSelected) {
                                    root.applyWallpaper(wallCardItem.modelData.path)
                                } else {
                                    root.selectWallpaper(wallCardItem.index)
                                }
                            }
                        }

                        // 1. Direct Mask for Rounded Wallpaper Corners
                        Rectangle {
                            id: wallMask
                            anchors.fill: parent
                            radius: 14
                            color: "black"
                            layer.enabled: true
                            visible: false
                        }

                        // 2. Wallpaper Image Thumbnail (Masked to rounded corners)
                        Image {
                            id: previewImg
                            anchors.fill: parent
                            source: (wallCardItem.modelData.thumb && wallCardItem.modelData.thumb !== "")
                                ? ("file://" + wallCardItem.modelData.thumb)
                                : (wallCardItem.modelData.path ? ("file://" + wallCardItem.modelData.path) : "")
                            fillMode: Image.PreserveAspectCrop
                            cache: true
                            asynchronous: true
                            smooth: true
                            mipmap: false
                            sourceSize: Qt.size(320, 196)

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: wallMask
                            }
                        }

                        // 3. Border overlay for selected wallpaper
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: "transparent"
                            border.color: wallCardItem.isSelected ? Theme.accent : "transparent"
                            border.width: wallCardItem.isSelected ? 2 : 0

                            Behavior on border.color { ColorAnimation { duration: 160 } }
                            Behavior on border.width { NumberAnimation { duration: 160 } }
                        }
                    }
                }
            }

            // Bottom Right: "Enter to apply" hint
            Text {
                anchors {
                    right: parent.right
                    rightMargin: 16
                    bottom: parent.bottom
                    bottomMargin: 4
                }
                text: "Enter to apply"
                font.family: root.fontFamily
                font.pixelSize: 11
                color: Theme.withAlpha(Theme.muted, 0.7)
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // VIEW 5: Staging Drop Shelf View
        // ─────────────────────────────────────────────────────────────────────
        ShelfView {
            id: shelfView
            anchors {
                fill: parent
                margins: 12
            }
            visible: root.currentView === "shelf"
            shelfService: root.shelfService
        }

        // ─────────────────────────────────────────────────────────────────────
        // VIEW 6: Text-Only Clipboard Manager View
        // ─────────────────────────────────────────────────────────────────────
        ClipboardView {
            id: clipboardView
            anchors.fill: parent
            visible: root.currentView === "clipboard"
            clipboardService: root.clipboardService
            onRequestClose: root.close()
        }
    }

    Component.onCompleted: {
        root.loadHistory()
        root.loadApps()
        root.filterItems()
    }
}
