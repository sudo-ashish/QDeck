import QtQuick
import Quickshell
import "../../../theme"
import "../../../services"

Item {
    id: root

    required property SysmonService service

    implicitHeight: 90
    implicitWidth: 640

    // Hover index tracking for asymmetric spring flex expansion
    property int hoveredIndex: -1

    // Critical stress detection for dynamic threshold state-shifting
    readonly property bool cpuStressed: root.service && (root.service.cpuUsage >= 85 || root.service.cpuTemp >= 80)
    readonly property bool cpuWarning: root.service && (root.service.cpuUsage >= 65 || root.service.cpuTemp >= 70)

    readonly property bool ramStressed: root.service && root.service.ramPercent >= 90
    readonly property bool ramWarning: root.service && root.service.ramPercent >= 75

    readonly property bool diskStressed: root.service && root.service.storagePercent >= 90
    readonly property bool diskWarning: root.service && root.service.storagePercent >= 80

    readonly property bool netStressed: root.service && (root.service.netRxRate > 5242880 || root.service.netTxRate > 5242880) // > 5 MB/s

    // Primary semantic accent resolvers strictly mapped to Theme tokens
    readonly property color cpuAccent: cpuStressed ? Theme.red : (cpuWarning ? Theme.orange : Theme.blue)
    readonly property color ramAccent: ramStressed ? Theme.red : (ramWarning ? Theme.orange : Theme.magenta)
    readonly property color diskAccent: diskStressed ? Theme.red : (diskWarning ? Theme.orange : Theme.yellow)
    readonly property color netAccent: netStressed ? Theme.bright_green : Theme.green

    // Active stressed card index for auto-expansion when not hovered
    readonly property int stressedIndex: {
        if (cpuStressed) return 0
        if (ramStressed) return 1
        if (diskStressed) return 2
        if (netStressed) return 3
        return -1
    }

    readonly property int activeFlexIndex: root.hoveredIndex !== -1 ? root.hoveredIndex : root.stressedIndex

    readonly property int cardSpacing: 8

    Row {
        id: cardsRow
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 4
        anchors.bottomMargin: 8
        spacing: root.cardSpacing

        readonly property real availableWidth: width - (spacing * 3)
        readonly property real baseCardWidth: Math.floor(availableWidth / 4)
        readonly property real flexBonus: 22

        function getCardWidth(index) {
            if (root.activeFlexIndex === -1) {
                return baseCardWidth
            }
            if (root.activeFlexIndex === index) {
                return baseCardWidth + flexBonus
            }
            return baseCardWidth - (flexBonus / 3.0)
        }

        // =====================================================================
        // 1. CPU CARD (Tactile Left Anchor)
        // =====================================================================
        Rectangle {
            id: cpuCard
            width: cardsRow.getCardWidth(0)
            height: parent.height

            // M3 Expressive mixed radii: generous outer corners, ergonomic inner corners
            topLeftRadius: 18
            bottomLeftRadius: 18
            topRightRadius: 10
            bottomRightRadius: 10

            color: {
                if (root.cpuStressed) return Theme.withAlpha(Theme.red, 0.18)
                if (cpuArea.containsMouse) return Theme.surfaceContainerHighest
                return Theme.withAlpha(Theme.surfaceContainerHigh, 0.65)
            }
            border.color: {
                if (root.cpuStressed) return Theme.withAlpha(Theme.red, 0.55)
                if (cpuArea.containsMouse) return Theme.withAlpha(root.cpuAccent, 0.40)
                return Theme.withAlpha(Theme.border, 0.15)
            }
            border.width: (root.cpuStressed || cpuArea.containsMouse) ? 1.5 : 1

            scale: cpuArea.pressed ? 0.97 : (cpuArea.containsMouse ? 1.025 : 1.0)

            Behavior on width {
                NumberAnimation {
                    duration: Motion.springDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.15
                }
            }
            Behavior on color { ColorAnimation { duration: Motion.short3 } }
            Behavior on border.color { ColorAnimation { duration: Motion.short3 } }
            Behavior on scale {
                NumberAnimation {
                    duration: Motion.short3
                    easing.type: Easing.OutBack
                    easing.overshoot: Motion.springOvershoot
                }
            }

            MouseArea {
                id: cpuArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredIndex = 0
                onExited: {
                    if (root.hoveredIndex === 0) root.hoveredIndex = -1
                }
                onClicked: {
                    Quickshell.execDetached(["qdeck", "terminal", "btop"])
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 6

                // Top Header Row: Tonal Squircle + Category Label + Display Numeral
                Item {
                    width: parent.width
                    height: 28

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // 28x28 Tonal Squircle Icon Container
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 8
                            color: Theme.withAlpha(root.cpuAccent, root.cpuStressed ? 0.30 : (cpuArea.containsMouse ? 0.22 : 0.14))
                            border.color: Theme.withAlpha(root.cpuAccent, root.cpuStressed ? 0.50 : 0.20)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Motion.short3 } }

                            Text {
                                anchors.centerIn: parent
                                text: "developer_board"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 15
                                color: root.cpuAccent

                                Behavior on color { ColorAnimation { duration: Motion.short3 } }
                            }
                        }

                        Text {
                            text: "CPU"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 0.8
                            color: root.cpuAccent
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color { ColorAnimation { duration: Motion.short3 } }
                        }
                    }

                    // Large Bold Tabular-Numeral Metric
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.service ? root.service.cpuUsage.toFixed(1) : "0.0") + "%"
                        font.family: Fonts.monoFont
                        font.pixelSize: 16
                        font.bold: true
                        color: root.cpuStressed ? Theme.bright_red : Theme.bright_foreground
                    }
                }

                // M3 Expressive Linear Progress Indicator (8px Track)
                Rectangle {
                    width: parent.width
                    height: 8
                    radius: 4
                    color: Theme.withAlpha(Theme.darker_background, 0.65)
                    clip: true

                    Rectangle {
                        id: cpuBarFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(6, Math.min(parent.width, parent.width * ((root.service ? root.service.cpuUsage : 0.0) / 100.0)))
                        radius: 4
                        color: root.cpuAccent

                        Behavior on width {
                            NumberAnimation { duration: Motion.medium2; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Motion.short3 }
                        }

                        // Glowing head accent dot
                        Rectangle {
                            width: 3
                            height: parent.height
                            anchors.right: parent.right
                            radius: 2
                            color: Theme.bright_foreground
                            opacity: 0.7
                        }
                    }
                }

                // Bottom Meta Row: Clean Telemetry Badge Pills
                Row {
                    width: parent.width
                    spacing: 4

                    // Temp Badge
                    Rectangle {
                        height: 16
                        width: cpuTempText.implicitWidth + 8
                        radius: 5
                        color: Theme.withAlpha(Theme.darker_background, 0.55)
                        border.color: Theme.withAlpha(Theme.border, 0.12)
                        border.width: 1

                        Text {
                            id: cpuTempText
                            anchors.centerIn: parent
                            text: root.service && root.service.cpuTemp > 0 ? (root.service.cpuTemp + "°C") : "TEMP"
                            font.family: Fonts.monoFont
                            font.pixelSize: 8
                            font.bold: true
                            color: root.cpuStressed ? Theme.red : (root.cpuWarning ? Theme.orange : Theme.light_foreground)
                        }
                    }

                    // Cores Badge
                    Rectangle {
                        height: 16
                        width: cpuCoresText.implicitWidth + 8
                        radius: 5
                        color: Theme.withAlpha(Theme.darker_background, 0.55)
                        border.color: Theme.withAlpha(Theme.border, 0.12)
                        border.width: 1

                        Text {
                            id: cpuCoresText
                            anchors.centerIn: parent
                            text: (root.service ? root.service.cpuCores : 1) + " Cores"
                            font.family: Fonts.monoFont
                            font.pixelSize: 8
                            color: Theme.foreground
                            opacity: 0.85
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. RAM CARD (Tactile Inner Card)
        // =====================================================================
        Rectangle {
            id: ramCard
            width: cardsRow.getCardWidth(1)
            height: parent.height
            radius: 10

            color: {
                if (root.ramStressed) return Theme.withAlpha(Theme.red, 0.18)
                if (ramArea.containsMouse) return Theme.surfaceContainerHighest
                return Theme.withAlpha(Theme.surfaceContainerHigh, 0.65)
            }
            border.color: {
                if (root.ramStressed) return Theme.withAlpha(Theme.red, 0.55)
                if (ramArea.containsMouse) return Theme.withAlpha(root.ramAccent, 0.40)
                return Theme.withAlpha(Theme.border, 0.15)
            }
            border.width: (root.ramStressed || ramArea.containsMouse) ? 1.5 : 1

            scale: ramArea.pressed ? 0.97 : (ramArea.containsMouse ? 1.025 : 1.0)

            Behavior on width {
                NumberAnimation {
                    duration: Motion.springDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.15
                }
            }
            Behavior on color { ColorAnimation { duration: Motion.short3 } }
            Behavior on border.color { ColorAnimation { duration: Motion.short3 } }
            Behavior on scale {
                NumberAnimation {
                    duration: Motion.short3
                    easing.type: Easing.OutBack
                    easing.overshoot: Motion.springOvershoot
                }
            }

            MouseArea {
                id: ramArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredIndex = 1
                onExited: {
                    if (root.hoveredIndex === 1) root.hoveredIndex = -1
                }
                onClicked: {
                    Quickshell.execDetached(["qdeck", "terminal", "btop"])
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 6

                // Top Header Row: Tonal Squircle + Category Label + Display Numeral
                Item {
                    width: parent.width
                    height: 28

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // 28x28 Tonal Squircle Icon Container
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 8
                            color: Theme.withAlpha(root.ramAccent, root.ramStressed ? 0.30 : (ramArea.containsMouse ? 0.22 : 0.14))
                            border.color: Theme.withAlpha(root.ramAccent, root.ramStressed ? 0.50 : 0.20)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Motion.short3 } }

                            Text {
                                anchors.centerIn: parent
                                text: "memory"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 15
                                color: root.ramAccent

                                Behavior on color { ColorAnimation { duration: Motion.short3 } }
                            }
                        }

                        Text {
                            text: "RAM"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 0.8
                            color: root.ramAccent
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color { ColorAnimation { duration: Motion.short3 } }
                        }
                    }

                    // Large Bold Tabular-Numeral Metric
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.service ? root.service.ramPercent.toFixed(0) : "0") + "%"
                        font.family: Fonts.monoFont
                        font.pixelSize: 16
                        font.bold: true
                        color: root.ramStressed ? Theme.bright_red : Theme.bright_foreground
                    }
                }

                // M3 Expressive Linear Progress Indicator (8px Track)
                Rectangle {
                    width: parent.width
                    height: 8
                    radius: 4
                    color: Theme.withAlpha(Theme.darker_background, 0.65)
                    clip: true

                    Rectangle {
                        id: ramBarFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(6, Math.min(parent.width, parent.width * ((root.service ? root.service.ramPercent : 0.0) / 100.0)))
                        radius: 4
                        color: root.ramAccent

                        Behavior on width {
                            NumberAnimation { duration: Motion.medium2; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Motion.short3 }
                        }

                        // Glowing head accent dot
                        Rectangle {
                            width: 3
                            height: parent.height
                            anchors.right: parent.right
                            radius: 2
                            color: Theme.bright_foreground
                            opacity: 0.7
                        }
                    }
                }

                // Bottom Meta Row: Clean Telemetry Badge Pills
                Row {
                    width: parent.width
                    spacing: 4

                    // Memory Stats Badge
                    Rectangle {
                        height: 16
                        width: parent.width
                        radius: 5
                        color: Theme.withAlpha(Theme.darker_background, 0.55)
                        border.color: Theme.withAlpha(Theme.border, 0.12)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.service ? (root.service.ramUsedStr + " / " + root.service.ramTotalStr) : "-"
                            font.family: Fonts.monoFont
                            font.pixelSize: 8
                            font.bold: true
                            color: root.ramStressed ? Theme.red : Theme.light_foreground
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 3. STORAGE CARD (Tactile Inner Card)
        // =====================================================================
        Rectangle {
            id: storageCard
            width: cardsRow.getCardWidth(2)
            height: parent.height
            radius: 10

            color: {
                if (root.diskStressed) return Theme.withAlpha(Theme.red, 0.18)
                if (storageArea.containsMouse) return Theme.surfaceContainerHighest
                return Theme.withAlpha(Theme.surfaceContainerHigh, 0.65)
            }
            border.color: {
                if (root.diskStressed) return Theme.withAlpha(Theme.red, 0.55)
                if (storageArea.containsMouse) return Theme.withAlpha(root.diskAccent, 0.40)
                return Theme.withAlpha(Theme.border, 0.15)
            }
            border.width: (root.diskStressed || storageArea.containsMouse) ? 1.5 : 1

            scale: storageArea.pressed ? 0.97 : (storageArea.containsMouse ? 1.025 : 1.0)

            Behavior on width {
                NumberAnimation {
                    duration: Motion.springDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.15
                }
            }
            Behavior on color { ColorAnimation { duration: Motion.short3 } }
            Behavior on border.color { ColorAnimation { duration: Motion.short3 } }
            Behavior on scale {
                NumberAnimation {
                    duration: Motion.short3
                    easing.type: Easing.OutBack
                    easing.overshoot: Motion.springOvershoot
                }
            }

            MouseArea {
                id: storageArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredIndex = 2
                onExited: {
                    if (root.hoveredIndex === 2) root.hoveredIndex = -1
                }
                onClicked: {
                    Quickshell.execDetached(["qdeck", "terminal", "btop"])
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 6

                // Top Header Row: Tonal Squircle + Category Label + Display Numeral
                Item {
                    width: parent.width
                    height: 28

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // 28x28 Tonal Squircle Icon Container
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 8
                            color: Theme.withAlpha(root.diskAccent, root.diskStressed ? 0.30 : (storageArea.containsMouse ? 0.22 : 0.14))
                            border.color: Theme.withAlpha(root.diskAccent, root.diskStressed ? 0.50 : 0.20)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Motion.short3 } }

                            Text {
                                anchors.centerIn: parent
                                text: "hard_drive"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 15
                                color: root.diskAccent

                                Behavior on color { ColorAnimation { duration: Motion.short3 } }
                            }
                        }

                        Text {
                            text: "DISK"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 0.8
                            color: root.diskAccent
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color { ColorAnimation { duration: Motion.short3 } }
                        }
                    }

                    // Large Bold Tabular-Numeral Metric
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.service ? root.service.storagePercent.toFixed(0) : "0") + "%"
                        font.family: Fonts.monoFont
                        font.pixelSize: 16
                        font.bold: true
                        color: root.diskStressed ? Theme.bright_red : Theme.bright_foreground
                    }
                }

                // M3 Expressive Linear Progress Indicator (8px Track)
                Rectangle {
                    width: parent.width
                    height: 8
                    radius: 4
                    color: Theme.withAlpha(Theme.darker_background, 0.65)
                    clip: true

                    Rectangle {
                        id: diskBarFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(6, Math.min(parent.width, parent.width * ((root.service ? root.service.storagePercent : 0.0) / 100.0)))
                        radius: 4
                        color: root.diskAccent

                        Behavior on width {
                            NumberAnimation { duration: Motion.medium2; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Motion.short3 }
                        }

                        // Glowing head accent dot
                        Rectangle {
                            width: 3
                            height: parent.height
                            anchors.right: parent.right
                            radius: 2
                            color: Theme.bright_foreground
                            opacity: 0.7
                        }
                    }
                }

                // Bottom Meta Row: Clean Telemetry Badge Pills
                Row {
                    width: parent.width
                    spacing: 4

                    // Disk Space Badge
                    Rectangle {
                        height: 16
                        width: parent.width
                        radius: 5
                        color: Theme.withAlpha(Theme.darker_background, 0.55)
                        border.color: Theme.withAlpha(Theme.border, 0.12)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.service ? (root.service.storageUsedStr + " / " + root.service.storageTotalStr) : "-"
                            font.family: Fonts.monoFont
                            font.pixelSize: 8
                            font.bold: true
                            color: root.diskStressed ? Theme.red : Theme.light_foreground
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 4. NETWORK CARD (Tactile Right Anchor & Expressive Directional Badges)
        // =====================================================================
        Rectangle {
            id: netCard
            width: cardsRow.getCardWidth(3)
            height: parent.height

            // M3 Expressive mixed radii: generous outer corners, ergonomic inner corners
            topRightRadius: 18
            bottomRightRadius: 18
            topLeftRadius: 10
            bottomLeftRadius: 10

            color: {
                if (root.netStressed) return Theme.withAlpha(Theme.bright_green, 0.18)
                if (netArea.containsMouse) return Theme.surfaceContainerHighest
                return Theme.withAlpha(Theme.surfaceContainerHigh, 0.65)
            }
            border.color: {
                if (root.netStressed) return Theme.withAlpha(Theme.bright_green, 0.55)
                if (netArea.containsMouse) return Theme.withAlpha(Theme.green, 0.40)
                return Theme.withAlpha(Theme.border, 0.15)
            }
            border.width: (root.netStressed || netArea.containsMouse) ? 1.5 : 1

            scale: netArea.pressed ? 0.97 : (netArea.containsMouse ? 1.025 : 1.0)

            readonly property bool isRxActive: root.service && root.service.netRxRate > 1024
            readonly property bool isTxActive: root.service && root.service.netTxRate > 1024

            Behavior on width {
                NumberAnimation {
                    duration: Motion.springDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.15
                }
            }
            Behavior on color { ColorAnimation { duration: Motion.short3 } }
            Behavior on border.color { ColorAnimation { duration: Motion.short3 } }
            Behavior on scale {
                NumberAnimation {
                    duration: Motion.short3
                    easing.type: Easing.OutBack
                    easing.overshoot: Motion.springOvershoot
                }
            }

            MouseArea {
                id: netArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredIndex = 3
                onExited: {
                    if (root.hoveredIndex === 3) root.hoveredIndex = -1
                }
                onClicked: {
                    Quickshell.execDetached(["qdeck", "terminal", "btop"])
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 6

                // Top Header Row: Tonal Squircle + Category Label + Primary Speed
                Item {
                    width: parent.width
                    height: 28

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // 28x28 Tonal Squircle Icon Container
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 8
                            color: Theme.withAlpha(Theme.green, root.netStressed ? 0.30 : (netArea.containsMouse ? 0.22 : 0.14))
                            border.color: Theme.withAlpha(Theme.green, root.netStressed ? 0.50 : 0.20)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Motion.short3 } }

                            Text {
                                anchors.centerIn: parent
                                text: "swap_vert"
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 15
                                color: Theme.green

                                Behavior on color { ColorAnimation { duration: Motion.short3 } }
                            }
                        }

                        Text {
                            text: "NET"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 0.8
                            color: Theme.green
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Status Badge (LIVE / IDLE)
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18
                        width: netStatusRow.implicitWidth + 10
                        radius: 6
                        color: (netCard.isRxActive || netCard.isTxActive)
                            ? Theme.withAlpha(Theme.green, 0.20)
                            : Theme.withAlpha(Theme.darker_background, 0.55)
                        border.color: (netCard.isRxActive || netCard.isTxActive)
                            ? Theme.withAlpha(Theme.green, 0.45)
                            : Theme.withAlpha(Theme.border, 0.15)
                        border.width: 1

                        Row {
                            id: netStatusRow
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: (netCard.isRxActive || netCard.isTxActive) ? Theme.green : Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: (netCard.isRxActive || netCard.isTxActive) ? "LIVE" : "IDLE"
                                font.family: Fonts.monoFont
                                font.pixelSize: 8
                                font.bold: true
                                color: (netCard.isRxActive || netCard.isTxActive) ? Theme.bright_foreground : Theme.light_foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Dual Opposing Micro-Activity Gauges (Rx Left, Tx Right)
                Item {
                    width: parent.width
                    height: 8

                    Row {
                        anchors.fill: parent
                        spacing: 3

                        // RX Active Bar
                        Rectangle {
                            height: parent.height
                            width: Math.floor((parent.width - 3) / 2)
                            radius: 4
                            color: Theme.withAlpha(Theme.darker_background, 0.65)
                            clip: true

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(4, Math.min(parent.width, netCard.isRxActive ? parent.width : 4))
                                radius: 4
                                color: netCard.isRxActive ? Theme.green : Theme.withAlpha(Theme.green, 0.25)

                                Behavior on color { ColorAnimation { duration: Motion.short2 } }
                                Behavior on width { NumberAnimation { duration: Motion.medium1; easing.type: Easing.OutCubic } }
                            }
                        }

                        // TX Active Bar
                        Rectangle {
                            height: parent.height
                            width: Math.ceil((parent.width - 3) / 2)
                            radius: 4
                            color: Theme.withAlpha(Theme.darker_background, 0.65)
                            clip: true

                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(4, Math.min(parent.width, netCard.isTxActive ? parent.width : 4))
                                radius: 4
                                color: netCard.isTxActive ? Theme.cyan : Theme.withAlpha(Theme.cyan, 0.25)

                                Behavior on color { ColorAnimation { duration: Motion.short2 } }
                                Behavior on width { NumberAnimation { duration: Motion.medium1; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }

                // Dual Directional Badges (↓ Download & ↑ Upload)
                Row {
                    width: parent.width
                    spacing: 4

                    // Download directional pill
                    Rectangle {
                        height: 16
                        width: Math.floor((parent.width - 4) / 2)
                        radius: 5
                        color: Theme.withAlpha(Theme.green, netCard.isRxActive ? 0.22 : 0.08)
                        border.color: Theme.withAlpha(Theme.green, netCard.isRxActive ? 0.40 : 0.15)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                text: "↓"
                                font.family: Fonts.monoFont
                                font.pixelSize: 9
                                font.bold: true
                                color: Theme.green
                            }

                            Text {
                                text: root.service ? root.service.netRxStr : "0 B/s"
                                font.family: Fonts.monoFont
                                font.pixelSize: 8
                                font.bold: true
                                color: netCard.isRxActive ? Theme.bright_foreground : Theme.light_foreground
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Upload directional pill
                    Rectangle {
                        height: 16
                        width: Math.ceil((parent.width - 4) / 2)
                        radius: 5
                        color: Theme.withAlpha(Theme.cyan, netCard.isTxActive ? 0.22 : 0.08)
                        border.color: Theme.withAlpha(Theme.cyan, netCard.isTxActive ? 0.40 : 0.15)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                text: "↑"
                                font.family: Fonts.monoFont
                                font.pixelSize: 9
                                font.bold: true
                                color: Theme.cyan
                            }

                            Text {
                                text: root.service ? root.service.netTxStr : "0 B/s"
                                font.family: Fonts.monoFont
                                font.pixelSize: 8
                                font.bold: true
                                color: netCard.isTxActive ? Theme.bright_foreground : Theme.light_foreground
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
