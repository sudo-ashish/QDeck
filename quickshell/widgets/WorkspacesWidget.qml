import QtQuick
import "../theme"
import "../services"

// Outer pill container for workspaces on the bar
Rectangle {
    id: root

    required property WorkspacesService service

    implicitHeight: Appearance.barButtonHeight
    implicitWidth: wsRow.implicitWidth + (Appearance.workspacesPaddingHorizontal * 2)
    radius: height / 2

    color: Theme.withAlpha(Theme.dark_background, 0.75)
    border.color: Appearance.barBorder ? Theme.selection : "transparent"
    border.width: Appearance.barBorder ? Appearance.borderWidthThin : 0
    antialiasing: true

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0) {
                root.service.next()
            } else if (event.angleDelta.y > 0) {
                root.service.prev()
            }
        }
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: Appearance.workspacesSpacing
        height: parent.height - (Appearance.workspacesPaddingVertical * 2)

        Repeater {
            model: root.service.workspaceIds

            Rectangle {
                id: wsCapsule
                required property int modelData

                readonly property bool isActive: root.service.activeWorkspaceId === modelData
                readonly property bool isOccupied: !!root.service.occupiedWorkspaces[modelData]

                height: parent.height
                width: isActive ? Appearance.workspacesActiveCapsuleWidth : Appearance.workspacesCapsuleWidth
                radius: height / 2
                antialiasing: true

                color: {
                    if (isActive) return Theme.accent
                    if (wsMouse.containsMouse) return Theme.withAlpha(Theme.foreground, 0.16)
                    return Theme.withAlpha(Theme.foreground, 0.08)
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.animDurationNormal
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animDurationNormal
                    }
                }

                // Inactive workspace indicator: circular dot (or custom inactive icon from Icons.qml)
                Rectangle {
                    id: dot
                    anchors.centerIn: parent
                    width: Appearance.workspacesDotSize
                    height: Appearance.workspacesDotSize
                    radius: width / 2
                    visible: !wsCapsule.isActive && (!Icons.workspaceInactive || Icons.workspaceInactive.length === 0)
                    color: "#ffffff"
                    opacity: wsCapsule.isOccupied ? 1.0 : 0.28
                    antialiasing: true

                    Behavior on opacity {
                        NumberAnimation { duration: Appearance.animDurationNormal }
                    }
                }

                Text {
                    id: inactiveIcon
                    anchors.centerIn: parent
                    visible: !wsCapsule.isActive && (Icons.workspaceInactive && Icons.workspaceInactive.length > 0)
                    text: Icons.workspaceInactive
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: Appearance.workspacesIconSize
                    color: "#ffffff"
                    opacity: wsCapsule.isOccupied ? 1.0 : 0.28
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter

                    Behavior on opacity {
                        NumberAnimation { duration: Appearance.animDurationNormal }
                    }
                }

                // Active workspace indicator: user manual icon defined in Icons.qml
                Text {
                    id: activeIcon
                    anchors.centerIn: parent
                    visible: wsCapsule.isActive
                    text: Icons.workspaceActive || Icons.workspace
                    font.family: Icons.effectiveFont(text)
                    font.pixelSize: Appearance.workspacesIconSize
                    color: Theme.dark_background
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.switchTo(wsCapsule.modelData)
                }
            }
        }
    }
}
