import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../components"
import "../../../services"

Item {
    id: root

    required property BatteryService batteryService
    required property PowerService powerService
    readonly property bool popupOpen: batPopup.open

    property bool showPercentage: true
    property int iconSize: Appearance.batteryIconSize

    readonly property color batteryColor: {
        if (root.batteryService.isCharging) return Theme.accent
        if (root.batteryService.capacity <= 20) return Theme.red
        if (root.batteryService.capacity <= 40) return Theme.yellow
        if (batPopup.open) return Theme.accent
        return Theme.foreground
    }

    Component {
        id: batteryIconWithPercentage

        Item {
            implicitWidth: batteryBody.width + 1 + batteryNub.width
            implicitHeight: batteryBody.height
            width: implicitWidth
            height: implicitHeight

            // Battery frame
            Rectangle {
                id: batteryBody
                width: root.batteryService.isCharging ? (root.batteryService.capacity >= 100 ? 36 : 34) : (root.batteryService.capacity >= 100 ? 33 : 31)
                height: 15
                radius: 4
                color: "transparent"
                border.color: root.batteryColor
                border.width: 1.5
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                // Charge fill bar
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: Math.max(0, Math.min(parent.width - 4, (parent.width - 4) * (root.batteryService.capacity / 100.0)))
                    radius: 2
                    color: Theme.withAlpha(root.batteryColor, 0.28)
                }

                // Centered percentage + charging bolt inside the battery icon
                Row {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        visible: root.batteryService.isCharging
                        text: "󱐋"
                        font.family: Icons.iconFont
                        font.pixelSize: 8
                        color: root.batteryColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.batteryService.capacity + "%"
                        font.family: Fonts.monoFont
                        font.pixelSize: (root.batteryService.isCharging && root.batteryService.capacity >= 100) ? 7 : 8
                        font.bold: true
                        color: Theme.bright_foreground
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Battery positive terminal nub
            Rectangle {
                id: batteryNub
                anchors.left: batteryBody.right
                anchors.leftMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 6
                radius: 1
                color: root.batteryColor
            }
        }
    }

    implicitWidth: batButton.implicitWidth
    implicitHeight: batButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    BarButton {
        id: batButton
        customContent: batteryIconWithPercentage
        customPadding: 4
        active: batPopup.open
        onClicked: {
            root.toggle()
        }
    }

    function toggle() {
        batPopup.toggle()
        if (batPopup.open) root.batteryService.refresh()
    }

    PopupCard {
        id: batPopup
        anchorItem: batButton
        showDefaultHeader: false
        contentWidth: 360
        contentHeight: batCol.implicitHeight + 30

        Column {
            id: batCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 12

            // ================= 1. STANDARDIZED M3 HEADER =================
            Item {
                width: parent.width
                height: 40

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
                            text: root.batteryService.icon
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 22
                            color: {
                                if (root.batteryService.isCharging) return Theme.accent
                                if (root.batteryService.capacity <= 20) return Theme.red
                                if (root.batteryService.capacity <= 40) return Theme.yellow
                                return Theme.accent
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Battery"
                            font.family: Fonts.uiFont
                            font.pixelSize: 15
                            font.bold: true
                            color: Theme.bright_foreground
                        }

                        Text {
                            text: root.batteryService.isCharging ? "PARTY MODE" : (root.batteryService.statusDisplay ? root.batteryService.statusDisplay.toUpperCase() : "BATTERY")
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                            color: root.batteryService.isCharging ? Theme.accent : Theme.muted
                            opacity: 0.85
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryService.capacity + "%"
                    font.family: Fonts.monoFont
                    font.pixelSize: 26
                    font.bold: true
                    color: Theme.bright_foreground
                }
            }

            // ================= 2. SLIM M3 CAPSULE PROGRESS BAR =================
            Rectangle {
                width: parent.width
                height: 8
                radius: 4
                color: Theme.surfaceContainerHigh
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(8, Math.min(parent.width, parent.width * (root.batteryService.capacity / 100.0)))
                    radius: 4
                    color: {
                        if (root.batteryService.capacity <= 20) return Theme.red
                        if (root.batteryService.capacity <= 40) return Theme.yellow
                        if (root.batteryService.isCharging) return Theme.accent
                        return Theme.accent
                    }

                    Behavior on width {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }
            }

            // ================= 3. STATS 2-COLUMN TONAL BENTO CARDS =================
            Row {
                width: parent.width
                spacing: 8

                readonly property real cardW: (width - spacing) / 2

                // Left Mini-Card
                Rectangle {
                    width: parent.cardW
                    height: 58
                    radius: 10
                    color: Theme.surfaceContainer

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 16

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Battery size"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                color: Theme.muted
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.batteryService.batterySize
                                font.family: Fonts.monoFont
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.bright_foreground
                            }
                        }

                        Item {
                            width: parent.width
                            height: 16

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Charge cycles"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                color: Theme.muted
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.batteryService.cycleCount
                                font.family: Fonts.monoFont
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.bright_foreground
                            }
                        }
                    }
                }

                // Right Mini-Card
                Rectangle {
                    width: parent.cardW
                    height: 58
                    radius: 10
                    color: Theme.surfaceContainer

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 16

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.batteryService.timeLabel
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                color: Theme.muted
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.batteryService.timeToFull
                                font.family: Fonts.monoFont
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.bright_foreground
                            }
                        }

                        Item {
                            width: parent.width
                            height: 16

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Charging"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                color: Theme.muted
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.batteryService.chargingRate
                                font.family: Fonts.monoFont
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.bright_foreground
                            }
                        }
                    }
                }
            }

            // ================= 4. POWER PROFILES (M3 Segmented Button Row) =================
            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: "POWER PROFILE"
                    font.family: Fonts.uiFont
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1
                    color: Theme.muted
                }

                Row {
                    id: profRow
                    width: parent.width
                    spacing: 3

                    readonly property var profiles: [
                        { id: "power-saver", label: "Power-saver", icon: "󰌪" },
                        { id: "balanced", label: "Balanced", icon: "󰾆" },
                        { id: "performance", label: "Performance", icon: "󰓅" }
                    ]
                    readonly property real segWidth: (width - (spacing * 2)) / 3

                    Repeater {
                        model: profRow.profiles

                        Rectangle {
                            id: profBtn
                            required property var modelData
                            required property int index

                            readonly property bool isActive: root.powerService.activeProfile === modelData.id
                            readonly property bool isFirst: index === 0
                            readonly property bool isLast: index === 2

                            width: profRow.segWidth
                            height: 36

                            topLeftRadius: isActive ? 12 : (isFirst ? 12 : 4)
                            bottomLeftRadius: isActive ? 12 : (isFirst ? 12 : 4)
                            topRightRadius: isActive ? 12 : (isLast ? 12 : 4)
                            bottomRightRadius: isActive ? 12 : (isLast ? 12 : 4)

                            color: isActive ? Theme.secondaryContainer : (profMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on topLeftRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomLeftRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on topRightRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomRightRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: profBtn.modelData.icon
                                    font.family: Icons.effectiveFont(profBtn.modelData.icon)
                                    font.pixelSize: Fonts.sizeRegular
                                    color: profBtn.isActive ? Theme.accent : Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: profBtn.modelData.label
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 11
                                    font.bold: profBtn.isActive
                                    color: profBtn.isActive ? Theme.accent : Theme.foreground
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: profMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.powerService.setProfile(profBtn.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
