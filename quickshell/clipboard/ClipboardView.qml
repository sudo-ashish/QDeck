import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../theme"
import "../services"

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
        if (searchInput) {
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

    function categoryGlyph(cat) {
        if (cat === "url") return Icons.link || "󰌹"
        if (cat === "command") return Icons.terminal || "󰆍"
        if (cat === "code") return Icons.code || "󰅩"
        if (cat === "multiline") return "format_align_left"
        return Icons.clipboard || "󰅍"
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
    // Top Header: Squircle, Title, Count Badge, Clear All Action
    // ─────────────────────────────────────────────────────────────────────────
    RowLayout {
        id: topHeader
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 2
            leftMargin: 4
            rightMargin: 4
        }
        height: 38
        spacing: 10

        // Left Icon Squircle (38x38)
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter
            radius: 11
            color: Theme.withAlpha(Theme.accent, 0.18)

            Text {
                anchors.centerIn: parent
                text: Icons.clipboard || "󰅍"
                font.family: Icons.effectiveFont(text)
                font.pixelSize: 18
                color: Theme.accent
            }
        }

        // Title & Monospace / Uppercase Subtitle Stack
        Column {
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Row {
                spacing: 8

                Text {
                    text: "Clipboard"
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    font.weight: Fonts.weightBold
                    color: Theme.foreground
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Live item count badge pill
                Rectangle {
                    visible: root.clipboardService ? root.clipboardService.count > 0 : false
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(22, countBadgeText.implicitWidth + 10)
                    height: 20
                    radius: 10
                    color: Theme.withAlpha(Theme.lighter_background, 0.35)

                    Text {
                        id: countBadgeText
                        anchors.centerIn: parent
                        text: String(root.clipboardService ? root.clipboardService.count : 0)
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        font.weight: Fonts.weightBold
                        color: Theme.muted
                    }
                }
            }

            Text {
                text: "CLIPBOARD HISTORY"
                font.family: root.fontFamily
                font.pixelSize: 9
                font.weight: Fonts.weightBold
                font.letterSpacing: 1.2
                color: Theme.muted
                opacity: 0.6
            }
        }

        Item { Layout.fillWidth: true }

        // Clear All Action Button
        Rectangle {
            visible: root.clipboardService ? root.clipboardService.count > 0 : false
            Layout.alignment: Qt.AlignVCenter
            width: clearRow.implicitWidth + 16
            height: 26
            radius: 13
            color: clearMouse.containsMouse
                ? Theme.withAlpha(Theme.urgent, 0.28)
                : Theme.withAlpha(Theme.lighter_background, 0.22)
            border.width: 0

            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                id: clearRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: Icons.close || "󰅖"
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 11
                    color: clearMouse.containsMouse ? Theme.urgent : Theme.muted
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Clear All"
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.weight: Fonts.weightMedium
                    color: clearMouse.containsMouse ? Theme.urgent : Theme.muted
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: clearMouse
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
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main Content: Clipboard Items List
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: listContainer
        anchors {
            top: topHeader.bottom
            bottom: searchContainer.top
            left: parent.left
            right: parent.right
            topMargin: 8
            bottomMargin: 8
            leftMargin: 2
            rightMargin: 2
        }

        // Empty Placeholder
        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: root.filteredCount === 0

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 40
                height: 40
                radius: 20
                color: Theme.withAlpha(Theme.lighter_background, 0.30)

                Text {
                    anchors.centerIn: parent
                    text: root.isSearching ? (Icons.search || "") : (Icons.clipboard || "󰅍")
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 18
                    color: Theme.muted
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.isSearching ? "No matching clipboard entries" : "Clipboard is empty"
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: Fonts.weightBold
                color: Theme.foreground
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.isSearching ? "Try a different search query" : "Copied text will appear here automatically"
                font.family: root.fontFamily
                font.pixelSize: 11
                color: Theme.muted
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
                readonly property int lineCount: itemData ? (itemData.lines || 1) : 1
                readonly property int charCount: itemData ? (itemData.chars || 0) : 0

                readonly property string category: root.detectCategory(rawText)
                readonly property bool isSelected: clipboardListView.currentIndex === itemDelegate.index
                readonly property bool isHovered: itemMouse.containsMouse
                readonly property bool isCopiedFlash: root.copiedFlashIndex === itemDelegate.index

                width: clipboardListView.width
                height: 58
                radius: Appearance.launcherItemRadius

                // Modern tonal background without harsh wireframe lines
                color: isCopiedFlash
                    ? Theme.withAlpha(Theme.accent, 0.35)
                    : (isSelected
                        ? Theme.withAlpha(Theme.accent, 0.20)
                        : (isHovered ? Theme.withAlpha(Theme.lighter_background, 0.32) : Theme.withAlpha(Theme.dark_background, 0.85)))

                border.width: 0

                Behavior on color { ColorAnimation { duration: 120 } }

                // Soft left accent pill indicator on selection
                Rectangle {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 3
                    }
                    width: 3
                    height: itemDelegate.isSelected ? 22 : 0
                    radius: 1.5
                    color: Theme.accent
                    visible: height > 0
                    opacity: itemDelegate.isSelected ? 1.0 : 0.0

                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    // Left Category Glyph / Color Swatch Container
                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        Layout.alignment: Qt.AlignVCenter

                        // Color swatch preview if item is hex color
                        Rectangle {
                            visible: itemDelegate.category === "color"
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            radius: 13
                            color: itemDelegate.rawText.trim()
                            border.color: Theme.withAlpha(Theme.foreground, 0.25)
                            border.width: 1
                        }

                        // Category Squircle for other items
                        Rectangle {
                            visible: itemDelegate.category !== "color"
                            anchors.fill: parent
                            radius: 9
                            color: itemDelegate.isSelected
                                ? Theme.withAlpha(Theme.accent, 0.28)
                                : Theme.withAlpha(Theme.lighter_background, 0.28)

                            Text {
                                anchors.centerIn: parent
                                text: root.categoryGlyph(itemDelegate.category)
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 15
                                color: itemDelegate.isSelected ? Theme.accent : Theme.foreground
                            }
                        }
                    }

                    // Middle Column: Text Preview & Metadata Subtitle
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

                        // Secondary Row: Lines, Chars & Time Ago
                        Row {
                            spacing: 6

                            Text {
                                text: itemDelegate.lineCount + (itemDelegate.lineCount === 1 ? " line" : " lines") + " · " + itemDelegate.charCount + " chars"
                                font.family: root.fontFamily
                                font.pixelSize: 10
                                color: Theme.muted
                            }

                            Text {
                                text: "·"
                                font.family: root.fontFamily
                                font.pixelSize: 10
                                color: Theme.withAlpha(Theme.muted, 0.5)
                            }

                            Text {
                                text: root.formatTimeAgo(itemDelegate.itemTs)
                                font.family: root.fontFamily
                                font.pixelSize: 10
                                color: Theme.withAlpha(Theme.muted, 0.85)
                            }
                        }
                    }

                    // Right Side: "Copied! ✓" Flash Feedback OR Delete (✕) on Hover
                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter

                        // Copied! Feedback Badge
                        Rectangle {
                            visible: itemDelegate.isCopiedFlash
                            anchors.centerIn: parent
                            width: copiedRow.implicitWidth + 12
                            height: 22
                            radius: 11
                            color: Theme.accent

                            Row {
                                id: copiedRow
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    text: Icons.check || "✓"
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 10
                                    color: Theme.darker_background
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Copied"
                                    font.family: root.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Fonts.weightBold
                                    color: Theme.darker_background
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Delete Button (✕)
                        Rectangle {
                            visible: !itemDelegate.isCopiedFlash && (itemMouse.containsMouse || delMouse.containsMouse)
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            radius: 12
                            color: delMouse.containsMouse
                                ? Theme.withAlpha(Theme.urgent, 0.28)
                                : Theme.withAlpha(Theme.lighter_background, 0.30)

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: Icons.close || "󰅖"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 11
                                color: delMouse.containsMouse ? Theme.urgent : Theme.muted
                            }

                            MouseArea {
                                id: delMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
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

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
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
            visible: clipboardListView.visibleArea.heightRatio < 1.0
            y: clipboardListView.visibleArea.yPosition * clipboardListView.height
            height: Math.max(20, clipboardListView.visibleArea.heightRatio * clipboardListView.height)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Bottom: Search Input Field (Matching AppLauncher search box)
    // ─────────────────────────────────────────────────────────────────────────
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
