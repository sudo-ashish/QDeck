import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Wayland
import "../theme"
import "../components"
import "../services"

Item {
    id: root

    required property NetworkService service

    property string selectedSsid: ""
    property bool showPasswordInput: false
    property string passwordError: ""
    property bool showQrView: false
    property int iconSize: Appearance.networkIconSize
    readonly property bool hasNetworks: (root.service.knownNetworks.length > 0 || root.service.otherNetworks.length > 0)

    onSelectedSsidChanged: {
        pwInput.text = ""
        root.passwordError = ""
    }

    onShowPasswordInputChanged: {
        if (root.showPasswordInput) {
            Qt.callLater(function() {
                pwInput.forceActiveFocus()
            })
        } else {
            root.passwordError = ""
        }
    }

    Connections {
        target: root.service
        function onPasswordRequired(ssid, message) {
            root.selectedSsid = ssid
            root.passwordError = message || "Password required"
            root.showPasswordInput = true
            Qt.callLater(function() {
                pwInput.selectAll()
                pwInput.forceActiveFocus()
            })
        }
        function onConnectingSsidChanged() {
            if (root.service.connectingSsid === "" && root.service.connectionErrorSsid === "" && root.selectedSsid === root.service.currentSsid) {
                root.showPasswordInput = false
                root.passwordError = ""
                pwInput.text = ""
            }
        }
    }

    implicitWidth: netButton.implicitWidth
    implicitHeight: netButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    BarButton {
        id: netButton
        icon: root.service.icon
        iconSize: root.iconSize
        accentActive: root.service.wifiEnabled && root.service.currentSsid !== ""
        customColor: !root.service.wifiEnabled ? Theme.muted : ""
        active: netPopup.open
        onClicked: {
            root.toggle()
        }
    }

    function toggle() {
        netPopup.toggle()
    }

    PopupCard {
        id: netPopup
        anchorItem: netButton
        showDefaultHeader: false
        contentWidth: 360
        contentHeight: {
            if (!root.service.wifiEnabled && !root.showQrView) return 130
            if (root.showQrView) return 420
            var h = netMainCol.implicitHeight + 30
            return Math.max(134, Math.min(540, h))
        }
        keyboardFocus: root.showPasswordInput ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Binding {
            target: root.service
            property: "menuOpen"
            value: netPopup.open
        }

        Binding {
            target: root.service
            property: "isInputActive"
            value: root.showPasswordInput
        }

        onOpenChanged: {
            if (!open) {
                root.showPasswordInput = false
                root.passwordError = ""
                pwInput.text = ""
            } else {
                root.showPasswordInput = false
                root.passwordError = ""
                root.showQrView = false
                root.service.refresh()
                if (root.service.wifiEnabled) {
                    root.service.scanWifi()
                }
            }
        }

        Column {
            id: netMainCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 12

            // ================= 1. STANDARDIZED M3 HEADER =================
            Item {
                width: parent.width
                height: 40

                // Left: 40x40 Squircle + Title + Subtitle
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
                            text: !root.service.wifiEnabled ? Icons.wifiOff : root.service.icon
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 22
                            color: !root.service.wifiEnabled ? Theme.muted : Theme.accent
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: {
                                if (!root.service.wifiEnabled) return "Wi-Fi"
                                if (root.service.connectingSsid) return root.service.connectingSsid
                                return root.service.currentSsid || "Wi-Fi"
                            }
                            font.family: Fonts.uiFont
                            font.pixelSize: 15
                            font.bold: true
                            color: Theme.bright_foreground
                            elide: Text.ElideRight
                            width: 135
                        }

                        Text {
                            text: {
                                if (!root.service.wifiEnabled) return "TURNED OFF"
                                if (root.service.connectingSsid) return "CONNECTING..."
                                if (!root.service.currentSsid) return root.service.scanning ? "SEARCHING..." : "NOT CONNECTED"
                                return "ROUTING CRUMBS"
                            }
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                            color: (root.service.connectingSsid || (root.service.scanning && !root.service.currentSsid)) ? Theme.accent : Theme.muted
                            opacity: 0.75
                        }
                    }
                }

                // Right Actions: QR, Quick Disconnect, M3 Pill Toggle Switch
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Quick Disconnect Button (32x32 tonal squircle, zero border)
                    Rectangle {
                        visible: root.service.wifiEnabled && root.service.currentSsid !== ""
                        width: 32
                        height: 32
                        radius: 10
                        color: topDisMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰌙"
                            font.family: Icons.effectiveFont("󰌙")
                            font.pixelSize: 15
                            color: topDisMouse.containsMouse ? Theme.red : Theme.muted
                        }

                        MouseArea {
                            id: topDisMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.disconnectNetwork(root.service.currentSsid)
                        }
                    }

                    // QR Code Button (32x32 tonal squircle, zero border)
                    Rectangle {
                        visible: root.service.wifiEnabled && root.service.currentSsid !== "" && !root.showQrView
                        width: 32
                        height: 32
                        radius: 10
                        color: root.showQrView ? Theme.secondaryContainer : (qrMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰐲"
                            font.family: Icons.effectiveFont("󰐲")
                            font.pixelSize: 16
                            color: root.showQrView ? Theme.accent : Theme.bright_foreground
                        }

                        MouseArea {
                            id: qrMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.showQrView = !root.showQrView
                                if (root.showQrView) {
                                    root.service.generateQr()
                                }
                            }
                        }
                    }

                    // Wi-Fi On/Off M3 Pill Toggle Switch
                    ToggleSwitch {
                        id: wifiToggle
                        checked: root.service.wifiEnabled
                        onToggled: root.service.toggleWifi()
                    }
                }
            }

            // ================= QR CODE OVERLAY VIEW =================
            Item {
                visible: root.showQrView
                width: parent.width
                height: root.showQrView ? 340 : 0

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "Scan to Join Wi-Fi"
                        font.family: Fonts.uiFont
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.foreground
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // QR Matrix Canvas Container
                    Rectangle {
                        id: qrBox
                        width: 210
                        height: 210
                        color: Theme.bright_foreground
                        radius: Appearance.radiusSmall
                        anchors.horizontalCenter: parent.horizontalCenter

                        readonly property int size: root.service.qrSize > 0 ? root.service.qrSize : 1
                        readonly property real cellSize: size > 0 ? (width / size) : 0

                        Grid {
                            anchors.fill: parent
                            columns: qrBox.size

                            Repeater {
                                model: qrBox.size * qrBox.size

                                Rectangle {
                                    required property int index
                                    readonly property int r: Math.floor(index / qrBox.size)
                                    readonly property int c: index % qrBox.size

                                    width: qrBox.cellSize
                                    height: qrBox.cellSize
                                    color: (root.service.qrMatrix.length > r && root.service.qrMatrix[r].charAt(c) === "1") ? Theme.darker_background : "transparent"
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.service.qrLoading
                            text: "Generating QR..."
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            color: Theme.darker_background
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.service.qrLoading && root.service.qrSize === 0
                            text: root.service.qrError || "No QR available"
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            color: Theme.red
                        }
                    }

                    Text {
                        text: "SSID: " + root.service.currentSsid
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        color: Theme.muted
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Rectangle {
                        width: 80
                        height: 26
                        radius: Appearance.radiusSmall
                        color: Theme.dark_background
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "Close"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            color: Theme.foreground
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showQrView = false
                        }
                    }
                }
            }

            // ================= 2. WI-FI TURNED OFF MESSAGE =================
            Item {
                visible: !root.service.wifiEnabled && !root.showQrView
                width: parent.width
                height: 48

                Text {
                    anchors.centerIn: parent
                    text: "Turn Wi-Fi on to search networks"
                    font.family: Fonts.uiFont
                    font.pixelSize: 11
                    color: Theme.muted
                }
            }

            // ================= 3. MAIN NETWORK CONTENT =================
            Column {
                visible: root.service.wifiEnabled && !root.showQrView
                width: parent.width
                spacing: 12

                // --- 2. DNS PROVIDER Section (M3 Expressive Segmented Buttons) ---
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "DNS PROVIDER"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    Row {
                        id: dnsRow
                        width: parent.width
                        spacing: 3

                        readonly property int count: root.service.dnsProviders.length
                        readonly property real cellWidth: (width - (spacing * (count - 1))) / count

                        Repeater {
                            model: root.service.dnsProviders

                            Rectangle {
                                id: dnsPill
                                required property string modelData
                                required property int index

                                readonly property bool isActive: (root.service.dnsProvider === modelData)

                                width: dnsRow.cellWidth
                                height: 32
                                radius: isActive ? 12 : 6
                                color: isActive ? Theme.secondaryContainer : (dnsMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
                                border.width: 0

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: dnsPill.modelData
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    font.bold: dnsPill.isActive 
                                    color: dnsPill.isActive ? Theme.accent : (dnsMouse.containsMouse ? Theme.bright_foreground : Theme.muted)
                                }

                                MouseArea {
                                    id: dnsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.service.setDns(dnsPill.modelData)
                                }
                            }
                        }
                    }
                }

                // Empty / Scanning state when no networks are found
                Item {
                    visible: root.service.wifiEnabled && !root.hasNetworks && !root.showQrView
                    width: parent.width
                    height: 38
                    implicitHeight: 38

                    Text {
                        anchors.centerIn: parent
                        text: root.service.scanning ? "Searching for networks…" : "No networks in range"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        color: Theme.muted
                    }
                }

                // --- Password Input Overlay (if joining a secured network) ---
                Rectangle {
                    visible: root.showPasswordInput
                    width: parent.width
                    height: root.showPasswordInput ? (root.passwordError ? 94 : 76) : 0
                    radius: 12
                    color: Theme.surfaceContainer
                    border.width: 0

                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                text: "Connect to: " + root.selectedSsid
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.accent
                                elide: Text.ElideRight
                                width: root.passwordError ? (parent.width - errorLabel.implicitWidth - 12) : parent.width
                            }

                            Text {
                                id: errorLabel
                                visible: root.passwordError.length > 0
                                text: root.passwordError
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.bold: true
                                color: Theme.red
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: parent.width - 144
                                height: 28
                                radius: 8
                                color: Theme.surfaceContainerHigh
                                border.color: root.passwordError ? Theme.red : (pwInput.activeFocus ? Theme.accent : "transparent")
                                border.width: 1

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.IBeamCursor
                                    onClicked: pwInput.forceActiveFocus()
                                }

                                TextInput {
                                    id: pwInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: TextInput.Password
                                    font.family: Fonts.monoFont
                                    font.pixelSize: 11
                                    color: Theme.bright_foreground
                                    selectionColor: Theme.secondaryContainer
                                    selectedTextColor: Theme.bright_foreground
                                    cursorVisible: activeFocus
                                    activeFocusOnPress: true
                                    clip: true
                                    onAccepted: joinBtn.join()

                                    Keys.onPressed: function(event) {
                                        if (event.key === Qt.Key_Escape) {
                                            root.showPasswordInput = false
                                            root.passwordError = ""
                                            pwInput.text = ""
                                            event.accepted = true
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: joinBtn
                                readonly property bool isJoining: root.service.connectingSsid === root.selectedSsid
                                width: isJoining ? 76 : 64
                                height: 28
                                radius: 14
                                color: Theme.accent

                                function join() {
                                    if (joinBtn.isJoining) return
                                    root.passwordError = ""
                                    root.service.connectToNetwork(root.selectedSsid, pwInput.text)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: joinBtn.isJoining ? "Joining…" : "Join"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.darker_background
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !joinBtn.isJoining
                                    cursorShape: joinBtn.isJoining ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: joinBtn.join()
                                }
                            }

                            Rectangle {
                                width: 64
                                height: 28
                                radius: 14
                                color: cancelMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                border.width: 0

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    color: Theme.muted
                                }

                                MouseArea {
                                    id: cancelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.showPasswordInput = false
                                        root.passwordError = ""
                                        pwInput.text = ""
                                    }
                                }
                            }
                        }
                    }
                }

                // --- 3. KNOWN NETWORKS Section ---
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.service.wifiEnabled && root.service.knownNetworks.length > 0

                    Text {
                        text: "KNOWN NETWORKS"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    Repeater {
                        model: root.service.knownNetworks

                        Rectangle {
                            id: knownRow
                            required property var modelData
                            required property int index

                            readonly property bool isConnected: modelData.active
                            readonly property bool isSelected: root.selectedSsid === modelData.ssid
                            readonly property bool isConnecting: root.service.connectingSsid === modelData.ssid
                            readonly property bool hasError: root.service.connectionErrorSsid === modelData.ssid

                            width: parent.width
                            height: 44
                            radius: 12
                            color: isConnected ? Theme.secondaryContainer : (isSelected || isConnecting ? Theme.secondaryContainer : (kMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"))
                            border.width: 0

                            // Left Wi-Fi Signal Icon Container
                            Item {
                                id: kNetIcon
                                width: 28
                                height: 28
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: root.service.wifiIconFor(knownRow.modelData.signal)
                                    font.family: Icons.effectiveFont(text)
                                    font.pixelSize: 16
                                    color: (knownRow.isConnected || knownRow.isConnecting) ? Theme.accent : Theme.foreground
                                }
                            }

                            // Right Actions: Lock Icon + Connect/Disconnect + Forget
                            Row {
                                id: kNetActions
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                // Lock icon
                                Text {
                                    visible: knownRow.modelData.isSecured
                                    text: "󰌾"
                                    font.family: Icons.effectiveFont("󰌾")
                                    font.pixelSize: 12
                                    color: Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Connect / Disconnect M3 Pill Button
                                Rectangle {
                                    id: connBtn
                                    width: knownRow.isConnecting ? 84 : (knownRow.isConnected ? 76 : 64)
                                    height: 28
                                    radius: 14
                                    color: knownRow.isConnecting ? Theme.secondaryContainer : (knownRow.isConnected ? (connMouse.containsMouse ? Theme.withAlpha(Theme.red, 0.20) : Theme.surfaceContainerHighest) : (connMouse.containsMouse ? Theme.accent : Theme.surfaceContainerHighest))
                                    border.width: 0
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: knownRow.isConnecting ? "Connecting…" : (knownRow.isConnected ? "Disconnect" : "Connect")
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: knownRow.isConnecting ? Theme.accent : (knownRow.isConnected ? (connMouse.containsMouse ? Theme.red : Theme.bright_foreground) : (connMouse.containsMouse ? Theme.darker_background : Theme.bright_foreground))
                                    }

                                    MouseArea {
                                        id: connMouse
                                        anchors.fill: parent
                                        enabled: !knownRow.isConnecting
                                        hoverEnabled: true
                                        cursorShape: knownRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedSsid = knownRow.modelData.ssid
                                            if (knownRow.isConnected) {
                                                root.service.disconnectNetwork(knownRow.modelData.ssid)
                                            } else if (knownRow.hasError) {
                                                root.passwordError = root.service.connectionErrorMessage || "Password required"
                                                root.showPasswordInput = true
                                            } else {
                                                root.passwordError = ""
                                                root.service.connectToNetwork(knownRow.modelData.ssid, "")
                                            }
                                        }
                                    }
                                }

                                // Forget M3 Pill Button
                                Rectangle {
                                    id: fgtBtn
                                    width: 54
                                    height: 28
                                    radius: 14
                                    color: fgtMouse.containsMouse ? Theme.withAlpha(Theme.red, 0.20) : Theme.surfaceContainerHighest
                                    border.width: 0
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Forget"
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: fgtMouse.containsMouse ? Theme.red : Theme.muted
                                    }

                                    MouseArea {
                                        id: fgtMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedSsid = knownRow.modelData.ssid
                                            root.service.forgetNetwork(knownRow.modelData.ssid)
                                        }
                                    }
                                }
                            }

                            // Center text column strictly bounded between icon and action buttons
                            Column {
                                anchors.left: kNetIcon.right
                                anchors.leftMargin: 10
                                anchors.right: kNetActions.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                clip: true

                                Text {
                                    width: parent.width
                                    text: knownRow.modelData.ssid
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 12
                                    font.bold: knownRow.isConnected 
                                    color: Theme.bright_foreground
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: knownRow.isConnecting ? "Connecting..." : (knownRow.hasError ? root.service.connectionErrorMessage : (knownRow.isConnected ? "Connected" : "Saved"))
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 10
                                    color: knownRow.isConnecting ? Theme.accent : (knownRow.hasError ? Theme.red : (knownRow.isConnected ? Theme.accent : Theme.muted))
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: kMouse
                                anchors.fill: parent
                                anchors.rightMargin: kNetActions.width + 16
                                enabled: !knownRow.isConnecting
                                hoverEnabled: true
                                cursorShape: knownRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedSsid = knownRow.modelData.ssid
                                    if (!knownRow.isConnected) {
                                        if (knownRow.hasError) {
                                            root.passwordError = root.service.connectionErrorMessage || "Password required"
                                            root.showPasswordInput = true
                                        } else {
                                            root.passwordError = ""
                                            root.service.connectToNetwork(knownRow.modelData.ssid, "")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- 4. OTHER NETWORKS Section ---
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.service.otherNetworks.length > 0

                    Text {
                        text: "OTHER NETWORKS"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.muted
                    }

                    // Scrollable list for other networks
                    Rectangle {
                        id: otherScrollContainer
                        width: parent.width
                        height: Math.min(216, root.service.otherNetworks.length * 40)
                        implicitHeight: height
                        color: "transparent"
                        clip: true

                        ListView {
                            id: otherList
                            anchors.fill: parent
                            spacing: 4
                            model: root.service.otherNetworks
                            boundsBehavior: Flickable.StopAtBounds
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

                            delegate: Rectangle {
                                id: otherRow
                                required property var modelData
                                required property int index
                                readonly property bool isConnecting: root.service.connectingSsid === modelData.ssid
                                readonly property bool hasError: root.service.connectionErrorSsid === modelData.ssid

                                width: otherList.width
                                height: (isConnecting || hasError) ? 44 : 38
                                radius: 12
                                color: isConnecting ? Theme.secondaryContainer : (oMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                                border.width: 0

                                // Left Wi-Fi Signal Icon Container
                                Item {
                                    id: oNetIcon
                                    width: 28
                                    height: 28
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.service.wifiIconFor(otherRow.modelData.signal)
                                        font.family: Icons.effectiveFont(text)
                                        font.pixelSize: 16
                                        color: otherRow.isConnecting ? Theme.accent : Theme.foreground
                                    }
                                }

                                // Right Actions: Lock Icon + Connect Button
                                Row {
                                    id: oNetActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    // Lock icon
                                    Text {
                                        visible: otherRow.modelData.isSecured
                                        text: "󰌾"
                                        font.family: Icons.effectiveFont("󰌾")
                                        font.pixelSize: 12
                                        color: Theme.muted
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Connect M3 Pill Button
                                    Rectangle {
                                        id: oConnBtn
                                        width: otherRow.isConnecting ? 84 : 64
                                        height: 28
                                        radius: 14
                                        color: otherRow.isConnecting ? Theme.secondaryContainer : (oConnMouse.containsMouse ? Theme.accent : Theme.surfaceContainerHighest)
                                        border.width: 0
                                        anchors.verticalCenter: parent.verticalCenter

                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: otherRow.isConnecting ? "Connecting…" : "Connect"
                                            font.family: Fonts.uiFont
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: otherRow.isConnecting ? Theme.accent : (oConnMouse.containsMouse ? Theme.darker_background : Theme.bright_foreground)
                                        }

                                        MouseArea {
                                            id: oConnMouse
                                            anchors.fill: parent
                                            enabled: !otherRow.isConnecting
                                            hoverEnabled: true
                                            cursorShape: otherRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onClicked: {
                                                root.selectedSsid = otherRow.modelData.ssid
                                                if (otherRow.modelData.isSecured || otherRow.hasError) {
                                                    root.passwordError = otherRow.hasError ? (root.service.connectionErrorMessage || "Password required") : ""
                                                    root.showPasswordInput = true
                                                } else {
                                                    root.passwordError = ""
                                                    root.service.connectToNetwork(root.selectedSsid, "")
                                                }
                                            }
                                        }
                                    }
                                }

                                // Center text column strictly bounded between icon and action button
                                Column {
                                    anchors.left: oNetIcon.right
                                    anchors.leftMargin: 10
                                    anchors.right: oNetActions.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    clip: true

                                    Text {
                                        width: parent.width
                                        text: otherRow.modelData.ssid
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 12
                                        color: Theme.bright_foreground
                                        font.bold: otherRow.modelData.active 
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: otherRow.isConnecting || otherRow.hasError
                                        width: parent.width
                                        text: otherRow.isConnecting ? "Connecting..." : (otherRow.hasError ? root.service.connectionErrorMessage : "")
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 9
                                        color: otherRow.isConnecting ? Theme.accent : Theme.red
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: oMouse
                                    anchors.fill: parent
                                    anchors.rightMargin: oNetActions.width + 16
                                    enabled: !otherRow.isConnecting
                                    hoverEnabled: true
                                    cursorShape: otherRow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedSsid = otherRow.modelData.ssid
                                        if (otherRow.modelData.isSecured || otherRow.hasError) {
                                            root.passwordError = otherRow.hasError ? (root.service.connectionErrorMessage || "Password required") : ""
                                            root.showPasswordInput = true
                                        } else {
                                            root.passwordError = ""
                                            root.service.connectToNetwork(root.selectedSsid, "")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
