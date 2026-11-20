import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/launcher/LauncherModel.js" as LauncherModel

Item {
    id: root

    // Installation states
    property bool isInstalling: false
    property bool installSuccess: false
    property bool installFailed: false
    property string activePackage: ""
    property int activeExitCode: 0

    // Visibility of bar pill
    readonly property bool showPill: isInstalling || installSuccess || installFailed

    // Track whether the bar popup is actively open to avoid auto-dismissing under the user
    property bool isPopupOpen: false

    // Live terminal output lines
    property alias logModel: logModel

    ListModel {
        id: logModel
    }

    // Auto-dismiss timer on success (14s)
    Timer {
        id: autoDismissTimer
        interval: 14000
        repeat: false
        onTriggered: {
            if (root.installSuccess && !root.isInstalling && !root.isPopupOpen) {
                root.dismiss()
            }
        }
    }

    onIsPopupOpenChanged: {
        // If popup was closed after success, restart auto-dismiss timer
        if (!root.isPopupOpen && root.installSuccess && !root.isInstalling) {
            autoDismissTimer.restart()
        }
    }

    // Process to run installation
    Process {
        id: installProc
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                if (line && line.length > 0) {
                    if (logModel.count >= 600) {
                        logModel.remove(0, 50)
                    }
                    logModel.append({ text: line })
                }
            }
        }

        stderr: SplitParser {
            onRead: function(line) {
                if (line && line.length > 0) {
                    if (logModel.count >= 600) {
                        logModel.remove(0, 50)
                    }
                    logModel.append({ text: line })
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            root.isInstalling = false
            root.activeExitCode = exitCode
            if (exitCode === 0) {
                root.installSuccess = true
                root.installFailed = false
                if (root.installedMap && root.activePackage) {
                    root.installedMap[root.activePackage] = true
                }
                root.packageInstalled(root.activePackage)
                root.refreshInstalledPackages()
                if (!root.isPopupOpen) {
                    autoDismissTimer.restart()
                }
            } else {
                root.installSuccess = false
                root.installFailed = true
                root.packageFailed(root.activePackage, exitCode)
            }
        }
    }

    // Public Signals
    signal packageInstalled(string name)
    signal packageFailed(string name, int exitCode)
    signal installedRefreshed()
    signal requestToggle()

    // Public methods
    function installPackage(pkgName) {
        if (!pkgName || pkgName.trim().length === 0) return
        var name = pkgName.trim()
        autoDismissTimer.stop()
        if (installProc.running) {
            cancelInstall()
        }
        root.activePackage = name
        root.isInstalling = true
        root.installSuccess = false
        root.installFailed = false
        root.activeExitCode = 0
        logModel.clear()
        logModel.append({ text: "==> Initiating installation of: " + name })

        installProc.command = ["qdeck-pkg", "install", name]
        installProc.running = true
    }

    function cancelInstall() {
        Quickshell.execDetached(["qdeck-pkg", "cancel"])
        if (installProc.running) {
            installProc.running = false
        }
        logModel.append({ text: "==> Installation cancelled by user." })
        root.isInstalling = false
        root.installSuccess = false
        root.installFailed = true
        root.activeExitCode = 130
    }

    function dismiss() {
        autoDismissTimer.stop()
        if (root.isInstalling) {
            cancelInstall()
        }
        root.installSuccess = false
        root.installFailed = false
        root.activePackage = ""
        root.activeExitCode = 0
    }

    // Installed packages tracking via pacman hook & stamp
    property var installedMap: ({})
    property string pkgStampPath: ""
    property bool isRefreshingInstalled: false
    property bool installedRefreshPending: false

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
                root.installedRefreshed()
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

    function refreshInstalledPackages() {
        if (root.isRefreshingInstalled || installedProc.running) {
            root.installedRefreshPending = true
            return
        }
        root.isRefreshingInstalled = true
        root.installedRefreshPending = false
        installedProc.running = true
    }

    IpcHandler {
        target: "pkgservice"
        function install(pkgName: string): string {
            root.installPackage(pkgName)
            return "ok"
        }
        function cancel(): string {
            root.cancelInstall()
            return "ok"
        }
        function dismiss(): string {
            root.dismiss()
            return "ok"
        }
        function toggle(): string {
            root.requestToggle()
            return "ok"
        }
        function status(): string {
            return root.isInstalling ? ("installing:" + root.activePackage) : (root.installSuccess ? "success" : (root.installFailed ? "failed" : "idle"))
        }
    }

    Component.onCompleted: {
        initStampProc.running = true
        refreshInstalledPackages()
    }
}
