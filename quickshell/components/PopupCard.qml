import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"

PanelWindow {
    id: root

    required property Item anchorItem
    property string title: ""
    property string icon: ""
    property bool open: false
    property int contentWidth: 320
    property int contentHeight: 280
    property bool showDefaultHeader: true
    property double lastClearedTime: 0
    property int keyboardFocus: WlrKeyboardFocus.None

    function toggle() {
        if (Date.now() - root.lastClearedTime < 250) {
            root.open = false
            return
        }
        root.open = !root.open
    }

    default property alias content: bodyContainer.data

    visible: root.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    screen: (root.anchorItem && root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window.screen : null

    WlrLayershell.namespace: "quickshell-surface"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.open ? root.keyboardFocus : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    HyprlandFocusGrab {
        active: false
        windows: [root]
        onCleared: {
            root.lastClearedTime = Date.now()
            root.open = false
        }
    }

    // Dismiss when clicking outside the card
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.lastClearedTime = Date.now()
            root.open = false
        }
    }

    // Dismiss when pressing Escape key
    Shortcut {
        enabled: root.open
        sequence: "Escape"
        onActivated: {
            root.lastClearedTime = Date.now()
            root.open = false
        }
    }

    // Calculate card position relative to anchorItem across different bar modes
    readonly property real cardX: {
        var _ = root.open // reactively recompute whenever popup opens
        if (!root.anchorItem) return Appearance.popupMargin

        var win = (root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window : null
        var screenW = (win && win.screen) ? win.screen.width : root.width

        // Compute bar window X position on screen
        var barScreenX = 0
        if (win) {
            if (win.anchors && win.anchors.left) {
                barScreenX = (win.margins && win.margins.left) ? win.margins.left : 0
            } else {
                // Compositor horizontally centers unanchored windows (compact & wide modes)
                barScreenX = Math.round((screenW - win.width) / 2)
            }
        }

        var pt = root.anchorItem.mapToItem(null, 0, 0)
        var itemCenterScreenX = barScreenX + pt.x + (root.anchorItem.width / 2)
        var desiredX = itemCenterScreenX - (root.contentWidth / 2)

        var margin = Appearance.popupMargin
        var maxRight = screenW - root.contentWidth - margin
        return Math.max(margin, Math.min(desiredX, maxRight))
    }

    readonly property real cardY: {
        var _ = root.open // reactively recompute whenever popup opens
        if (!root.anchorItem) return Appearance.barHeight + 6

        var win = (root.anchorItem.QsWindow && root.anchorItem.QsWindow.window) ? root.anchorItem.QsWindow.window : null
        var barScreenY = 0
        if (win && win.margins && win.margins.top) {
            barScreenY = win.margins.top
        }

        var pt = root.anchorItem.mapToItem(null, 0, 0)
        var itemBottomScreenY = barScreenY + pt.y + root.anchorItem.height
        return Math.max(Appearance.barHeight + 6, itemBottomScreenY + 6)
    }

    property real enterProgress: root.open ? 1.0 : 0.0
    NumberAnimation {
        id: enterAnim
        target: root
        property: "enterProgress"
        from: 0.0
        to: 1.0
        duration: Motion.enterYDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.emphasizedDecelerateCurve
    }
    onOpenChanged: {
        if (root.open) {
            root.enterProgress = 0.0
            enterAnim.restart()
        }
    }

    // Outer Card Container
    Rectangle {
        id: cardRect
        x: Math.round(root.cardX)
        y: Math.round(root.cardY)
        width: root.contentWidth
        height: root.contentHeight
        color: Theme.surfaceBase
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        radius: 18

        // M3 Shared Axis Y + Z entrance
        opacity: root.enterProgress
        scale: Motion.enterZScaleStart + (1.0 - Motion.enterZScaleStart) * root.enterProgress
        transform: Translate {
            y: (1.0 - root.enterProgress) * -12
        }

        // M3 Container Transform on height
        Behavior on height {
            enabled: root.open
            NumberAnimation {
                duration: Motion.medium3
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.emphasizedCurve
            }
        }

        // Prevent clicks inside the card from closing the popup
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: function(mouse) { mouse.accepted = false }
        }

        // Card Header (Optional, default true)
        Item {
            id: headerRect
            visible: root.showDefaultHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.showDefaultHeader ? Appearance.popupHeaderHeight : 0

            // Bottom border of header
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Appearance.borderWidthThin
                color: Theme.selection
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.spacingLarge
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacingMedium

                Text {
                    visible: root.icon.length > 0
                    text: root.icon
                    font.family: Icons.effectiveFont(root.icon)
                    font.pixelSize: Fonts.sizeMedium
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.title
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.sizeMedium
                    font.weight: Fonts.weightBold
                    color: Theme.foreground
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Body Content Container
        Item {
            id: bodyContainer
            anchors.top: root.showDefaultHeader ? headerRect.bottom : parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.showDefaultHeader ? Appearance.paddingMedium : Appearance.popupPadding
            clip: true
        }
    }
}
