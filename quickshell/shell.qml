//@ pragma IconTheme Yaru-purple
import QtQuick
import Quickshell
import Quickshell.Io
import "theme"
import "components"
import "services"
import "modules/bar"
import "modules/launcher"
import "modules/osd"
import "modules/notifications"
import "modules/polkit"

ShellRoot {
    id: root

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
