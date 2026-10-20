pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Central single source of truth path for colors configuration
    readonly property string colorsConfigPath: Quickshell.env("HOME") + "/.config/themes/current/colors.toml"
    readonly property string localColorsPath: (Quickshell.env("QS_CONFIG_PATH") || (Quickshell.env("HOME") + "/.config/quickshell")) + "/theme/colors.toml"
    readonly property string blurStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/blur-state"

    // Raw parsed colors dictionary
    property var _c: ({})

    // Surfaces & Backgrounds
    readonly property color background: _c.background || "#1a1b26"
    readonly property color dark_background: _c.dark_background || _c.color0 || Qt.darker(root.background, 1.25)
    readonly property color darker_background: _c.darker_background || Qt.darker(root.background, 1.45)
    readonly property color lighter_background: _c.lighter_background || Qt.lighter(root.background, 1.25)

    // Primary Accents
    readonly property color accent: _c.accent || _c.color4 || "#7aa2f7"
    readonly property color selection: _c.selection || _c.color0 || "#292e42"
    readonly property color muted: _c.muted || _c.color8 || "#585b70"

    // Typography & Foregrounds
    readonly property color foreground: _c.foreground || "#a9b1d6"
    readonly property color dark_foreground: _c.dark_foreground || _c.color8 || Qt.darker(root.foreground, 1.35)
    readonly property color light_foreground: _c.light_foreground || _c.color7 || Qt.lighter(root.foreground, 1.1)
    readonly property color bright_foreground: _c.bright_foreground || _c.color15 || _c.cursor || "#ffffff"

    // Semantic & Accent Palette
    readonly property color red: _c.red || _c.color1 || "#f7768e"
    readonly property color urgent: root.red
    readonly property color yellow: _c.yellow || _c.color3 || "#e0af68"
    readonly property color orange: _c.orange || _c.color3 || "#eb927b"
    readonly property color green: _c.green || _c.color2 || "#9ece6a"
    readonly property color cyan: _c.cyan || _c.color6 || "#449dab"
    readonly property color blue: _c.blue || _c.color4 || root.accent
    readonly property color magenta: _c.magenta || _c.color5 || "#ad8ee6"
    readonly property color brown: _c.brown || Qt.darker(root.yellow, 1.4)

    // High-Vibrancy Variants
    readonly property color bright_red: _c.bright_red || _c.color9 || root.red
    readonly property color bright_yellow: _c.bright_yellow || _c.color11 || root.yellow
    readonly property color bright_green: _c.bright_green || _c.color10 || root.green
    readonly property color bright_cyan: _c.bright_cyan || _c.color14 || root.cyan
    readonly property color bright_blue: _c.bright_blue || _c.color12 || root.blue
    readonly property color bright_magenta: _c.bright_magenta || _c.color13 || root.magenta

    // ─────────────────────────────────────────────────────────────────────────
    // Dual Alpha + Compositor Blur Architecture
    // ─────────────────────────────────────────────────────────────────────────
    property bool blurEnabled: true

    readonly property real baseOpacity: root.blurEnabled ? Appearance.baseOpacity : 1.0
    readonly property real elevatedOpacity: root.blurEnabled ? Appearance.elevatedOpacity : 1.0
    readonly property real layerOpacity: Appearance.layerOpacity
    readonly property real scrimOpacity: Appearance.scrimOpacity

    function withAlpha(colorVal, alphaVal) {
        return Qt.rgba(colorVal.r, colorVal.g, colorVal.b, alphaVal)
    }

    function setBlurState(enabled) {
        root.blurEnabled = enabled
        var stateStr = enabled ? "on" : "off"
        var cmd = "mkdir -p \"$(dirname \"" + root.blurStatePath + "\")\" && printf '%s' \"" + stateStr + "\" > \"" + root.blurStatePath + "\""
        if (enabled) {
            cmd += " && hyprctl eval 'hl.layer_rule({ name = \"qdeck-blur\", match = { namespace = \"^quickshell-.*\" }, blur = true, blur_popups = true, ignore_alpha = 0.57 })' 2>/dev/null || true"
        } else {
            cmd += " && hyprctl eval 'hl.layer_rule({ name = \"qdeck-blur\", match = { namespace = \"^quickshell-.*\" }, blur = false, blur_popups = false })' 2>/dev/null || true"
        }
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    // IPC Interface for theme / blur control
    property IpcHandler ipcHandler: IpcHandler {
        target: "theme"

        function reload(): string {
            root.reloadTheme()
            return "reloaded"
        }

        function toggleBlur(): string {
            root.setBlurState(!root.blurEnabled)
            return root.blurEnabled ? "on" : "off"
        }

        function setBlur(mode: string): string {
            var m = String(mode || "").trim().toLowerCase()
            if (m === "on" || m === "true" || m === "1") root.setBlurState(true)
            else if (m === "off" || m === "false" || m === "0") root.setBlurState(false)
            return root.blurEnabled ? "on" : "off"
        }

        function getBlur(): string {
            return root.blurEnabled ? "on" : "off"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Typography & Metrics Bridges (Centralized in Fonts & Appearance)
    // ─────────────────────────────────────────────────────────────────────────
    property int baseTextSize: Fonts.baseTextSize
    onBaseTextSizeChanged: {
        if (Fonts.baseTextSize !== baseTextSize) {
            Fonts.baseTextSize = baseTextSize
        }
    }

    readonly property string fontFamily: Fonts.uiFont
    readonly property int fontSizeSmall: Fonts.sizeSmall
    readonly property int fontSizeRegular: Fonts.sizeRegular
    readonly property int fontSizeMedium: Fonts.sizeMedium
    readonly property int fontSizeLarge: Fonts.sizeLarge
    readonly property int fontSizeTitle: Fonts.sizeTitle

    readonly property int barHeight: Appearance.barHeight
    readonly property int radiusSmall: Appearance.radiusSmall
    readonly property int radiusMedium: Appearance.radiusMedium
    readonly property int radiusLarge: Appearance.radiusLarge

    readonly property int animDuration: Appearance.animDurationNormal

    property FileView blurStateFile: FileView {
        path: root.blurStatePath
        watchChanges: true
        printErrors: false
        onLoaded: {
            var raw = String(text() || "").trim().toLowerCase()
            if (raw === "off" || raw === "false" || raw === "0") {
                if (root.blurEnabled) root.blurEnabled = false
            } else if (raw === "on" || raw === "true" || raw === "1") {
                if (!root.blurEnabled) root.blurEnabled = true
            }
        }
    }

    function parseThemeFile(rawText) {
        var lines = String(rawText || "").split("\n")
        var map = {}
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line || line.startsWith("#") || line.startsWith(";")) continue
            var eqIdx = line.indexOf("=")
            if (eqIdx < 1) continue
            var key = line.slice(0, eqIdx).trim()
            var rawVal = line.slice(eqIdx + 1).trim()
            var val = ""

            var quotedMatch = rawVal.match(/^["']([^"']*)["']/)
            if (quotedMatch) {
                val = quotedMatch[1].trim()
            } else {
                var hashIdx = rawVal.indexOf("#")
                var semiIdx = rawVal.indexOf(";")
                var cutIdx = -1
                if (hashIdx !== -1 && semiIdx !== -1) cutIdx = Math.min(hashIdx, semiIdx)
                else if (hashIdx !== -1) cutIdx = hashIdx
                else if (semiIdx !== -1) cutIdx = semiIdx

                if (cutIdx !== -1) {
                    val = rawVal.slice(0, cutIdx).trim()
                } else {
                    val = rawVal.trim()
                }
                val = val.replace(/^['"]+|['";\s]+$/g, "").trim()
            }

            if (val) {
                map[key] = val
            }
        }
        root._c = map
    }

    property FileView colorsFile: FileView {
        path: root.colorsConfigPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (text()) root.parseThemeFile(text())
        }
    }

    property FileView fallbackColorsFile: FileView {
        path: root.localColorsPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (!colorsFile.text() && text()) {
                root.parseThemeFile(text())
            }
        }
    }

    property Process themeReaderProc: Process {
        id: themeReaderProc
        command: ["cat", root.colorsConfigPath]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text && text.trim().length > 0) {
                    root.parseThemeFile(text)
                    if (root.blurEnabled) {
                        root.setBlurState(true)
                    }
                }
            }
        }
    }

    function reloadTheme() {
        if (!themeReaderProc.running) {
            themeReaderProc.running = true
        }
    }

    property string _lastCurrentTarget: ""
    property Process linkCheckProc: Process {
        id: linkCheckProc
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.config/themes/current"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var target = text.trim()
                if (target && target !== root._lastCurrentTarget) {
                    root._lastCurrentTarget = target
                    root.reloadTheme()
                }
            }
        }
    }

    property Timer symlinkWatcherTimer: Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            if (!linkCheckProc.running) {
                linkCheckProc.running = true
            }
        }
    }

    Component.onCompleted: {
        root.reloadTheme()

        if (colorsFile.text()) {
            root.parseThemeFile(colorsFile.text())
        } else if (fallbackColorsFile.text()) {
            root.parseThemeFile(fallbackColorsFile.text())
        }

        var rawBlur = String(blurStateFile.text() || "").trim().toLowerCase()
        if (rawBlur === "off" || rawBlur === "false" || rawBlur === "0") {
            root.blurEnabled = false
            root.setBlurState(false)
        } else {
            root.blurEnabled = true
            root.setBlurState(true)
        }
    }
}
