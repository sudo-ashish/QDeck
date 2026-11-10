import QtQuick
import "../theme"

Item {
    id: root

    property bool checked: false
    property bool interactive: true
    signal toggled()

    implicitWidth: 46
    implicitHeight: 26
    width: implicitWidth
    height: implicitHeight

    // M3 Expressive Pill Switch (46x26, radius 13)
    Rectangle {
        id: track
        anchors.fill: parent
        radius: 13
        color: root.checked ? Theme.accent : Theme.surfaceContainerHigh
        border.color: root.checked ? "transparent" : Theme.withAlpha(Theme.muted, 0.40)
        border.width: root.checked ? 0 : 1

        scale: mouseArea.pressed ? 0.94 : (mouseArea.containsMouse ? 1.03 : 1.0)

        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Behavior on border.color {
            ColorAnimation { duration: 180 }
        }

        Rectangle {
            id: thumb
            width: 20
            height: 20
            radius: 10
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? (track.width - width - 3) : 3
            color: root.checked ? Theme.darker_background : Theme.muted

            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.15
                }
            }

            Behavior on color {
                ColorAnimation { duration: 180 }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
