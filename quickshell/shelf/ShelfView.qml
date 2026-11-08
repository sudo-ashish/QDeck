import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../theme"
import "../services"

Item {
    id: root

    property ShelfService shelfService: null
    readonly property string fontFamily: Fonts.uiFont
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

    // ─────────────────────────────────────────────────────────────────────────
    // Offscreen visual drag badge component for grabToImage snapshot
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: dragBadgeProxy
        x: -300
        y: -300
        width: 80
        height: 80
        visible: true
        layer.enabled: true

        // Background stack card 2 (for 3+ files)
        Rectangle {
            visible: root.badgeCount >= 3
            anchors.centerIn: parent
            width: 60
            height: 60
            radius: 10
            color: Theme.withAlpha(Theme.darker_background, 0.90)
            border.color: Theme.withAlpha(Theme.accent, 0.40)
            border.width: 1
            transform: [
                Translate { x: -6; y: -6 },
                Rotation { angle: -6; origin.x: 30; origin.y: 30 }
            ]
        }

        // Background stack card 1 (for 2+ files)
        Rectangle {
            visible: root.badgeCount >= 2
            anchors.centerIn: parent
            width: 62
            height: 62
            radius: 10
            color: Theme.withAlpha(Theme.dark_background, 0.95)
            border.color: Theme.withAlpha(Theme.accent, 0.60)
            border.width: 1
            transform: [
                Translate { x: 4; y: -4 },
                Rotation { angle: 5; origin.x: 31; origin.y: 31 }
            ]
        }

        // Main Front Card
        Rectangle {
            anchors.centerIn: parent
            width: 64
            height: 64
            radius: 12
            color: Theme.darker_background
            border.color: Theme.accent
            border.width: 2
            clip: true

            Rectangle {
                id: badgeMask
                anchors.fill: parent
                radius: 10
                color: "black"
                layer.enabled: true
                visible: false
            }

            Image {
                visible: root.badgeIsImage && root.badgeThumb !== ""
                anchors.fill: parent
                source: root.badgeIsImage ? root.badgeThumb : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: false
                sourceSize: Qt.size(128, 128)
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: badgeMask
                }
            }

            Rectangle {
                visible: !root.badgeIsImage || root.badgeThumb === ""
                anchors.fill: parent
                radius: 10
                color: Theme.withAlpha(root.badgeColor, 0.22)

                Text {
                    anchors.centerIn: parent
                    text: root.badgeIcon
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 26
                    color: root.badgeColor
                }
            }
        }

        // Badge Count Pill (+N)
        Rectangle {
            visible: root.badgeCount > 1
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 2
                rightMargin: 2
            }
            width: Math.max(22, badgeCountText.implicitWidth + 8)
            height: 20
            radius: 10
            color: Theme.accent
            border.width: 1.5
            border.color: Theme.darker_background

            Text {
                id: badgeCountText
                anchors.centerIn: parent
                text: "+" + root.badgeCount
                font.family: root.fontFamily
                font.pixelSize: 10
                font.weight: Fonts.weightBold
                color: Theme.darker_background
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Inbound DropArea
    // ─────────────────────────────────────────────────────────────────────────
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
            } else if (drop.hasText) {
                var raw = drop.getText("text/uri-list") || drop.text || ""
                var lines = raw.split(/[\r\n]+/)
                for (var j = 0; j < lines.length; j++) {
                    var l = lines[j].trim()
                    if (l.length > 0 && !l.startsWith("#")) urls.push(l)
                }
            }
            if (urls.length > 0 && root.shelfService) {
                for (var k = 0; k < urls.length; k++) {
                    root.shelfService.addUrl(urls[k])
                }
                drop.acceptProposedAction()
            }
        }
    }

    readonly property bool hasSelection: root.shelfService ? root.shelfService.selectedCount > 0 : false

    // ─────────────────────────────────────────────────────────────────────────
    // Shelf Action Bar (Selection Pills & Batch Actions)
    // ─────────────────────────────────────────────────────────────────────────
    RowLayout {
        id: shelfActionRow
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 4
            leftMargin: 4
            rightMargin: 4
        }
        height: 26
        spacing: 8

        // Selection Pill or Info Hint on Left
        Row {
            visible: root.hasSelection
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                width: selBadgeRow.implicitWidth + 14
                height: 22
                radius: 11
                color: Theme.withAlpha(Theme.accent, 0.22)
                border.width: 0

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

        Row {
            visible: !root.hasSelection
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: (root.shelfService && root.shelfService.count > 0)
                    ? (root.shelfService.count + (root.shelfService.count === 1 ? " staged file" : " staged files"))
                    : "Drag files here to stage"
                font.family: root.fontFamily
                font.pixelSize: 11
                color: Theme.muted
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item { Layout.fillWidth: true }

        // Normal state: "Select" (Select All)
        Rectangle {
            visible: !root.hasSelection && (root.shelfService ? root.shelfService.count > 0 : false)
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

        // Normal state: "Clear"
        Rectangle {
            visible: !root.hasSelection && (root.shelfService ? root.shelfService.count > 0 : false)
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

        // Selection state: "All"
        Rectangle {
            visible: root.hasSelection && (root.shelfService ? root.shelfService.selectedCount < root.shelfService.count : false)
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

        // Selection state: "Deselect"
        Rectangle {
            visible: root.hasSelection
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

        // Selection state: "Remove"
        Rectangle {
            visible: root.hasSelection
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
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main Staged Files List
    // ─────────────────────────────────────────────────────────────────────────
    ListView {
        id: shelfListView
        anchors {
            top: shelfActionRow.bottom
            bottom: footerRow.top
            left: parent.left
            right: parent.right
            topMargin: 8
            bottomMargin: 8
            leftMargin: 4
            rightMargin: 4
        }
        clip: true
        spacing: 6
        model: root.shelfService ? root.shelfService.items : null

        delegate: Item {
            id: delegateRoot
            required property var model
            required property int index
            readonly property bool isSelected: !!(delegateRoot.model && delegateRoot.model.selected)

            width: ListView.view.width
            height: 58

            Item {
                id: dragSensor
                x: 0; y: 0; width: 1; height: 1; visible: false
                Drag.active: dragArea.drag.active
                Drag.source: delegateRoot
                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.CopyAction
                Drag.mimeData: ({
                    "text/uri-list": root.getDragUris(delegateRoot.index).join("\r\n") + "\r\n"
                })
                Drag.hotSpot: Qt.point(dragBadgeProxy.width / 2, dragBadgeProxy.height / 2)
                Drag.imageSource: root.dragBadgeImageSource
            }

            Rectangle {
                id: card
                anchors.fill: parent
                radius: Appearance.launcherItemRadius

                opacity: (root.isDraggingItem && (delegateRoot.isSelected || root.activeDragIndex === delegateRoot.index))
                    ? 0.50
                    : 1.0

                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                color: delegateRoot.isSelected
                    ? (dragArea.containsMouse ? Theme.withAlpha(Theme.accent, 0.28) : Theme.withAlpha(Theme.accent, 0.20))
                    : (dragArea.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.38) : Theme.withAlpha(Theme.dark_background, 0.90))

                border.width: delegateRoot.isSelected ? 1 : 0
                border.color: Theme.accent

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.width { NumberAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

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
                        dragSensor.x = 0; dragSensor.y = 0
                        root.isDraggingItem = false
                        root.activeDragIndex = -1
                    }

                    onCanceled: {
                        dragSensor.x = 0; dragSensor.y = 0
                        root.isDraggingItem = false
                        root.activeDragIndex = -1
                    }
                }

                // Selection Checkbox Target on Left
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
                        onPressed: function(mouse) { mouse.accepted = true }
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

                    // Thumbnail / Icon (44x44)
                    Item {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            id: thumbMask
                            anchors.fill: parent
                            radius: 8
                            color: "black"
                            layer.enabled: true
                            visible: false
                        }

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

                    // Filename & Path
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
                        z: 20
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

    // ─────────────────────────────────────────────────────────────────────────
    // Empty State Placeholder
    // ─────────────────────────────────────────────────────────────────────────
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
                font.pixelSize: 28
                color: Theme.muted
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Shelf is empty"
            font.family: root.fontFamily
            font.pixelSize: 14
            font.weight: Fonts.weightBold
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

    // ─────────────────────────────────────────────────────────────────────────
    // Drop Banner Overlay
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: dropArea.containsDrag && !root.isDraggingItem
        radius: Appearance.launcherRadius
        color: Theme.withAlpha(Theme.accent, 0.12)
        border.color: Theme.accent
        border.width: 2
        z: 30

        Rectangle {
            anchors.centerIn: parent
            width: dropBannerCol.implicitWidth + 36
            height: dropBannerCol.implicitHeight + 24
            radius: 16
            color: Theme.withAlpha(Theme.darker_background, 0.94)

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

    // ─────────────────────────────────────────────────────────────────────────
    // Footer Row
    // ─────────────────────────────────────────────────────────────────────────
    RowLayout {
        id: footerRow
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: 4
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
