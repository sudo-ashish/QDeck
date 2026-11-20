import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "LauncherModel.js" as LauncherModel

Item {
    id: root

    readonly property string fontFamily: Fonts.uiFont
    readonly property string monoFont: Fonts.monoFont

    signal requestClose()

    property PackageService packageService: null
    property string filterText: ""
    readonly property int resultCount: resultsModel.count

    property int selectedIndex: 0
    property alias resultsModel: resultsModel

    property var pkgIndexList: []
    property var installedMap: (root.packageService && root.packageService.installedMap) ? root.packageService.installedMap : ({})
    property var descCache: ({})
    property string pkgStampPath: ""
    property bool isRefreshingInstalled: false
    property bool installedRefreshPending: false

    readonly property string cacheDir: {
        var xdg = Quickshell.env("XDG_CACHE_HOME")
        if (xdg && xdg.length > 0) return xdg + "/qdeck"
        var home = Quickshell.env("HOME") || ""
        return home + "/.cache/qdeck"
    }
    readonly property string indexFilePath: cacheDir + "/pkg-index.tsv"

    ListModel {
        id: resultsModel
    }

    Connections {
        target: root.packageService
        function onInstalledRefreshed() {
            if (root.packageService) {
                root.installedMap = root.packageService.installedMap
                for (var i = 0; i < resultsModel.count; i++) {
                    var pkgName = resultsModel.get(i).name
                    var isInst = !!(root.installedMap && root.installedMap[pkgName])
                    if (resultsModel.get(i).installed !== isInst) {
                        resultsModel.setProperty(i, "installed", isInst)
                    }
                }
            }
        }
    }

    FileView {
        id: indexFileView
        path: root.indexFilePath
        printErrors: false
        watchChanges: true
        onLoaded: {
            var raw = text()
            if (raw && raw.length > 0) {
                root.loadIndexData(raw)
            }
        }
    }

    Process {
        id: indexSyncProc
        command: ["qdeck-pkg", "index"]
        onExited: function(exitCode, exitStatus) {
            if (root.pkgIndexList.length === 0) {
                var raw = indexFileView.text()
                if (raw && raw.length > 0) {
                    root.loadIndexData(raw)
                }
            }
        }
    }

    FileView {
        id: pkgStampView
        path: root.pkgStampPath
        watchChanges: true
        preload: false
        printErrors: false
        onFileChanged: reloadDebounce.restart()
    }

    Timer {
        id: reloadDebounce
        interval: 800
        repeat: false
        onTriggered: {
            root.refreshInstalledPackages()
        }
    }

    Process {
        id: initStampProc
        command: ["touch", "/tmp/qs-pkg-stamp"]
        onExited: function(exitCode, exitStatus) {
            root.pkgStampPath = "/tmp/qs-pkg-stamp"
        }
    }

    Process {
        id: installedProc
        command: ["pacman", "-Qq"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.installedMap = LauncherModel.parseInstalledPackages(text)
                for (var i = 0; i < resultsModel.count; i++) {
                    var pkgName = resultsModel.get(i).name
                    var isInst = !!(root.installedMap && root.installedMap[pkgName])
                    if (resultsModel.get(i).installed !== isInst) {
                        resultsModel.setProperty(i, "installed", isInst)
                    }
                }
            }
        }
        onExited: function(exitCode, exitStatus) {
            root.isRefreshingInstalled = false
            if (root.installedRefreshPending) {
                root.installedRefreshPending = false
                Qt.callLater(function() {
                    root.refreshInstalledPackages()
                })
            }
        }
    }

    Timer {
        id: descTimer
        interval: 150
        repeat: false
        onTriggered: {
            root.fetchDescriptionForCurrent()
        }
    }

    Process {
        id: infoProc
        running: false
        property string targetName: ""

        stdout: SplitParser {
            onRead: function(line) {
                var clean = line.trim()
                if (!clean) return
                try {
                    var data = JSON.parse(clean)
                    if (!data || !data.name) return
                    var name = data.name
                    var desc = data.description || ""
                    var ver = data.version || ""

                    root.descCache[name] = {
                        description: desc,
                        version: ver
                    }

                    for (var i = 0; i < resultsModel.count; i++) {
                        var cur = resultsModel.get(i)
                        if (cur.name === name) {
                            if (desc) {
                                resultsModel.setProperty(i, "description", desc)
                            }
                            if (ver && (!cur.version || cur.version.length === 0)) {
                                resultsModel.setProperty(i, "version", ver)
                            }
                            break
                        }
                    }
                } catch (e) {}
            }
        }
    }

    function refreshInstalledPackages() {
        if (root.isRefreshingInstalled || installedProc.running) {
            root.installedRefreshPending = true
            return
        }
        root.isRefreshingInstalled = true
        root.installedRefreshPending = false
        installedProc.running = true
    }

    function loadIndexData(rawTsv) {
        if (!rawTsv) return
        root.pkgIndexList = LauncherModel.parsePackageIndex(rawTsv)
        if (root.filterText.trim().length > 0) {
            root.applyFilter()
        }
    }

    function ensureLoaded() {
        if (root.pkgIndexList.length === 0) {
            var raw = indexFileView.text()
            if (raw && raw.length > 0) {
                root.loadIndexData(raw)
            } else if (!indexSyncProc.running) {
                indexSyncProc.running = true
            }
        }
        if (Object.keys(root.installedMap).length === 0) {
            root.refreshInstalledPackages()
        }
    }

    function applyFilter() {
        var q = root.filterText.trim()
        root.selectedIndex = 0
        if (q.length === 0) {
            resultsModel.clear()
            if (infoProc.running) infoProc.running = false
            descTimer.stop()
            return
        }

        var matches = LauncherModel.filterPackages(root.pkgIndexList, q, root.installedMap, 80)
        resultsModel.clear()
        for (var i = 0; i < matches.length; i++) {
            var m = matches[i]
            var cached = root.descCache[m.name]
            resultsModel.append({
                name: m.name,
                version: (cached && cached.version) ? cached.version : m.version,
                source: m.source,
                repo: m.repo,
                installed: m.installed,
                description: (cached && cached.description) ? cached.description : ""
            })
        }

        if (resultsModel.count > 0) {
            var first = resultsModel.get(0)
            if (first && root.descCache[first.name]) {
                var c = root.descCache[first.name]
                if (c.description) resultsModel.setProperty(0, "description", c.description)
                if (c.version && (!first.version || first.version.length === 0)) resultsModel.setProperty(0, "version", c.version)
            } else {
                descTimer.restart()
            }
        }
    }

    function fetchDescriptionForCurrent() {
        if (root.selectedIndex < 0 || root.selectedIndex >= resultsModel.count) return
        var item = resultsModel.get(root.selectedIndex)
        if (!item || !item.name) return
        var name = item.name
        var source = item.source || "official"

        if (root.descCache[name]) {
            var cached = root.descCache[name]
            if (cached.description && item.description !== cached.description) {
                resultsModel.setProperty(root.selectedIndex, "description", cached.description)
            }
            if (cached.version && item.version !== cached.version) {
                resultsModel.setProperty(root.selectedIndex, "version", cached.version)
            }
            return
        }

        if (infoProc.running) {
            infoProc.running = false
        }

        infoProc.targetName = name
        infoProc.command = ["qdeck-pkg", "info", source, name]
        infoProc.running = true
    }

    onSelectedIndexChanged: {
        if (resultsModel.count > 0 && selectedIndex >= 0 && selectedIndex < resultsModel.count) {
            var item = resultsModel.get(selectedIndex)
            if (item && item.name && root.descCache[item.name]) {
                var cached = root.descCache[item.name]
                if (cached.description) resultsModel.setProperty(selectedIndex, "description", cached.description)
                if (cached.version && (!item.version || item.version.length === 0)) resultsModel.setProperty(selectedIndex, "version", cached.version)
            } else {
                descTimer.restart()
            }
        }
    }

    function focusSearch() {
        searchInput.forceActiveFocus()
    }

    function setInitialQuery(q) {
        var query = (typeof q === "string") ? q.trim() : ""
        resetState()
        ensureLoaded()
        root.filterText = query
        searchInput.text = query
        root.applyFilter()
        Qt.callLater(function() {
            searchInput.forceActiveFocus()
        })
    }

    function resetState() {
        if (infoProc.running) {
            infoProc.running = false
        }
        descTimer.stop()
        filterText = ""
        searchInput.text = ""
        resultsModel.clear()
        selectedIndex = 0
    }

    function installPackage(pkgName) {
        if (!pkgName || pkgName.trim().length === 0) return
        var name = pkgName.trim()
        if (root.packageService) {
            root.packageService.installPackage(name)
        }
        root.requestClose()
    }

    function cancelInstall() {
        if (root.packageService) {
            root.packageService.cancelInstall()
        }
    }

    function handleConfirmKey() {
        if (resultsModel.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < resultsModel.count) {
            var item = resultsModel.get(root.selectedIndex)
            if (item && item.name) {
                root.installPackage(item.name)
            }
        }
    }

    Component.onCompleted: {
        initStampProc.running = true
        root.ensureLoaded()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main Body Area: Results List OR Live Install Console
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: contentArea
        anchors {
            top: parent.top
            bottom: searchContainer.top
            left: parent.left
            right: parent.right
            topMargin: 14
            bottomMargin: 10
            leftMargin: 14
            rightMargin: 14
        }

        // ── Search & Package List ──────────────────────────────────────────
        ListView {
            id: resultsListView
            anchors.fill: parent
            clip: true
            spacing: 4
            model: resultsModel
            currentIndex: root.selectedIndex

                delegate: Rectangle {
                    id: delegateRoot
                    width: resultsListView.width
                    height: 56
                    radius: 12
                    border.width: 0

                    readonly property bool isSelected: index === root.selectedIndex
                    readonly property bool isHovered: itemMouse.containsMouse || actionBtnMouse.containsMouse
                    readonly property bool isOfficial: model.source === "official"

                    color: isSelected
                        ? Theme.withAlpha(Theme.accent, 0.18)
                        : (isHovered ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.6) : Theme.surfaceContainer)

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    // Whole-card MouseArea for hover & selection
                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: {
                            if (root.selectedIndex !== index) {
                                root.selectedIndex = index
                            }
                        }
                        onClicked: {
                            root.selectedIndex = index
                            root.installPackage(model.name)
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        // Info column
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3

                            // Top line: Name + version + badges
                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Text {
                                    text: model.name || ""
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: delegateRoot.isSelected ? Theme.bright_foreground : Theme.foreground
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: model.version || ""
                                    font.family: root.monoFont
                                    font.pixelSize: 11
                                    color: Theme.muted
                                    elide: Text.ElideRight
                                }

                                // Source badge
                                Rectangle {
                                    radius: 6
                                    border.width: 0
                                    color: isOfficial
                                        ? Theme.withAlpha(Theme.accent, 0.20)
                                        : Theme.withAlpha(Theme.yellow, 0.20)
                                    implicitWidth: srcText.implicitWidth + 10
                                    implicitHeight: 18

                                    Text {
                                        id: srcText
                                        anchors.centerIn: parent
                                        text: isOfficial ? (model.repo ? model.repo.toUpperCase() : "OFFICIAL") : "AUR"
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: isOfficial ? Theme.accent : Theme.yellow
                                    }
                                }

                                // Installed badge
                                Rectangle {
                                    visible: model.installed === true
                                    radius: 6
                                    border.width: 0
                                    color: Theme.withAlpha(Theme.green, 0.22)
                                    implicitWidth: instText.implicitWidth + 10
                                    implicitHeight: 18

                                    Text {
                                        id: instText
                                        anchors.centerIn: parent
                                        text: "✓ Installed"
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: Theme.green
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // Bottom line: Description
                            Text {
                                Layout.fillWidth: true
                                text: {
                                    if (model.description && model.description.length > 0) {
                                        return model.description
                                    }
                                    if (delegateRoot.isSelected && infoProc.running && infoProc.targetName === model.name) {
                                        return "Loading description..."
                                    }
                                    return "No description provided."
                                }
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                color: Theme.muted
                                elide: Text.ElideRight
                            }
                        }

                        // Right action pill
                        Rectangle {
                            id: actionBtnPill
                            visible: delegateRoot.isSelected || delegateRoot.isHovered
                            radius: 8
                            border.width: 0
                            color: actionBtnMouse.containsMouse
                                ? Qt.lighter(Theme.accent, 1.15)
                                : Theme.accent
                            implicitWidth: actionText.implicitWidth + 14
                            implicitHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            z: 10

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            Text {
                                id: actionText
                                anchors.centerIn: parent
                                text: model.installed ? "Reinstall" : "Install"
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.background
                            }

                            MouseArea {
                                id: actionBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                propagateComposedEvents: false
                                onPressed: function(mouse) { mouse.accepted = true }
                                onReleased: function(mouse) { mouse.accepted = true }
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    root.selectedIndex = index
                                    root.installPackage(model.name)
                                }
                            }
                        }
                    }
                }
            }
        }

    // ─────────────────────────────────────────────────────────────────────────
    // Bottom Search Bar & Simple Cancel Button
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: searchContainer
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: 14
        }
        height: 56
        radius: 14
        color: Theme.withAlpha(Theme.dark_background, 0.95)
        border.width: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            spacing: 12

            Text {
                text: ""
                font.family: root.fontFamily
                font.pixelSize: 18
                color: (indexSyncProc.running && root.pkgIndexList.length === 0) ? Theme.accent : Theme.muted
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search packages from Arch & AUR..."
                    font.family: root.fontFamily
                    font.pixelSize: 15
                    color: Theme.muted
                    visible: searchInput.text.length === 0
                    elide: Text.ElideRight
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: root.fontFamily
                    font.pixelSize: 15
                    color: Theme.foreground
                    selectionColor: Theme.selection
                    selectedTextColor: Theme.bright_foreground
                    clip: true
                    focus: true

                    onTextChanged: {
                        root.filterText = text
                        root.applyFilter()
                    }

                    Keys.onDownPressed: {
                        if (resultsModel.count > 0) {
                            root.selectedIndex = (root.selectedIndex + 1) % resultsModel.count
                            resultsListView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        }
                    }

                    Keys.onUpPressed: {
                        if (resultsModel.count > 0) {
                            root.selectedIndex = (root.selectedIndex - 1 + resultsModel.count) % resultsModel.count
                            resultsListView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        }
                    }

                    Keys.onReturnPressed: root.handleConfirmKey()
                    Keys.onEnterPressed: root.handleConfirmKey()

                    Keys.onEscapePressed: {
                        if (searchInput.text.length > 0) {
                            searchInput.text = ""
                            root.filterText = ""
                            resultsModel.clear()
                        } else {
                            root.requestClose()
                        }
                    }

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_PageDown) {
                            if (resultsModel.count > 0) {
                                root.selectedIndex = Math.min(resultsModel.count - 1, root.selectedIndex + 5)
                                resultsListView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_PageUp) {
                            if (resultsModel.count > 0) {
                                root.selectedIndex = Math.max(0, root.selectedIndex - 5)
                                resultsListView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                            }
                            event.accepted = true
                        }
                    }
                }
            }

            // Background installation badge
            Rectangle {
                visible: root.packageService && root.packageService.isInstalling
                radius: 8
                border.width: 0
                color: Theme.withAlpha(Theme.accent, 0.20)
                implicitWidth: installingBadgeContent.implicitWidth + 16
                implicitHeight: 24
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: installingBadgeContent
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "󰑓"
                        font.family: Icons.effectiveFont("󰑓")
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.accent
                        RotationAnimation on rotation {
                            running: root.packageService && root.packageService.isInstalling
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 1000
                        }
                    }

                    Text {
                        text: "Installing " + (root.packageService ? root.packageService.activePackage : "") + " (in bar)"
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.accent
                    }
                }
            }

            // Indexing indicator badge
            Rectangle {
                visible: (indexSyncProc.running && root.pkgIndexList.length === 0)
                radius: 8
                border.width: 0
                color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.7)
                implicitWidth: searchBadgeText.implicitWidth + 14
                implicitHeight: 24
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: searchBadgeText
                    anchors.centerIn: parent
                    text: "Indexing..."
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.accent
                }
            }

            // Simple Bottom Close Button
            Rectangle {
                id: bottomCancelBtn
                radius: 10
                border.width: 0
                color: bottomCancelMouse.containsMouse
                    ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.9)
                    : Theme.withAlpha(Theme.surfaceContainerHigh, 0.7)
                implicitWidth: bottomCancelText.implicitWidth + 20
                implicitHeight: 34
                Layout.alignment: Qt.AlignVCenter

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Text {
                    id: bottomCancelText
                    anchors.centerIn: parent
                    text: "Close"
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: Theme.foreground
                }

                MouseArea {
                    id: bottomCancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.requestClose()
                    }
                }
            }
        }
    }
}
