import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../theme"
import "../../services"

Item {
    id: root

    property ClipboardService clipboardService: null
    readonly property string fontFamily: Fonts.uiFont
    readonly property string monoFont: Fonts.monoFont

    signal requestClose()

    property string filterText: ""
    readonly property bool isSearching: filterText.trim().length > 0

    property int copiedFlashIndex: -1

    Timer {
        id: flashTimer
        interval: 180
        repeat: false
        onTriggered: {
            root.copiedFlashIndex = -1
            root.requestClose()
        }
    }

    readonly property var filteredIndices: {
        var res = []
        if (!clipboardService || !clipboardService.items) return res
        var count = clipboardService.items.count
        var q = root.filterText.trim().toLowerCase()
        for (var i = 0; i < count; i++) {
            var item = clipboardService.items.get(i)
            if (!item || !item.text) continue
            if (!q || item.text.toLowerCase().indexOf(q) !== -1) {
                res.push(i)
            }
        }
        return res
    }

    readonly property int filteredCount: filteredIndices ? filteredIndices.length : 0

    function focusSearch() {
        if (searchInput && searchContainer.visible) {
            searchInput.text = ""
            root.filterText = ""
            searchInput.forceActiveFocus()
        }
    }

    function applySelection(visualIndex) {
        if (visualIndex < 0 || visualIndex >= filteredIndices.length) return
        var realIdx = filteredIndices[visualIndex]
        if (clipboardService) {
            clipboardService.copyItem(realIdx)
        }
        root.copiedFlashIndex = visualIndex
        flashTimer.restart()
    }

    function detectCategory(text) {
        if (!text) return "text"
        var trimmed = text.trim()
        if (/^https?:\/\/[^\s]+$/i.test(trimmed)) return "url"
        if (/^#[0-9a-fA-F]{3,8}$/.test(trimmed) || /^rgba?\(.+\)$/i.test(trimmed)) return "color"
        if (/^(\$|#|sudo |pacman |git |cd |ls |npm |cargo |docker |yarn |paru |systemctl )/.test(trimmed)) return "command"
        if (trimmed.indexOf("{") !== -1 && trimmed.indexOf("}") !== -1) return "code"
        if (trimmed.indexOf("def ") !== -1 || trimmed.indexOf("function") !== -1 || trimmed.indexOf("const ") !== -1 || trimmed.indexOf("class ") !== -1 || trimmed.indexOf("import ") !== -1) return "code"
        if (text.indexOf("\n") !== -1 && text.split("\n").length >= 3) return "multiline"
        return "text"
    }

    function formatPreview(text) {
        if (!text) return ""
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (l.length > 0) return l
        }
        return text.trim()
    }

    function formatTimeAgo(ts) {
        if (!ts) return "Just now"
        var now = Math.floor(Date.now() / 1000)
        var diff = Math.max(0, now - ts)
        if (diff < 15) return "Just now"
        if (diff < 60) return diff + "s ago"
        var mins = Math.floor(diff / 60)
        if (mins < 60) return mins + "m ago"
        var hours = Math.floor(mins / 60)
        if (hours < 24) return hours + "h ago"
        var days = Math.floor(hours / 24)
        if (days < 7) return days + "d ago"
        return "Earlier"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main Content: Clipboard Items List
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: listContainer
        anchors {
            top: parent.top
            bottom: searchContainer.visible ? searchContainer.top : parent.bottom
            left: parent.left
            right: parent.right
            topMargin: 14
            bottomMargin: searchContainer.visible ? 10 : 14
            leftMargin: 14
            rightMargin: 14
        }

        // Clean Minimal Zero-Border M3 Expressive Empty State
        ColumnLayout {
            id: emptyStateLayout
            anchors.centerIn: parent
            spacing: 8
            visible: root.filteredCount === 0
            opacity: visible ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            // 1. Tonal Icon Pill (Focal Anchor)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 42
                implicitHeight: 42
                radius: 12
                border.width: 0
                color: Theme.withAlpha(Theme.accent, 0.12)

                Text {
                    id: emptyIconText
                    anchors.centerIn: parent
                    text: root.isSearching ? (Icons.search || "") : (Icons.clipboard || "󰅍")
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 20
                    color: Theme.accent
                }
            }

            // 2. Primary Title
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.isSearching ? "No matching clips" : "Clipboard is empty"
                font.family: root.fontFamily
                font.pixelSize: 14
                font.bold: true
                color: Theme.bright_foreground
            }

            // 3. Subtle Actionable Hint (Single Line)
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.isSearching
                    ? "Try a different search term or press Esc to clear"
                    : "Copy text or images to see your history here"
                font.family: root.fontFamily
                font.pixelSize: 11
                color: Theme.withAlpha(Theme.muted, 0.85)
            }
        }

        // Items ListView
        ListView {
            id: clipboardListView
            anchors.fill: parent
            anchors.rightMargin: scrollbar.visible ? 8 : 0
            visible: root.filteredCount > 0
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.filteredIndices

            delegate: Rectangle {
                id: itemDelegate
                required property int modelData
                required property int index

                readonly property int realIndex: itemDelegate.modelData
                readonly property var itemData: (root.clipboardService && root.clipboardService.items)
                    ? root.clipboardService.items.get(realIndex)
                    : null
                readonly property string rawText: itemData ? String(itemData.text || "") : ""
                readonly property int itemTs: itemData ? (itemData.timestamp || 0) : 0
                readonly property bool isPinned: !!(itemData && itemData.pinned)

                readonly property string category: root.detectCategory(rawText)
                readonly property bool isSelected: clipboardListView.currentIndex === itemDelegate.index
                readonly property bool isHovered: itemMouse.containsMouse || pinBtnMouse.containsMouse || removeBtnMouse.containsMouse
                readonly property bool isCopiedFlash: root.copiedFlashIndex === itemDelegate.index

                width: clipboardListView.width
                height: 56
                radius: Appearance.launcherItemRadius

                // Modern tonal background without harsh wireframe lines
                color: isCopiedFlash
                    ? Theme.withAlpha(Theme.accent, 0.35)
                    : (isSelected
                        ? Theme.withAlpha(Theme.accent, 0.20)
                        : (isHovered ? Theme.withAlpha(Theme.lighter_background, 0.32) : Theme.withAlpha(Theme.dark_background, 0.85)))

                border.width: 0

                Behavior on color { ColorAnimation { duration: 120 } }

                // Soft left accent pill indicator on selection or pinned
                Rectangle {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 3
                    }
                    width: 3
                    height: (itemDelegate.isSelected || itemDelegate.isPinned) ? 22 : 0
                    radius: 1.5
                    color: itemDelegate.isPinned ? Theme.accent : Theme.accent
                    visible: height > 0
                    opacity: itemDelegate.isSelected ? 1.0 : (itemDelegate.isPinned ? 0.65 : 0.0)

                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                RowLayout {
                    id: itemContentRow
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10

                    // Text Preview & Metadata Subtitle
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        // Primary Text Preview (1st non-empty line)
                        Text {
                            Layout.fillWidth: true
                            text: root.formatPreview(itemDelegate.rawText)
                            font.family: (itemDelegate.category === "code" || itemDelegate.category === "command" || itemDelegate.category === "url")
                                ? root.monoFont
                                : root.fontFamily
                            font.pixelSize: 13
                            font.weight: itemDelegate.isSelected ? Fonts.weightBold : Fonts.weightMedium
                            color: itemDelegate.isSelected ? Theme.bright_foreground : Theme.foreground
                            elide: Text.ElideRight
                        }

                        // Secondary Row: Time Ago & Pinned label
                        RowLayout {
                            spacing: 6

                            Text {
                                text: root.formatTimeAgo(itemDelegate.itemTs)
                                font.family: root.fontFamily
                                font.pixelSize: 10
                                color: Theme.withAlpha(Theme.muted, 0.85)
                            }

                            Text {
                                visible: itemDelegate.isPinned
                                text: "• Pinned"
                                font.family: root.fontFamily
                                font.pixelSize: 10
                                font.weight: Fonts.weightMedium
                                color: Theme.accent
                            }
                        }
                    }

                    // Right Side Actions: Flash Copied / Pin / Remove
                    RowLayout {
                        id: actionsRowContainer
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6
                        z: 50

                        // Copied! Feedback Badge
                        Rectangle {
                            visible: itemDelegate.isCopiedFlash
                            Layout.alignment: Qt.AlignVCenter
                            width: copiedRow.implicitWidth + 14
                            height: 28
                            radius: 14
                            color: Theme.accent
                            border.width: 0

                            Row {
                                id: copiedRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: Icons.check || "✓"
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 11
                                    color: Theme.darker_background
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Copied"
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Fonts.weightBold
                                    color: Theme.darker_background
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Pin Action Button (34x34)
                        Rectangle {
                            id: pinBtn
                            visible: !itemDelegate.isCopiedFlash && (itemDelegate.isPinned || itemDelegate.isHovered)
                            Layout.alignment: Qt.AlignVCenter
                            width: 34
                            height: 34
                            radius: 17
                            color: itemDelegate.isPinned
                                ? (pinBtnMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.35) : Theme.withAlpha(Theme.accent, 0.18))
                                : (pinBtnMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.40) : "transparent")
                            border.width: 0

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: Icons.pin || "󰐃"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 16
                                color: itemDelegate.isPinned ? Theme.accent : (pinBtnMouse.containsMouse ? Theme.bright_foreground : Theme.muted)
                            }

                            MouseArea {
                                id: pinBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                propagateComposedEvents: false
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    if (root.clipboardService) {
                                        root.clipboardService.togglePin(itemDelegate.realIndex)
                                    }
                                }
                            }
                        }

                        // Remove Action Button (34x34)
                        Rectangle {
                            id: removeBtn
                            visible: !itemDelegate.isCopiedFlash && itemDelegate.isHovered
                            Layout.alignment: Qt.AlignVCenter
                            width: 34
                            height: 34
                            radius: 17
                            color: removeBtnMouse.containsMouse
                                ? Theme.withAlpha(Theme.urgent, 0.22)
                                : "transparent"
                            border.width: 0

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: Icons.close || "󰅖"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 15
                                color: removeBtnMouse.containsMouse ? Theme.urgent : Theme.muted
                            }

                            MouseArea {
                                id: removeBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                propagateComposedEvents: false
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    if (root.clipboardService) {
                                        root.clipboardService.removeItem(itemDelegate.realIndex)
                                    }
                                }
                            }
                        }
                    }
                }

                // Dedicated Item Selection Click Area:
                // Only covers the text preview area and stops before the action buttons
                MouseArea {
                    id: itemMouse
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        right: actionsRowContainer.left
                        rightMargin: 6
                    }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        clipboardListView.currentIndex = itemDelegate.index
                        root.applySelection(itemDelegate.index)
                    }
                }
            }
        }

        // Slim 4px Scrollbar matching popovers
        Rectangle {
            id: scrollbar
            anchors.right: parent.right
            anchors.rightMargin: 1
            width: 4
            radius: 2
            color: Theme.withAlpha(Theme.foreground, 0.22)
            visible: clipboardListView.visibleArea.heightRatio < 0.999 && clipboardListView.count > 0
            y: clipboardListView.visibleArea.yPosition * clipboardListView.height
            height: Math.max(20, clipboardListView.visibleArea.heightRatio * clipboardListView.height)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Bottom: Search Input Field (Matching AppLauncher search box)
    // Hidden when clipboard history has 0 items
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: searchContainer
        visible: root.clipboardService ? root.clipboardService.count > 0 : false
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

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            spacing: 12

            Text {
                text: Icons.search || ""
                font.family: Icons.effectiveFont(text)
                font.pixelSize: 18
                color: Theme.muted
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search clipboard history..."
                    font.family: root.fontFamily
                    font.pixelSize: 15
                    color: Theme.muted
                    visible: searchInput.text.length === 0
                    elide: Text.ElideRight
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: root.fontFamily
                    font.pixelSize: 15
                    color: Theme.foreground
                    selectionColor: Theme.selection
                    selectedTextColor: Theme.bright_foreground
                    clip: true
                    focus: true

                    onTextChanged: {
                        root.filterText = text
                        clipboardListView.currentIndex = 0
                    }

                    Keys.onDownPressed: {
                        if (clipboardListView.count > 0) {
                            clipboardListView.currentIndex = (clipboardListView.currentIndex + 1) % clipboardListView.count
                            clipboardListView.positionViewAtIndex(clipboardListView.currentIndex, ListView.Contain)
                        }
                    }

                    Keys.onUpPressed: {
                        if (clipboardListView.count > 0) {
                            clipboardListView.currentIndex = (clipboardListView.currentIndex - 1 + clipboardListView.count) % clipboardListView.count
                            clipboardListView.positionViewAtIndex(clipboardListView.currentIndex, ListView.Contain)
                        }
                    }

                    Keys.onTabPressed: {
                        if (clipboardListView.count > 0) {
                            clipboardListView.currentIndex = (clipboardListView.currentIndex + 1) % clipboardListView.count
                            clipboardListView.positionViewAtIndex(clipboardListView.currentIndex, ListView.Contain)
                        }
                    }

                    Keys.onBacktabPressed: {
                        if (clipboardListView.count > 0) {
                            clipboardListView.currentIndex = (clipboardListView.currentIndex - 1 + clipboardListView.count) % clipboardListView.count
                            clipboardListView.positionViewAtIndex(clipboardListView.currentIndex, ListView.Contain)
                        }
                    }

                    Keys.onReturnPressed: root.applySelection(clipboardListView.currentIndex)
                    Keys.onEnterPressed: root.applySelection(clipboardListView.currentIndex)
                    Keys.onEscapePressed: root.requestClose()

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_PageDown) {
                            if (clipboardListView.count > 0) {
                                clipboardListView.currentIndex = Math.min(clipboardListView.count - 1, clipboardListView.currentIndex + 5)
                                clipboardListView.positionViewAtIndex(clipboardListView.currentIndex, ListView.Contain)
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_PageUp) {
                            if (clipboardListView.count > 0) {
                                clipboardListView.currentIndex = Math.max(0, clipboardListView.currentIndex - 5)
                                clipboardListView.positionViewAtIndex(clipboardListView.currentIndex, ListView.Contain)
                            }
                            event.accepted = true
                        }
                    }
                }
            }

            // Clear search query button (✕)
            Rectangle {
                visible: searchInput.text.length > 0
                Layout.alignment: Qt.AlignVCenter
                width: 22
                height: 22
                radius: 11
                color: clearQueryMouse.containsMouse
                    ? Theme.withAlpha(Theme.lighter_background, 0.45)
                    : Theme.withAlpha(Theme.lighter_background, 0.25)

                Text {
                    anchors.centerIn: parent
                    text: Icons.close || "󰅖"
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 10
                    color: Theme.muted
                }

                MouseArea {
                    id: clearQueryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        searchInput.text = ""
                        root.filterText = ""
                        searchInput.forceActiveFocus()
                    }
                }
            }

            // Clear all unpinned items button (visible when not actively typing query)
            Rectangle {
                visible: searchInput.text.length === 0 && (root.clipboardService ? root.clipboardService.count > 0 : false)
                Layout.alignment: Qt.AlignVCenter
                width: clearAllRow.implicitWidth + 14
                height: 22
                radius: 6
                color: clearAllMouse.containsMouse
                    ? Theme.withAlpha(Theme.urgent, 0.22)
                    : Theme.withAlpha(Theme.lighter_background, 0.20)

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: clearAllRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: Icons.close || "󰅖"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 10
                        color: clearAllMouse.containsMouse ? Theme.urgent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Clear"
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        font.weight: Fonts.weightMedium
                        color: clearAllMouse.containsMouse ? Theme.urgent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: clearAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.clipboardService) {
                            root.clipboardService.clear()
                        }
                    }
                }
            }

            // Keyboard shortcut hint pill
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: hintText.implicitWidth + 12
                height: 22
                radius: 6
                color: Theme.withAlpha(Theme.lighter_background, 0.20)

                Text {
                    id: hintText
                    anchors.centerIn: parent
                    text: "Enter to copy"
                    font.family: root.fontFamily
                    font.pixelSize: 10
                    color: Theme.withAlpha(Theme.muted, 0.8)
                }
            }
        }
    }
}
