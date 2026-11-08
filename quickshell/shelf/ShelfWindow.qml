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

    function categoryColor(cat) {
        if (cat === "code") return Theme.orange
        if (cat === "document") return Theme.cyan
        if (cat === "archive") return Theme.yellow
        if (cat === "video" || cat === "audio") return Theme.magenta
        if (cat === "pdf") return Theme.urgent
        if (cat === "image") return Theme.cyan
        return Theme.accent
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

            // Left: Icon + Title + Count Pill
            Row {
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

                // Count Badge
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

            Item { Layout.fillWidth: true }

            // "Clear All" button (visible when items present)
            Rectangle {
                visible: root.shelfService ? root.shelfService.count > 0 : false
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

                readonly property bool isDragging: dragArea.drag.active
                onIsDraggingChanged: {
                    root.isDraggingItem = isDragging
                }

                width: listView.width
                height: 60

                // ─────────────────────────────────────────────────────────────
                // Ghost Slot Placeholder (In-Shelf Feedback when card is lifted)
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: ghostSlot
                    anchors.fill: parent
                    visible: dragArea.drag.active
                    radius: Appearance.launcherItemRadius
                    color: Theme.withAlpha(Theme.dark_background, 0.40)
                    border.color: Theme.withAlpha(Theme.accent, 0.35)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 8
                        opacity: 0.55

                        Text {
                            text: Icons.move || Icons.folder
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 14
                            color: Theme.accent
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: "Dragging file out..."
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.weight: Fonts.weightMedium
                            color: Theme.muted
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // Foreground Interactive Card (Lift, Spring, Wayland Drag Target)
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: card
                    width: parent.width
                    height: parent.height
                    x: 0
                    y: 0
                    radius: Appearance.launcherItemRadius

                    // Outbound Wayland Drag Properties attached directly to card
                    Drag.active: dragArea.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: ({ "text/uri-list": delegateRoot.model.filePath + "\r\n" })
                    Drag.hotSpot: Qt.point(card.width / 2, card.height / 2)
                    Drag.imageSource: cardDragImageSource

                    property string cardDragImageSource: delegateRoot.model.isImage ? delegateRoot.model.filePath : ""

                    function refreshDragSnapshot() {
                        if (!card || card.width <= 0 || card.height <= 0) return
                        card.grabToImage(function(result) {
                            if (result && result.url) {
                                cardDragImageSource = result.url
                            }
                        }, Qt.size(card.width, card.height))
                    }

                    Component.onCompleted: {
                        Qt.callLater(card.refreshDragSnapshot)
                    }

                    // Spring Lift & Press Animations
                    scale: dragArea.drag.active ? 0.94 : (dragArea.containsPress ? 0.98 : (dragArea.containsMouse ? 1.01 : 1.0))
                    opacity: dragArea.drag.active ? 0.4 : 1.0
                    color: dragArea.drag.active
                        ? Theme.withAlpha(Theme.accent, 0.32)
                        : (dragArea.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.38) : Theme.withAlpha(Theme.dark_background, 0.90))
                    border.width: dragArea.drag.active ? 1 : 0
                    border.color: Theme.accent

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.width { NumberAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    // Snap-back animation when released
                    Behavior on x {
                        enabled: !dragArea.drag.active
                        NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                    }
                    Behavior on y {
                        enabled: !dragArea.drag.active
                        NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                    }

                    // Drag MouseArea on the card
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : (dragArea.containsMouse ? Qt.OpenHandCursor : Qt.ArrowCursor)
                        drag.target: card
                        drag.axis: Drag.XAndYAxis

                        onPressed: {
                            if (!card.cardDragImageSource) {
                                card.refreshDragSnapshot()
                            }
                        }

                        onReleased: {
                            card.x = 0
                            card.y = 0
                            root.isDraggingItem = false
                        }
                        onCanceled: {
                            card.x = 0
                            card.y = 0
                            root.isDraggingItem = false
                        }
                    }

                    // Category Color Indicator Pill (Left Edge)
                    Rectangle {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 5
                        }
                        width: 3
                        height: 32
                        radius: 1.5
                        color: root.categoryColor(delegateRoot.model.fileCategory)
                        opacity: dragArea.drag.active ? 1.0 : (dragArea.containsMouse ? 0.95 : 0.75)

                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        spacing: 10

                        // Thumbnail / Icon Box (48x48)
                        Item {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
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

                                onStatusChanged: {
                                    if (status === Image.Ready) {
                                        Qt.callLater(card.refreshDragSnapshot)
                                    }
                                }

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
                                    font.pixelSize: 22
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
                                onClicked: {
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
                    return root.shelfService.count + (root.shelfService.count === 1 ? " file staged" : " files staged")
                }
                font.family: root.fontFamily
                font.pixelSize: 11
                color: Theme.muted
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root.shelfService ? root.shelfService.count > 0 : false
                text: "Drag card to export"
                font.family: root.fontFamily
                font.pixelSize: 11
                color: Theme.withAlpha(Theme.accent, 0.85)
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
