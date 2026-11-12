import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../../theme"
import "../../../services"

// Windows Alt+Tab-style Workspace Switcher Overlay
// Clean, text-free UI showing visual workspace previews with app logos only
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

    readonly property int monitorWidth: (root.screen && root.screen.width > 0) ? root.screen.width : 1920
    readonly property int monitorHeight: (root.screen && root.screen.height > 0) ? root.screen.height : 1080

    // ─────────────────────────────────────────────────
    // State & Dynamic Windows Cache
    // ─────────────────────────────────────────────────
    property bool isOpen: false
    property int selectedId: 1
    property var windowsByWorkspace: ({})
    property var occupiedWorkspaceIds: []

    // Process to query active clients and their layout geometries
    Process {
        id: windowsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var rawText = (text || "").trim()
                if (!rawText) return
                try {
                    var clients = JSON.parse(rawText) || []
                    var map = {}
                    var ids = []

                    for (var i = 0; i < clients.length; i++) {
                        var c = clients[i]
                        if (!c || !c.workspace) continue
                        var wsId = c.workspace.id
                        // Only consider normal workspaces with valid numeric ID
                        if (typeof wsId !== "number" || wsId <= 0) continue

                        if (!map[wsId]) {
                            map[wsId] = []
                            ids.push(wsId)
                        }

                        map[wsId].push({
                            x: (c.at && c.at.length > 0) ? c.at[0] : 0,
                            y: (c.at && c.at.length > 1) ? c.at[1] : 0,
                            w: (c.size && c.size.length > 0) ? c.size[0] : root.monitorWidth,
                            h: (c.size && c.size.length > 1) ? c.size[1] : root.monitorHeight,
                            appClass: c.class || "",
                            floating: !!c.floating,
                            fullscreen: !!c.fullscreen
                        })
                    }

                    ids.sort(function(a, b) { return a - b })

                    // If no occupied workspaces exist, fallback to active workspace
                    if (ids.length === 0) {
                        ids = [ root.workspacesService.activeWorkspaceId ]
                    }

                    root.windowsByWorkspace = map
                    root.occupiedWorkspaceIds = ids

                    // Ensure selectedId is in the occupied list
                    if (root.occupiedWorkspaceIds.indexOf(root.selectedId) === -1) {
                        root.selectedId = root.occupiedWorkspaceIds[0]
                    }
                } catch(e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent() {
            if (root.isOpen) windowsProc.running = true
        }
        function onFocusedWorkspaceChanged() {
            if (root.isOpen) windowsProc.running = true
        }
    }

    Component.onCompleted: {
        windowsProc.running = true
    }

    // ─────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────
    function open(): string {
        if (root.isOpen) return "already-open"
        windowsProc.running = true

        var cur = root.workspacesService.activeWorkspaceId
        root.selectedId = cur
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
        var ids = root.occupiedWorkspaceIds
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

    // Helper: Resolve app logo icon path
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

        // 2. Known desktop application aliases
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
        return Quickshell.iconPath("application-x-executable", true) || ""
    }

    // ─────────────────────────────────────────────────
    // Window Configuration
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
            windowsProc.running = true
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
    // Visual Layer: Pure Visual, Zero Text
    // ─────────────────────────────────────────────────

    // Dim blurred backdrop (clicking closes without switching)
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

    // Floating Centered HUD Card
    Item {
        id: hud
        anchors.centerIn: parent

        width: cardsRow.implicitWidth + 36
        height: cardsRow.implicitHeight + 36

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

        // HUD Glass Background Panel
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Theme.withAlpha(Theme.background, 0.88)
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

        // Row of workspace preview cards
        Row {
            id: cardsRow
            anchors.centerIn: parent
            spacing: 16

            Repeater {
                model: root.occupiedWorkspaceIds

                delegate: Item {
                    id: cardItem
                    required property var modelData
                    required property int index

                    readonly property int wsId: Number(modelData || 0)
                    readonly property bool isSelected: root.selectedId === wsId
                    readonly property bool isActive: root.workspacesService.activeWorkspaceId === wsId
                    readonly property var winList: root.windowsByWorkspace[wsId] || []

                    // 16:9 Aspect Ratio card (256x144)
                    width: 256
                    height: 144

                    // Elevation on selection
                    y: isSelected ? -8 : 0
                    Behavior on y {
                        NumberAnimation { duration: Motion.medium1; easing.type: Easing.OutCubic }
                    }

                    // Ambient selection glow
                    Rectangle {
                        anchors { fill: parent; margins: -4 }
                        radius: 18
                        color: Theme.withAlpha(Theme.accent, 0.35)
                        visible: cardItem.isSelected
                        opacity: cardItem.isSelected ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Motion.medium1 } }
                    }

                    // Workspace Miniature Monitor Frame
                    Rectangle {
                        id: cardBox
                        anchors.fill: parent
                        radius: 14
                        antialiasing: true
                        clip: true

                        // Miniature desktop canvas
                        color: cardItem.isSelected
                            ? Theme.withAlpha(Theme.accent, 0.12)
                            : Theme.withAlpha(Theme.darker_background, 0.85)

                        border.color: cardItem.isSelected
                            ? Theme.accent
                            : Theme.withAlpha(Theme.border, cardItem.isActive ? 0.45 : 0.20)
                        border.width: cardItem.isSelected ? 2.5 : 1

                        Behavior on color { ColorAnimation { duration: Motion.colorDuration } }
                        Behavior on border.color { ColorAnimation { duration: Motion.colorDuration } }

                        // Scale animation
                        scale: cardItem.isSelected ? 1.06 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: Motion.medium1
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.emphasizedCurve
                            }
                        }

                        // ── Workspace Screen Preview Area ─────
                        Item {
                            id: previewCanvas
                            anchors {
                                fill: parent
                                margins: 6
                            }

                            readonly property real scaleX: width / root.monitorWidth
                            readonly property real scaleY: height / root.monitorHeight

                            // Render miniature window boxes inside this workspace
                            Repeater {
                                model: cardItem.winList

                                delegate: Rectangle {
                                    id: winRect
                                    required property var modelData
                                    required property int index

                                    readonly property var win: modelData
                                    readonly property bool singleWindow: cardItem.winList.length === 1
                                    readonly property string iconSrc: root.resolveIcon(win ? win.appClass : "")

                                    // Position and dimension scaled from monitor coordinates
                                    x: singleWindow ? 4 : Math.max(2, Math.min(previewCanvas.width - width - 2, Math.round(win.x * previewCanvas.scaleX)))
                                    y: singleWindow ? 4 : Math.max(2, Math.min(previewCanvas.height - height - 2, Math.round(win.y * previewCanvas.scaleY)))
                                    width: singleWindow ? (previewCanvas.width - 8) : Math.max(36, Math.min(previewCanvas.width - 4, Math.round(win.w * previewCanvas.scaleX)))
                                    height: singleWindow ? (previewCanvas.height - 8) : Math.max(36, Math.min(previewCanvas.height - 4, Math.round(win.h * previewCanvas.scaleY)))

                                    radius: 6
                                    antialiasing: true
                                    clip: true

                                    // Miniature window glass surface
                                    color: Theme.withAlpha(Theme.background, 0.90)
                                    border.color: Theme.withAlpha(Theme.foreground, 0.20)
                                    border.width: 1

                                    // Miniature window titlebar strip
                                    Rectangle {
                                        anchors {
                                            top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 2
                                        }
                                        height: 3
                                        radius: 1
                                        color: Theme.withAlpha(Theme.foreground, 0.16)
                                    }

                                    // App Logo centered in window
                                    Image {
                                        id: appLogoImg
                                        anchors.centerIn: parent
                                        width: singleWindow ? 54 : Math.min(38, Math.min(parent.width - 8, parent.height - 8))
                                        height: width
                                        source: winRect.iconSrc
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                        visible: status === Image.Ready && winRect.iconSrc !== ""
                                    }

                                    // Fallback logo placeholder if icon is loading / unresolvable
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: singleWindow ? 48 : Math.min(32, Math.min(parent.width - 8, parent.height - 8))
                                        height: width
                                        radius: width / 2
                                        color: Theme.withAlpha(Theme.muted, 0.40)
                                        visible: !appLogoImg.visible
                                    }
                                }
                            }
                        }

                        // ── Active Workspace Glowing Indicator Dot ─
                        // (Only on current workspace, positioned top-right, NO text)
                        Rectangle {
                            visible: cardItem.isActive
                            anchors {
                                top: parent.top
                                right: parent.right
                                margins: 8
                            }
                            width: 8
                            height: 8
                            radius: 4
                            color: Theme.accent

                            // Subtle pulsing glow
                            Rectangle {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                radius: 7
                                color: Theme.withAlpha(Theme.accent, 0.35)
                            }
                        }
                    }

                    // Click to switch immediately
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
    }
}
