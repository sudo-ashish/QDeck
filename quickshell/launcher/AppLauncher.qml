import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
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
        if (root.currentView === "power") return 500
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
        if (root.currentView === "power") return 170
        if (root.currentView === "wallpaper") return 250
        return 290 // theme view
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

        // ── Top: Unified Navigation Tabs Bar (Visible on Session, Theme, Wallpaper — Hidden on Apps Launcher) ─
        RowLayout {
            id: navHeader
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 12
                leftMargin: 14
                rightMargin: 14
            }
            height: 28
            spacing: 8
            visible: root.currentView !== "apps"

            // Segmented View Switcher Tabs
            Row {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                // Tab 1: Apps
                Rectangle {
                    width: appsTabRow.implicitWidth + 14
                    height: 26
                    radius: 13
                    color: (root.currentView === "apps")
                        ? Theme.accent
                        : (appsTabMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.4) : "transparent")

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: appsTabRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: Icons.apps
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 12
                            color: (root.currentView === "apps") ? Theme.darker_background : Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Apps"
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.weight: (root.currentView === "apps") ? Fonts.weightBold : Fonts.weightMedium
                            color: (root.currentView === "apps") ? Theme.darker_background : Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: appsTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchToView("apps")
                    }
                }

                // Tab 2: Session (Power)
                Rectangle {
                    width: sessionTabRow.implicitWidth + 14
                    height: 26
                    radius: 13
                    color: (root.currentView === "power")
                        ? Theme.accent
                        : (sessionTabMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.4) : "transparent")

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: sessionTabRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: Icons.power
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 12
                            color: (root.currentView === "power") ? Theme.darker_background : Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Session"
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.weight: (root.currentView === "power") ? Fonts.weightBold : Fonts.weightMedium
                            color: (root.currentView === "power") ? Theme.darker_background : Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: sessionTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchToView("power")
                    }
                }

                // Tab 3: Themes
                Rectangle {
                    width: themeTabRow.implicitWidth + 14
                    height: 26
                    radius: 13
                    color: (root.currentView === "theme")
                        ? Theme.accent
                        : (themeTabMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.4) : "transparent")

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: themeTabRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: Icons.palette
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 12
                            color: (root.currentView === "theme") ? Theme.darker_background : Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Themes"
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.weight: (root.currentView === "theme") ? Fonts.weightBold : Fonts.weightMedium
                            color: (root.currentView === "theme") ? Theme.darker_background : Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: themeTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchToView("theme")
                    }
                }

                // Tab 4: Wallpapers
                Rectangle {
                    width: wallpaperTabRow.implicitWidth + 14
                    height: 26
                    radius: 13
                    color: (root.currentView === "wallpaper")
                        ? Theme.accent
                        : (wallpaperTabMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.4) : "transparent")

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: wallpaperTabRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: Icons.wallpaper
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 12
                            color: (root.currentView === "wallpaper") ? Theme.darker_background : Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Wallpapers"
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.weight: (root.currentView === "wallpaper") ? Fonts.weightBold : Fonts.weightMedium
                            color: (root.currentView === "wallpaper") ? Theme.darker_background : Theme.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: wallpaperTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchToView("wallpaper")
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Right View Context Status / Hint
            Text {
                text: {
                    if (root.currentView === "power") {
                        return root.powerActions[root.powerIndex] ? root.powerActions[root.powerIndex].name : "Power"
                    } else if (root.currentView === "theme") {
                        return root.currentTheme ? ("Active: " + root.currentTheme) : "Themes"
                    } else if (root.currentView === "wallpaper") {
                        return root.wallpapersCount ? (root.wallpapersCount + " wallpapers") : "Wallpapers"
                    }
                    return ""
                }
                font.family: root.fontFamily
                font.pixelSize: 11
                color: Theme.muted
                Layout.alignment: Qt.AlignVCenter
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
            anchors {
                top: navHeader.bottom
                topMargin: 8
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: 12
            }
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

                        width: 64
                        height: 64

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
                            "cookie4": "M55.8 55.7C51.9 59.6 45.8 61.4 39.8 58.8C38.9 58.4 38.1 58 37.2 57.7C33.9 56.2 30.1 56.2 26.8 57.7C26 58 25.1 58.4 24.2 58.8C12.2 64 0 51.8 5.2 39.8C5.6 38.9 6 38.1 6.3 37.2C7.8 33.9 7.8 30.1 6.3 26.8C6 26 5.6 25.1 5.2 24.2C0 12.2 12.2 0 24.2 5.2C25.1 5.6 26 6 26.8 6.3C30.1 7.8 33.9 7.8 37.2 6.3C38.1 6 38.9 5.6 39.8 5.2C51.8 0 64 12.2 58.8 24.2C58.4 25.1 58 25.9 57.7 26.8C56.2 30.1 56.2 33.9 57.7 37.2C58.1 38 58.4 38.9 58.8 39.8C61.4 45.8 59.7 51.8 55.8 55.7Z",
                            "gem": "M32 64C31.4 64 30.9 64 30.4 63.9C27.9 63.7 25.4 62.5 20.6 60.3C16.6 58.5 12.7 56.7 8.8 54.9C3.4 52.4 0.3 46.7 1.1 40.9C2 34.8 2.9 28.7 3.8 22.7C4.4 18.7 6.5 15.2 9.7 12.9C14.5 9.4 19.4 6 24.2 2.5C26.5 0.9 29.3 0 32.1 0C34.9 0 37.7 0.9 40 2.6C44.8 6 49.6 9.5 54.4 13C57.6 15.3 59.8 18.8 60.3 22.8C61.2 28.8 62 34.9 62.9 41C63.7 46.8 60.6 52.5 55.2 55C51.3 56.8 47.3 58.6 43.4 60.4C38.5 62.6 36.1 63.7 33.5 63.9C33 64 32.5 64 32 64Z",
                            "oval": "M58.1 5.9C60.3 8 61.8 10.9 62.6 14.3C64 21 62.2 29.3 57.5 37.5C52.8 45.6 45.6 52.8 37.5 57.5C29.3 62.2 21 64 14.3 62.6C7.5 61.1 2.9 56.5 1.4 49.7C0 43 1.8 34.7 6.5 26.5C11.2 18.4 18.4 11.2 26.5 6.5C34.7 1.8 43 0 49.7 1.4C53.1 2.2 56 3.7 58.1 5.9Z",
                            "pill": "M55.9 8.1C60.2 12.4 63 18.2 63.7 24.6C63.8 25.5 63.9 26.5 64 27.4C64 34.8 61 41.9 55.8 47.1C52.9 50 50 52.9 47.1 55.8C41.9 61 34.8 64 27.4 64C26.5 63.9 25.5 63.8 24.6 63.7C11.7 62.4 1.6 52.3 0.3 39.4C0.2 38.5 0.1 37.5 0 36.6C0 29.2 3 22.1 8.2 16.9C11.1 14 14 11.1 16.9 8.2C22.1 3 29.2 0 36.6 0C37.5 0.1 38.5 0.2 39.4 0.3C45.8 1 51.6 3.8 55.9 8.1Z",
                            "square": "M58.4 58.4C54.9 61.9 50.1 64 44.8 64C36.3 64 27.7 64 19.2 64C8.6 64 0 55.4 0 44.8C0 36.3 0 27.7 0 19.2C0 8.6 8.6 0 19.2 0C27.7 0 36.3 0 44.8 0C55.4 0 64 8.6 64 19.2C64 27.7 64 36.3 64 44.8C64 50.1 61.9 54.9 58.4 58.4Z",
                            "arrow": "M32 53.6C30.7 53.6 29.3 53.7 28.1 54C24.6 54.7 21.2 55.5 17.8 56.2C7.8 58.4 0 47.7 5.2 38.9C7.2 35.6 9.1 32.3 11.1 28.9C20.4 13.2 25 5.4 31.9 5.3C38.8 5.3 43.5 13.2 52.9 28.9C54.8 32.1 56.7 35.4 58.6 38.6C64 47.6 55.9 58.7 45.7 56.3C42.4 55.5 39.1 54.8 35.9 54C34.6 53.7 33.3 53.6 32 53.6Z",
                            "sunny": "M63.8 32C63.8 33.1 63.4 34.3 62.6 35.2C61 37.1 59.4 39 57.8 40.9C57.1 41.7 56.7 42.7 56.6 43.8C56.4 46.2 56.2 48.7 56 51.2C55.8 53.7 53.9 55.6 51.4 55.8C48.9 56 46.4 56.2 44 56.4C42.9 56.5 41.9 56.9 41.1 57.6C39.2 59.2 37.3 60.8 35.4 62.4C33.6 64 30.8 64 29 62.4C27.1 60.8 25.2 59.2 23.3 57.6C22.5 56.9 21.5 56.5 20.4 56.4C18 56.2 15.5 56 13 55.8C10.5 55.6 8.6 53.7 8.4 51.2C8.2 48.7 8 46.2 7.8 43.8C7.7 42.7 7.3 41.7 6.6 40.9C5 39 3.4 37.1 1.8 35.2C0.2 33.4 0.2 30.6 1.8 28.8C3.4 26.9 5 25 6.6 23.1C7.3 22.3 7.7 21.3 7.8 20.2C8 17.8 8.2 15.3 8.4 12.8C8.6 10.3 10.5 8.4 13 8.2C15.5 8 18 7.8 20.4 7.6C21.5 7.5 22.5 7.1 23.3 6.4C25.2 4.8 27.1 3.2 29 1.6C30.8 0 33.6 0 35.4 1.6C37.3 3.2 39.2 4.8 41.1 6.4C41.9 7.1 42.9 7.5 44 7.6C46.4 7.8 48.9 8 51.4 8.2C53.9 8.4 55.8 10.3 56 12.8C56.2 15.3 56.4 17.8 56.6 20.2C56.7 21.3 57.1 22.3 57.8 23.1C59.4 25 61 26.9 62.6 28.8C63.4 29.7 63.8 30.9 63.8 32Z"
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
                            anchors.fill: parent

                            scale: powerActionBtn.isActive ? 1.14 : (powerBtnMouse.containsMouse ? 1.05 : 1.0)
                            rotation: powerActionBtn.isActive ? ((powerActionBtn.index % 2 === 0) ? 5 : -5) : 0

                            Behavior on scale {
                                NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                            }
                            Behavior on rotation {
                                NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                            }

                            SequentialAnimation {
                                id: bounceAnim
                                NumberAnimation {
                                    target: buttonContent
                                    property: "scale"
                                    from: 0.88
                                    to: 1.18
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: buttonContent
                                    property: "scale"
                                    to: 1.14
                                    duration: 120
                                    easing.type: Easing.OutBack
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
                                font.pixelSize: powerActionBtn.isActive ? 27 : 23
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
        // VIEW 3: Theme Switcher
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: themeViewContainer
            anchors {
                top: navHeader.bottom
                topMargin: 8
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 12
            }
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
            anchors {
                top: navHeader.bottom
                topMargin: 8
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 12
            }
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
