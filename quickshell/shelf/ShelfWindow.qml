import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

PanelWindow {
    id: root

    property ShelfService shelfService: null

    readonly property string fontFamily: Fonts.uiFont
    property real animProgress: 0.0
    property bool isDraggingItem: false
    property int activeDragIndex: -1

    // Drag Badge Preview State (for Wayland cursor drag icon snapshot)
    property string dragBadgeImageSource: ""
    property string badgeThumb: ""
    property bool badgeIsImage: false
    property string badgeIcon: Icons.folder
    property color badgeColor: Theme.accent
    property int badgeCount: 1

    function categoryColor(cat) {
        if (cat === "code") return Theme.orange
        if (cat === "document") return Theme.cyan
        if (cat === "archive") return Theme.yellow
        if (cat === "video" || cat === "audio") return Theme.magenta
        if (cat === "pdf") return Theme.urgent
        if (cat === "image") return Theme.cyan
        return Theme.accent
    }

    function getDragUris(index) {
        if (!shelfService || index < 0 || index >= shelfService.items.count) return []
        var item = shelfService.items.get(index)
        if (!item) return []
        if (item.selected && shelfService.selectedCount > 1) {
            return shelfService.getSelectedUris()
        }
        return [item.filePath]
    }

    function updateDragBadge(index) {
        if (!shelfService || index < 0 || index >= shelfService.items.count) return
        var item = shelfService.items.get(index)
        if (!item) return

        var isSel = !!item.selected
        var count = (isSel && shelfService.selectedCount > 1) ? shelfService.selectedCount : 1

        root.badgeThumb = item.isImage ? item.filePath : ""
        root.badgeIsImage = item.isImage
        root.badgeIcon = item.fileIcon || Icons.folder
        root.badgeColor = root.categoryColor(item.fileCategory)
        root.badgeCount = count

        Qt.callLater(function() {
            if (dragBadgeProxy) {
                dragBadgeProxy.grabToImage(function(result) {
                    if (result && result.url) {
                        root.dragBadgeImageSource = result.url
                    }
                }, Qt.size(dragBadgeProxy.width, dragBadgeProxy.height))
            }
        })
    }

    function onItemDragStarted(index) {
        if (!shelfService || index < 0 || index >= shelfService.items.count) return
        var item = shelfService.items.get(index)
        if (!item) return

        if (!item.selected) {
            shelfService.clearSelection()
            shelfService.setSelected(index, true)
        }

        root.activeDragIndex = index
        root.isDraggingItem = true
        root.updateDragBadge(index)
    }

    function onItemDragEnded(index) {
        root.isDraggingItem = false
        root.activeDragIndex = -1
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            if (dragBadgeProxy) {
                dragBadgeProxy.grabToImage(function(result) {
                    if (result && result.url) {
                        root.dragBadgeImageSource = result.url
                    }
                }, Qt.size(dragBadgeProxy.width, dragBadgeProxy.height))
            }
        })
    }

    visible: (shelfService && shelfService.isOpen) || closeAnim.running

    // Multi-monitor support: focus monitor or primary
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

    // Floating overlay on bottom-right, separated from launcher
    anchors {
        right: true
        bottom: true
    }
    margins {
        right: 28
        bottom: 28
    }

    implicitWidth: 340
    implicitHeight: Math.min(screen ? (screen.height - 100) : 480, 480)
    color: "transparent"

    WlrLayershell.namespace: "quickshell-shelf"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Motion animations: Slide in from right + Scale + Opacity
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
        }
    }

    Connections {
        target: root.shelfService
        function onIsOpenChanged() {
            if (root.shelfService && root.shelfService.isOpen) {
                closeAnim.stop()
                openAnim.restart()
            } else {
                openAnim.stop()
                closeAnim.restart()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main Shelf Card
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: shelfCard
        anchors.fill: parent
        radius: Appearance.launcherRadius

        color: (dropArea.containsDrag && !root.isDraggingItem)
            ? Theme.withAlpha(Theme.dark_background, Theme.baseOpacity)
            : Theme.withAlpha(Theme.darker_background, Theme.baseOpacity)
        border.width: 0
        border.color: "transparent"
        clip: true

        Behavior on color { ColorAnimation { duration: 180 } }

        // M3 Slide-in from right + Scale + Opacity
        transform: Translate {
            x: (1.0 - root.animProgress) * 48
            y: (1.0 - root.animProgress) * 16
        }
        opacity: Math.min(1.0, root.animProgress * 1.5)
        scale: 0.94 + 0.06 * Math.max(0, Math.min(1.0, root.animProgress))

        // ─────────────────────────────────────────────────────────────────────
        // Inbound DropArea (covers the entire surface)
        // ─────────────────────────────────────────────────────────────────────
        DropArea {
            id: dropArea
            anchors.fill: parent

            onEntered: function(drag) {
                if (root.isDraggingItem) return
                drag.acceptProposedAction()
            }

            onDropped: function(drop) {
                var urls = []
                if (drop.urls && drop.urls.length > 0) {
                    for (var i = 0; i < drop.urls.length; i++) {
                        var u = drop.urls[i]
                        urls.push((u && u.toString) ? u.toString() : String(u))
                    }
                } else if (drop.formats && drop.formats.indexOf("text/uri-list") !== -1) {
                    var raw = drop.getDataAsString("text/uri-list")
                    urls = raw.split(/[\r\n]+/)
                } else if (drop.hasText) {
                    var rawText = drop.text
                    urls = rawText.split(/[\r\n]+/)
                }
                if (root.shelfService) {
                    root.shelfService.addUrls(urls)
                }
                drop.acceptProposedAction()
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Offscreen Drag Badge Component (Wayland Cursor Drag Preview Snapshot)
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: dragBadgeProxy
            x: -300
            y: -300
            width: 80
            height: 80
            visible: true

            // Stack layer 2 (when dragging 3+ files)
            Rectangle {
                visible: root.badgeCount >= 3
                width: 52
                height: 52
                radius: 10
                color: Theme.withAlpha(Theme.dark_background, 0.75)
                border.color: Theme.withAlpha(Theme.border, 0.40)
                border.width: 1
                rotation: 10
                x: 18
                y: 11
            }

            // Stack layer 1 (when dragging 2+ files)
            Rectangle {
                visible: root.badgeCount >= 2
                width: 52
                height: 52
                radius: 10
                color: Theme.withAlpha(Theme.dark_background, 0.88)
                border.color: Theme.withAlpha(Theme.border, 0.50)
                border.width: 1
                rotation: -8
                x: 10
                y: 15
            }

            // Main Preview Card (Front, 52x52)
            Rectangle {
                id: badgeMainCard
                width: 52
                height: 52
                radius: 10
                x: 14
                y: 14
                color: Theme.darker_background
                border.color: Theme.accent
                border.width: 2
                clip: true

                // Thumbnail for image files
                Rectangle {
                    id: badgeThumbMask
                    anchors.fill: parent
                    radius: 8
                    color: "black"
                    layer.enabled: true
                    visible: false
                }

                Image {
                    visible: root.badgeIsImage && !!root.badgeThumb
                    anchors.fill: parent
                    source: root.badgeThumb
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    mipmap: true
                    sourceSize: Qt.size(96, 96)
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: badgeThumbMask
                    }
                }

                // Icon container for non-image files
                Rectangle {
                    visible: !root.badgeIsImage || !root.badgeThumb
                    anchors.fill: parent
                    radius: 8
                    color: Theme.withAlpha(root.badgeColor, 0.25)

                    Text {
                        anchors.centerIn: parent
                        text: root.badgeIcon
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 26
                        color: root.badgeColor
                    }
                }
            }

            // Multi-item Counter Pill Badge
            Rectangle {
                visible: root.badgeCount > 1
                anchors.top: badgeMainCard.top
                anchors.right: badgeMainCard.right
                anchors.topMargin: -6
                anchors.rightMargin: -6
                width: Math.max(22, badgeCountText.implicitWidth + 8)
                height: 22
                radius: 11
                color: Theme.accent
                border.color: Theme.darker_background
                border.width: 2
                z: 10

                Text {
                    id: badgeCountText
                    anchors.centerIn: parent
                    text: String(root.badgeCount)
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.weight: Fonts.weightBold
                    color: Theme.darker_background
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Keyboard Controller for Selection (Escape to deselect, Ctrl+A, Delete)
        // ─────────────────────────────────────────────────────────────────────
        Item {
            id: shelfKeys
            anchors.fill: parent
            focus: root.visible

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    if (root.shelfService && root.shelfService.selectedCount > 0) {
                        root.shelfService.clearSelection()
                        event.accepted = true
                        return
                    }
                    if (root.shelfService) {
                        root.shelfService.close()
                        event.accepted = true
                        return
                    }
                }
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

        readonly property bool hasSelection: root.shelfService ? root.shelfService.selectedCount > 0 : false

        // ─────────────────────────────────────────────────────────────────────
        // Header
        // ─────────────────────────────────────────────────────────────────────
        RowLayout {
            id: headerRow
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 14
            }
            height: 28
            spacing: 8

            // Normal State Left: Folder Icon + Title + Count Pill
            Row {
                visible: !shelfCard.hasSelection
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: Icons.folder
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 16
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Staging Shelf"
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    font.weight: Fonts.weightBold
                    color: Theme.bright_foreground
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Total Count Badge
                Rectangle {
                    visible: root.shelfService ? root.shelfService.count > 0 : false
                    width: Math.max(18, countBadgeText.implicitWidth + 8)
                    height: 18
                    radius: 9
                    color: Theme.withAlpha(Theme.accent, 0.28)
                    border.width: 0
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: countBadgeText
                        anchors.centerIn: parent
                        text: root.shelfService ? String(root.shelfService.count) : "0"
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        font.weight: Fonts.weightBold
                        color: Theme.accent
                    }
                }
            }

            // Selection State Left: Checkmark + "X selected" Pill
            Row {
                visible: shelfCard.hasSelection
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: selBadgeRow.implicitWidth + 14
                    height: 22
                    radius: 11
                    color: Theme.withAlpha(Theme.accent, 0.22)
                    border.width: 0
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: selBadgeRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: Icons.check || "✓"
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 11
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: (root.shelfService ? root.shelfService.selectedCount : 0) + " selected"
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.weight: Fonts.weightBold
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Normal State Button: "Select" (Select All)
            Rectangle {
                visible: !shelfCard.hasSelection && (root.shelfService ? root.shelfService.count > 0 : false)
                width: selectAllRow.implicitWidth + 14
                height: 24
                radius: 12
                color: selectAllMouse.containsMouse
                    ? Theme.withAlpha(Theme.accent, 0.28)
                    : Theme.withAlpha(Theme.lighter_background, 0.30)
                border.width: 0
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: selectAllRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: Icons.check || "✓"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 10
                        color: selectAllMouse.containsMouse ? Theme.accent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Select"
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        font.weight: Fonts.weightMedium
                        color: selectAllMouse.containsMouse ? Theme.accent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: selectAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.shelfService) root.shelfService.selectAll()
                    }
                }
            }

            // Normal State Button: "Clear All"
            Rectangle {
                visible: !shelfCard.hasSelection && (root.shelfService ? root.shelfService.count > 0 : false)
                width: clearRow.implicitWidth + 14
                height: 24
                radius: 12
                color: clearMouse.containsMouse
                    ? Theme.withAlpha(Theme.urgent, 0.28)
                    : Theme.withAlpha(Theme.lighter_background, 0.30)
                border.width: 0
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: Icons.close
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 11
                        color: clearMouse.containsMouse ? Theme.urgent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Clear"
                        font.family: root.fontFamily
                        font.pixelSize: 10
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
                        if (root.shelfService) root.shelfService.clear()
                    }
                }
            }

            // Selection State Button: "All" (when not all items are selected)
            Rectangle {
                visible: shelfCard.hasSelection && (root.shelfService ? root.shelfService.selectedCount < root.shelfService.count : false)
                width: selAllInSelRow.implicitWidth + 14
                height: 24
                radius: 12
                color: selAllInSelMouse.containsMouse
                    ? Theme.withAlpha(Theme.accent, 0.28)
                    : Theme.withAlpha(Theme.lighter_background, 0.25)
                border.width: 0
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: selAllInSelRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "All"
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        font.weight: Fonts.weightMedium
                        color: selAllInSelMouse.containsMouse ? Theme.accent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: selAllInSelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.shelfService) root.shelfService.selectAll()
                    }
                }
            }

            // Selection State Button: "Deselect" (Clear Selection)
            Rectangle {
                visible: shelfCard.hasSelection
                width: deselectRow.implicitWidth + 14
                height: 24
                radius: 12
                color: deselectMouse.containsMouse
                    ? Theme.withAlpha(Theme.lighter_background, 0.45)
                    : Theme.withAlpha(Theme.lighter_background, 0.25)
                border.width: 0
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: deselectRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "Deselect"
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        font.weight: Fonts.weightMedium
                        color: deselectMouse.containsMouse ? Theme.bright_foreground : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: deselectMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.shelfService) root.shelfService.clearSelection()
                    }
                }
            }

            // Selection State Button: "Remove Selected"
            Rectangle {
                visible: shelfCard.hasSelection
                width: removeSelRow.implicitWidth + 14
                height: 24
                radius: 12
                color: removeSelMouse.containsMouse
                    ? Theme.withAlpha(Theme.urgent, 0.35)
                    : Theme.withAlpha(Theme.urgent, 0.20)
                border.width: 0
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: removeSelRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: Icons.close
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 11
                        color: Theme.urgent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Remove"
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        font.weight: Fonts.weightBold
                        color: Theme.urgent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: removeSelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.shelfService) root.shelfService.removeSelected()
                    }
                }
            }

            // Close button (✕)
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: closeMouse.containsMouse
                    ? Theme.withAlpha(Theme.lighter_background, 0.45)
                    : "transparent"
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: Icons.close
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 13
                    color: closeMouse.containsMouse ? Theme.bright_foreground : Theme.muted
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.shelfService) root.shelfService.close()
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Items List
        // ─────────────────────────────────────────────────────────────────────
        ListView {
            id: listView
            anchors {
                top: headerRow.bottom
                topMargin: 10
                left: parent.left
                leftMargin: 12
                right: parent.right
                rightMargin: 12
                bottom: footerRow.top
                bottomMargin: 8
            }
            clip: true
            spacing: 8
            model: root.shelfService ? root.shelfService.items : null
            interactive: count > 0

            delegate: Item {
                id: delegateRoot
                required property var model
                required property int index

                readonly property bool isSelected: !!delegateRoot.model.selected

                width: listView.width
                height: 60

                // Dummy stationary drag sensor (Wayland Drag Target without moving UI)
                Item {
                    id: dragSensor
                    width: 1
                    height: 1
                    visible: false

                    Drag.active: dragArea.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: ({
                        "text/uri-list": root.getDragUris(delegateRoot.index).join("\r\n") + "\r\n"
                    })
                    Drag.hotSpot: Qt.point(dragBadgeProxy.width / 2, dragBadgeProxy.height / 2)
                    Drag.imageSource: root.dragBadgeImageSource
                }

                // Stationary Visual Card
                Rectangle {
                    id: card
                    anchors.fill: parent
                    radius: Appearance.launcherItemRadius

                    // Dim currently dragged item(s) to 0.50 opacity while dragging
                    opacity: (root.isDraggingItem && (delegateRoot.isSelected || root.activeDragIndex === delegateRoot.index))
                        ? 0.50
                        : 1.0

                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    // Visual selection state: active container surface and accent border
                    color: delegateRoot.isSelected
                        ? (dragArea.containsMouse ? Theme.withAlpha(Theme.accent, 0.28) : Theme.withAlpha(Theme.accent, 0.20))
                        : (dragArea.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.38) : Theme.withAlpha(Theme.dark_background, 0.90))

                    border.width: delegateRoot.isSelected ? 1 : 0
                    border.color: Theme.accent

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.width { NumberAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    // Drag & Click Selection MouseArea
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : (dragArea.containsMouse ? Qt.OpenHandCursor : Qt.ArrowCursor)
                        drag.target: dragSensor
                        drag.axis: Drag.XAndYAxis

                        readonly property bool isDragging: drag.active
                        onIsDraggingChanged: {
                            if (isDragging) {
                                root.onItemDragStarted(delegateRoot.index)
                            } else {
                                root.onItemDragEnded(delegateRoot.index)
                            }
                        }

                        onPressed: function(mouse) {
                            root.updateDragBadge(delegateRoot.index)
                        }

                        onClicked: function(mouse) {
                            if (root.shelfService) {
                                root.shelfService.toggleSelection(delegateRoot.index, mouse.modifiers)
                            }
                        }

                        onReleased: {
                            dragSensor.x = 0
                            dragSensor.y = 0
                            root.isDraggingItem = false
                            root.activeDragIndex = -1
                        }

                        onCanceled: {
                            dragSensor.x = 0
                            dragSensor.y = 0
                            root.isDraggingItem = false
                            root.activeDragIndex = -1
                        }
                    }

                    // Checkmark / Selection Indicator (Dedicated GUI Multi-Select target)
                    Item {
                        id: selIndicatorBox
                        z: 20
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: 36

                        Rectangle {
                            id: selIndicator
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 10
                            color: delegateRoot.isSelected
                                ? Theme.accent
                                : (selMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.40) : (dragArea.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.25) : "transparent"))
                            border.color: delegateRoot.isSelected
                                ? Theme.accent
                                : (selMouse.containsMouse ? Theme.withAlpha(Theme.border, 0.60) : (dragArea.containsMouse ? Theme.withAlpha(Theme.border, 0.40) : Theme.withAlpha(root.categoryColor(delegateRoot.model.fileCategory), 0.6)))
                            border.width: delegateRoot.isSelected ? 0 : 1

                            scale: selMouse.pressed ? 0.88 : (selMouse.containsMouse ? 1.10 : 1.0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: delegateRoot.isSelected ? (Icons.check || "✓") : ""
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 11
                                font.weight: Fonts.weightBold
                                color: Theme.darker_background
                            }
                        }

                        MouseArea {
                            id: selMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onPressed: function(mouse) {
                                mouse.accepted = true
                            }
                            onClicked: function(mouse) {
                                mouse.accepted = true
                                if (root.shelfService) {
                                    root.shelfService.toggleItem(delegateRoot.index)
                                }
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 38
                        anchors.rightMargin: 8
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        spacing: 10

                        // Thumbnail / Icon Box (44x44)
                        Item {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            Layout.alignment: Qt.AlignVCenter

                            // Rounded Mask for Thumbnail
                            Rectangle {
                                id: thumbMask
                                anchors.fill: parent
                                radius: 8
                                color: "black"
                                layer.enabled: true
                                visible: false
                            }

                            // Image Thumbnail
                            Image {
                                id: thumbImg
                                visible: delegateRoot.model.isImage
                                anchors.fill: parent
                                source: delegateRoot.model.isImage ? delegateRoot.model.filePath : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                mipmap: true
                                sourceSize: Qt.size(96, 96)

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: thumbMask
                                }
                            }

                            // Non-image Icon Tile with Category Background Indicator
                            Rectangle {
                                visible: !delegateRoot.model.isImage || thumbImg.status === Image.Error
                                anchors.fill: parent
                                radius: 8
                                color: Theme.withAlpha(root.categoryColor(delegateRoot.model.fileCategory), 0.22)
                                border.width: 0

                                Text {
                                    anchors.centerIn: parent
                                    text: delegateRoot.model.fileIcon || Icons.folder
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 20
                                    color: root.categoryColor(delegateRoot.model.fileCategory)
                                }
                            }
                        }

                        // File info Column
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3

                            Text {
                                width: parent.width
                                text: delegateRoot.model.fileName || ""
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                font.weight: Fonts.weightMedium
                                color: Theme.bright_foreground
                                elide: Text.ElideMiddle
                            }

                            Text {
                                width: parent.width
                                text: {
                                    var p = (delegateRoot.model.filePath || "").replace(/^file:\/\//, "")
                                    var parts = p.split("/")
                                    return parts.length > 2 ? (".../" + parts.slice(-2).join("/")) : p
                                }
                                font.family: root.fontFamily
                                font.pixelSize: 10
                                color: Theme.muted
                                elide: Text.ElideMiddle
                            }
                        }

                        // Remove button (✕)
                        Rectangle {
                            z: 10
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            radius: 6
                            color: removeMouse.containsMouse ? Theme.withAlpha(Theme.urgent, 0.25) : "transparent"

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: Icons.close
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 13
                                color: removeMouse.containsMouse ? Theme.urgent : Theme.muted
                            }

                            MouseArea {
                                id: removeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    if (root.shelfService) root.shelfService.removeAt(delegateRoot.index)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Empty State Placeholder
        // ─────────────────────────────────────────────────────────────────────
        Column {
            anchors.centerIn: parent
            spacing: 12
            visible: (root.shelfService ? root.shelfService.count === 0 : true) && (!dropArea.containsDrag || root.isDraggingItem)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64
                height: 64
                radius: 32
                color: Theme.withAlpha(Theme.lighter_background, 0.32)
                border.width: 0

                Text {
                    anchors.centerIn: parent
                    text: Icons.folder
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 30
                    color: Theme.withAlpha(Theme.muted, 0.7)
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Shelf is empty"
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    font.weight: Fonts.weightMedium
                    color: Theme.foreground
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Drop files here to stage"
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    color: Theme.muted
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Inbound Drag Active Overlay (Borderless with background indicator)
        // ─────────────────────────────────────────────────────────────────────
        Rectangle {
            anchors {
                top: headerRow.bottom
                left: parent.left
                right: parent.right
                bottom: footerRow.top
                margins: 10
            }
            radius: Appearance.launcherItemRadius
            visible: dropArea.containsDrag && !root.isDraggingItem
            color: Theme.withAlpha(Theme.accent, 0.22)
            border.width: 0

            Rectangle {
                anchors.centerIn: parent
                width: dropBannerCol.implicitWidth + 36
                height: dropBannerCol.implicitHeight + 20
                radius: 16
                color: Theme.withAlpha(Theme.darker_background, 0.92)
                border.width: 0

                Column {
                    id: dropBannerCol
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Icons.folder
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 34
                        color: Theme.accent
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Release to stage files"
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.weight: Fonts.weightBold
                        color: Theme.bright_foreground
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Footer Row
        // ─────────────────────────────────────────────────────────────────────
        RowLayout {
            id: footerRow
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: 12
            }
            height: 22

            Text {
                text: {
                    if (!root.shelfService) return "Ready"
                    if (root.shelfService.count === 0) return "Ready for drops"
                    if (root.shelfService.selectedCount > 0) {
                        return root.shelfService.selectedCount + " of " + root.shelfService.count + " selected"
                    }
                    return root.shelfService.count + (root.shelfService.count === 1 ? " file staged" : " files staged")
                }
                font.family: root.fontFamily
                font.pixelSize: 11
                color: (root.shelfService && root.shelfService.selectedCount > 0) ? Theme.accent : Theme.muted
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root.shelfService ? root.shelfService.count > 0 : false
                text: (root.shelfService && root.shelfService.selectedCount > 1)
                    ? "Drag batch to export (" + root.shelfService.selectedCount + ")"
                    : "Drag card to export"
                font.family: root.fontFamily
                font.pixelSize: 11
                color: Theme.withAlpha(Theme.accent, 0.85)
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
