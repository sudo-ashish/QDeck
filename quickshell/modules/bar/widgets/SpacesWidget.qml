import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Optional imports for seamless integration if available in parent environment
import "../../../theme" 1.0 as QDeckTheme

Item {
    id: root

    // Dimensions & Spacing (can be configured directly or via theme)
    property int pillHeight: {
        try { return Appearance.barButtonHeight } catch(e) { return 28 }
    }
    property int pillRadius: Math.round(root.pillHeight / 2)
    property int pillPadding: 10
    property int iconSize: 18
    property int iconSpacing: 5
    property int spacing: 6

    // =========================================================================
    // 1. THEME & COLOR TOKENS
    // Exposed as a clean top-level QtObject for dynamic theming & customization.
    // Automatically hooks into QDeck Theme singleton if present, with standalone fallbacks.
    // =========================================================================
    property QtObject theme: QtObject {
        id: defaultTheme
        property color background: {
            try { return Theme.background } catch(e) { return "#1f1f28" }
        }
        property color foreground: {
            try { return Theme.foreground } catch(e) { return "#dcd7ba" }
        }
        property color activeBackground: {
            try { return Theme.accent } catch(e) { return "#7aa89f" }
        }
        property color activeForeground: {
            try { return Theme.dark_background } catch(e) { return "#181616" }
        }
        property color inactivePillBackground: {
            try { return Theme.withAlpha(Theme.foreground, 0.08) } catch(e) { return Qt.rgba(1, 1, 1, 0.08) }
        }
        property color hoveredPillBackground: {
            try { return Theme.withAlpha(Theme.foreground, 0.16) } catch(e) { return Qt.rgba(1, 1, 1, 0.16) }
        }
        property color focusedIconHighlight: {
            try { return Theme.withAlpha(Theme.dark_background, 0.28) } catch(e) { return Qt.rgba(0, 0, 0, 0.24) }
        }
        property color borderColor: {
            try { return Theme.selection } catch(e) { return Qt.rgba(1, 1, 1, 0.10) }
        }
        property int pillHeight: root.pillHeight
        property int pillRadius: root.pillRadius
        property int pillPadding: root.pillPadding
        property int iconSize: root.iconSize
        property int iconSpacing: root.iconSpacing
        property int spacing: root.spacing
        property int animDuration: 280
        property int fastDuration: 160
        property string fontFamily: {
            try { return Theme.fontFamily } catch(e) { return "JetBrainsMono Nerd Font" }
        }
    }

    implicitHeight: root.theme.pillHeight
    implicitWidth: pillRow.implicitWidth
    height: implicitHeight
    width: implicitWidth

    // Drop-in compatibility with WorkspacesWidget
    property var service: null

    // When true, displays solely the active workspace tab (ideal for Alt+Tab HUD)
    property bool onlyActiveWorkspace: false

    // Programmatic / external hover preview property (-1 = none)
    property int previewHoveredWsId: -1

    // Notification signals for external containers/HUDs
    signal workspaceSelected(int id)
    signal windowSelected(string address)

    // =========================================================================
    // 2. HYPRLAND STATE & WINDOW QUERYING
    // =========================================================================
    property int _rev: 0

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            root._rev++
            refreshDebounce.restart()
        }
        function onFocusedWorkspaceChanged() {
            root._rev++
            refreshDebounce.restart()
        }
        function onActiveToplevelChanged() {
            root._rev++
            refreshDebounce.restart()
        }
    }

    Timer {
        id: refreshDebounce
        interval: 100
        repeat: false
        onTriggered: {
            refreshClientsProc.running = true
            refreshActiveWindowProc.running = true
        }
    }

    Timer {
        id: initTimer
        interval: 150
        running: true
        repeat: false
        onTriggered: {
            root._rev++
            refreshClientsProc.running = true
            refreshActiveWindowProc.running = true
        }
    }

    // Normalized Address helper (ensures consistent "0x..." hex representation)
    function normalizeAddress(addr) {
        if (!addr) return ""
        var str = String(addr).trim().toLowerCase()
        if (str.startsWith("0x")) return str
        return "0x" + str
    }

    // Fallback JSON IPC collectors
    property var _ipcClients: []
    property var _ipcActiveWindow: ({})

    Process {
        id: refreshClientsProc
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text && text.length > 0) {
                    try {
                        root._ipcClients = JSON.parse(text) || []
                        root._rev++
                    } catch(e) {}
                }
            }
        }
    }

    Process {
        id: refreshActiveWindowProc
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text && text.length > 0) {
                    try {
                        root._ipcActiveWindow = JSON.parse(text) || {}
                        root._rev++
                    } catch(e) {}
                }
            }
        }
    }

    readonly property int currentWorkspaceId: {
        root._rev
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) {
            return Hyprland.focusedWorkspace.id
        }
        if (root._ipcActiveWindow && root._ipcActiveWindow.workspace && root._ipcActiveWindow.workspace.id > 0) {
            return root._ipcActiveWindow.workspace.id
        }
        return 1
    }

    readonly property string focusedAddress: {
        root._rev
        if (Hyprland.activeToplevel && Hyprland.activeToplevel.address) {
            return root.normalizeAddress(Hyprland.activeToplevel.address)
        }
        if (root._ipcActiveWindow && root._ipcActiveWindow.address) {
            return root.normalizeAddress(root._ipcActiveWindow.address)
        }
        return ""
    }

    // Dynamic list of visible workspace IDs (persistent 1..5 + active/occupied)
    readonly property var workspaceIds: {
        root._rev
        if (root.onlyActiveWorkspace) {
            return [ root.currentWorkspaceId ]
        }
        var set = [1, 2, 3, 4, 5]
        var list = Hyprland.workspaces ? Hyprland.workspaces.values : []
        for (var i = 0; i < list.length; i++) {
            var ws = list[i]
            if (ws && ws.id > 0 && ws.id <= 10 && set.indexOf(ws.id) === -1) {
                set.push(ws.id)
            }
        }
        for (var j = 0; j < root._ipcClients.length; j++) {
            var c = root._ipcClients[j]
            var cid = c.workspace ? c.workspace.id : -1
            if (cid > 0 && cid <= 10 && set.indexOf(cid) === -1) {
                set.push(cid)
            }
        }
        if (currentWorkspaceId > 0 && currentWorkspaceId <= 10 && set.indexOf(currentWorkspaceId) === -1) {
            set.push(currentWorkspaceId)
        }
        set.sort(function(a, b) { return a - b })
        return set
    }

    // Desktop Icon Resolution
    function resolveAppIcon(rawClass, title) {
        if (!rawClass && !title) return ""
        var cls = String(rawClass || "").trim()
        var low = cls.toLowerCase()

        // 1. Direct system lookup
        var p = Quickshell.iconPath(cls, true)
        if (p && p.length > 0) return p

        // 2. Common application aliases & desktop naming normalizations
        if (low === "zen" || low.indexOf("zen-") !== -1) {
            return Quickshell.iconPath("zen-browser", true) || Quickshell.iconPath("firefox", true) || ""
        }
        if (low === "brave" || low.indexOf("brave-") !== -1) {
            return Quickshell.iconPath("brave-origin", true) || Quickshell.iconPath("brave-browser", true) || ""
        }
        if (low === "pavucontrol" || low.indexOf("volume") !== -1) {
            return Quickshell.iconPath("org.pulseaudio.pavucontrol", true) || Quickshell.iconPath("multimedia-volume-control", true) || ""
        }
        if (low === "nautilus" || low.indexOf("files") !== -1) {
            return Quickshell.iconPath("org.gnome.Nautilus", true) || Quickshell.iconPath("system-file-manager", true) || ""
        }
        if (low === "code" || low.indexOf("codium") !== -1 || low.indexOf("vscode") !== -1) {
            return Quickshell.iconPath("vscodium", true) || Quickshell.iconPath("code", true) || ""
        }
        if (low.indexOf("antigravity") !== -1) {
            return Quickshell.iconPath("antigravity-ide", true) || Quickshell.iconPath("antigravity", true) || ""
        }
        if (low === "kitty" || low.indexOf("terminal") !== -1) {
            return Quickshell.iconPath("kitty", true) || Quickshell.iconPath("utilities-terminal", true) || ""
        }

        // 3. Strip reverse-DNS prefixes (e.g. org.gnome.Nautilus -> Nautilus, com.zarz.mornye -> mornye)
        var stripped = cls.replace(/^(org|com|net|io|de)\.[^.]+\./i, "")
        p = Quickshell.iconPath(stripped, true) || Quickshell.iconPath(stripped.toLowerCase(), true)
        if (p && p.length > 0) return p

        // 4. Lowercase trial
        p = Quickshell.iconPath(low, true)
        if (p && p.length > 0) return p

        return Quickshell.iconPath("application-x-executable", true) || ""
    }

    // Windows by Workspace Querying
    function getWindowsForWorkspace(wsId) {
        root._rev
        var results = []
        var seenAddrs = {}

        // A. Native Hyprland toplevels
        var tls = Hyprland.toplevels ? Hyprland.toplevels.values : []
        for (var i = 0; i < tls.length; i++) {
            var tl = tls[i]
            if (!tl) continue
            var wid = tl.workspace ? tl.workspace.id : (tl.lastIpcObject && tl.lastIpcObject.workspace ? tl.lastIpcObject.workspace.id : -1)
            if (wid === wsId) {
                var rawAddr = tl.address || (tl.lastIpcObject ? tl.lastIpcObject.address : "")
                var normAddr = root.normalizeAddress(rawAddr)
                var app = (tl.wayland ? tl.wayland.appId : "") || (tl.lastIpcObject ? (tl.lastIpcObject.class || tl.lastIpcObject.initialClass) : "")
                var tit = tl.title || (tl.lastIpcObject ? tl.lastIpcObject.title : "")
                var foc = (normAddr && normAddr === root.focusedAddress) || tl.activated

                if (normAddr) seenAddrs[normAddr] = true
                results.push({
                    address: normAddr,
                    appId: app,
                    title: tit,
                    isFocused: foc,
                    iconSource: root.resolveAppIcon(app, tit)
                })
            }
        }

        // B. Merge with JSON IPC clients if not seen yet
        for (var j = 0; j < root._ipcClients.length; j++) {
            var client = root._ipcClients[j]
            var cwid = client.workspace ? client.workspace.id : -1
            if (cwid === wsId) {
                var cAddr = root.normalizeAddress(client.address || "")
                if (cAddr && seenAddrs[cAddr]) continue
                if (cAddr) seenAddrs[cAddr] = true

                var cApp = client.class || client.initialClass || ""
                var cTit = client.title || client.initialTitle || ""
                var cFoc = (cAddr && cAddr === root.focusedAddress)
                results.push({
                    address: cAddr,
                    appId: cApp,
                    title: cTit,
                    isFocused: cFoc,
                    iconSource: root.resolveAppIcon(cApp, cTit)
                })
            }
        }

        return results
    }

    // =========================================================================
    // 3. NAVIGATION DISPATCH ACTIONS
    // =========================================================================
    function switchToWorkspace(id) {
        if (!id) return
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
        Hyprland.dispatch("workspace " + id)
        root.workspaceSelected(id)
        refreshDebounce.restart()
    }

    function focusWindow(address) {
        if (!address) return
        var addr = root.normalizeAddress(address)
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + addr + "\" })")
        Hyprland.dispatch("focuswindow address:" + addr)
        root.windowSelected(addr)
        refreshDebounce.restart()
    }

    function nextWorkspace() {
        var cur = root.currentWorkspaceId
        var nextWs = (cur >= 10 || cur < 1) ? 1 : cur + 1
        root.switchToWorkspace(nextWs)
    }

    function prevWorkspace() {
        var cur = root.currentWorkspaceId
        var prevWs = (cur <= 1 || cur > 10) ? 10 : cur - 1
        root.switchToWorkspace(prevWs)
    }

    function cycleNext() {
        var wins = root.getWindowsForWorkspace(root.currentWorkspaceId)
        if (wins && wins.length > 1) {
            var curIdx = -1
            for (var i = 0; i < wins.length; i++) {
                if (wins[i].address === root.focusedAddress || wins[i].isFocused) {
                    curIdx = i
                    break
                }
            }
            var nextIdx = (curIdx + 1) % wins.length
            root.focusWindow(wins[nextIdx].address)
        } else {
            root.nextWorkspace()
        }
    }

    function cyclePrev() {
        var wins = root.getWindowsForWorkspace(root.currentWorkspaceId)
        if (wins && wins.length > 1) {
            var curIdx = -1
            for (var i = 0; i < wins.length; i++) {
                if (wins[i].address === root.focusedAddress || wins[i].isFocused) {
                    curIdx = i
                    break
                }
            }
            var prevIdx = curIdx <= 0 ? wins.length - 1 : curIdx - 1
            root.focusWindow(wins[prevIdx].address)
        } else {
            root.prevWorkspace()
        }
    }

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0) {
                root.nextWorkspace()
            } else if (event.angleDelta.y > 0) {
                root.prevWorkspace()
            }
        }
    }

    // =========================================================================
    // 4. WORKSPACE PILL ROW & ACCORDION EXPANSION
    // =========================================================================
    Row {
        id: pillRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.theme.spacing

        Repeater {
            model: root.workspaceIds

            Rectangle {
                id: pill
                required property int modelData

                readonly property int wsId: modelData
                readonly property bool isActive: wsId === root.currentWorkspaceId
                readonly property var windowList: root.getWindowsForWorkspace(wsId)
                readonly property bool hasWindows: windowList.length > 0
                readonly property bool isHovered: (root.previewHoveredWsId === wsId) || pillMouse.containsMouse || pillHover.hovered

                // Feature 2 & 4: Accordion expansion on active or hover
                readonly property bool isExpanded: isActive || (isHovered && hasWindows)

                readonly property color currentTextColor: isActive ? root.theme.activeForeground : root.theme.foreground

                height: root.theme.pillHeight
                radius: root.theme.pillRadius
                antialiasing: true

                // Smooth width expansion
                implicitWidth: contentRow.implicitWidth + (root.theme.pillPadding * 2)
                width: implicitWidth

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: root.theme.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                color: {
                    if (isActive) return root.theme.activeBackground
                    if (isHovered) return root.theme.hoveredPillBackground
                    if (hasWindows) return root.theme.inactivePillBackground
                    return "transparent"
                }

                border.color: isActive ? "transparent" : root.theme.borderColor
                border.width: isActive ? 0 : 1

                Behavior on color {
                    ColorAnimation { duration: root.theme.fastDuration }
                }

                HoverHandler {
                    id: pillHover
                }

                // Pill click switches workspace
                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        root.switchToWorkspace(pill.wsId)
                    }
                }

                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: pill.isExpanded && pill.hasWindows ? root.theme.iconSpacing + 3 : 0

                    // Workspace number / label
                    Text {
                        id: wsLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(pill.wsId)
                        color: pill.currentTextColor
                        font.family: root.theme.fontFamily
                        font.pixelSize: Math.round(root.theme.pillHeight * 0.44)
                        font.bold: pill.isActive
                        opacity: pill.isActive || pill.hasWindows || pill.isHovered ? 1.0 : 0.45

                        Behavior on color {
                            ColorAnimation { duration: root.theme.fastDuration }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: root.theme.fastDuration }
                        }
                    }

                    // Sliding icon strip with clipped extent
                    Item {
                        id: iconClip
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        implicitWidth: pill.isExpanded ? iconStripRow.implicitWidth : 0
                        implicitHeight: root.theme.iconSize + 8
                        width: implicitWidth
                        height: implicitHeight

                        opacity: pill.isExpanded ? 1.0 : 0.0

                        Behavior on implicitWidth {
                            NumberAnimation {
                                duration: root.theme.animDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.theme.fastDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Row {
                            id: iconStripRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.theme.iconSpacing

                            Repeater {
                                model: pill.windowList

                                Item {
                                    id: appIconItem
                                    required property var modelData

                                    readonly property var win: modelData
                                    readonly property bool isFocusedWin: !!win.isFocused && pill.isActive
                                    readonly property bool isHoveredIcon: iconMouseArea.containsMouse

                                    implicitWidth: root.theme.iconSize + 8
                                    implicitHeight: root.theme.iconSize + 8
                                    width: implicitWidth
                                    height: implicitHeight

                                    // Feature 3: Active & Focused Window Highlighting
                                    Rectangle {
                                        id: focusHighlightChip
                                        anchors.fill: parent
                                        radius: 6
                                        color: {
                                            if (appIconItem.isFocusedWin) return root.theme.focusedIconHighlight
                                            if (appIconItem.isHoveredIcon) return Qt.rgba(pill.currentTextColor.r, pill.currentTextColor.g, pill.currentTextColor.b, 0.16)
                                            return "transparent"
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: root.theme.fastDuration }
                                        }
                                    }

                                    // Feature 1: App Icon Image
                                    Image {
                                        id: iconImg
                                        anchors.centerIn: parent
                                        width: root.theme.iconSize
                                        height: root.theme.iconSize
                                        source: appIconItem.win.iconSource || ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        asynchronous: true
                                        visible: status === Image.Ready

                                        opacity: (appIconItem.isFocusedWin || appIconItem.isHoveredIcon) ? 1.0 : (pill.isActive ? 0.65 : 0.85)
                                        scale: appIconItem.isHoveredIcon ? 1.15 : 1.0

                                        Behavior on opacity {
                                            NumberAnimation { duration: root.theme.fastDuration }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: root.theme.fastDuration
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    // Fallback Letter Chip when icon is unavailable
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: root.theme.iconSize
                                        height: root.theme.iconSize
                                        visible: iconImg.status !== Image.Ready
                                        radius: width * 0.28
                                        color: Qt.rgba(pill.currentTextColor.r, pill.currentTextColor.g, pill.currentTextColor.b, 0.18)

                                        Text {
                                            anchors.centerIn: parent
                                            text: {
                                                var name = appIconItem.win.appId || appIconItem.win.title || ""
                                                return name.length > 0 ? name.charAt(0).toUpperCase() : "?"
                                            }
                                            color: pill.currentTextColor
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: Math.round(parent.height * 0.58)
                                            font.bold: true
                                        }
                                    }

                                    // Feature 4: Clicking specific app icon focuses that exact window
                                    MouseArea {
                                        id: iconMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton
                                        onClicked: (mouse) => {
                                            mouse.accepted = true
                                            root.focusWindow(appIconItem.win.address)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

