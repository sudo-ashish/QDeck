import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../../theme"
import "../../../components"
import "../../../services"

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
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 4
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: Theme.muted
                            opacity: parent.active ? 0.6 : 0.25
                        }
                    }

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
                                    id: connDevRow
                                    required property var modelData
                                    width: parent.width
                                    height: 48
                                    radius: 12
                                    color: Theme.secondaryContainer
                                    border.width: 0

                                    Item {
                                        id: cIcon
                                        width: 28
                                        height: 28
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰂱"
                                            font.family: Icons.effectiveFont("󰂱")
                                            font.pixelSize: 16
                                            color: Theme.accent
                                        }
                                    }

                                    // Disconnect Button (circular tonal pill)
                                    Rectangle {
                                        id: disBtn
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 28
                                        height: 28
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
                                            onClicked: root.service.disconnectDevice(connDevRow.modelData.mac)
                                        }
                                    }

                                    Column {
                                        anchors.left: cIcon.right
                                        anchors.leftMargin: 10
                                        anchors.right: disBtn.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1
                                        clip: true

                                        Text {
                                            width: parent.width
                                            text: connDevRow.modelData.name || connDevRow.modelData.mac
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: Theme.bright_foreground
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: connDevRow.modelData.battery || "Connected"
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 10
                                            color: Theme.accent
                                            elide: Text.ElideRight
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

                                    Item {
                                        id: pIcon
                                        width: 28
                                        height: 28
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰂯"
                                            font.family: Icons.effectiveFont("󰂯")
                                            font.pixelSize: 15
                                            color: isConnecting ? Theme.accent : Theme.muted
                                        }
                                    }

                                    // Right Action Buttons Row
                                    Row {
                                        id: pActions
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        // Connect M3 Pill Button
                                        Rectangle {
                                            id: connBtn
                                            width: pairedRow.isConnecting ? 84 : 64
                                            height: 28
                                            radius: 14
                                            color: pairedRow.isConnecting ? Theme.secondaryContainer : (cMouse.containsMouse ? Theme.accent : Theme.surfaceContainerHighest)
                                            border.width: 0
                                            anchors.verticalCenter: parent.verticalCenter

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
                                                onClicked: root.service.connectDevice(pairedRow.modelData.mac, true)
                                            }
                                        }

                                        // Forget circular tonal button
                                        Rectangle {
                                            id: forgetBtn
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: forgetMouse.containsMouse ? Theme.withAlpha(Theme.red, 0.20) : "transparent"
                                            border.width: 0
                                            anchors.verticalCenter: parent.verticalCenter

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
                                                onClicked: root.service.forgetDevice(pairedRow.modelData.mac)
                                            }
                                        }
                                    }

                                    // Center text container strictly bounded between icon and action buttons
                                    Column {
                                        anchors.left: pIcon.right
                                        anchors.leftMargin: 10
                                        anchors.right: pActions.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1
                                        clip: true

                                        Text {
                                            width: parent.width
                                            text: pairedRow.modelData.name || pairedRow.modelData.mac
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: Theme.bright_foreground
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: pairedRow.isConnecting ? "Connecting..." : (pairedRow.hasError ? root.service.actionErrorMessage : "Offline")
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 10
                                            color: pairedRow.isConnecting ? Theme.accent : (pairedRow.hasError ? Theme.red : Theme.muted)
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: pMouse
                                        anchors.fill: parent
                                        anchors.rightMargin: pActions.width + 16
                                        enabled: !pairedRow.isConnecting
                                        hoverEnabled: true
                                        cursorShape: pairedRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: root.service.connectDevice(pairedRow.modelData.mac, true)
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

                                    Item {
                                        id: aIcon
                                        width: 28
                                        height: 28
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰂯"
                                            font.family: Icons.effectiveFont("󰂯")
                                            font.pixelSize: 15
                                            color: (availRow.isPairing || availRow.isConnecting) ? Theme.accent : Theme.muted
                                        }
                                    }

                                    // Pair/Connect M3 Pill Button
                                    Rectangle {
                                        id: pairBtn
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: (availRow.isPairing || availRow.isConnecting) ? 80 : 60
                                        height: 28
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
                                            onClicked: root.service.pairDevice(availRow.modelData.mac)
                                        }
                                    }

                                    // Center text container strictly bounded between icon and action button
                                    Column {
                                        anchors.left: aIcon.right
                                        anchors.leftMargin: 10
                                        anchors.right: pairBtn.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1
                                        clip: true

                                        Text {
                                            width: parent.width
                                            text: availRow.modelData.name || availRow.modelData.mac
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 12
                                            color: Theme.bright_foreground
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: availRow.isPairing || availRow.isConnecting || availRow.hasError
                                            width: parent.width
                                            text: availRow.isPairing ? "Pairing..." : (availRow.isConnecting ? "Connecting..." : (availRow.hasError ? root.service.actionErrorMessage : ""))
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 9
                                            color: (availRow.isPairing || availRow.isConnecting) ? Theme.accent : Theme.red
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: aMouse
                                        anchors.fill: parent
                                        anchors.rightMargin: pairBtn.width + 16
                                        enabled: !availRow.isPairing && !availRow.isConnecting
                                        hoverEnabled: true
                                        cursorShape: (availRow.isPairing || availRow.isConnecting) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: root.service.pairDevice(availRow.modelData.mac)
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
