import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../components"
import "../services"

Item {
    id: root

    required property BrightnessService service

    property int iconSize: Appearance.monitorIconSize

    implicitWidth: monButton.implicitWidth
    implicitHeight: monButton.implicitHeight
    width: implicitWidth
    height: implicitHeight

    BarButton {
        id: monButton
        icon: root.service.icon
        iconSize: root.iconSize
        accentActive: false
        active: monPopup.open
        onClicked: {
            root.toggle()
        }
    }

    function toggle() {
        monPopup.toggle()
        if (monPopup.open) root.service.refresh()
    }

    Connections {
        target: monPopup
        function onOpenChanged() {
            root.service.menuOpen = monPopup.open
            if (monPopup.open) {
                root.service.inhibitOsd(2500)
            } else {
                root.service.inhibitOsd(1500)
            }
        }
    }

    PopupCard {
        id: monPopup
        anchorItem: monButton
        showDefaultHeader: false
        contentWidth: 350
        contentHeight: mainCol.implicitHeight + 30

        Column {
            id: mainCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
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
                            text: "󰍹"
                            font.family: Icons.effectiveFont("󰍹")
                            font.pixelSize: 22
                            color: Theme.accent
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Display"
                            font.family: Fonts.uiFont
                            font.pixelSize: 15
                            font.bold: true
                            color: Theme.bright_foreground
                        }

                        Text {
                            text: (root.service.brightnessName && root.service.brightnessName.toUpperCase() !== "SUN BLAST") ? ("SUN BLAST · " + root.service.brightnessName.toUpperCase()) : "SUN BLAST"
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                            color: Theme.muted
                            opacity: 0.75
                        }
                    }
                }
            }

            // ================= 2. BRIGHTNESS (Tonal Container Card) =================
            Rectangle {
                width: parent.width
                height: 64
                radius: 12
                color: Theme.surfaceContainer

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "BRIGHTNESS"
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                            color: Theme.muted
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.service.brightness + "%"
                            font.family: Fonts.monoFont
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.bright_foreground
                        }
                    }

                    // Thick M3 Continuous Slider
                    Item {
                        id: brightSliderItem
                        width: parent.width
                        height: 20

                        Rectangle {
                            id: bTrack
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 14
                            radius: 7
                            color: Theme.surfaceContainerHigh
                            clip: true

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(0, Math.min(parent.width, parent.width * (root.service.brightness / 100.0)))
                                radius: 7
                                color: Theme.accent

                                Behavior on width {
                                    enabled: !bMouse.pressed
                                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        // M3 Vertical Pill Thumb
                        Rectangle {
                            id: bKnob
                            width: 4
                            height: 20
                            radius: 2
                            color: Theme.bright_foreground
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(brightSliderItem.width - width, (brightSliderItem.width * (root.service.brightness / 100.0)) - (width / 2)))

                            scale: bMouse.containsMouse || bMouse.pressed ? 1.25 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Behavior on x {
                                enabled: !bMouse.pressed
                                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: bMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function updateFromPos(mouseX) {
                                root.service.inhibitOsd(2000)
                                var pct = Math.max(1, Math.min(100, Math.round((mouseX / brightSliderItem.width) * 100)))
                                root.service.setBrightness(pct)
                            }

                            onPressed: function(mouse) { updateFromPos(mouse.x) }
                            onPositionChanged: function(mouse) {
                                if (pressed) updateFromPos(mouse.x)
                            }
                        }
                    }
                }
            }

            // ================= 3. TEXT SIZE (Tonal Container with Tick Dots) =================
            Rectangle {
                width: parent.width
                height: 64
                radius: 12
                color: Theme.surfaceContainer

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "TEXT SIZE"
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                            color: Theme.muted
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.service.textSize + "px"
                            font.family: Fonts.monoFont
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.bright_foreground
                        }
                    }

                    // Thick M3 Stepped Slider with Tick Dots
                    Item {
                        id: textSliderItem
                        width: parent.width
                        height: 20

                        readonly property int dotInset: 10
                        readonly property var stops: root.service.textSizeStops
                        readonly property int activeIndex: {
                            var idx = stops.indexOf(root.service.textSize)
                            if (idx >= 0) return idx
                            var best = 0
                            var bestDiff = 1e9
                            for (var i = 0; i < stops.length; i++) {
                                var d = Math.abs(stops[i] - root.service.textSize)
                                if (d < bestDiff) {
                                    bestDiff = d
                                    best = i
                                }
                            }
                            return best
                        }

                        Rectangle {
                            id: tTrack
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 14
                            radius: 7
                            color: Theme.surfaceContainerHigh
                            clip: true

                            // Filled portion (up to the center of active thumb)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: {
                                    var count = textSliderItem.stops.length
                                    if (count <= 1) return 0
                                    var ratio = textSliderItem.activeIndex / (count - 1)
                                    var usableW = tTrack.width - (2 * textSliderItem.dotInset)
                                    return Math.round(textSliderItem.dotInset + (ratio * usableW))
                                }
                                radius: 7
                                color: Theme.accent

                                Behavior on width {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                }
                            }

                            // Circular 4x4 Tick Dots inside track (inset past rounded end-caps)
                            Repeater {
                                model: textSliderItem.stops.length

                                Rectangle {
                                    required property int index
                                    width: 4
                                    height: 4
                                    radius: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: {
                                        var count = textSliderItem.stops.length
                                        if (count <= 1) return textSliderItem.dotInset - 2
                                        var ratio = index / (count - 1)
                                        var usableW = tTrack.width - (2 * textSliderItem.dotInset)
                                        return Math.round(textSliderItem.dotInset + (ratio * usableW) - 2)
                                    }
                                    color: (index <= textSliderItem.activeIndex) ? Theme.surfaceBase : Theme.bright_foreground
                                    opacity: (index <= textSliderItem.activeIndex) ? 0.85 : 0.45
                                }
                            }
                        }

                        // M3 Vertical Pill Thumb
                        Rectangle {
                            id: tKnob
                            width: 4
                            height: 20
                            radius: 2
                            color: Theme.bright_foreground
                            anchors.verticalCenter: parent.verticalCenter
                            x: {
                                var count = textSliderItem.stops.length
                                if (count <= 1) return textSliderItem.dotInset - 2
                                var ratio = textSliderItem.activeIndex / (count - 1)
                                var usableW = textSliderItem.width - (2 * textSliderItem.dotInset)
                                return Math.round(textSliderItem.dotInset + (ratio * usableW) - 2)
                            }

                            scale: tMouse.containsMouse || tMouse.pressed ? 1.25 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Behavior on x {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }
                        }

                        MouseArea {
                            id: tMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function updateFromPos(mouseX) {
                                var count = textSliderItem.stops.length
                                if (count <= 1) return
                                var usableW = textSliderItem.width - (2 * textSliderItem.dotInset)
                                var relX = mouseX - textSliderItem.dotInset
                                var ratio = Math.max(0, Math.min(1.0, relX / usableW))
                                var nearestIndex = Math.round(ratio * (count - 1))
                                var newSize = textSliderItem.stops[nearestIndex]
                                if (newSize !== root.service.textSize) {
                                    root.service.setTextSize(newSize)
                                }
                            }

                            onPressed: function(mouse) { updateFromPos(mouse.x) }
                            onPositionChanged: function(mouse) {
                                if (pressed) updateFromPos(mouse.x)
                            }
                        }
                    }
                }
            }

            // ================= 4. SCALE (M3 Segmented Button Row) =================
            Column {
                width: parent.width
                spacing: 6

                Item {
                    width: parent.width
                    height: 16

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SCALE"
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1
                        color: Theme.muted
                    }

                    Text {
                        visible: root.service.displays.length > 1
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.service.focusedMonitor
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        color: Theme.dark_foreground
                    }
                }

                Row {
                    id: scaleRow
                    width: parent.width
                    spacing: 3

                    readonly property int count: root.service.scalePresets.length
                    readonly property real segWidth: (width - (spacing * (count - 1))) / count

                    Repeater {
                        model: root.service.scalePresets

                        Rectangle {
                            id: scalePill
                            required property string modelData
                            required property int index

                            readonly property bool isActive: {
                                var cur = parseFloat(root.service.scale)
                                var tgt = parseFloat(modelData)
                                return !isNaN(cur) && !isNaN(tgt) && Math.abs(cur - tgt) < 0.05
                            }
                            readonly property bool isFirst: index === 0
                            readonly property bool isLast: index === (scaleRow.count - 1)

                            width: scaleRow.segWidth
                            height: 32

                            topLeftRadius: isActive ? 12 : (isFirst ? 12 : 4)
                            bottomLeftRadius: isActive ? 12 : (isFirst ? 12 : 4)
                            topRightRadius: isActive ? 12 : (isLast ? 12 : 4)
                            bottomRightRadius: isActive ? 12 : (isLast ? 12 : 4)

                            color: isActive ? Theme.secondaryContainer : (pillMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on topLeftRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomLeftRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on topRightRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomRightRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: scalePill.modelData + "x"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: scalePill.isActive
                                color: scalePill.isActive ? Theme.accent : Theme.foreground
                            }

                            MouseArea {
                                id: pillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.service.setScale(scalePill.modelData)
                            }
                        }
                    }
                }
            }

            // ================= 5. REFRESH RATE (M3 Segmented Button Row) =================
            Column {
                width: parent.width
                spacing: 6

                Item {
                    width: parent.width
                    height: 16

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "REFRESH RATE"
                        font.family: Fonts.uiFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1
                        color: Theme.muted
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            visible: root.service.displays.length > 1
                            text: root.service.activeMonitorName
                            font.family: Fonts.uiFont
                            font.pixelSize: 10
                            color: Theme.dark_foreground
                        }

                        Text {
                            text: root.service.currentRefreshRate + "Hz"
                            font.family: Fonts.monoFont
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.bright_foreground
                        }
                    }
                }

                Row {
                    id: hzRow
                    width: parent.width
                    spacing: 3

                    readonly property int maxHz: root.service.maxRefreshRate
                    readonly property bool canSwitch: maxHz > 60
                    readonly property real segWidth: canSwitch ? (width - spacing) / 2 : width

                    // 60 Hz Pill
                    Rectangle {
                        id: hz60Pill
                        width: hzRow.segWidth
                        height: 32

                        readonly property bool isActive: Math.abs(root.service.currentRefreshRate - 60) <= 2

                        topLeftRadius: isActive ? 12 : 12
                        bottomLeftRadius: isActive ? 12 : 12
                        topRightRadius: isActive ? 12 : (hzRow.canSwitch ? 4 : 12)
                        bottomRightRadius: isActive ? 12 : (hzRow.canSwitch ? 4 : 12)

                        color: isActive ? Theme.secondaryContainer : (p60Mouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on topLeftRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on bottomLeftRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on topRightRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on bottomRightRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: "60 Hz" + (hzRow.canSwitch ? "" : " (Max)")
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            font.bold: hz60Pill.isActive
                            color: hz60Pill.isActive ? Theme.accent : Theme.foreground
                        }

                        MouseArea {
                            id: p60Mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.setRefreshRate(60)
                        }
                    }

                    // Max Hz Pill (shown if maxHz > 60)
                    Rectangle {
                        id: hzMaxPill
                        visible: hzRow.canSwitch
                        width: hzRow.segWidth
                        height: 32

                        readonly property bool isActive: Math.abs(root.service.currentRefreshRate - hzRow.maxHz) <= 2

                        topLeftRadius: isActive ? 12 : 4
                        bottomLeftRadius: isActive ? 12 : 4
                        topRightRadius: isActive ? 12 : 12
                        bottomRightRadius: isActive ? 12 : 12

                        color: isActive ? Theme.secondaryContainer : (pMaxMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on topLeftRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on bottomLeftRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on topRightRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on bottomRightRadius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: hzRow.maxHz + " Hz (Max)"
                            font.family: Fonts.uiFont
                            font.pixelSize: 11
                            font.bold: hzMaxPill.isActive
                            color: hzMaxPill.isActive ? Theme.accent : Theme.foreground
                        }

                        MouseArea {
                            id: pMaxMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.setRefreshRate(hzRow.maxHz)
                        }
                    }
                }
            }

            // ================= 6. DISPLAYS (Multiple Monitors) =================
            Column {
                visible: root.service.displays.length > 1
                width: parent.width
                spacing: 6

                Text {
                    text: "DISPLAYS"
                    font.family: Fonts.uiFont
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1
                    color: Theme.muted
                }

                Repeater {
                    model: root.service.displays

                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 36
                        radius: 12
                        color: modelData.focused ? Theme.secondaryContainer : (dispMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: "󰍹"
                                font.family: Icons.effectiveFont("󰍹")
                                font.pixelSize: 14
                                color: modelData.focused ? Theme.accent : Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.name + (modelData.focused ? " · active" : "") + " (" + modelData.refreshRate + "Hz)"
                                font.family: Fonts.uiFont
                                font.pixelSize: 11
                                font.bold: modelData.focused
                                color: modelData.focused ? Theme.bright_foreground : Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: dispMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.selectDisplay(modelData.name)
                        }
                    }
                }
            }
        }
    }
}
