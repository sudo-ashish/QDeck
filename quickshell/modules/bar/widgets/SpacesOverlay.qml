import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../../../theme"
import "."

// =============================================================================
// SpacesOverlay: Centered On-Screen Spaces Switcher HUD (Alt+Tab & CLI Trigger)
// =============================================================================
PanelWindow {
    id: root

    property bool isOpen: false
    property real animProgress: 0.0

    // Match focused monitor dynamically
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

    // Keep surface mapped while opening or during close fade-out
    visible: root.isOpen || closeAnim.running

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.namespace: "quickshell-spaces"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!root.isOpen || closeAnim.running) return WlrKeyboardFocus.None
        return WlrKeyboardFocus.OnDemand
    }
    exclusionMode: ExclusionMode.Ignore

    // ─────────────────────────────────────────────────────────────────────────
    // Animation Controllers
    // ─────────────────────────────────────────────────────────────────────────
    NumberAnimation {
        id: openAnim
        target: root
        property: "animProgress"
        to: 1.0
        duration: 220
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "animProgress"
        to: 0.0
        duration: 160
        easing.type: Easing.InCubic
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Auto-Dismiss Timer
    // ─────────────────────────────────────────────────────────────────────────
    Timer {
        id: autoHideTimer
        interval: 3500
        repeat: false
        onTriggered: {
            root.close()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public Trigger API
    // ─────────────────────────────────────────────────────────────────────────
    function open(): string {
        root.isOpen = true
        closeAnim.stop()
        openAnim.restart()
        autoHideTimer.restart()
        return "open"
    }

    function close(): string {
        root.isOpen = false
        autoHideTimer.stop()
        openAnim.stop()
        closeAnim.restart()
        return "closed"
    }

    function toggle(): string {
        if (root.isOpen) {
            // Already open: cycle to next window/workspace and keep active
            return root.next()
        } else {
            return root.open()
        }
    }

    function next(): string {
        if (!root.isOpen) {
            root.open()
        }
        autoHideTimer.restart()
        spacesCore.cycleNext()
        return "next"
    }

    function prev(): string {
        if (!root.isOpen) {
            root.open()
        }
        autoHideTimer.restart()
        spacesCore.cyclePrev()
        return "prev"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Modal Dimming Backdrop (Click outside dismisses)
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.40 * root.animProgress)
        opacity: root.animProgress

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
                root.close()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Centered Spaces HUD Card
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: hudCard
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30

        implicitWidth: cardContent.implicitWidth + 36
        implicitHeight: cardContent.implicitHeight + 28
        width: implicitWidth
        height: implicitHeight

        radius: Appearance.barRadius > 0 ? Appearance.barRadius + 4 : 20
        color: Theme.withAlpha(Theme.dark_background, 0.94)
        border.color: Theme.selection
        border.width: Appearance.barBorder ? Appearance.borderWidthThin : 1
        antialiasing: true

        opacity: root.animProgress
        scale: 0.94 + (0.06 * root.animProgress)

        // Reset autoHideTimer whenever user moves mouse over the card
        HoverHandler {
            onHoveredChanged: {
                if (hovered) autoHideTimer.restart()
            }
        }

        Column {
            id: cardContent
            anchors.centerIn: parent
            spacing: 12

            // Top Header: Subtle indicator
            Row {
                id: headerRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                opacity: 0.60

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󱂬"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SPACES"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.5
                }
            }

            // Embedded Spaces Widget
            SpacesWidget {
                id: spacesCore
                anchors.horizontalCenter: parent.horizontalCenter

                pillHeight: 34
                pillRadius: 17
                pillPadding: 12
                iconSize: 20
                iconSpacing: 6
                spacing: 8

                onWorkspaceSelected: function(id) {
                    root.close()
                }

                onWindowSelected: function(address) {
                    root.close()
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Keyboard Handler
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        focus: root.isOpen

        Keys.onEscapePressed: {
            root.close()
        }

        Keys.onTabPressed: (event) => {
            event.accepted = true
            root.next()
        }

        Keys.onBacktabPressed: (event) => {
            event.accepted = true
            root.prev()
        }

        Keys.onRightPressed: {
            root.next()
        }

        Keys.onLeftPressed: {
            root.prev()
        }

        Keys.onReturnPressed: {
            root.close()
        }

        Keys.onSpacePressed: {
            root.close()
        }

        Keys.onDigit1Pressed: { spacesCore.switchToWorkspace(1); root.close() }
        Keys.onDigit2Pressed: { spacesCore.switchToWorkspace(2); root.close() }
        Keys.onDigit3Pressed: { spacesCore.switchToWorkspace(3); root.close() }
        Keys.onDigit4Pressed: { spacesCore.switchToWorkspace(4); root.close() }
        Keys.onDigit5Pressed: { spacesCore.switchToWorkspace(5); root.close() }
        Keys.onDigit6Pressed: { spacesCore.switchToWorkspace(6); root.close() }
        Keys.onDigit7Pressed: { spacesCore.switchToWorkspace(7); root.close() }
        Keys.onDigit8Pressed: { spacesCore.switchToWorkspace(8); root.close() }
        Keys.onDigit9Pressed: { spacesCore.switchToWorkspace(9); root.close() }
    }
}
