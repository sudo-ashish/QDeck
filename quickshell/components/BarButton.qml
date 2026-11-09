import QtQuick
import Quickshell
import "../theme"

Rectangle {
    id: root

    readonly property var window: QsWindow.window

    property string icon: ""
    property string text: ""
    property bool active: false
    property bool accentActive: false
    property color customColor: "transparent"
    property int customPadding: Appearance.buttonPadding
    property int iconSize: Icons.sizeNormal
    property int textSize: Fonts.sizeRegular

    signal clicked()

    implicitWidth: Math.max(Appearance.barButtonHeight, contentRow.implicitWidth + (customPadding * 2))
    implicitHeight: Appearance.barButtonHeight
    width: implicitWidth
    height: implicitHeight
    radius: 10

    color: {
        if (active) return Theme.secondaryContainer
        if (mouseArea.containsMouse) return Theme.surfaceContainerHigh
        return "transparent"
    }

    scale: mouseArea.pressed ? 0.94 : (mouseArea.containsMouse ? 1.04 : 1.0)

    Behavior on scale {
        NumberAnimation {
            duration: Motion.short3
            easing.type: Easing.OutBack
            easing.overshoot: Motion.springOvershoot
        }
    }

    Behavior on color {
        ColorAnimation { duration: Motion.short3 }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Appearance.spacingMedium - 2 // 6px

        Text {
            visible: root.icon.length > 0
            text: root.icon
            font.family: Icons.effectiveFont(root.icon)
            font.pixelSize: root.iconSize
            color: {
                if (root.accentActive || root.active) return Theme.accent
                if (root.customColor.a > 0) return root.customColor
                return Theme.foreground
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.text.length > 0
            text: root.text
            font.family: Fonts.uiFont
            font.pixelSize: root.textSize
            font.bold: root.active
            color: root.active ? Theme.accent : Theme.foreground
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
