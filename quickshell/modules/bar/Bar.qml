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

    // Panel anchors: top attached, centered horizontally (compact notch design)
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

    readonly property real totalContentWidth: leftSection.width + clockWidget.width + rightSection.width + (Appearance.barSectionSpacing * 4)

    implicitHeight: Appearance.barHeight
    implicitWidth: Math.round(root.totalContentWidth + (Appearance.barMarginHorizontal * 2))

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
    }

    // Widget content container
    Item {
        id: barContainer
        anchors.fill: parent

        // Left section: workspace switcher and media pill
        Row {
            id: leftSection
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.barSectionSpacing
            width: implicitWidth
            height: implicitHeight
            x: Appearance.barMarginHorizontal

            WorkspacesWidget {
                service: root.workspacesService
            }

            NowBarPill {
                audioService: root.audioService
            }
        }

        // Center section: date and clock
        ClockWidget {
            id: clockWidget
            anchors.verticalCenter: parent.verticalCenter
            x: leftSection.x + leftSection.width + (Appearance.barSectionSpacing * 2)
            powerService: root.powerService
        }

        // Right section: hardware and status controls
        Row {
            id: rightSection
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.barSpacing
            width: implicitWidth
            height: implicitHeight
            x: clockWidget.x + clockWidget.width + (Appearance.barSectionSpacing * 2)

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

    // IPC handler for external popup toggles
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

        function getMode(): string {
            return "compact"
        }
    }
}
