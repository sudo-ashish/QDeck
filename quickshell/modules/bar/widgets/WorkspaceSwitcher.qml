import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../../theme"
import "../../../services"

// Windows Alt+Tab-style Workspace Switcher Overlay
// Activated via IPC: qs ipc call wsswitcher toggle/next/prev/open/close
PanelWindow {
    id: root

    required property WorkspacesService workspacesService

    // Focused monitor binding
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

    // ─────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────
    property bool isOpen: false
    property int selectedId: 1

    // ─────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────
    function open(): string {
        if (root.isOpen) return "already-open"
        root.selectedId = root.workspacesService.activeWorkspaceId
        root.isOpen = true
        return "opened"
    }

    function close(): string {
        if (!root.isOpen) return "already-closed"
        root.isOpen = false
        return "closed"
    }

    function toggle(): string {
        return root.isOpen ? root.close() : root.open()
    }

    function next(): string {
        if (!root.isOpen) {
            root.open()
        }
        _move(1)
        return "next"
    }

    function prev(): string {
        if (!root.isOpen) {
            root.open()
        }
        _move(-1)
        return "prev"
    }

    function confirm(): string {
        if (!root.isOpen) return "not-open"
        _confirm()
        return "confirmed"
    }

    function _move(dir) {
        var ids = root.workspacesService.workspaceIds
        if (!ids || ids.length === 0) return
        var idx = ids.indexOf(root.selectedId)
        if (idx < 0) idx = 0
        idx = (idx + dir + ids.length) % ids.length
        root.selectedId = ids[idx]
    }

    function _confirm() {
        root.workspacesService.switchTo(root.selectedId)
        root.close()
    }

    // Helper: Resolve icon path from app class / title
    function resolveIcon(appClass) {
        if (!appClass || appClass === "") return ""
        var raw = String(appClass).trim()
        var lower = raw.toLowerCase()

        // 1. DesktopEntries heuristic lookup
        if (typeof DesktopEntries !== "undefined" && DesktopEntries.heuristicLookup) {
            var de = DesktopEntries.heuristicLookup(raw)
            if (de && de.icon) {
                var pDe = Quickshell.iconPath(de.icon, true)
                if (pDe && pDe !== "") return pDe
            }
        }

        // 2. Curated fallback aliases
        var candidates = [raw, lower]
        if (lower === "zen") candidates.push("zen-browser", "zen")
        else if (lower === "codium" || lower === "vscodium") candidates.push("vscodium", "codium", "code")
        else if (lower.indexOf("antigravity") !== -1) candidates.push("antigravity-ide", "antigravity", "code")
        else if (lower === "code") candidates.push("visual-studio-code", "vscode", "code")
        else if (lower === "kitty") candidates.push("kitty")
        else if (lower === "alacritty") candidates.push("alacritty")
        else if (lower === "nautilus" || lower === "org.gnome.nautilus") candidates.push("org.gnome.Nautilus", "system-file-manager", "nautilus")
        else if (lower.indexOf("chrome") !== -1) candidates.push("google-chrome", "google-chrome-stable", "chrome")
        else if (lower.indexOf("firefox") !== -1) candidates.push("firefox")

        for (var i = 0; i < candidates.length; i++) {
            var p = Quickshell.iconPath(candidates[i], true)
            if (p && p !== "") return p
        }
        return ""
    }

    // Helper: Collect windows for a given workspace id
    function getWindowsForWorkspace(wsId) {
        var arr = []

        // Source 1: Check Hyprland.workspaces
        var wsList = Hyprland.workspaces ? Hyprland.workspaces.values : []
        for (var i = 0; i < wsList.length; i++) {
            var ws = wsList[i]
            if (ws && ws.id === wsId && ws.toplevels) {
                var tls = ws.toplevels.values || []
                for (var j = 0; j < tls.length; j++) {
                    var tl = tls[j]
                    if (!tl) continue
                    var app = ""
                    if (tl.lastIpcObject && (tl.lastIpcObject["class"] || tl.lastIpcObject["initialClass"])) {
                        app = tl.lastIpcObject["class"] || tl.lastIpcObject["initialClass"]
                    } else if (tl.wayland && tl.wayland.appId) {
                        app = tl.wayland.appId
                    }
                    arr.push({
                        title: tl.title || app || "Window",
                        appClass: app || "application-x-executable"
                    })
                }
                if (arr.length > 0) return arr
            }
        }

        // Source 2: Hyprland.toplevels global collection
        if (Hyprland.toplevels) {
            var allTls = Hyprland.toplevels.values || []
            for (var k = 0; k < allTls.length; k++) {
                var item = allTls[k]
                if (item && item.workspace && item.workspace.id === wsId) {
                    var a = ""
                    if (item.lastIpcObject && (item.lastIpcObject["class"] || item.lastIpcObject["initialClass"])) {
                        a = item.lastIpcObject["class"] || item.lastIpcObject["initialClass"]
                    } else if (item.wayland && item.wayland.appId) {
                        a = item.wayland.appId
                    }
                    arr.push({
                        title: item.title || a || "Window",
                        appClass: a || "application-x-executable"
                    })
                }
            }
        }

        return arr
    }

    // ─────────────────────────────────────────────────
    // Window configuration
    // ─────────────────────────────────────────────────
    visible: root.isOpen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; left: true; right: true; bottom: true }
    implicitHeight: 1080

    WlrLayershell.namespace: "quickshell-wsswitcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Delayed focus grab to avoid immediate closing on map
    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [root]
        onCleared: root.close()
    }

    Timer {
        id: focusGrabTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (root.isOpen) {
                focusGrab.active = true
                keyHandler.forceActiveFocus()
            }
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            focusGrabTimer.restart()
            keyHandler.forceActiveFocus()
        } else {
            focusGrabTimer.stop()
            focusGrab.active = false
        }
    }

    // ─────────────────────────────────────────────────
    // Keyboard Handler (Windows Alt+Tab navigation)
    // ─────────────────────────────────────────────────
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.isOpen

        Keys.onPressed: (event) => {
            if (!root.isOpen) return
            switch (event.key) {
                case Qt.Key_Tab:
                    if (event.modifiers & Qt.ShiftModifier) {
                        root._move(-1)
                    } else {
                        root._move(1)
                    }
                    event.accepted = true
                    break
                case Qt.Key_Right:
                case Qt.Key_L:
                    root._move(1)
                    event.accepted = true
                    break
                case Qt.Key_Left:
                case Qt.Key_H:
                    root._move(-1)
                    event.accepted = true
                    break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    root._confirm()
                    event.accepted = true
                    break
                case Qt.Key_Escape:
                    root.close()
                    event.accepted = true
                    break
                default:
                    break
            }
        }

        Keys.onReleased: (event) => {
            if (!root.isOpen) return
            // Releasing Alt alone confirms and switches (Windows behavior)
            if (event.key === Qt.Key_Alt && !(event.modifiers & Qt.AltModifier)) {
                root._confirm()
                event.accepted = true
            }
        }
    }

    // ─────────────────────────────────────────────────
    // Visual Layer
    // ─────────────────────────────────────────────────

    // Dim blurred backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.darker_background, 0.70)
        opacity: root.isOpen ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Motion.medium1; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Centered Windows-style HUD container
    Item {
        id: hud
        anchors.centerIn: parent

        width: mainCol.implicitWidth + 56
        height: mainCol.implicitHeight + 48

        opacity: root.isOpen ? 1.0 : 0.0
        scale: root.isOpen ? 1.0 : 0.90

        Behavior on opacity {
            NumberAnimation { duration: Motion.medium2; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Motion.medium2
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.emphasizedDecelerateCurve
            }
        }

        // HUD Glass Background Card
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Theme.withAlpha(Theme.background, 0.92)
            border.color: Theme.withAlpha(Theme.border, 0.35)
            border.width: 1

            // Subtle inner glow
            Rectangle {
                anchors { fill: parent; margins: 1 }
                radius: parent.radius - 1
                color: "transparent"
                border.color: Theme.withAlpha(Theme.foreground, 0.05)
                border.width: 1
            }
        }

        ColumnLayout {
            id: mainCol
            anchors.centerIn: parent
            spacing: 14

            // ── Top Header Bar ────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                    text: "󰍹"
                    font.pixelSize: 13
                    font.family: Icons.effectiveFont(text)
                    color: Theme.accent
                }

                Text {
                    text: "TASK VIEW  ·  WORKSPACES"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.0
                    color: Theme.withAlpha(Theme.foreground, 0.55)
                }
            }

            // ── Workspaces Cards Row ──────────────────
            Row {
                id: cardsRow
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Repeater {
                    model: root.workspacesService.workspaceIds

                    delegate: Item {
                        id: cardItem
                        required property var modelData
                        required property int index

                        readonly property int wsId: Number(modelData || 0)
                        readonly property bool isSelected: root.selectedId === wsId
                        readonly property bool isActive: root.workspacesService.activeWorkspaceId === wsId
                        readonly property bool isOccupied: !!root.workspacesService.occupiedWorkspaces[wsId]
                        readonly property var windows: root.getWindowsForWorkspace(wsId)

                        width: 148
                        height: 96

                        // Elevate selected card
                        y: isSelected ? -6 : 0
                        Behavior on y {
                            NumberAnimation { duration: Motion.medium1; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            id: cardBox
                            anchors.fill: parent
                            radius: 12
                            antialiasing: true
                            clip: true

                            // Card Background
                            color: cardItem.isSelected
                                ? Theme.withAlpha(Theme.accent, 0.16)
                                : cardItem.isActive
                                    ? Theme.withAlpha(Theme.foreground, 0.08)
                                    : Theme.withAlpha(Theme.darker_background, 0.75)

                            // Card Border
                            border.color: cardItem.isSelected
                                ? Theme.accent
                                : Theme.withAlpha(Theme.border, cardItem.isActive ? 0.45 : 0.20)
                            border.width: cardItem.isSelected ? 2 : 1

                            Behavior on color { ColorAnimation { duration: Motion.colorDuration } }
                            Behavior on border.color { ColorAnimation { duration: Motion.colorDuration } }

                            // Card Scale
                            scale: cardItem.isSelected ? 1.05 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Motion.medium1
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.emphasizedCurve
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                // Top row: Workspace badge + Active dot
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Rectangle {
                                        implicitHeight: 18
                                        implicitWidth: wsText.implicitWidth + 12
                                        radius: 9
                                        color: cardItem.isSelected
                                            ? Theme.accent
                                            : Theme.withAlpha(Theme.foreground, 0.10)

                                        Text {
                                            id: wsText
                                            anchors.centerIn: parent
                                            text: "WS " + cardItem.wsId
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            color: cardItem.isSelected ? Theme.dark_background : Theme.foreground
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Active indicator pill/dot
                                    Rectangle {
                                        visible: cardItem.isActive
                                        implicitHeight: 16
                                        implicitWidth: 44
                                        radius: 8
                                        color: Theme.withAlpha(Theme.accent, 0.20)
                                        border.color: Theme.accent
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "CURRENT"
                                            font.pixelSize: 7
                                            font.weight: Font.Bold
                                            color: Theme.accent
                                        }
                                    }
                                }

                                // Center: App Icons / Window Preview Icons
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    // Windows apps grid
                                    Flow {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, 120)
                                        spacing: 6

                                        Repeater {
                                            model: Math.min(cardItem.windows.length, 6)

                                            delegate: Item {
                                                id: appIconSlot
                                                required property int index
                                                readonly property var win: cardItem.windows[index]
                                                readonly property string iconSrc: root.resolveIcon(win ? win.appClass : "")

                                                width: 24
                                                height: 24

                                                Image {
                                                    id: appImg
                                                    anchors.fill: parent
                                                    source: appIconSlot.iconSrc
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                    mipmap: true
                                                    visible: status === Image.Ready && appIconSlot.iconSrc !== ""
                                                }

                                                // Letter badge fallback if icon not found
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 5
                                                    color: cardItem.isSelected
                                                        ? Theme.withAlpha(Theme.accent, 0.35)
                                                        : Theme.withAlpha(Theme.muted, 0.40)
                                                    visible: !appImg.visible

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: (appIconSlot.win && appIconSlot.win.appClass)
                                                            ? appIconSlot.win.appClass.charAt(0).toUpperCase()
                                                            : "?"
                                                        font.pixelSize: 11
                                                        font.weight: Font.Bold
                                                        color: Theme.bright_foreground
                                                    }
                                                }
                                            }
                                        }

                                        // Empty Workspace Visual
                                        Rectangle {
                                            visible: cardItem.windows.length === 0
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: Theme.withAlpha(Theme.foreground, 0.18)
                                        }
                                    }
                                }

                                // Bottom count: Window count badge
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: cardItem.windows.length > 0
                                        ? cardItem.windows.length + (cardItem.windows.length === 1 ? " window" : " windows")
                                        : "Empty"
                                    font.pixelSize: 8
                                    color: Theme.withAlpha(Theme.foreground, 0.40)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedId = cardItem.wsId
                                root._confirm()
                            }
                        }
                    }
                }
            }

            // ── Selected Workspace Window List Preview ─
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitHeight: 28
                implicitWidth: Math.max(340, previewText.implicitWidth + 32)
                radius: 14
                color: Theme.withAlpha(Theme.darker_background, 0.55)
                border.color: Theme.withAlpha(Theme.border, 0.20)
                border.width: 1

                readonly property var selWindows: root.getWindowsForWorkspace(root.selectedId)

                Text {
                    id: previewText
                    anchors.centerIn: parent
                    text: {
                        var wins = parent.selWindows
                        if (wins.length === 0) return "Workspace " + root.selectedId + "  ·  No open windows"
                        var titles = []
                        for (var i = 0; i < Math.min(wins.length, 3); i++) {
                            var t = wins[i].title || wins[i].appClass
                            if (t.length > 32) t = t.substring(0, 30) + "…"
                            titles.push(t)
                        }
                        if (wins.length > 3) titles.push("+" + (wins.length - 3) + " more")
                        return "WS " + root.selectedId + "  ·  " + titles.join("   |   ")
                    }
                    font.pixelSize: 10
                    color: Theme.withAlpha(Theme.foreground, 0.75)
                    elide: Text.ElideRight
                }
            }

            // ── Footer Keyboard Navigation Hints ──────
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Tab / ← → to navigate   ·   Enter or release Alt to switch   ·   Esc to cancel"
                font.pixelSize: 9
                color: Theme.withAlpha(Theme.foreground, 0.35)
            }
        }
    }
}
