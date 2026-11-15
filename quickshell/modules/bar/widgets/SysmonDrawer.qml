import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../theme"
import "../../../services"

Item {
    id: root

    required property SysmonService service

    implicitHeight: 92
    implicitWidth: 640

    // Backward-compatible and clean public data bindings
    readonly property real cpuUsage: root.service ? root.service.cpuUsage : 0.0
    readonly property real ramUsage: root.service ? root.service.ramPercent : 0.0
    readonly property real diskUsage: root.service ? root.service.storagePercent : 0.0
    readonly property string netDown: root.service ? root.service.netRxStr : "0 B/s"
    readonly property string netUp: root.service ? root.service.netTxStr : "0 B/s"

    // Semantic accent colors with smooth threshold shifting
    readonly property color cpuAccent: {
        var u = root.cpuUsage
        if (u >= 85) return Theme.red
        if (u >= 65) return Theme.orange
        return Theme.accent
    }

    readonly property color ramAccent: {
        var r = root.ramUsage
        if (r >= 90) return Theme.red
        if (r >= 75) return Theme.orange
        return Theme.mauve || Theme.magenta || Theme.accent
    }

    readonly property color diskAccent: {
        var d = root.diskUsage
        if (d >= 90) return Theme.red
        if (d >= 80) return Theme.orange
        return Theme.yellow
    }

    // Dynamic peak throughput tracker for organic breathing of dual activity bars
    property real peakNetThroughput: 1048576.0 // 1 MB/s baseline
    readonly property real currentMaxNet: root.service ? Math.max(root.service.netRxRate, root.service.netTxRate) : 0

    onCurrentMaxNetChanged: {
        if (currentMaxNet > peakNetThroughput) {
            peakNetThroughput = currentMaxNet
        } else {
            peakNetThroughput = Math.max(262144.0, peakNetThroughput * 0.985)
        }
    }

    readonly property real rxRatio: {
        if (!root.service || root.service.netRxRate <= 0) return 0.0
        return Math.min(1.0, Math.max(0.06, root.service.netRxRate / Math.max(65536.0, peakNetThroughput)))
    }

    readonly property real txRatio: {
        if (!root.service || root.service.netTxRate <= 0) return 0.0
        return Math.min(1.0, Math.max(0.06, root.service.netTxRate / Math.max(65536.0, peakNetThroughput)))
    }

    RowLayout {
        id: cardsRow
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 4
        anchors.bottomMargin: 8
        spacing: 10

        // =====================================================================
        // CARD 1 — CPU
        // =====================================================================
        Rectangle {
            id: cpuCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: cpuMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
            border.width: 0
            scale: cpuMouse.pressed ? 0.98 : 1.0

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }

            MouseArea {
                id: cpuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qdeck", "terminal", "btop"])
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 0

                // Top row: Minimalist icon (Theme.accent) + "CPU" label (pixelSize: 11, font.bold: true, letterSpacing: 1.2)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "developer_board"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 14
                        color: root.cpuAccent
                        Layout.alignment: Qt.AlignVCenter

                        Behavior on color {
                            ColorAnimation { duration: 250 }
                        }
                    }

                    Text {
                        text: "CPU"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: Theme.muted
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }
                }

                Item { Layout.fillHeight: true }

                // Middle / Hero row: Large percentage readout (pixelSize: 24, font.bold: true)
                Text {
                    Layout.fillWidth: true
                    text: root.cpuUsage.toFixed(1) + "%"
                    font.family: Fonts.monoFont
                    font.pixelSize: 24
                    font.bold: true
                    color: root.cpuUsage >= 85 ? Theme.bright_red : Theme.bright_foreground

                    Behavior on color {
                        ColorAnimation { duration: 250 }
                    }
                }

                Item { Layout.fillHeight: true }

                // Bottom visual: Clean 6px borderless rounded progress bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 4
                    color: Theme.withAlpha(root.cpuAccent, 0.14)
                    border.width: 0
                    clip: true

                    Rectangle {
                        id: cpuBarFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(0, Math.min(parent.width, parent.width * (Math.max(0.0, root.cpuUsage) / 100.0)))
                        radius: 4
                        color: root.cpuAccent
                        border.width: 0

                        Behavior on width {
                            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 250 }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // CARD 2 — RAM
        // =====================================================================
        Rectangle {
            id: ramCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: ramMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
            border.width: 0
            scale: ramMouse.pressed ? 0.98 : 1.0

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }

            MouseArea {
                id: ramMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qdeck", "terminal", "btop"])
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 0

                // Top row: Icon + "RAM" label
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "memory"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 14
                        color: root.ramAccent
                        Layout.alignment: Qt.AlignVCenter

                        Behavior on color {
                            ColorAnimation { duration: 250 }
                        }
                    }

                    Text {
                        text: "RAM"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: Theme.muted
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }
                }

                Item { Layout.fillHeight: true }

                // Middle / Hero row: Large percentage readout (pixelSize: 24, font.bold: true)
                Text {
                    Layout.fillWidth: true
                    text: root.ramUsage.toFixed(0) + "%"
                    font.family: Fonts.monoFont
                    font.pixelSize: 24
                    font.bold: true
                    color: root.ramUsage >= 90 ? Theme.bright_red : Theme.bright_foreground

                    Behavior on color {
                        ColorAnimation { duration: 250 }
                    }
                }

                Item { Layout.fillHeight: true }

                // Bottom visual: Clean 6px borderless rounded progress bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 4
                    color: Theme.withAlpha(root.ramAccent, 0.14)
                    border.width: 0
                    clip: true

                    Rectangle {
                        id: ramBarFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(0, Math.min(parent.width, parent.width * (Math.max(0.0, root.ramUsage) / 100.0)))
                        radius: 4
                        color: root.ramAccent
                        border.width: 0

                        Behavior on width {
                            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 250 }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // CARD 3 — DISK
        // =====================================================================
        Rectangle {
            id: diskCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: diskMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
            border.width: 0
            scale: diskMouse.pressed ? 0.98 : 1.0

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }

            MouseArea {
                id: diskMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qdeck", "terminal", "btop"])
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 0

                // Top row: Icon + "DISK" label
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "hard_drive"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 14
                        color: root.diskAccent
                        Layout.alignment: Qt.AlignVCenter

                        Behavior on color {
                            ColorAnimation { duration: 250 }
                        }
                    }

                    Text {
                        text: "DISK"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: Theme.muted
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }
                }

                Item { Layout.fillHeight: true }

                // Middle / Hero row: Large percentage readout (pixelSize: 24, font.bold: true)
                Text {
                    Layout.fillWidth: true
                    text: root.diskUsage.toFixed(0) + "%"
                    font.family: Fonts.monoFont
                    font.pixelSize: 24
                    font.bold: true
                    color: root.diskUsage >= 90 ? Theme.bright_red : Theme.bright_foreground

                    Behavior on color {
                        ColorAnimation { duration: 250 }
                    }
                }

                Item { Layout.fillHeight: true }

                // Bottom visual: Clean 6px borderless rounded progress bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 4
                    color: Theme.withAlpha(root.diskAccent, 0.14)
                    border.width: 0
                    clip: true

                    Rectangle {
                        id: diskBarFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(0, Math.min(parent.width, parent.width * (Math.max(0.0, root.diskUsage) / 100.0)))
                        radius: 4
                        color: root.diskAccent
                        border.width: 0

                        Behavior on width {
                            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 250 }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // CARD 4 — NET
        // =====================================================================
        Rectangle {
            id: netCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: netMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
            border.width: 0
            scale: netMouse.pressed ? 0.98 : 1.0

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }

            MouseArea {
                id: netMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qdeck", "terminal", "btop"])
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 0

                // Top row: Icon + "NET" label
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "swap_vert"
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: 14
                        color: Theme.green
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: "NET"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: Theme.muted
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }
                }

                Item { Layout.fillHeight: true }

                // Middle / Hero row: Clean borderless two-value readout without background pills
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "↓"
                            font.family: Fonts.monoFont
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.green
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.netDown
                            font.family: Fonts.monoFont
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.bright_foreground
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "↑"
                            font.family: Fonts.monoFont
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.cyan
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.netUp
                            font.family: Fonts.monoFont
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.bright_foreground
                            elide: Text.ElideRight
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Bottom visual: Split dual 6px borderless rounded activity bars
                RowLayout {
                    Layout.fillWidth: true
                    height: 6
                    spacing: 4

                    // Download Activity Bar (Left fill in Theme.green)
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 4
                        color: Theme.withAlpha(Theme.green, 0.14)
                        border.width: 0
                        clip: true

                        Rectangle {
                            id: downBarFill
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(parent.width, parent.width * root.rxRatio))
                            radius: 4
                            color: Theme.green
                            border.width: 0

                            Behavior on width {
                                NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    // Upload Activity Bar (Right fill in Theme.cyan)
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 4
                        color: Theme.withAlpha(Theme.cyan, 0.14)
                        border.width: 0
                        clip: true

                        Rectangle {
                            id: upBarFill
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(parent.width, parent.width * root.txRatio))
                            radius: 4
                            color: Theme.cyan
                            border.width: 0

                            Behavior on width {
                                NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
    }
}
