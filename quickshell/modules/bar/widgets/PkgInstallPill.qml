import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../theme"
import "../../../components"
import "../../../services"

Item {
    id: root

    required property PackageService packageService

    readonly property bool isInstalling: packageService ? packageService.isInstalling : false
    readonly property bool installSuccess: packageService ? packageService.installSuccess : false
    readonly property bool installFailed: packageService ? packageService.installFailed : false
    readonly property string activePackage: packageService ? packageService.activePackage : ""
    readonly property bool hasActive: isInstalling || installSuccess || installFailed
    readonly property bool popupOpen: installPopup.open

    readonly property string pillLabel: {
        if (!root.activePackage) return ""
        if (root.installSuccess) return root.activePackage + " ✓"
        if (root.installFailed) return root.activePackage + " ✕"
        return root.activePackage
    }

    implicitHeight: Math.max(26, Appearance.barHeight - 8)
    implicitWidth: hasActive ? Math.min(240, Math.max(120, labelMeasure.implicitWidth + 62)) : 0
    height: implicitHeight
    width: implicitWidth
    visible: width > 0 || opacity > 0

    opacity: hasActive ? 1.0 : 0.0

    Behavior on implicitWidth {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }

    function toggle() {
        installPopup.toggle()
    }

    // Inform packageService whether the popup is open so auto-dismiss waits
    onPopupOpenChanged: {
        if (root.packageService) {
            root.packageService.isPopupOpen = root.popupOpen
        }
    }

    // Off-screen text measure for dynamic width expansion
    Text {
        id: labelMeasure
        text: root.pillLabel
        font.family: Fonts.uiFont
        font.pixelSize: Fonts.scale(11)
        font.weight: Fonts.weightBold
        visible: false
    }

    // Outer Capsule Pill Container in Bar
    Rectangle {
        id: pillBg
        anchors.fill: parent
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2

        color: {
            if (root.installSuccess) {
                return pillMouse.containsMouse ? Theme.withAlpha(Theme.green, 0.30) : Theme.withAlpha(Theme.green, 0.20)
            }
            if (root.installFailed) {
                return pillMouse.containsMouse ? Theme.withAlpha(Theme.red, 0.30) : Theme.withAlpha(Theme.red, 0.20)
            }
            return pillMouse.containsMouse
                ? Theme.withAlpha(Theme.accent, 0.30)
                : Theme.withAlpha(Theme.accent, 0.18)
        }

        border.color: {
            if (root.installSuccess) return Theme.withAlpha(Theme.green, 0.60)
            if (root.installFailed) return Theme.withAlpha(Theme.red, 0.60)
            return root.popupOpen ? Theme.accent : Theme.withAlpha(Theme.accent, 0.45)
        }
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            spacing: 6

            // Status Icon (Spinning when installing, checkmark when success, cross when failed)
            Item {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: statusIcon
                    anchors.centerIn: parent
                    text: root.installSuccess ? "✓" : (root.installFailed ? "✕" : "󰑓")
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: Fonts.scale(12)
                    font.bold: true
                    color: root.installSuccess ? Theme.green : (root.installFailed ? Theme.red : Theme.accent)

                    RotationAnimation on rotation {
                        running: root.isInstalling
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }
            }

            // Package Name
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.pillLabel
                font.family: Fonts.uiFont
                font.pixelSize: Fonts.scale(11)
                font.weight: Fonts.weightBold
                color: root.installSuccess
                    ? Theme.green
                    : (root.installFailed ? Theme.red : Theme.bright_foreground)
                elide: Text.ElideRight
            }

            // Expand indicator icon
            Text {
                Layout.preferredWidth: 10
                Layout.alignment: Qt.AlignVCenter
                text: root.popupOpen ? "󰅃" : "󰅀"
                font.family: Icons.effectiveFont("󰅀")
                font.pixelSize: Fonts.scale(10)
                color: Theme.muted
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.toggle()
            }
        }
    }

    // Expanded Aqua Dynamics / Popup Card showing Live Install Instance
    PopupCard {
        id: installPopup
        anchorItem: root
        showDefaultHeader: false
        contentWidth: 540
        contentHeight: 400

        onOpenChanged: {
            if (open && logListView.count > 0) {
                Qt.callLater(function() {
                    logListView.positionViewAtEnd()
                })
            }
        }

        Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                // ── 1. Status Header ─────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 52
                    radius: 12
                    border.width: 0
                    color: root.installSuccess
                        ? Theme.withAlpha(Theme.green, 0.15)
                        : (root.installFailed ? Theme.withAlpha(Theme.red, 0.15) : Theme.withAlpha(Theme.surfaceContainerHighest, 0.50))

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 12

                        // Status Icon in Header
                        Item {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: root.installSuccess ? "✓" : (root.installFailed ? "✕" : "󰑓")
                                font.family: Icons.effectiveFont(text)
                                font.pixelSize: 18
                                font.bold: true
                                color: root.installSuccess ? Theme.green : (root.installFailed ? Theme.red : Theme.accent)

                                RotationAnimation on rotation {
                                    running: root.isInstalling
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 1000
                                }
                            }
                        }

                        // Info Column
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: root.activePackage || "Package"
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Theme.bright_foreground
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    radius: 4
                                    border.width: 0
                                    color: root.installSuccess
                                        ? Theme.withAlpha(Theme.green, 0.25)
                                        : (root.installFailed ? Theme.withAlpha(Theme.red, 0.25) : Theme.withAlpha(Theme.accent, 0.25))
                                    implicitWidth: statusBadgeText.implicitWidth + 8
                                    implicitHeight: 18

                                    Text {
                                        id: statusBadgeText
                                        anchors.centerIn: parent
                                        text: root.installSuccess ? "INSTALLED" : (root.installFailed ? "FAILED" : "INSTALLING")
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: root.installSuccess ? Theme.green : (root.installFailed ? Theme.red : Theme.accent)
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.installSuccess
                                    ? "Package is now installed and ready to use."
                                    : (root.installFailed
                                        ? ("Failed to install (Exit code: " + (root.packageService ? root.packageService.activeExitCode : 1) + ")")
                                        : "Processing dependencies, build files, and package installation via yay...")
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                color: Theme.muted
                                elide: Text.ElideRight
                            }
                        }

                        // Cancel or Dismiss Button in Header
                        Rectangle {
                            id: hdrActionBtn
                            radius: 8
                            border.width: 0
                            color: root.isInstalling
                                ? (hdrActionMouse.containsMouse ? Theme.withAlpha(Theme.red, 0.35) : Theme.withAlpha(Theme.red, 0.20))
                                : (hdrActionMouse.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, 1.0) : Theme.withAlpha(Theme.surfaceContainerHighest, 0.70))
                            implicitWidth: hdrActionText.implicitWidth + 18
                            implicitHeight: 28
                            Layout.alignment: Qt.AlignVCenter

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: hdrActionText
                                anchors.centerIn: parent
                                text: root.isInstalling ? "Cancel" : "Dismiss"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: true
                                color: root.isInstalling ? Theme.red : Theme.bright_foreground
                            }

                            MouseArea {
                                id: hdrActionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.isInstalling) {
                                        if (root.packageService) root.packageService.cancelInstall()
                                    } else {
                                        installPopup.open = false
                                        if (root.packageService) root.packageService.dismiss()
                                    }
                                }
                            }
                        }

                        // Close "X" Button
                        Rectangle {
                            radius: 6
                            border.width: 0
                            color: closeMouse.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.8) : "transparent"
                            implicitWidth: 26
                            implicitHeight: 26
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.family: Fonts.uiFont
                                font.pixelSize: 12
                                color: Theme.muted
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    installPopup.open = false
                                }
                            }
                        }
                    }
                }

                // ── 2. Terminal Log Box Container ────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.border, 0.20)
                    color: Theme.withAlpha(Theme.dark_background, 0.98)
                    clip: true

                    ListView {
                        id: logListView
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2
                        model: root.packageService ? root.packageService.logModel : null
                        clip: true

                        delegate: Text {
                            width: logListView.width
                            text: model.text || ""
                            font.family: Fonts.monoFont
                            font.pixelSize: 11
                            readonly property bool isErrorLine: /^(error:|==> ERROR:|:: error|fatal:|Failed to )/i.test(text.trim())
                            readonly property bool isHeaderLine: /^(==>|->)/.test(text.trim())
                            readonly property bool isWarningLine: /^(warning:|==> WARNING:)/i.test(text.trim())

                            color: isErrorLine ? Theme.red : (isHeaderLine ? Theme.accent : (isWarningLine ? Theme.yellow : Theme.foreground))
                            wrapMode: Text.WrapAnywhere
                        }

                        onCountChanged: {
                            if (logListView.count > 0) {
                                logListView.positionViewAtEnd()
                            }
                        }
                    }
                }

                // ── 3. Footer Bar: Status & Copy Logs ────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    height: 26
                    spacing: 8

                    Text {
                        text: root.isInstalling
                            ? "● Live installation output"
                            : (root.installSuccess ? "✓ Transaction completed" : "✕ Process terminated")
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.weight: Fonts.weightMedium
                        color: root.isInstalling ? Theme.accent : (root.installSuccess ? Theme.green : Theme.red)
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    // "Copy Logs" button
                    Rectangle {
                        id: copyBtn
                        radius: 6
                        border.width: 0
                        color: copyMouse.containsMouse
                            ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.9)
                            : Theme.withAlpha(Theme.surfaceContainerHighest, 0.5)
                        implicitWidth: copyContentRow.implicitWidth + 14
                        implicitHeight: 24
                        Layout.alignment: Qt.AlignVCenter

                        property bool copied: false
                        Timer {
                            id: copiedTimer
                            interval: 1800
                            repeat: false
                            onTriggered: copyBtn.copied = false
                        }

                        RowLayout {
                            id: copyContentRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: copyBtn.copied ? "✓" : "󰆏"
                                font.family: Icons.effectiveFont("󰆏")
                                font.pixelSize: 11
                                color: copyBtn.copied ? Theme.green : Theme.muted
                            }

                            Text {
                                text: copyBtn.copied ? "Copied!" : "Copy Logs"
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.bold: true
                                color: copyBtn.copied ? Theme.green : Theme.foreground
                            }
                        }

                        MouseArea {
                            id: copyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.packageService || !root.packageService.logModel) return
                                var lines = []
                                for (var i = 0; i < root.packageService.logModel.count; i++) {
                                    lines.push(root.packageService.logModel.get(i).text || "")
                                }
                                var allText = lines.join("\n")
                                Quickshell.execDetached(["wl-copy", allText])
                                copyBtn.copied = true
                                copiedTimer.restart()
                            }
                        }
                    }
                }
            }
        }
    }
}
