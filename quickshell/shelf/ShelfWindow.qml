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

        color: Theme.withAlpha(Theme.darker_background, Theme.baseOpacity)
        border.color: dropArea.containsDrag
            ? Theme.accent
            : Theme.withAlpha(Theme.border, 0.28)
        border.width: dropArea.containsDrag ? 2 : 1
        clip: true

        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on border.width { NumberAnimation { duration: 150 } }

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
                    color: Theme.withAlpha(Theme.accent, 0.22)
                    border.color: Theme.withAlpha(Theme.accent, 0.5)
                    border.width: 1
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
                    ? Theme.withAlpha(Theme.urgent, 0.22)
                    : Theme.withAlpha(Theme.lighter_background, 0.25)
                border.color: clearMouse.containsMouse
                    ? Theme.withAlpha(Theme.urgent, 0.6)
                    : Theme.withAlpha(Theme.border, 0.2)
                border.width: 1
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

                width: listView.width
                height: 60

                // Invisible drag proxy for outbound Wayland dragging
                Item {
                    id: dragProxy
                    width: 60
                    height: 60
                    visible: false

                    Drag.active: dragArea.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: ({ "text/uri-list": delegateRoot.model.filePath + "\r\n" })
                    Drag.hotSpot.x: 30
                    Drag.hotSpot.y: 30
                }

                // Visual Card
                Rectangle {
                    id: cardVisual
                    anchors.fill: parent
                    radius: Appearance.launcherItemRadius
                    color: dragArea.drag.active
                        ? Theme.withAlpha(Theme.accent, 0.28)
                        : (dragArea.containsMouse ? Theme.withAlpha(Theme.lighter_background, 0.38) : Theme.withAlpha(Theme.dark_background, 0.75))
                    border.color: dragArea.drag.active
                        ? Theme.accent
                        : (dragArea.containsMouse ? Theme.withAlpha(Theme.accent, 0.45) : Theme.withAlpha(Theme.border, 0.22))
                    border.width: dragArea.drag.active ? 2 : 1
                    scale: dragArea.drag.active ? 0.96 : (dragArea.containsMouse ? 1.01 : 1.0)

                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
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

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: thumbMask
                                }
                            }

                            // Non-image Icon Tile
                            Rectangle {
                                visible: !delegateRoot.model.isImage || thumbImg.status === Image.Error
                                anchors.fill: parent
                                radius: 8
                                color: Theme.withAlpha(Theme.lighter_background, 0.45)
                                border.color: Theme.withAlpha(Theme.border, 0.2)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: delegateRoot.model.fileIcon || Icons.folder
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 22
                                    color: Theme.accent
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
                            z: 2
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

                // Drag MouseArea on the card
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: dragProxy
                    drag.axis: Drag.XAndYAxis

                    onReleased: {
                        dragProxy.x = 0
                        dragProxy.y = 0
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
            visible: (root.shelfService ? root.shelfService.count === 0 : true) && !dropArea.containsDrag

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64
                height: 64
                radius: 32
                color: Theme.withAlpha(Theme.lighter_background, 0.3)
                border.color: Theme.withAlpha(Theme.border, 0.2)
                border.width: 1

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
        // Inbound Drag Active Overlay
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
            visible: dropArea.containsDrag
            color: Theme.withAlpha(Theme.accent, 0.15)
            border.color: Theme.accent
            border.width: 2

            Column {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Icons.folder
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: 36
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
