import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../components"
import "../../services"

PanelWindow {
    id: root

    required property PackageService packageService

    readonly property bool isInstalling: packageService ? packageService.isInstalling : false
    readonly property bool installSuccess: packageService ? packageService.installSuccess : false
    readonly property bool installFailed: packageService ? packageService.installFailed : false
    readonly property string activePackage: packageService ? packageService.activePackage : ""
    readonly property bool shouldShow: packageService ? packageService.showPill : false

    property bool isExpanded: false

    readonly property string pillLabel: {
        if (!root.activePackage) return "Package"
        if (root.installSuccess) return root.activePackage + " ✓"
        if (root.installFailed) return root.activePackage + " ✕"
        return root.activePackage
    }

    // Keep packageService informed so auto-dismiss timer does not fire while expanded
    onIsExpandedChanged: {
        if (root.packageService) {
            root.packageService.isPopupOpen = root.isExpanded
        }
    }

    Connections {
        target: root.packageService
        function onRequestToggle() {
            root.isExpanded = !root.isExpanded
        }
    }

    visible: root.shouldShow

    WlrLayershell.namespace: "quickshell-pkg-pill"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // When collapsed: only containerCard receives pointer events.
    // When expanded: full screen captures clicks outside to collapse.
    mask: Region {
        item: root.isExpanded ? screenScrim : containerCard
    }

    // Full screen scrim (active only when expanded to allow clicking outside to collapse)
    Item {
        id: screenScrim
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            enabled: root.isExpanded
            onClicked: {
                root.isExpanded = false
            }
        }

        Shortcut {
            enabled: root.isExpanded
            sequence: "Escape"
            onActivated: {
                root.isExpanded = false
            }
        }
    }

    // Text measure for dynamic pill width
    Text {
        id: labelMeasure
        text: root.pillLabel
        font.family: Fonts.uiFont
        font.pixelSize: Fonts.scale(12)
        font.weight: Fonts.weightBold
        visible: false
    }

    // Floating Overlay Card at Top-Right of the Screen
    Rectangle {
        id: containerCard
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 14
        anchors.rightMargin: 16

        // Collapsed: pill dimensions. Expanded: full console card dimensions.
        readonly property real collapsedW: Math.min(280, Math.max(140, labelMeasure.implicitWidth + 68))
        readonly property real collapsedH: 38
        readonly property real expandedW: 540
        readonly property real expandedH: 420

        width: root.isExpanded ? expandedW : collapsedW
        height: root.isExpanded ? expandedH : collapsedH
        radius: root.isExpanded ? 16 : (height / 2)

        Behavior on width {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
        Behavior on radius {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        color: {
            if (root.installSuccess) {
                return root.isExpanded
                    ? Theme.withAlpha(Theme.surfaceBase, 0.96)
                    : (pillHoverArea.containsMouse ? Theme.withAlpha(Theme.green, 0.32) : Theme.withAlpha(Theme.dark_background, 0.94))
            }
            if (root.installFailed) {
                return root.isExpanded
                    ? Theme.withAlpha(Theme.surfaceBase, 0.96)
                    : (pillHoverArea.containsMouse ? Theme.withAlpha(Theme.red, 0.32) : Theme.withAlpha(Theme.dark_background, 0.94))
            }
            return root.isExpanded
                ? Theme.withAlpha(Theme.surfaceBase, 0.96)
                : (pillHoverArea.containsMouse ? Theme.withAlpha(Theme.accent, 0.30) : Theme.withAlpha(Theme.dark_background, 0.94))
        }

        border.color: {
            if (root.installSuccess) return Theme.withAlpha(Theme.green, 0.70)
            if (root.installFailed) return Theme.withAlpha(Theme.red, 0.70)
            return root.isExpanded ? Theme.accent : Theme.withAlpha(Theme.accent, 0.55)
        }
        border.width: 1

        clip: true

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // ═════════════════════════════════════════════════════════════════════
        // VIEW 1: Collapsed Pill State
        // ═════════════════════════════════════════════════════════════════════
        Item {
            id: collapsedView
            anchors.fill: parent
            visible: !root.isExpanded || containerCard.height < 60
            opacity: root.isExpanded ? 0.0 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                // Status Icon
                Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: root.installSuccess ? "✓" : (root.installFailed ? "✕" : "󰑓")
                        font.family: Icons.effectiveFont(text)
                        font.pixelSize: Fonts.scale(13)
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

                // Package Label
                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.pillLabel
                    font.family: Fonts.uiFont
                    font.pixelSize: Fonts.scale(12)
                    font.weight: Fonts.weightBold
                    color: root.installSuccess
                        ? Theme.green
                        : (root.installFailed ? Theme.red : Theme.bright_foreground)
                    elide: Text.ElideRight
                }

                // Expand indicator icon
                Text {
                    Layout.preferredWidth: 12
                    Layout.alignment: Qt.AlignVCenter
                    text: "󰅀"
                    font.family: Icons.effectiveFont("󰅀")
                    font.pixelSize: Fonts.scale(11)
                    color: Theme.muted
                }
            }

            MouseArea {
                id: pillHoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.isExpanded = true
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // VIEW 2: Expanded Live Installation Instance
        // ═════════════════════════════════════════════════════════════════════
        Item {
            id: expandedView
            anchors.fill: parent
            anchors.margins: 14
            visible: root.isExpanded && containerCard.height > 60
            opacity: root.isExpanded ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

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
                                        root.isExpanded = false
                                        if (root.packageService) root.packageService.dismiss()
                                    }
                                }
                            }
                        }

                        // Collapse Button
                        Rectangle {
                            radius: 6
                            border.width: 0
                            color: collapseMouse.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.8) : "transparent"
                            implicitWidth: 26
                            implicitHeight: 26
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: "󰅃"
                                font.family: Icons.effectiveFont("󰅃")
                                font.pixelSize: 14
                                color: Theme.muted
                            }

                            MouseArea {
                                id: collapseMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.isExpanded = false
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
