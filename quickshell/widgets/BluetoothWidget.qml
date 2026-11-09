import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../theme"
import "../components"
import "../services"

Item {
    id: root

    required property BluetoothService service

    property int iconSize: Appearance.bluetoothIconSize

    implicitWidth: btButton.implicitWidth
    implicitHeight: btButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    function toggle() {
        btPopup.toggle()
        if (btPopup.open) {
            root.service.refresh()
            if (root.service.bluetoothEnabled) root.service.scan()
        }
    }

    BarButton {
        id: btButton
        icon: root.service.icon
        iconSize: root.iconSize
        accentActive: root.service.connectedDevices.length > 0
        customColor: root.service.bluetoothEnabled ? (root.service.connectedDevices.length > 0 ? Theme.accent : Theme.foreground) : Theme.muted
        active: btPopup.open
        onClicked: {
            btPopup.toggle()
            if (btPopup.open) {
                root.service.refresh()
                if (root.service.bluetoothEnabled) {
                    root.service.scan()
                }
            }
        }
    }

    Connections {
        target: root.service
        function onRequestToggleMenu() {
            btPopup.toggle()
            if (btPopup.open) {
                root.service.refresh()
                if (root.service.bluetoothEnabled) {
                    root.service.scan()
                }
            }
        }
    }

    PopupCard {
        id: btPopup
        anchorItem: btButton
        showDefaultHeader: false
        contentWidth: 340
        contentHeight: {
            if (!root.service.bluetoothEnabled) return 124
            var listH = Math.min(320, btScrollCol.implicitHeight)
            return Math.max(130, listH + 84)
        }

        Binding {
            target: root.service
            property: "menuOpen"
            value: btPopup.open
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            // ── Standardized M3 Header ────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // 40x40 Tonal Squircle Container
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 12
                        color: Theme.secondaryContainer
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: root.service.connectedDevices.length > 0 ? "󰂱" : (root.service.bluetoothEnabled ? "󰂯" : "󰂲")
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 22
                            color: root.service.bluetoothEnabled ? Theme.accent : Theme.muted
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Bluetooth"
                            font.family: Fonts.uiFont
                            font.pixelSize: 15
                            font.bold: true
                            color: Theme.bright_foreground
                        }

                        Text {
                            text: (root.service.heroSubtitle || "RADIO ON").toUpperCase()
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                            color: Theme.muted
                            opacity: 0.75
                        }
                    }
                }

                ToggleSwitch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.service.bluetoothEnabled
                    onToggled: root.service.togglePower()
                }
            }

            // ── Bluetooth Turned Off Message ──────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.service.bluetoothEnabled
                height: 48

                Text {
                    anchors.centerIn: parent
                    text: "Turn Bluetooth on to scan"
                    font.family: Fonts.uiFont
                    font.pixelSize: 11
                    color: Theme.muted
                }
            }

            // ── Enabled Content Container ─────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Math.min(320, btScrollCol.implicitHeight)
                visible: root.service.bluetoothEnabled

                ScrollView {
                    anchors.fill: parent
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    Column {
                        id: btScrollCol
                        width: parent.width
                        spacing: 10

                        // ── Connected Devices Section ─────────────────
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.service.connectedDevices.length > 0

                            Text {
                                text: "CONNECTED"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.muted
                            }

                            Repeater {
                                model: root.service.connectedDevices

                                delegate: Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 48
                                    radius: 12
                                    color: Theme.secondaryContainer
                                    border.width: 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Item {
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            Layout.alignment: Qt.AlignVCenter

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰂱"
                                                font.family: Icons.effectiveFont("󰂱")
                                                font.pixelSize: 16
                                                color: Theme.accent
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 1

                                            Text {
                                                text: modelData.name || modelData.mac
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Theme.bright_foreground
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.battery || "Connected"
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 10
                                                color: Theme.accent
                                            }
                                        }

                                        // Disconnect Button (circular tonal pill)
                                        Rectangle {
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 14
                                            color: disMouse.containsMouse ? Theme.withAlpha(Theme.red, 0.20) : Theme.surfaceContainerHighest
                                            border.width: 0

                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰅙"
                                                font.family: Icons.effectiveFont("󰅙")
                                                font.pixelSize: 13
                                                color: disMouse.containsMouse ? Theme.red : Theme.muted
                                            }

                                            MouseArea {
                                                id: disMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.service.disconnectDevice(modelData.mac)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Saved Devices Section ────────────────────
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.service.pairedDevices.length > 0

                            Text {
                                text: "SAVED DEVICES"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.muted
                            }

                            Repeater {
                                model: root.service.pairedDevices

                                delegate: Rectangle {
                                    id: pairedRow
                                    required property var modelData
                                    readonly property bool isConnecting: root.service.connectingMac === modelData.mac
                                    readonly property bool hasError: root.service.actionErrorMac === modelData.mac

                                    width: parent.width
                                    height: 44
                                    radius: 12
                                    color: isConnecting ? Theme.secondaryContainer : (pMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                                    border.width: 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Item {
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            Layout.alignment: Qt.AlignVCenter

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰂯"
                                                font.family: Icons.effectiveFont("󰂯")
                                                font.pixelSize: 15
                                                color: isConnecting ? Theme.accent : Theme.muted
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 1

                                            Text {
                                                text: modelData.name || modelData.mac
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Theme.bright_foreground
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: pairedRow.isConnecting ? "Connecting..." : (pairedRow.hasError ? root.service.actionErrorMessage : "Offline")
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 10
                                                color: pairedRow.isConnecting ? Theme.accent : (pairedRow.hasError ? Theme.red : Theme.muted)
                                            }
                                        }

                                        // Connect M3 Pill Button
                                        Rectangle {
                                            id: connBtn
                                            Layout.preferredWidth: pairedRow.isConnecting ? 80 : 64
                                            Layout.preferredHeight: 28
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 14
                                            color: pairedRow.isConnecting ? Theme.secondaryContainer : (cMouse.containsMouse ? Theme.accent : Theme.surfaceContainerHighest)
                                            border.width: 0

                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: pairedRow.isConnecting ? "Connecting…" : "Connect"
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: pairedRow.isConnecting ? Theme.accent : (cMouse.containsMouse ? Theme.darker_background : Theme.bright_foreground)
                                            }

                                            MouseArea {
                                                id: cMouse
                                                anchors.fill: parent
                                                enabled: !pairedRow.isConnecting
                                                hoverEnabled: true
                                                cursorShape: pairedRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                onClicked: root.service.connectDevice(modelData.mac, true)
                                            }
                                        }

                                        // Forget circular tonal button
                                        Rectangle {
                                            id: forgetBtn
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 14
                                            color: forgetMouse.containsMouse ? Theme.withAlpha(Theme.red, 0.20) : "transparent"
                                            border.width: 0

                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰅙"
                                                font.family: Icons.effectiveFont("󰅙")
                                                font.pixelSize: 13
                                                color: forgetMouse.containsMouse ? Theme.red : Theme.muted
                                            }

                                            MouseArea {
                                                id: forgetMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.service.forgetDevice(modelData.mac)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: pMouse
                                        anchors.fill: parent
                                        anchors.rightMargin: pairedRow.isConnecting ? 120 : 105
                                        enabled: !pairedRow.isConnecting
                                        hoverEnabled: true
                                        cursorShape: pairedRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: root.service.connectDevice(modelData.mac, true)
                                    }
                                }
                            }
                        }

                        // ── Available Devices Section ─────────────────
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.service.availableDevices.length > 0

                            Text {
                                text: "AVAILABLE DEVICES"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.muted
                            }

                            Repeater {
                                model: root.service.availableDevices

                                delegate: Rectangle {
                                    id: availRow
                                    required property var modelData
                                    readonly property bool isPairing: root.service.pairingMac === modelData.mac
                                    readonly property bool isConnecting: root.service.connectingMac === modelData.mac
                                    readonly property bool hasError: root.service.actionErrorMac === modelData.mac

                                    width: parent.width
                                    height: (isPairing || isConnecting || hasError) ? 44 : 38
                                    radius: 12
                                    color: (isPairing || isConnecting) ? Theme.secondaryContainer : (aMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                                    border.width: 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Item {
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            Layout.alignment: Qt.AlignVCenter

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰂯"
                                                font.family: Icons.effectiveFont("󰂯")
                                                font.pixelSize: 15
                                                color: (isPairing || isConnecting) ? Theme.accent : Theme.muted
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 1

                                            Text {
                                                text: modelData.name || modelData.mac
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 12
                                                color: Theme.bright_foreground
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                visible: availRow.isPairing || availRow.isConnecting || availRow.hasError
                                                text: availRow.isPairing ? "Pairing..." : (availRow.isConnecting ? "Connecting..." : (availRow.hasError ? root.service.actionErrorMessage : ""))
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 9
                                                color: (availRow.isPairing || availRow.isConnecting) ? Theme.accent : Theme.red
                                            }
                                        }

                                        // Pair/Connect M3 Pill Button
                                        Rectangle {
                                            Layout.preferredWidth: (availRow.isPairing || availRow.isConnecting) ? 80 : 60
                                            Layout.preferredHeight: 28
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 14
                                            color: (availRow.isPairing || availRow.isConnecting) ? Theme.secondaryContainer : (pairMouse.containsMouse ? Theme.accent : Theme.surfaceContainerHighest)
                                            border.width: 0

                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: availRow.isPairing ? "Pairing…" : (availRow.isConnecting ? "Connecting…" : "Pair")
                                                font.family: Fonts.uiFont
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: (availRow.isPairing || availRow.isConnecting) ? Theme.accent : (pairMouse.containsMouse ? Theme.darker_background : Theme.bright_foreground)
                                            }

                                            MouseArea {
                                                id: pairMouse
                                                anchors.fill: parent
                                                enabled: !availRow.isPairing && !availRow.isConnecting
                                                hoverEnabled: true
                                                cursorShape: (availRow.isPairing || availRow.isConnecting) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                onClicked: root.service.pairDevice(modelData.mac)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: aMouse
                                        anchors.fill: parent
                                        anchors.rightMargin: (availRow.isPairing || availRow.isConnecting) ? 90 : 70
                                        enabled: !availRow.isPairing && !availRow.isConnecting
                                        hoverEnabled: true
                                        cursorShape: (availRow.isPairing || availRow.isConnecting) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: root.service.pairDevice(modelData.mac)
                                    }
                                }
                            }
                        }

                        // Empty Scanning State
                        Item {
                            width: parent.width
                            height: 40
                            visible: root.service.connectedDevices.length === 0 && root.service.pairedDevices.length === 0 && root.service.availableDevices.length === 0

                            Text {
                                anchors.centerIn: parent
                                text: "Scanning for devices…"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                color: Theme.dark_foreground
                            }
                        }
                    }
                }
            }
        }
    }
}
