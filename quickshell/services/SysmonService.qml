import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    // When active is true, poll timer runs every 1500ms; when false, polls stop to conserve resources
    property bool active: false

    // CPU Metrics
    property real cpuUsage: 0.0
    property int cpuTemp: 0
    property int cpuCores: 1

    // RAM Metrics
    property real ramPercent: 0.0
    property string ramUsedStr: "0 GB"
    property string ramTotalStr: "0 GB"

    // Storage Metrics
    property real storagePercent: 0.0
    property string storageUsedStr: "0 GB"
    property string storageTotalStr: "0 GB"

    // Network Metrics
    property int netRxRate: 0
    property int netTxRate: 0
    property string netRxStr: "0 B/s"
    property string netTxStr: "0 B/s"

    function refresh() {
        if (!statsProc.running) {
            statsProc.running = true
        }
    }

    onActiveChanged: {
        if (active) {
            refresh()
            pollTimer.restart()
        } else {
            pollTimer.stop()
        }
    }

    property Timer pollTimer: Timer {
        id: pollTimer
        interval: 1500
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

    property Process statsProc: Process {
        id: statsProc
        command: ["qdeck-sysmon-stats"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim())
                    if (data) {
                        if (data.cpu) {
                            if (typeof data.cpu.usage === "number") root.cpuUsage = data.cpu.usage
                            if (typeof data.cpu.temp === "number") root.cpuTemp = data.cpu.temp
                            if (typeof data.cpu.cores === "number") root.cpuCores = data.cpu.cores
                        }
                        if (data.ram) {
                            if (typeof data.ram.percent === "number") root.ramPercent = data.ram.percent
                            if (data.ram.usedStr) root.ramUsedStr = data.ram.usedStr
                            if (data.ram.totalStr) root.ramTotalStr = data.ram.totalStr
                        }
                        if (data.storage) {
                            if (typeof data.storage.percent === "number") root.storagePercent = data.storage.percent
                            if (data.storage.usedStr) root.storageUsedStr = data.storage.usedStr
                            if (data.storage.totalStr) root.storageTotalStr = data.storage.totalStr
                        }
                        if (data.network) {
                            if (typeof data.network.rxRate === "number") root.netRxRate = data.network.rxRate
                            if (typeof data.network.txRate === "number") root.netTxRate = data.network.txRate
                            if (data.network.rxStr) root.netRxStr = data.network.rxStr
                            if (data.network.txStr) root.netTxStr = data.network.txStr
                        }
                    }
                } catch (e) {
                    // Ignore transient parsing errors
                }
            }
        }
    }
}
