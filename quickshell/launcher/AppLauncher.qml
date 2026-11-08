import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"
import "../components"
import "LauncherModel.js" as LauncherModel

PanelWindow {
    id: root

    readonly property string fontFamily: Fonts.uiFont

    property bool isOpen: false
    property real animProgress: 0.0

    property var allApps: []
    property var filteredItems: []
    property var historyMap: ({})

    // Animation physics: Pop down-to-up from bottom with spring overshoot
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
        }
    }

    function open(initialQuery) {
        closeAnim.stop()
        root.loadHistory()
        root.loadApps()
        searchInput.text = (typeof initialQuery === "string") ? initialQuery : ""
        root.filterItems()
        listView.currentIndex = 0
        root.isOpen = true
        openAnim.restart()
        Qt.callLater(function() {
            searchInput.forceActiveFocus()
        })
    }

    function close() {
        if (!root.isOpen && !openAnim.running) return
        openAnim.stop()
        root.isOpen = false
        closeAnim.restart()
    }

    function toggle(initialQuery) {
        if (root.isOpen) {
            root.close()
        } else {
            root.open(initialQuery)
        }
    }

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

        if (item.type === "action" && item.cmd) {
            Quickshell.execDetached(["bash", "-c", item.cmd])
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

    // Window Setup & Native Hyprland Blur Integration
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

    // LayerShell configuration
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (root.isOpen && !closeAnim.running) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    onIsOpenChanged: {
        if (root.isOpen) {
            Qt.callLater(function() {
                searchInput.forceActiveFocus()
            })
        }
    }

    // Read history from local state
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

    // IPC interface for qdeck-launcher CLI compatibility
    IpcHandler {
        target: "launcher"
        function open() { root.open("") }
        function search(query: string) { root.open(query) }
        function close() { root.close() }
        function toggle() { root.toggle("") }
        function setMode(mode: string) { root.open("") }
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

    // ─────────────────────────────────────────────────────────────────────────
    // Main Launcher Card (Floating at bottom with pop down-to-up spring animation)
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: launcherCard

        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 28
        }

        width: Math.min(parent.width - 32, Appearance.launcherWidth)
        height: Math.min(parent.height - 60, Appearance.launcherHeight)
        radius: Appearance.launcherRadius

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

        // Consume clicks inside card
        MouseArea {
            anchors.fill: parent
            onClicked: searchInput.forceActiveFocus()
        }

        // ── Top: Items List (Above Search Input) ─────────────────────────────
        Item {
            anchors {
                top: parent.top
                topMargin: 12
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

                            // Line 2: Subtitle Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                // Action badge [⚡ Action]
                                Rectangle {
                                    visible: modelData.type === "action"
                                    Layout.preferredHeight: 18
                                    Layout.preferredWidth: actionBadgeRow.implicitWidth + 10
                                    radius: 4
                                    color: "#22d3ee"

                                    RowLayout {
                                        id: actionBadgeRow
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            text: "⚡"
                                            font.pixelSize: 9
                                            color: "#083344"
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Text {
                                            text: "Action"
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Fonts.weightBold
                                            color: "#083344"
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }
                                }

                                Text {
                                    visible: modelData.type === "action"
                                    text: "•"
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.muted
                                }

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
                anchors.bottom: parent.bottom
                width: 4
                radius: 2
                color: Theme.withAlpha(Theme.dark_background, 0.5)
                visible: listView.count > 8

                Rectangle {
                    id: scrollbarHandle
                    width: parent.width
                    radius: 2
                    color: Theme.accent
                    height: Math.max(20, listView.visibleArea.heightRatio * scrollbar.height)
                    y: listView.visibleArea.yPosition * scrollbar.height
                }
            }
        }

        // ── Bottom: Search Input Field ───────────────────────────────────────
        Rectangle {
            id: searchContainer

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 14
            }
            height: 48
            radius: 12

            color: Theme.withAlpha(Theme.dark_background, 0.92)
            border.color: searchInput.activeFocus ? Theme.accent : Theme.withAlpha(Theme.border, 0.22)
            border.width: 1

            Item {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search"
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    color: Theme.muted
                    visible: searchInput.text.length === 0
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: root.fontFamily
                    font.pixelSize: 14
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

    Component.onCompleted: {
        root.loadHistory()
        root.loadApps()
    }
}
