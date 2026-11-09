import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"
import "../services"
import "../services/ClockModel.js" as Model

Item {
    id: root

    property PowerService powerService: null

    property date today: new Date()
    property date now: new Date()
    readonly property string todayKey: Model.keyForDate(today)

    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth() // 0-indexed

    readonly property date viewDate: new Date(viewYear, viewMonth, 1)
    readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

    readonly property real yearDone: Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property int yearDonePercent: Model.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())

    // 0 = Sunday start (matching screenshot SUN, MON, TUE...)
    readonly property int weekStart: 0
    readonly property var weekdays: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var current = new Date()
            root.now = current
            if (current.getDate() !== root.today.getDate() || current.getMonth() !== root.today.getMonth() || current.getFullYear() !== root.today.getFullYear()) {
                root.today = current
            }
        }
    }

    function goToToday() {
        var current = new Date()
        root.now = current
        root.today = current
        root.viewYear = current.getFullYear()
        root.viewMonth = current.getMonth()
    }

    function toggle() {
        clockPopup.toggle()
        if (clockPopup.open) root.goToToday()
    }

    function moveMonth(delta) {
        var next = Model.stepMonth(viewYear, viewMonth, delta)
        root.viewYear = next.year
        root.viewMonth = next.month
    }

    function formatTime(d) {
        var h = String(d.getHours()).padStart(2, "0")
        var m = String(d.getMinutes()).padStart(2, "0")
        return h + ":" + m
    }

    function formatDayTime(d) {
        var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[d.getDay()] + " " + formatTime(d)
    }

    implicitWidth: clockButton.implicitWidth
    implicitHeight: clockButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    BarButton {
        id: clockButton
        icon: ""
        text: root.formatDayTime(root.now)
        active: clockPopup.open
        onClicked: {
            clockPopup.toggle()
            if (clockPopup.open) root.goToToday()
        }
    }

    PopupCard {
        id: clockPopup
        anchorItem: clockButton
        showDefaultHeader: false
        contentWidth: 380
        contentHeight: 395

        WheelHandler {
            onWheel: function(event) {
                if (event.angleDelta.y === 0) return
                root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
            }
        }

        Column {
            id: calendarCol
            anchors.fill: parent
            anchors.margins: 10
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
                            text: "󰃭"
                            font.family: Icons.effectiveFont("󰃭")
                            font.pixelSize: 22
                            color: Theme.accent
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: Qt.formatDate(root.today, "MMMM d")
                            font.family: Fonts.uiFont
                            font.pixelSize: 15
                            font.bold: true
                            color: Theme.bright_foreground
                        }

                        Text {
                            text: root.viewingCurrentMonth ? "TODAY" : Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                            color: Theme.accent
                            opacity: 0.85
                        }
                    }
                }

                // Return to Today pill (shown when navigating away from current month)
                Rectangle {
                    visible: !root.viewingCurrentMonth
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    height: 26
                    radius: 13
                    color: todayPillMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                    Text {
                        anchors.centerIn: parent
                        text: "Today"
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.accent
                    }

                    MouseArea {
                        id: todayPillMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToToday()
                    }
                }
            }

            // ================= 2. YEAR PROGRESS RAIL (Inside surfaceContainer) =================
            Rectangle {
                width: parent.width
                height: 32
                radius: 10
                color: Theme.surfaceContainer

                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    width: parent.width - 24

                    Text {
                        text: String(root.today.getFullYear())
                        color: Theme.muted
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        id: yearTrack
                        height: 6
                        radius: 3
                        color: Theme.surfaceContainerHigh
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: Math.round(parent.width * root.yearDone)
                            color: Theme.accent

                            Behavior on width {
                                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Text {
                        text: root.yearDonePercent + "%"
                        color: Theme.foreground
                        font.family: Fonts.monoFont
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // ================= 3. CALENDAR MONTH GRID =================
            Item {
                width: parent.width
                height: 220

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    // Weekday Header Row
                    Row {
                        spacing: 2

                        // Week column header "W"
                        Item {
                            width: 36
                            height: 18
                            opacity: 0.35

                            Text {
                                anchors.centerIn: parent
                                text: "W"
                                color: Theme.muted
                                font.family: Fonts.uiFont
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1
                            }
                        }

                        // Gutter space before day headers
                        Item { width: 8; height: 18 }

                        // Days headers: SUN, MON, TUE, WED, THU, FRI, SAT
                        Repeater {
                            model: root.weekdays

                            Item {
                                required property string modelData
                                width: 42
                                height: 18

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: Theme.muted
                                    font.family: Fonts.uiFont
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 0.5
                                }
                            }
                        }
                    }

                    // 6 Weeks Rows
                    Repeater {
                        model: root.weeks

                        Row {
                            id: weekRow
                            required property var modelData
                            spacing: 2

                            // Week number column (dimmed slightly)
                            Item {
                                width: 36
                                height: 30
                                opacity: 0.35

                                Text {
                                    anchors.centerIn: parent
                                    text: weekRow.modelData.week
                                    color: Theme.muted
                                    font.family: Fonts.monoFont
                                    font.pixelSize: 11
                                }
                            }

                            // Gutter space
                            Item { width: 8; height: 30 }

                            // 7 Days in Week
                            Repeater {
                                model: weekRow.modelData.days

                                Rectangle {
                                    id: dayCell
                                    required property var modelData

                                    width: 42
                                    height: 30
                                    radius: 10
                                    color: {
                                        if (modelData.today) return Theme.accent
                                        if (dayCellMouse.containsMouse) return Theme.surfaceContainerHigh
                                        return "transparent"
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCell.modelData.day
                                        color: {
                                            if (dayCell.modelData.today) return Theme.dark_background
                                            if (dayCell.modelData.inMonth) return Theme.foreground
                                            return Theme.dark_foreground
                                        }
                                        font.family: Fonts.uiFont
                                        font.pixelSize: 12
                                        font.bold: dayCell.modelData.today
                                    }

                                    MouseArea {
                                        id: dayCellMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================= 4. FOOTER / MONTH NAVIGATION =================
            Item {
                width: parent.width
                height: 32

                Row {
                    anchors.centerIn: parent
                    spacing: 36

                    // Prev Month Chevron Button (<)
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: prevM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅁"
                            font.family: Icons.effectiveFont("󰅁")
                            font.pixelSize: 13
                            color: prevM.containsMouse ? Theme.bright_foreground : Theme.foreground
                        }

                        MouseArea {
                            id: prevM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.moveMonth(-1)
                        }
                    }

                    // Month & Year Label (e.g. "NOVEMBER 2026")
                    Text {
                        text: Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()
                        color: Theme.bright_foreground
                        font.family: Fonts.uiFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Next Month Chevron Button (>)
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: nextM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅂"
                            font.family: Icons.effectiveFont("󰅂")
                            font.pixelSize: 13
                            color: nextM.containsMouse ? Theme.bright_foreground : Theme.foreground
                        }

                        MouseArea {
                            id: nextM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.moveMonth(1)
                        }
                    }
                }
            }
        }
    }
}
