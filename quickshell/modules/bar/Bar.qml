import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../theme"
import "../../services"
import "widgets"
import "../../components"

PanelWindow {
    id: root

    visible: Appearance.barVisible

    required property WorkspacesService workspacesService
    required property AudioService audioService
    required property BrightnessService brightnessService
    required property BatteryService batteryService
    required property NetworkService networkService
    required property BluetoothService bluetoothService
    required property PowerService powerService

    // Bar layout mode configuration (compact, clock)
    property string barMode: "compact"
    readonly property bool isClockMode: barMode === "clock"

    // Configuration file watcher for bar layout mode
    property FileView barModeFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/bar-mode"
        watchChanges: true
        printErrors: false
        onLoaded: {
            var raw = String(text() || "").trim().toLowerCase()
            if (raw === "clock" || raw === "minimal" || raw === "peek" || raw === "clock-pill") {
                root.barMode = "clock"
            } else {
                root.barMode = "compact"
            }
        }
    }

    // Configuration file watcher for bar visibility
    property FileView barVisibilityFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/bar-visibility"
        watchChanges: true
        printErrors: false
        onLoaded: {
            var raw = String(text() || "").trim().toLowerCase()
            if (raw === "hidden" || raw === "false" || raw === "hide" || raw === "off") {
                Appearance.barVisible = false
            } else if (raw === "visible" || raw === "true" || raw === "show" || raw === "on") {
                Appearance.barVisible = true
            }
        }
    }

    // Panel anchors: top attached, centered horizontally (notch design)
    anchors {
        top: true
    }

    // Outer screen margins
    margins {
        left: Appearance.barMarginHorizontal
        right: Appearance.barMarginHorizontal
        top: 0
        bottom: 0
    }

    // Pointer hover tracking
    property bool isHovered: false

    Timer {
        id: unhoverTimer
        interval: 280
        repeat: false
        onTriggered: {
            if (!barHoverHandler.hovered) {
                root.isHovered = false
            }
        }
    }

    // Check if any popup is active
    readonly property bool anyPopupOpen: (clockWidget && clockWidget.popupOpen)
        || (nowBarPill && nowBarPill.popupOpen)
        || (audioWidget && audioWidget.popupOpen)
        || (batteryWidget && batteryWidget.popupOpen)
        || (bluetoothWidget && bluetoothWidget.popupOpen)
        || (monitorWidget && monitorWidget.popupOpen)
        || (networkWidget && networkWidget.popupOpen)

    // In clock mode, expand when hovered or when any popup is open
    readonly property bool isExpanded: !isClockMode || isHovered || anyPopupOpen

    readonly property real totalContentWidth: leftSection.width + clockWidget.width + rightSection.width + (Appearance.barSectionSpacing * 4)

    readonly property real collapsedWidth: Math.round(clockWidget.width + (Appearance.barMarginHorizontal * 2))
    readonly property real expandedWidth: Math.round(root.totalContentWidth + (Appearance.barMarginHorizontal * 2))

    implicitHeight: Appearance.barHeight
    implicitWidth: root.isExpanded ? root.expandedWidth : root.collapsedWidth

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Motion.short4
            easing.type: Easing.OutCubic
        }
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Auto

    // Unified background surface with rounded bottom corners (compact notch design)
    Rectangle {
        id: barBackground
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Appearance.barRadius > 0 ? Appearance.barRadius : 16
        bottomRightRadius: Appearance.barRadius > 0 ? Appearance.barRadius : 16
        color: Theme.withAlpha(Theme.background, Theme.baseOpacity)
        border.color: Appearance.barBorder ? Theme.selection : "transparent"
        border.width: Appearance.barBorder ? Appearance.borderWidthThin : 0

        HoverHandler {
            id: barHoverHandler
            onHoveredChanged: {
                if (hovered) {
                    unhoverTimer.stop()
                    root.isHovered = true
                } else {
                    unhoverTimer.restart()
                }
            }
        }
    }

    // Widget content container
    Item {
        id: barContainer
        anchors.fill: parent
        clip: true

        // Left section: workspace switcher and media pill
        Row {
            id: leftSection
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.barSectionSpacing
            width: implicitWidth
            height: implicitHeight
            x: Appearance.barMarginHorizontal
            visible: opacity > 0.01
            opacity: root.isExpanded ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: Motion.short3 }
            }

            WorkspacesWidget {
                service: root.workspacesService
            }

            NowBarPill {
                id: nowBarPill
                audioService: root.audioService
            }
        }

        // Center section: date and clock
        ClockWidget {
            id: clockWidget
            anchors.verticalCenter: parent.verticalCenter
            minimal: root.isClockMode && !root.isExpanded
            x: root.isExpanded
                ? (leftSection.x + leftSection.width + (Appearance.barSectionSpacing * 2))
                : Math.round((barContainer.width - width) / 2)
            powerService: root.powerService

            Behavior on x {
                NumberAnimation {
                    duration: Motion.short4
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Right section: hardware and status controls
        Row {
            id: rightSection
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.barSpacing
            width: implicitWidth
            height: implicitHeight
            x: clockWidget.x + clockWidget.width + (Appearance.barSectionSpacing * 2)
            visible: opacity > 0.01
            opacity: root.isExpanded ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: Motion.short3 }
            }

            BluetoothWidget {
                id: bluetoothWidget
                service: root.bluetoothService
            }

            NetworkWidget {
                id: networkWidget
                service: root.networkService
            }

            AudioWidget {
                id: audioWidget
                service: root.audioService
            }

            MonitorWidget {
                id: monitorWidget
                service: root.brightnessService
            }

            BatteryWidget {
                id: batteryWidget
                batteryService: root.batteryService
                powerService: root.powerService
            }
        }
    }

    // IPC handler for external popup toggles and bar mode control
    IpcHandler {
        target: "barpopups"

        function toggle(name: string): string {
            if (name === "clock") clockWidget.toggle()
            else if (name === "monitor") monitorWidget.toggle()
            else if (name === "battery") batteryWidget.toggle()
            else if (name === "network") networkWidget.toggle()
            else if (name === "audio") audioWidget.toggle()
            else if (name === "bluetooth") bluetoothWidget.toggle()
            return "ok"
        }

        function setMode(newMode: string): string {
            var m = String(newMode || "").trim().toLowerCase()
            if (m === "clock" || m === "minimal" || m === "peek" || m === "clock-pill") {
                root.barMode = "clock"
                return "ok: clock"
            } else if (m === "compact" || m === "normal" || m === "full") {
                root.barMode = "compact"
                return "ok: compact"
            }
            return "error: unknown mode"
        }

        function getMode(): string {
            return root.barMode
        }

        function toggleMode(): string {
            root.barMode = (root.barMode === "clock") ? "compact" : "clock"
            return "ok: " + root.barMode
        }
    }
}
