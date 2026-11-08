import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"
import "../components"
import "../services"
import "LauncherModel.js" as LauncherModel

PanelWindow {
    id: root

    readonly property string fontFamily: Fonts.uiFont

    property PowerService powerService: null
    property ThemeSwitcherService themeService: null
    property WallpaperSwitcherService wallpaperService: null

    property bool isOpen: false
    property string currentView: "apps" // "apps" | "power" | "theme" | "wallpaper"
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
    property var historyMap: ({})

    // Dynamic target dimensions per view
    readonly property real targetWidth: {
        if (root.currentView === "apps") return Appearance.launcherWidth
        if (root.currentView === "power") return 400
        if (root.currentView === "theme") {
            var tCount = Math.min(5, Math.max(1, root.themesCount))
            return Math.min(root.width - 48, Math.max(580, (tCount * 196) + ((tCount - 1) * 12) + 28))
        }
        // wallpaper view
        var wCount = Math.min(5, Math.max(1, root.wallpapersCount))
        return Math.min(root.width - 48, Math.max(580, (wCount * 210) + ((wCount - 1) * 12) + 28))
    }

    readonly property real targetHeight: {
        if (root.currentView === "apps") return Appearance.launcherHeight
        if (root.currentView === "power") return 116
        if (root.currentView === "wallpaper") return 210
        return 260 // theme view
    }

    // Spring pop-up & retraction physics from bottom
    NumberAnimation {
        id: openAnim
        target: root
        property: "animProgress"
        to: 1.0
        duration: 320
        easing.type: Easing.OutBack
        easing.overshoot: 1.12
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "animProgress"
        to: 0.0
        duration: 190
        easing.type: Easing.InCubic
        onFinished: {
            root.animProgress = 0.0
            if (!root.isOpen) {
                if (root.powerService) root.powerService.powerMenuOpen = false
                if (root.themeService) root.themeService.isOpen = false
                if (root.wallpaperService) root.wallpaperService.isOpen = false
                root.currentView = "apps"
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Navigation & View Switching Helpers
    // ─────────────────────────────────────────────────────────────────────────
    function openApps(initialQuery) {
        closeAnim.stop()
        root.loadHistory()
        root.loadApps()
        root.currentView = "apps"
        searchInput.text = (typeof initialQuery === "string") ? initialQuery : ""
        root.filterItems()
        listView.currentIndex = 0
        root.isOpen = true
        openAnim.restart()
        Qt.callLater(function() {
            searchInput.forceActiveFocus()
        })
    }

    function openPower() {
        closeAnim.stop()
        root.currentView = "power"
        root.powerIndex = 0
        if (root.powerService) root.powerService.powerMenuOpen = true
        root.isOpen = true
        openAnim.restart()
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    function openTheme() {
        closeAnim.stop()
        if (root.themeService) {
            root.themeService.refresh()
            root.themeService.isOpen = true
        }
        root.currentView = "theme"
        root.themeIndex = (root.themeService && root.themeService.middleIndex !== undefined)
            ? root.themeService.middleIndex
            : Math.floor(root.themesCount / 2)
        root.isOpen = true
        openAnim.restart()
        Qt.callLater(function() {
            keyCatcher.forceActiveFocus()
            if (themesList) themesList.positionViewAtIndex(root.themeIndex, ListView.Center)
        })
    }

    function openWallpaper() {
        closeAnim.stop()
        if (root.wallpaperService) {
            root.wallpaperService.refresh()
            root.wallpaperService.isOpen = true
        }
        root.currentView = "wallpaper"
        root.wallpaperIndex = (root.wallpaperService && root.wallpaperService.middleIndex !== undefined)
            ? root.wallpaperService.middleIndex
            : Math.floor(root.wallpapersCount / 2)
        root.isOpen = true
        openAnim.restart()
        Qt.callLater(function() {
            keyCatcher.forceActiveFocus()
            if (wallpapersList) wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Center)
        })
    }

    function close() {
        if (!root.isOpen && !openAnim.running) return
        openAnim.stop()
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

    function switchToView(viewName) {
        if (root.currentView === viewName) return
        if (viewName === "apps") {
            root.openApps("")
        } else if (viewName === "power") {
            root.openPower()
        } else if (viewName === "theme") {
            root.openTheme()
        } else if (viewName === "wallpaper") {
            root.openWallpaper()
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
        if (root.themesCount <= 0) return
        root.themeIndex = (root.themeIndex + 1) % root.themesCount
        if (themesList) themesList.positionViewAtIndex(root.themeIndex, ListView.Contain)
    }

    function prevTheme() {
        if (root.themesCount <= 0) return
        root.themeIndex = (root.themeIndex - 1 + root.themesCount) % root.themesCount
        if (themesList) themesList.positionViewAtIndex(root.themeIndex, ListView.Contain)
    }

    function selectTheme(idx) {
        if (idx >= 0 && idx < root.themesCount) {
            root.themeIndex = idx
            if (themesList) themesList.positionViewAtIndex(root.themeIndex, ListView.Contain)
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
        if (root.wallpapersCount <= 0) return
        root.wallpaperIndex = (root.wallpaperIndex + 1) % root.wallpapersCount
        if (wallpapersList) wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Contain)
    }

    function prevWallpaper() {
        if (root.wallpapersCount <= 0) return
        root.wallpaperIndex = (root.wallpaperIndex - 1 + root.wallpapersCount) % root.wallpapersCount
        if (wallpapersList) wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Contain)
    }

    function selectWallpaper(idx) {
        if (idx >= 0 && idx < root.wallpapersCount) {
            root.wallpaperIndex = idx
            if (wallpapersList) wallpapersList.positionViewAtIndex(root.wallpaperIndex, ListView.Contain)
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
        if (listView.currentIndex >= root.filteredItems.length) {
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
    WlrLayershell.keyboardFocus: (root.isOpen && !closeAnim.running) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    onIsOpenChanged: {
        if (root.isOpen) {
            if (root.currentView === "apps") {
                Qt.callLater(function() { searchInput.forceActiveFocus() })
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

    // Backdrop Scrim
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.darker_background, 0.45)
        opacity: root.isOpen ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
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

    // Keyboard Controller for non-input views (power, theme, wallpaper)
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: root.isOpen && root.currentView !== "apps"

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
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
                    if (root.themeIndex >= 0 && root.themeIndex < root.themesCount) {
                        root.applyTheme(root.themes[root.themeIndex].id)
                    }
                    event.accepted = true
                }
            } else if (root.currentView === "wallpaper") {
                if (event.key === Qt.Key_Left) {
                    root.prevWallpaper()
                    event.accepted = true
                } else if (event.key === Qt.Key_Right) {
                    root.nextWallpaper()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.wallpaperIndex >= 0 && root.wallpaperIndex < root.wallpapersCount) {
                        root.applyWallpaper(root.wallpapers[root.wallpaperIndex].path)
                    }
                    event.accepted = true
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

        Behavior on width {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        color: Theme.withAlpha(Theme.darker_background, Theme.baseOpacity)
        border.color: Theme.withAlpha(Theme.border, 0.28)
        border.width: 1
        clip: true

        // Pop down-to-up translation & spring physics
        transform: Translate {
            y: (1.0 - root.animProgress) * (launcherCard.height + 64)
        }
        opacity: Math.min(1.0, root.animProgress * 1.5)
        scale: 0.94 + 0.06 * Math.max(0, root.animProgress)

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
                    anchors.rightMargin: scrollbar.visible ? 8 : 0
                    clip: true
                    spacing: 2
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
                        border.color: isSelected ? Theme.withAlpha(Theme.accent, 0.35) : "transparent"
                        border.width: 1

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
                                    border.color: itemDelegate.isSelected ? Theme.accent : Theme.withAlpha(Theme.border, 0.3)
                                    border.width: 1

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
                                    border.color: itemDelegate.isSelected ? Theme.accent : Theme.selection
                                    border.width: 1

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

                // Scrollbar
                Rectangle {
                    id: scrollbar
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    width: 4
                    radius: 2
                    color: Theme.withAlpha(Theme.dark_background, 0.5)
                    clip: true
                    visible: listView.visibleArea.heightRatio < 1.0 && listView.count > 0

                    Rectangle {
                        id: scrollbarHandle
                        width: parent.width
                        radius: 2
                        color: Theme.accent

                        readonly property real rawHeight: Math.max(24, listView.visibleArea.heightRatio * scrollbar.height)
                        readonly property real clampedHeight: Math.min(scrollbar.height, rawHeight)
                        readonly property real maxY: Math.max(0, scrollbar.height - clampedHeight)

                        height: clampedHeight
                        y: Math.max(0, Math.min(maxY, listView.visibleArea.yPosition * scrollbar.height))
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
                    anchors.rightMargin: 18

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: searchInput.text.startsWith(">") ? "Search action commands..." : "Search apps or type '> ' for commands..."
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        color: Theme.muted
                        visible: searchInput.text.length === 0
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
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
                spacing: 16

                Repeater {
                    model: root.powerActions

                    Item {
                        id: powerActionBtn
                        required property var modelData
                        required property int index

                        readonly property bool isActive: (root.currentView === "power") && (root.powerIndex === index)

                        width: isActive ? 80 : 64
                        height: 64

                        Behavior on width {
                            NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                        }

                        scale: isActive ? 1.08 : (powerBtnMouse.containsMouse ? 1.04 : 1.0)
                        Behavior on scale {
                            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                        }

                        Rectangle {
                            id: powerBtnBg
                            anchors.fill: parent
                            // Google Material 3 Shape: Circle (32) morphs to Squircle (16) on select
                            radius: powerActionBtn.isActive ? 16 : 32

                            Behavior on radius {
                                NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                            }

                            color: {
                                if (powerActionBtn.isActive) {
                                    return powerActionBtn.modelData.isUrgent ? Theme.urgent : Theme.accent
                                }
                                if (powerBtnMouse.containsMouse) {
                                    return Theme.withAlpha(Theme.lighter_background, 0.45)
                                }
                                return Theme.withAlpha(Theme.dark_background, 0.65)
                            }
                            border.color: powerActionBtn.isActive
                                ? "transparent"
                                : (powerBtnMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.4) : Theme.withAlpha(Theme.border, 0.2))
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on border.color { ColorAnimation { duration: 180 } }

                            MouseArea {
                                id: powerBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.powerIndex = powerActionBtn.index
                                onClicked: powerActionBtn.modelData.exec()
                            }

                            // Only Logo inside (no text)
                            Text {
                                anchors.centerIn: parent
                                text: powerActionBtn.modelData.icon
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: powerActionBtn.isActive ? 28 : 24
                                color: powerActionBtn.isActive
                                    ? Theme.darker_background
                                    : (powerActionBtn.modelData.isUrgent ? Theme.urgent : Theme.foreground)

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
        // VIEW 3: Theme Switcher
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: themeViewContainer
            anchors.fill: parent
            anchors.margins: 14
            visible: root.currentView === "theme"

            ListView {
                id: themesList
                anchors.fill: parent
                anchors.bottomMargin: 14
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                model: root.themes
                currentIndex: root.themeIndex
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    target: null
                    onWheel: function(event) {
                        if (event.angleDelta.y !== 0) {
                            themesList.flick(event.angleDelta.y * 6, 0)
                        }
                    }
                }

                delegate: Item {
                    id: cardItem
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: (root.currentView === "theme") && (root.themeIndex === cardItem.index)
                    readonly property bool isCurrentTheme: modelData.isCurrent === true
                    readonly property color themeAccent: modelData.accent ? modelData.accent : Theme.accent

                    width: 196
                    height: 180

                    Rectangle {
                        anchors.fill: parent
                        radius: 14

                        color: cardItem.isSelected
                            ? Theme.withAlpha(Theme.lighter_background, 0.95)
                            : (themeCardMouse.containsMouse
                                ? Theme.withAlpha(Theme.lighter_background, 0.45)
                                : Theme.withAlpha(Theme.dark_background, 0.5))

                        border.color: cardItem.isSelected
                            ? cardItem.themeAccent
                            : (cardItem.isCurrentTheme ? Theme.withAlpha(Theme.accent, 0.6) : Theme.withAlpha(Theme.border, 0.25))
                        border.width: cardItem.isSelected ? 2 : 1

                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        MouseArea {
                            id: themeCardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.themeIndex = cardItem.index
                            onClicked: root.applyTheme(cardItem.modelData.id)
                        }

                        // Thumbnail
                        Item {
                            id: themeImgContainer
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 1
                            height: 120

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: themeTopMask
                            }

                            Image {
                                anchors.fill: parent
                                source: cardItem.modelData.wallpaper ? ("file://" + cardItem.modelData.wallpaper) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                sourceSize: Qt.size(392, 220)
                            }
                        }

                        Rectangle {
                            id: themeTopMask
                            width: themeImgContainer.width
                            height: themeImgContainer.height + 20
                            radius: 13
                            color: "black"
                            layer.enabled: true
                            visible: false
                        }

                        // Theme Name
                        Item {
                            anchors.top: themeImgContainer.bottom
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right

                            Text {
                                anchors.centerIn: parent
                                text: cardItem.modelData.name || ""
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.weight: cardItem.isSelected ? Fonts.weightBold : Fonts.weightMedium
                                color: cardItem.isSelected ? cardItem.themeAccent : Theme.foreground
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width - 12
                            }
                        }
                    }
                }
            }

            // Scroll indicator
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(160, parent.width * 0.25)
                height: 3
                radius: 1.5
                color: Theme.withAlpha(Theme.selection, 0.4)
                visible: themesList.contentWidth > (themesList.width + 4)

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                    width: Math.max(20, parent.width * (themesList.width / Math.max(1, themesList.contentWidth)))
                    x: {
                        var scrollableDist = themesList.contentWidth - themesList.width
                        if (scrollableDist <= 0) return 0
                        var trackTravel = parent.width - width
                        return Math.max(0, Math.min(trackTravel, (themesList.contentX / scrollableDist) * trackTravel))
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // VIEW 4: Wallpaper Switcher
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: wallpaperViewContainer
            anchors.fill: parent
            anchors.margins: 14
            visible: root.currentView === "wallpaper"

            ListView {
                id: wallpapersList
                anchors.fill: parent
                anchors.bottomMargin: 14
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                model: root.wallpapers
                currentIndex: root.wallpaperIndex
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    target: null
                    onWheel: function(event) {
                        if (event.angleDelta.y !== 0) {
                            wallpapersList.flick(event.angleDelta.y * 6, 0)
                        }
                    }
                }

                delegate: Item {
                    id: wallCardItem
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: (root.currentView === "wallpaper") && (root.wallpaperIndex === wallCardItem.index)
                    readonly property bool isActiveWall: modelData.isActive === true

                    width: 210
                    height: 140

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: wallCardItem.isSelected
                            ? Theme.withAlpha(Theme.lighter_background, 0.95)
                            : (wallCardMouse.containsMouse
                                ? Theme.withAlpha(Theme.lighter_background, 0.45)
                                : Theme.withAlpha(Theme.dark_background, 0.5))
                        border.color: wallCardItem.isSelected
                            ? Theme.accent
                            : (wallCardItem.isActiveWall ? Theme.withAlpha(Theme.accent, 0.6) : Theme.withAlpha(Theme.border, 0.25))
                        border.width: wallCardItem.isSelected ? 2 : 1

                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        MouseArea {
                            id: wallCardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.wallpaperIndex = wallCardItem.index
                            onClicked: root.applyWallpaper(wallCardItem.modelData.path)
                        }

                        Item {
                            id: wallImgContainer
                            anchors.fill: parent
                            anchors.margins: 1

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: wallMask
                            }

                            Image {
                                anchors.fill: parent
                                source: wallCardItem.modelData.path ? ("file://" + wallCardItem.modelData.path) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                sourceSize: Qt.size(392, 220)
                            }
                        }

                        Rectangle {
                            id: wallMask
                            width: wallImgContainer.width
                            height: wallImgContainer.height
                            radius: 13
                            color: "black"
                            layer.enabled: true
                            visible: false
                        }
                    }
                }
            }

            // Scroll indicator
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(160, parent.width * 0.25)
                height: 3
                radius: 1.5
                color: Theme.withAlpha(Theme.selection, 0.4)
                visible: wallpapersList.contentWidth > (wallpapersList.width + 4)

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                    width: Math.max(20, parent.width * (wallpapersList.width / Math.max(1, wallpapersList.contentWidth)))
                    x: {
                        var scrollableDist = wallpapersList.contentWidth - wallpapersList.width
                        if (scrollableDist <= 0) return 0
                        var trackTravel = parent.width - width
                        return Math.max(0, Math.min(trackTravel, (wallpapersList.contentX / scrollableDist) * trackTravel))
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.loadHistory()
        root.loadApps()
    }
}
