import QtQuick
import Quickshell
import "../../../theme"
import "../../../services"

Item {
    id: root

    required property SysmonService service

    implicitHeight: 72
    implicitWidth: 520

    readonly property int cardSpacing: 8

    Row {
        id: cardsRow
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 4
        anchors.bottomMargin: 8
        spacing: root.cardSpacing

        readonly property real cardWidth: Math.floor((width - (spacing * 3)) / 4)

        // =====================================================================
        // 1. CPU CARD
        // =====================================================================
        Rectangle {
            width: cardsRow.cardWidth
            height: parent.height
            radius: 10
            color: cpuArea.containsMouse ? Theme.surfaceContainerHighest : Theme.withAlpha(Theme.surfaceContainerHigh, 0.65)
            border.color: Theme.withAlpha(Theme.border, 0.15)
            border.width: 1

            Behavior on color { ColorAnimation { duration: Motion.short2 } }

            MouseArea {
                id: cpuArea
                anchors.fill: parent
                hoverEnabled: true
            }

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                // Header Row
                Item {
                    width: parent.width
                    height: 16

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: "developer_board"
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 13
                            color: Theme.blue
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "CPU"
                            font.family: Fonts.uiFont
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.8
                            color: Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.service ? root.service.cpuUsage.toFixed(1) : "0.0") + "%"
                        font.family: Fonts.monoFont
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.bright_foreground
                    }
                }

                // Capsule Progress Bar
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.withAlpha(Theme.darker_background, 0.6)
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(3, Math.min(parent.width, parent.width * ((root.service ? root.service.cpuUsage : 0.0) / 100.0)))
                        radius: 2
                        color: {
                            var u = root.service ? root.service.cpuUsage : 0
                            if (u >= 85) return Theme.red
                            if (u >= 65) return Theme.orange
                            return Theme.blue
                        }

                        Behavior on width {
                            NumberAnimation { duration: Motion.medium1; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // Meta Details Row
                Text {
                    width: parent.width
                    text: root.service && root.service.cpuTemp > 0
                        ? (root.service.cpuTemp + "°C • " + root.service.cpuCores + " Cores")
                        : ((root.service ? root.service.cpuCores : 1) + " Cores")
                    font.family: Fonts.uiFont
                    font.pixelSize: 9
                    color: Theme.light_foreground
                    opacity: 0.85
                    elide: Text.ElideRight
                }
            }
        }

        // =====================================================================
        // 2. RAM CARD
        // =====================================================================
        Rectangle {
            width: cardsRow.cardWidth
            height: parent.height
            radius: 10
            color: ramArea.containsMouse ? Theme.surfaceContainerHighest : Theme.withAlpha(Theme.surfaceContainerHigh, 0.65)
            border.color: Theme.withAlpha(Theme.border, 0.15)
            border.width: 1

            Behavior on color { ColorAnimation { duration: Motion.short2 } }

            MouseArea {
                id: ramArea
                anchors.fill: parent
                hoverEnabled: true
            }

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                // Header Row
                Item {
                    width: parent.width
                    height: 16

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: "memory"
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 13
                            color: Theme.magenta
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "RAM"
                            font.family: Fonts.uiFont
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.8
                            color: Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.service ? root.service.ramPercent.toFixed(0) : "0") + "%"
                        font.family: Fonts.monoFont
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.bright_foreground
                    }
                }

                // Capsule Progress Bar
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.withAlpha(Theme.darker_background, 0.6)
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(3, Math.min(parent.width, parent.width * ((root.service ? root.service.ramPercent : 0.0) / 100.0)))
                        radius: 2
                        color: {
                            var p = root.service ? root.service.ramPercent : 0
                            if (p >= 90) return Theme.red
                            if (p >= 75) return Theme.orange
                            return Theme.magenta
                        }

                        Behavior on width {
                            NumberAnimation { duration: Motion.medium1; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // Meta Details Row
                Text {
                    width: parent.width
                    text: root.service ? (root.service.ramUsedStr + " / " + root.service.ramTotalStr) : "-"
                    font.family: Fonts.uiFont
                    font.pixelSize: 9
                    color: Theme.light_foreground
                    opacity: 0.85
                    elide: Text.ElideRight
                }
            }
        }

        // =====================================================================
        // 3. STORAGE CARD
        // =====================================================================
        Rectangle {
            width: cardsRow.cardWidth
            height: parent.height
            radius: 10
            color: storageArea.containsMouse ? Theme.surfaceContainerHighest : Theme.withAlpha(Theme.surfaceContainerHigh, 0.65)
            border.color: Theme.withAlpha(Theme.border, 0.15)
            border.width: 1

            Behavior on color { ColorAnimation { duration: Motion.short2 } }

            MouseArea {
                id: storageArea
                anchors.fill: parent
                hoverEnabled: true
            }

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                // Header Row
                Item {
                    width: parent.width
                    height: 16

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: "hard_drive"
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 13
                            color: Theme.yellow
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "DISK"
                            font.family: Fonts.uiFont
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.8
                            color: Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.service ? root.service.storagePercent.toFixed(0) : "0") + "%"
                        font.family: Fonts.monoFont
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.bright_foreground
                    }
                }

                // Capsule Progress Bar
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.withAlpha(Theme.darker_background, 0.6)
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(3, Math.min(parent.width, parent.width * ((root.service ? root.service.storagePercent : 0.0) / 100.0)))
                        radius: 2
                        color: {
                            var sp = root.service ? root.service.storagePercent : 0
                            if (sp >= 90) return Theme.red
                            if (sp >= 80) return Theme.orange
                            return Theme.yellow
                        }

                        Behavior on width {
                            NumberAnimation { duration: Motion.medium1; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // Meta Details Row
                Text {
                    width: parent.width
                    text: root.service ? (root.service.storageUsedStr + " / " + root.service.storageTotalStr) : "-"
                    font.family: Fonts.uiFont
                    font.pixelSize: 9
                    color: Theme.light_foreground
                    opacity: 0.85
                    elide: Text.ElideRight
                }
            }
        }

        // =====================================================================
        // 4. NETWORK CARD
        // =====================================================================
        Rectangle {
            width: cardsRow.cardWidth
            height: parent.height
            radius: 10
            color: netArea.containsMouse ? Theme.surfaceContainerHighest : Theme.withAlpha(Theme.surfaceContainerHigh, 0.65)
            border.color: Theme.withAlpha(Theme.border, 0.15)
            border.width: 1

            Behavior on color { ColorAnimation { duration: Motion.short2 } }

            MouseArea {
                id: netArea
                anchors.fill: parent
                hoverEnabled: true
            }

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                // Header Row
                Item {
                    width: parent.width
                    height: 16

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: "swap_vert"
                            font.family: Icons.effectiveFont(text)
                            font.pixelSize: 13
                            color: Theme.green
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "NET"
                            font.family: Fonts.uiFont
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.8
                            color: Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↓ " + (root.service ? root.service.netRxStr : "0 B/s")
                        font.family: Fonts.monoFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.bright_foreground
                        elide: Text.ElideRight
                    }
                }

                // Split Activity Bars (Rx Left, Tx Right)
                Item {
                    width: parent.width
                    height: 4

                    Row {
                        anchors.fill: parent
                        spacing: 2

                        Rectangle {
                            height: parent.height
                            width: Math.floor((parent.width - 2) / 2)
                            radius: 2
                            color: (root.service && root.service.netRxRate > 1024) ? Theme.green : Theme.withAlpha(Theme.darker_background, 0.6)

                            Behavior on color { ColorAnimation { duration: Motion.short2 } }
                        }

                        Rectangle {
                            height: parent.height
                            width: Math.ceil((parent.width - 2) / 2)
                            radius: 2
                            color: (root.service && root.service.netTxRate > 1024) ? Theme.cyan : Theme.withAlpha(Theme.darker_background, 0.6)

                            Behavior on color { ColorAnimation { duration: Motion.short2 } }
                        }
                    }
                }

                // Meta Details Row
                Text {
                    width: parent.width
                    text: "↑ " + (root.service ? root.service.netTxStr : "0 B/s")
                    font.family: Fonts.uiFont
                    font.pixelSize: 9
                    color: Theme.light_foreground
                    opacity: 0.85
                    elide: Text.ElideRight
                }
            }
        }
    }
}
