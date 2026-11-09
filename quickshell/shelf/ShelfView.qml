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
    property string badgeIconName: "folder"
    property int badgeCount: 1

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
        root.badgeIconName = item.iconName || "folder"
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
        x: -400
        y: -400
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
            border.width: 0
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
            border.width: 0
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
            border.width: 0
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
                color: Qt.rgba(1, 1, 1, 0.04)

                Image {
                    anchors.centerIn: parent
                    source: Quickshell.iconPath(root.badgeIconName || "folder", "text-x-generic")
                    sourceSize: Qt.size(64, 64)
                    width: 32
                    height: 32
                    fillMode: Image.PreserveAspectFit
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
            border.width: 0

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
                root.shelfService.addUrls(urls)
                drop.acceptProposedAction()
            }
        }
    }

    readonly property bool hasSelection: root.shelfService ? root.shelfService.selectedCount > 0 : false

    // ─────────────────────────────────────────────────────────────────────────
    // Consolidated Single Top Header
    // ─────────────────────────────────────────────────────────────────────────
    RowLayout {
        id: shelfHeader
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 2
            leftMargin: 4
            rightMargin: 4
        }
        height: 28
        spacing: 8

        // Left Side: Title & Dynamic Count / Selection Pill
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 8

            Text {
                text: "Staging Shelf"
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: Fonts.weightBold
                color: Theme.foreground
                anchors.verticalCenter: parent.verticalCenter
            }

            // Idle State: Compact item count badge pill
            Rectangle {
                visible: !root.hasSelection && (root.shelfService ? root.shelfService.count > 0 : false)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(22, countText.implicitWidth + 10)
                height: 20
                radius: 10
                color: Theme.withAlpha(Theme.lighter_background, 0.40)

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: root.shelfService ? String(root.shelfService.count) : "0"
                    font.family: root.fontFamily
                    font.pixelSize: 10
                    font.weight: Fonts.weightBold
                    color: Theme.muted
                }
            }

            // Selection State: Accent pill badge "3 / 4 selected"
            Rectangle {
                visible: root.hasSelection
                anchors.verticalCenter: parent.verticalCenter
                width: selCountRow.implicitWidth + 14
                height: 22
                radius: 11
                color: Theme.withAlpha(Theme.accent, 0.22)
                border.color: Theme.withAlpha(Theme.accent, 0.50)
                border.width: 1

                Row {
                    id: selCountRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: Icons.check || "✓"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 10
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: (root.shelfService ? root.shelfService.selectedCount : 0) + " / " + (root.shelfService ? root.shelfService.count : 0) + " selected"
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

        // Right Side: Action Pills (Only visible when items exist)
        Row {
            visible: root.shelfService ? root.shelfService.count > 0 : false
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            // Dynamic Selection Toggle: "Select All" vs "Deselect"
            Rectangle {
                readonly property bool allSelected: root.shelfService && root.shelfService.count > 0 && root.shelfService.selectedCount === root.shelfService.count
                width: toggleSelRow.implicitWidth + 16
                height: 24
                radius: 12
                color: toggleSelMouse.containsMouse
                    ? (allSelected ? Theme.withAlpha(Theme.lighter_background, 0.45) : Theme.withAlpha(Theme.accent, 0.28))
                    : Theme.withAlpha(Theme.lighter_background, 0.25)
                border.width: 0

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: toggleSelRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: parent.parent.allSelected ? "Deselect" : "Select All"
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        font.weight: Fonts.weightMedium
                        color: toggleSelMouse.containsMouse
                            ? (parent.parent.allSelected ? Theme.bright_foreground : Theme.accent)
                            : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: toggleSelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.shelfService) return
                        if (parent.allSelected) {
                            root.shelfService.clearSelection()
                        } else {
                            root.shelfService.selectAll()
                        }
                    }
                }
            }

            // Destructive Action: "Remove (N)" when items selected, or "Clear" when idle
            Rectangle {
                width: destrRow.implicitWidth + 16
                height: 24
                radius: 12
                color: destrMouse.containsMouse
                    ? Theme.withAlpha(Theme.urgent, 0.35)
                    : (root.hasSelection ? Theme.withAlpha(Theme.urgent, 0.20) : Theme.withAlpha(Theme.lighter_background, 0.25))
                border.width: 0

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: destrRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: Icons.close
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 10
                        color: destrMouse.containsMouse || root.hasSelection ? Theme.urgent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.hasSelection
                            ? ("Remove (" + (root.shelfService ? root.shelfService.selectedCount : 0) + ")")
                            : "Clear"
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        font.weight: root.hasSelection ? Fonts.weightBold : Fonts.weightMedium
                        color: destrMouse.containsMouse || root.hasSelection ? Theme.urgent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: destrMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.shelfService) return
                        if (root.hasSelection) {
                            root.shelfService.removeSelected()
                        } else {
                            root.shelfService.clear()
                        }
                    }
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
            top: shelfHeader.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            topMargin: 6
            bottomMargin: 6
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
            height: 56

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

                // Modern tonal background without harsh 1px borders
                color: delegateRoot.isSelected
                    ? (dragArea.containsMouse ? Theme.withAlpha(Theme.accent, 0.22) : Theme.withAlpha(Theme.accent, 0.14))
                    : (dragArea.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.35) : Theme.withAlpha(Theme.dark_background, 0.85))

                border.width: 0

                Behavior on color { ColorAnimation { duration: 140 } }

                // Soft left accent pill indicator on selection
                Rectangle {
                    id: leftAccentPill
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 3
                    }
                    width: 3
                    height: delegateRoot.isSelected ? 22 : 0
                    radius: 1.5
                    color: Theme.accent
                    visible: height > 0
                    opacity: delegateRoot.isSelected ? 1.0 : 0.0

                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

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

                // Progressive Disclosure: Selection Checkbox on Left
                // Only rendered/visible when hovered OR when shelf has active selection
                readonly property bool showCheckbox: delegateRoot.isSelected || root.hasSelection || dragArea.containsMouse || selMouse.containsMouse

                Item {
                    id: selIndicatorBox
                    z: 20
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        leftMargin: 8
                    }
                    width: card.showCheckbox ? 24 : 0
                    opacity: card.showCheckbox ? 1.0 : 0.0
                    visible: width > 0

                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Rectangle {
                        id: selIndicator
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        radius: 9
                        color: delegateRoot.isSelected
                            ? Theme.accent
                            : (selMouse.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.40) : "transparent")
                        border.color: delegateRoot.isSelected
                            ? Theme.accent
                            : (selMouse.containsMouse ? Theme.withAlpha(Theme.border, 0.80) : Theme.withAlpha(Theme.border, 0.55))
                        border.width: delegateRoot.isSelected ? 0 : 1.5

                        scale: selMouse.pressed ? 0.88 : (selMouse.containsMouse ? 1.10 : 1.0)

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: delegateRoot.isSelected ? (Icons.check || "✓") : ""
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 10
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

                // Card Content: Icon, Filename, Path & Remove Button
                RowLayout {
                    id: contentRow
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        rightMargin: 8
                        topMargin: 5
                        bottomMargin: 5
                    }
                    anchors.leftMargin: card.showCheckbox ? 38 : 12
                    spacing: 12

                    Behavior on anchors.leftMargin { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    // Native File Manager Icon or Thumbnail Container (38x38)
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        Layout.alignment: Qt.AlignVCenter
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 0

                        Rectangle {
                            id: thumbMask
                            anchors.fill: parent
                            radius: 8
                            color: "black"
                            layer.enabled: true
                            visible: false
                        }

                        // Image Thumbnail (when item is an image)
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

                        // Native XDG MIME-type icon (matching Nautilus / GNOME)
                        Image {
                            id: mimeIconImg
                            visible: !delegateRoot.model.isImage || thumbImg.status === Image.Error
                            anchors.centerIn: parent
                            source: Quickshell.iconPath(delegateRoot.model.iconName || "text-x-generic", "text-x-generic")
                            sourceSize: Qt.size(64, 64)
                            width: 26
                            height: 26
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                        }
                    }

                    // Filename & Path
                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: delegateRoot.model.fileName || ""
                            font.family: root.fontFamily
                            font.pixelSize: 13
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
                            font.pixelSize: 11
                            color: Theme.withAlpha(Theme.foreground, 0.60)
                            elide: Text.ElideMiddle
                        }
                    }

                    // Progressive Disclosure: Remove button (✕)
                    // Only visible on hover of this card
                    Rectangle {
                        z: 20
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        radius: 14
                        color: removeMouse.containsMouse ? Theme.withAlpha(Theme.urgent, 0.22) : "transparent"

                        opacity: (dragArea.containsMouse || removeMouse.containsMouse) ? 1.0 : 0.0
                        visible: opacity > 0

                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.close
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 12
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
            width: 60
            height: 60
            radius: 30
            color: Theme.withAlpha(Theme.lighter_background, 0.32)
            border.width: 0

            Image {
                anchors.centerIn: parent
                source: Quickshell.iconPath("folder", "text-x-generic")
                sourceSize: Qt.size(64, 64)
                width: 32
                height: 32
                fillMode: Image.PreserveAspectFit
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
        border.width: 0
        z: 30

        Rectangle {
            anchors.centerIn: parent
            width: dropBannerCol.implicitWidth + 36
            height: dropBannerCol.implicitHeight + 24
            radius: 16
            color: Theme.withAlpha(Theme.darker_background, 0.94)
            border.width: 0

            Column {
                id: dropBannerCol
                anchors.centerIn: parent
                spacing: 8

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: Quickshell.iconPath("folder", "text-x-generic")
                    sourceSize: Qt.size(64, 64)
                    width: 36
                    height: 36
                    fillMode: Image.PreserveAspectFit
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
}
