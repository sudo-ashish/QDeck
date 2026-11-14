import QtQuick
import Quickshell
import "../../../theme"
import "../../../components"
import "../../../services"

Item {
    id: root

    required property SysmonService service
    property bool open: false
    signal clicked()

    implicitWidth: sysmonButton.implicitWidth
    implicitHeight: sysmonButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    BarButton {
        id: sysmonButton
        icon: "developer_board"
        iconSize: Appearance.barIconSize
        active: root.open
        accentActive: root.open
        onClicked: root.clicked()
    }
}
