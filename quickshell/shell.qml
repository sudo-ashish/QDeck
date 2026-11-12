//@ pragma IconTheme Yaru-blue
//@ pragma Env QS_NO_RELOAD_POPUP=1
import QtQuick
import Quickshell
import Quickshell.Io
import "theme"
import "components"
import "services"
import "modules/bar"
import "modules/bar/widgets"
import "modules/launcher"
import "modules/osd"
import "modules/notifications"
import "modules/polkit"

ShellRoot {
    id: root

    // Suppress intrusive Quickshell reload popup windows at both evaluation and runtime
    readonly property var _noReloadPopup: (typeof Quickshell.inhibitReloadPopup === "function") ? Quickshell.inhibitReloadPopup() : null
    Component.onCompleted: {
        if (typeof Quickshell.inhibitReloadPopup === "function") {
            Quickshell.inhibitReloadPopup()
        }
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() {
            if (typeof Quickshell.inhibitReloadPopup === "function") {
                Quickshell.inhibitReloadPopup()
            }
        }
        function onReloadFailed(errorString) {
            if (typeof Quickshell.inhibitReloadPopup === "function") {
                Quickshell.inhibitReloadPopup()
            }
        }
    }

    // Core Shared Services
    property WorkspacesService workspacesService: WorkspacesService { }
    property AudioService audioService: AudioService { }
    property BrightnessService brightnessService: BrightnessService { }
    property BatteryService batteryService: BatteryService { }
    property NetworkService networkService: NetworkService { }
    property BluetoothService bluetoothService: BluetoothService { }
    property PowerService powerService: PowerService { }
    property ThemeSwitcherService themeSwitcherService: ThemeSwitcherService { }
    property WallpaperSwitcherService wallpaperSwitcherService: WallpaperSwitcherService { }
    property ShelfService shelfService: ShelfService { id: shelfService }
    property ClipboardService clipboardService: ClipboardService { id: clipboardService }

    IpcHandler {
        target: "bar"

        function toggle(): string {
            Appearance.barVisible = !Appearance.barVisible
            return Appearance.barVisible ? "visible" : "hidden"
        }

        function hide(): string {
            Appearance.barVisible = false
            return "hidden"
        }

        function show(): string {
            Appearance.barVisible = true
            return "visible"
        }

        function isVisible(): string {
            return Appearance.barVisible ? "true" : "false"
        }
    }

    IpcHandler {
        target: "powerconfirm"
        function test(): string {
            root.powerService.requestShutdown(null)
            return "ok"
        }
        function cancel(): string {
            root.powerService.cancelConfirm()
            return "ok"
        }
    }

    // Unified Launcher: App Launcher, Power Session Menu, Theme Switcher, Wallpaper Picker & Staging Shelf
    AppLauncher {
        id: launcher
        powerService: root.powerService
        themeService: root.themeSwitcherService
        wallpaperService: root.wallpaperSwitcherService
        shelfService: root.shelfService
        clipboardService: root.clipboardService
    }

    // Power Confirmation Dialog (centered overlay)
    PowerConfirmDialog {
        id: powerConfirm
        powerService: root.powerService
    }

    // Polkit Authentication Agent (centered overlay)
    Polkit {
        id: polkit
    }

    // Windows Alt+Tab-style Workspace Switcher Overlay
    WorkspaceSwitcher {
        id: workspaceSwitcher
        workspacesService: root.workspacesService
    }

    IpcHandler {
        target: "wsswitcher"
        function toggle(): string { return workspaceSwitcher.toggle() }
        function open(): string   { return workspaceSwitcher.open() }
        function close(): string  { return workspaceSwitcher.close() }
        function next(): string   { return workspaceSwitcher.next() }
        function prev(): string   { return workspaceSwitcher.prev() }
        function confirm(): string { return workspaceSwitcher.confirm() }
    }

    // On-Screen Display (OSD UI Window)
    Osd {
        id: osd
        bluetoothService: root.bluetoothService
        brightnessService: root.brightnessService
    }

    // OSD IPC & Trigger Service (modeled on swayosd-client)
    OsdService {
        id: osdService
        osd: osd
    }

    // Desktop Notifications Service
    Notifications {
        id: notifications
    }

    // Mount Bar on each screen
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData

            workspacesService: root.workspacesService
            audioService: root.audioService
            brightnessService: root.brightnessService
            batteryService: root.batteryService
            networkService: root.networkService
            bluetoothService: root.bluetoothService
            powerService: root.powerService
        }
    }
}
