import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"

Item {
    id: root

    readonly property string fontFamily: Fonts.uiFont
    readonly property string monoFont: Fonts.monoFont

    signal requestClose()

    property string filterText: ""
    property bool isSearching: false
    property bool isInstalling: false
    property bool installSuccess: false
    property bool installFailed: false
    property string activePackage: ""
    property int activeExitCode: 0
    property int searchGen: 0
    property bool pendingSearchRestart: false
    property string pendingSearchQuery: ""

    property int selectedIndex: 0

    ListModel {
        id: resultsModel
    }

    ListModel {
        id: logModel
    }

    function focusSearch() {
        searchInput.forceActiveFocus()
    }

    function setInitialQuery(q) {
        var query = (typeof q === "string") ? q.trim() : ""
        resetState()
        root.filterText = query
        searchInput.text = query
        if (query.length > 0) {
            searchDebounce.restart()
        }
        Qt.callLater(function() {
            searchInput.forceActiveFocus()
        })
    }

    function resetState() {
        if (installProc.running) {
            cancelInstall()
        }
        if (searchProc.running) {
            searchProc.running = false
        }
        pendingSearchRestart = false
        pendingSearchQuery = ""
        isSearching = false
        isInstalling = false
        installSuccess = false
        installFailed = false
        activePackage = ""
        activeExitCode = 0
        logModel.clear()
    }

    function insertRankedResult(item) {
        var newRank = (item.rank !== undefined) ? item.rank : 99
        var newLen = item.name.length
        for (var i = 0; i < resultsModel.count; i++) {
            var cur = resultsModel.get(i)
            if (cur.name === item.name) return // deduplicate
            var curRank = (cur.rank !== undefined) ? cur.rank : 99
            if (newRank < curRank || (newRank === curRank && newLen < cur.name.length)) {
                resultsModel.insert(i, item)
                return
            }
        }
        resultsModel.append(item)
    }

    function triggerSearch() {
        var q = root.filterText.trim()
        root.searchGen += 1
        resultsModel.clear()
        root.selectedIndex = 0

        if (q.length === 0) {
            root.pendingSearchRestart = false
            root.pendingSearchQuery = ""
            root.isSearching = false
            if (searchProc.running) {
                searchProc.running = false
            }
            return
        }

        root.isSearching = true
        if (searchProc.running) {
            // Wait for onExited before spawning the next process
            root.pendingSearchQuery = q
            root.pendingSearchRestart = true
            searchProc.running = false
        } else {
            root.pendingSearchRestart = false
            searchProc.command = ["qdeck-pkg-search", "--gen", String(root.searchGen), q]
            searchProc.running = true
        }
    }

    function installPackage(pkgName) {
        if (!pkgName || pkgName.trim().length === 0) return
        var name = pkgName.trim()
        root.activePackage = name
        root.isInstalling = true
        root.installSuccess = false
        root.installFailed = false
        root.activeExitCode = 0
        logModel.clear()
        logModel.append({ text: "==> Initiating installation of: " + name })

        installProc.command = ["qdeck-pkg-install", name]
        installProc.running = true
    }

    function cancelInstall() {
        Quickshell.execDetached(["qdeck-pkg-install", "--cancel"])
        if (installProc.running) {
            installProc.running = false
        }
        logModel.append({ text: "==> Installation cancelled by user." })
        root.isInstalling = false
        root.installSuccess = false
        root.installFailed = false
    }

    function handleConfirmKey() {
        if (root.isInstalling) return
        if (root.installSuccess || root.installFailed) {
            root.resetState()
            return
        }
        if (resultsModel.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < resultsModel.count) {
            var item = resultsModel.get(root.selectedIndex)
            if (item && item.name) {
                root.installPackage(item.name)
            }
        }
    }

    Timer {
        id: searchDebounce
        interval: 260
        repeat: false
        onTriggered: root.triggerSearch()
    }

    Process {
        id: searchProc
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                var clean = line.trim()
                if (!clean) return
                try {
                    var item = JSON.parse(clean)
                    if (!item || !item.name) return
                    if (item.gen !== undefined && item.gen !== root.searchGen) return
                    root.insertRankedResult(item)
                } catch (e) {}
            }
        }
        onExited: function(exitCode, exitStatus) {
            if (root.pendingSearchRestart && root.pendingSearchQuery.length > 0) {
                var nextQ = root.pendingSearchQuery
                root.pendingSearchRestart = false
                root.pendingSearchQuery = ""
                root.isSearching = true
                searchProc.command = ["qdeck-pkg-search", "--gen", String(root.searchGen), nextQ]
                searchProc.running = true
            } else {
                root.isSearching = false
            }
        }
    }

    Process {
        id: installProc
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                if (line && line.length > 0) {
                    if (logModel.count >= 400) {
                        logModel.remove(0, 50)
                    }
                    logModel.append({ text: line })
                    if (logListView.count > 0) {
                        logListView.positionViewAtEnd()
                    }
                }
            }
        }
        onExited: function(exitCode, exitStatus) {
            root.isInstalling = false
            root.activeExitCode = exitCode
            if (exitCode === 0) {
                root.installSuccess = true
                for (var i = 0; i < resultsModel.count; i++) {
                    if (resultsModel.get(i).name === root.activePackage) {
                        resultsModel.setProperty(i, "installed", true)
                        break
                    }
                }
            } else {
                root.installFailed = true
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Header Bar (Search summary & Quick Cancel)
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: headerBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 14
            leftMargin: 16
            rightMargin: 16
        }
        height: 34

        RowLayout {
            anchors.fill: parent
            spacing: 10

            // Icon & Title
            RowLayout {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: "󰏖"
                    font.family: root.fontFamily
                    font.pixelSize: 18
                    color: Theme.accent
                }

                Text {
                    text: root.isInstalling ? ("Installing " + root.activePackage) : "Package Manager"
                    font.family: root.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                    color: Theme.bright_foreground
                }

                // Status pill
                Rectangle {
                    visible: !root.isInstalling && (resultsModel.count > 0 || root.isSearching)
                    radius: 8
                    border.width: 0
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.7)
                    implicitWidth: countText.implicitWidth + 14
                    implicitHeight: 22

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.isSearching ? "Searching..." : (resultsModel.count + " packages")
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: root.isSearching ? Theme.accent : Theme.muted
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Simple Top Cancel / Close Button
            Rectangle {
                id: topCancelBtn
                radius: 8
                border.width: 0
                color: topCancelMouse.hovered
                    ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.9)
                    : Theme.withAlpha(Theme.surfaceContainerHigh, 0.6)
                implicitWidth: topCancelLabel.implicitWidth + 18
                implicitHeight: 28

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "✕"
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        color: Theme.muted
                    }

                    Text {
                        id: topCancelLabel
                        text: root.isInstalling ? "Cancel Install" : "Close"
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.foreground
                    }
                }

                MouseArea {
                    id: topCancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.isInstalling) {
                            root.cancelInstall()
                        } else {
                            root.requestClose()
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main Body Area: Results List OR Live Install Console
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: contentArea
        anchors {
            top: headerBar.bottom
            bottom: searchContainer.top
            left: parent.left
            right: parent.right
            topMargin: 10
            bottomMargin: 10
            leftMargin: 14
            rightMargin: 14
        }

        // ── View A: Search & Package List ─────────────────────────────────────
        Item {
            anchors.fill: parent
            visible: !root.isInstalling && !root.installSuccess && !root.installFailed

            // Empty state hint
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: resultsModel.count === 0 && !root.isSearching

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰏖"
                    font.family: root.fontFamily
                    font.pixelSize: 42
                    color: Theme.withAlpha(Theme.muted, 0.5)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.filterText.trim().length > 0
                        ? "No packages found matching '" + root.filterText + "'"
                        : "Type to search packages from Arch Linux and AUR"
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    color: Theme.muted
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Press Enter to install selected package • Esc to cancel"
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    color: Theme.withAlpha(Theme.muted, 0.7)
                }
            }

            // Results List
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
                    readonly property bool isHovered: itemMouse.hovered
                    readonly property bool isOfficial: model.source === "official"

                    color: isSelected
                        ? Theme.withAlpha(Theme.accent, 0.18)
                        : (isHovered ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.6) : Theme.surfaceContainer)

                    Behavior on color {
                        ColorAnimation { duration: 120 }
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
                                text: model.description || "No description provided."
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                color: Theme.muted
                                elide: Text.ElideRight
                            }
                        }

                        // Right action pill
                        Rectangle {
                            visible: delegateRoot.isSelected || delegateRoot.isHovered
                            radius: 8
                            border.width: 0
                            color: Theme.accent
                            implicitWidth: actionText.implicitWidth + 14
                            implicitHeight: 26
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: actionText
                                anchors.centerIn: parent
                                text: model.installed ? "Reinstall ⏎" : "Install ⏎"
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.background
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = index
                            root.installPackage(model.name)
                        }
                    }
                }
            }
        }

        // ── View B: Live Installation Console ────────────────────────────────
        Item {
            anchors.fill: parent
            visible: root.isInstalling || root.installSuccess || root.installFailed

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                // Installation Status Header
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: 12
                    border.width: 0
                    color: root.installSuccess
                        ? Theme.withAlpha(Theme.green, 0.15)
                        : (root.installFailed ? Theme.withAlpha(Theme.red, 0.15) : Theme.surfaceContainer)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: root.installSuccess ? "✓" : (root.installFailed ? "✕" : "󱑑")
                            font.family: root.fontFamily
                            font.pixelSize: 20
                            color: root.installSuccess ? Theme.green : (root.installFailed ? Theme.red : Theme.accent)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: root.installSuccess
                                    ? ("Successfully installed " + root.activePackage)
                                    : (root.installFailed
                                        ? ("Failed to install " + root.activePackage + " (Exit code: " + root.activeExitCode + ")")
                                        : ("Installing " + root.activePackage + "..."))
                                font.family: root.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                color: root.installSuccess ? Theme.green : (root.installFailed ? Theme.red : Theme.bright_foreground)
                            }

                            Text {
                                text: root.installSuccess
                                    ? "Package is now installed and ready to use."
                                    : (root.installFailed
                                        ? "Review log output below for details."
                                        : "Processing dependencies, build files, and package installation via yay...")
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                color: Theme.muted
                            }
                        }

                        // Cancel / Back Button inside Header
                        Rectangle {
                            radius: 8
                            border.width: 0
                            color: root.isInstalling
                                ? Theme.withAlpha(Theme.red, 0.20)
                                : Theme.withAlpha(Theme.surfaceContainerHighest, 0.8)
                            implicitWidth: actionBtnText.implicitWidth + 18
                            implicitHeight: 28

                            Text {
                                id: actionBtnText
                                anchors.centerIn: parent
                                text: root.isInstalling ? "Cancel" : "Back to Search"
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: root.isInstalling ? Theme.red : Theme.bright_foreground
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.isInstalling) {
                                        root.cancelInstall()
                                    } else {
                                        root.resetState()
                                    }
                                }
                            }
                        }
                    }
                }

                // Log Box Container
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    border.width: 0
                    color: Theme.withAlpha(Theme.dark_background, 0.98)
                    clip: true

                    ListView {
                        id: logListView
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 2
                        model: logModel

                        delegate: Text {
                            width: logListView.width
                            text: model.text || ""
                            font.family: root.monoFont
                            font.pixelSize: 12
                            readonly property bool isErrorLine: /^(error:|==> ERROR:|:: error|fatal:|Failed to )/i.test(text.trim())
                            readonly property bool isHeaderLine: /^(==>|->)/.test(text.trim())

                            color: isErrorLine ? Theme.red : (isHeaderLine ? Theme.accent : Theme.foreground)
                            wrapMode: Text.WrapAnywhere
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
                color: root.isSearching ? Theme.accent : Theme.muted
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
                        searchDebounce.restart()
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
                        if (root.isInstalling) {
                            root.cancelInstall()
                        } else if (root.installSuccess || root.installFailed) {
                            root.resetState()
                        } else if (searchInput.text.length > 0) {
                            searchInput.text = ""
                            root.filterText = ""
                            resultsModel.clear()
                        } else {
                            root.requestClose()
                        }
                    }
                }
            }

            // Simple Bottom Cancel Button
            Rectangle {
                id: bottomCancelBtn
                radius: 10
                border.width: 0
                color: bottomCancelMouse.hovered
                    ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.9)
                    : Theme.withAlpha(Theme.surfaceContainerHigh, 0.7)
                implicitWidth: bottomCancelText.implicitWidth + 20
                implicitHeight: 34
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: bottomCancelText
                    anchors.centerIn: parent
                    text: root.isInstalling ? "Cancel Install" : "Cancel"
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: root.isInstalling ? Theme.red : Theme.foreground
                }

                MouseArea {
                    id: bottomCancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.isInstalling) {
                            root.cancelInstall()
                        } else {
                            root.requestClose()
                        }
                    }
                }
            }
        }
    }
}
