# QDeck

[![Platform: Arch Linux](https://img.shields.io/badge/Platform-Arch_Linux-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Compositor: Hyprland](https://img.shields.io/badge/Compositor-Hyprland-00B4D8?logo=wayland&logoColor=white)](https://hyprland.org/)
[![Runtime: Quickshell](https://img.shields.io/badge/Runtime-Quickshell-7AA2F7?logo=qt&logoColor=white)](https://git.outfoxxed.me/outfoxxed/quickshell)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

<!-- Add demo banner/screenshot here -->

**QDeck** is a unified, native desktop shell suite built on [Quickshell](https://git.outfoxxed.me/outfoxxed/quickshell) for **minimal Arch Linux** systems running the **Hyprland** Wayland compositor. It replaces the traditional constellation of fragmented desktop utilities—Waybar, Dunst/Mako, Rofi/Wofi, SwayOSD, and external Polkit agents—with a single, ultra-responsive Qt6/QML runtime that shares state, theming, and memory.

---

## Table of Contents

- [Philosophy & Architecture](#philosophy--architecture)
- [System Requirements & Dependencies](#system-requirements--dependencies)
- [Installation Guide](#installation-guide)
  - [Automated Bootstrap (Recommended)](#automated-bootstrap-recommended)
  - [Manual Step-by-Step Setup](#manual-step-by-step-setup)
- [Hyprland Integration & Autostart](#hyprland-integration--autostart)
- [QDeck CLI Reference](#qdeck-cli-reference)
- [Component Breakdown](#component-breakdown)
  - [1. Status Bar](#1-status-bar)
  - [2. Application Launcher](#2-application-launcher)
  - [3. On-Screen Display (OSD)](#3-on-screen-display-osd)
  - [4. Desktop Notification Daemon](#4-desktop-notification-daemon)
  - [5. Native Polkit Authentication Agent](#5-native-polkit-authentication-agent)
  - [6. Unified Power & Session Control Center](#6-unified-power--session-control-center)
- [Configuration & Customization](#configuration--customization)
  - [Bar Layout Modes](#bar-layout-modes)
  - [Dynamic Text Scaling](#dynamic-text-scaling)
  - [Dual-Alpha & Compositor Blur](#dual-alpha--compositor-blur)
  - [Themes & Color Tokens](#themes--color-tokens)
- [Roadmap & Known Limitations](#roadmap--known-limitations)
- [Contributing](#contributing)
- [License & Acknowledgments](#license--acknowledgments)

---

## Philosophy & Architecture

Traditional Wayland desktop setups typically rely on 5 to 7 independent background daemons:

| Function | Traditional Desktop Stack | QDeck Stack |
| :--- | :--- | :--- |
| **Status Bar** | `waybar` or `eww` | **QDeck Bar** (Quickshell QML) |
| **App Launcher** | `rofi-wayland` or `wofi` | **QDeck AppLauncher** (Native XDG parsing) |
| **Notifications** | `dunst`, `mako`, or `swaync` | **QDeck Notifications** (`org.freedesktop.Notifications`) |
| **Volume/Backlight OSD** | `swayosd-server` or `avizo` | **QDeck OSD** (`Quickshell.Io.IpcHandler`) |
| **Privilege Escalation** | `hyprpolkitagent` or `polkit-gnome` | **QDeck Polkit** (`Quickshell.Services.Polkit`) |
| **Theme & Wallpaper Switcher** | Ad-hoc shell scripts & external menus | **QDeck Unified PowerMenu / Services** |

### Why Quickshell?

1. **Unified In-Memory State**: Components do not communicate over cumbersome IPC roundtrips or arbitrary shell pipes for visual updates. Signals from audio (`PipeWire`), backlight (`brightnessctl`), network (`NetworkManager`), and battery (`UPower`) bind directly into reactive QML properties.
2. **Zero IPC Overhead**: Subcomponents (bar popups, launcher, OSD toasts, notification banners) share the same execution thread and memory pool.
3. **Cohesive Design Language**: Corner radii, borders, font metrics, and palettes synchronize globally through reactive singleton modules (`Theme.qml`, `Appearance.qml`, `Fonts.qml`, `Icons.qml`).
4. **Minimal Footprint**: Running one consolidated Qt6 Wayland client consumes significantly less system RAM and idle CPU cycles than keeping half a dozen standalone daemons active.

---

## System Requirements & Dependencies

QDeck is tailored specifically for a **clean, base Arch Linux installation**. It does not assume any pre-installed desktop environments (GNOME, KDE Plasma, XFCE) or helper suites.

### 1. Official Repository Packages (`pacman`)

```bash
sudo pacman -S --needed \
  base-devel git curl wget unzip jq \
  hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-utils \
  grim slurp wl-clipboard libnotify \
  pipewire pipewire-pulse wireplumber pavucontrol \
  bluez bluez-utils \
  brightnessctl upower power-profiles-daemon networkmanager qrencode \
  kitty zsh btop awww eza fzf zoxide \
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-5compat qt6-multimedia qt6-shadertools gcc
```

### 2. Fonts & Icon Sets

QDeck relies on **JetBrains Mono Nerd Font** for text and monospace layouts, paired with **Material Symbols Rounded** for UI glyphs:

```bash
# Official pacman font packages
sudo pacman -S --needed \
  ttf-jetbrains-mono-nerd \
  ttf-material-symbols-variable \
  ttf-material-icons \
  noto-fonts noto-fonts-cjk noto-fonts-emoji
```

> [!NOTE]
> The automated installer will also download and place `MaterialSymbolsRounded.ttf` into `~/.local/share/fonts/` if it is not detected on your system.

### 3. AUR Packages (`yay` or `paru`)

Quickshell and optional companion utilities are installed from the Arch User Repository (AUR):

```bash
# Quickshell runtime (git release recommended for latest Wayland layer-shell enhancements)
yay -S --needed quickshell-git

# Recommended companion packages
yay -S --needed \
  ttf-rubik-vf \
  bibata-cursor-theme-bin
```

---

## Installation Guide

### Automated Bootstrap (Recommended)

QDeck ships with an unattended, non-interactive installer orchestrator that sets up system dependencies, AUR packages, fonts, configs, helper binaries, and shell profiles:

```bash
# Clone the repository
git clone https://github.com/sudo-ashish/qdeck.git ~/qdeck
cd ~/qdeck

# Run full unattended installation
./install.sh
```

#### Selective Module Execution

The installer is fully modular. You can inspect or trigger specific stages using the `-s` / `--step` option:

```bash
./install.sh --step deps        # 01: Core pacman dependencies & AUR helper
./install.sh --step fonts       # 02: JetBrains Mono Nerd Font & Material Symbols
./install.sh --step quickshell  # 03: Quickshell runtime & C lockstate monitor build
./install.sh --step dotfiles    # 04: Deploy config files to ~/.config/
./install.sh --step assets      # 06: Deploy wallpapers and theme palettes
./install.sh --step scripts     # 07: Install CLI scripts to ~/.local/bin/
```

Available flags:
- `--skip-backup`: Omit backing up pre-existing dotfiles.
- `--skip-deps`: Skip installing pacman and AUR packages.
- `--skip-fonts`: Skip downloading and caching fonts.
- `--dry-run`: Preview steps without mutating filesystem state.

---

### Manual Step-by-Step Setup

If you prefer to configure your system manually:

#### 1. Compile the Hardware Lockstate Monitor
QDeck includes a low-overhead C helper (`quickshell/src/qdeck-lockstate-monitor.c`) that reads `/sys/class/leds/*` with zero CPU overhead to signal CapsLock and NumLock changes to the OSD:

```bash
mkdir -p ~/.local/bin
gcc -O2 ~/qdeck/quickshell/src/qdeck-lockstate-monitor.c -o ~/.local/bin/qdeck-lockstate-monitor
chmod +x ~/.local/bin/qdeck-lockstate-monitor
```

#### 2. Deploy Configuration Suites
Copy or symlink the project configurations into your user `~/.config/` directory:

```bash
mkdir -p ~/.config/quickshell ~/.config/themes ~/.config/hypr

# Deploy Quickshell shell
cp -r ~/qdeck/quickshell/* ~/.config/quickshell/

# Deploy Theme suites
cp -r ~/qdeck/themes/* ~/.config/themes/
ln -sfn ~/.config/themes/catppuccin ~/.config/themes/current

# Deploy Hyprland configs (if adopting QDeck Hyprland suite)
cp -r ~/qdeck/hypr/* ~/.config/hypr/
```

#### 3. Install CLI Scripts
Deploy the control scripts into `~/.local/bin/` and ensure your `PATH` includes it:

```bash
cp ~/qdeck/bin/qdeck* ~/.local/bin/
chmod +x ~/.local/bin/qdeck*

# Append to ~/.bashrc or ~/.zshrc if not already present
export PATH="$HOME/.local/bin:$PATH"
```

#### 4. Test Quickshell Standalone
Run the shell in a terminal window to verify QML compilation and inspect live debug logs:

```bash
quickshell -p ~/.config/quickshell
```

---

## Hyprland Integration & Autostart

### 1. Autostart Daemon

Add the startup command to your Hyprland configuration (`~/.config/hypr/hyprland.conf` or `hypr/modules/autostart.lua`):

```ini
# Standard hyprland.conf
exec-once = qdeck
```

Or when running Quickshell directly:

```ini
exec-once = quickshell -p ~/.config/quickshell
```

> [!IMPORTANT]
> The `qdeck` wrapper script automatically terminates conflicting standalone daemons (`waybar`, `swaync`, `swayosd-server`, and standalone Polkit agents) and bridges the active Quickshell IPC socket before launching the runtime.

### 2. Recommended Keybindings

Add these bindings to your Hyprland configuration to integrate your hardware keys and shortcuts with QDeck's IPC interface:

```ini
# ==============================================================================
# QDeck UI Toggles
# ==============================================================================
bind = ALT, SPACE,       exec, qdeck launcher
bind = SUPER, D,         exec, qdeck launcher
bind = SUPER, ESCAPE,    exec, qdeck powermenu
bind = SUPER, SPACE,     exec, qdeck wallpaper
bind = SUPER ALT, SPACE, exec, qdeck theme
bind = SUPER SHIFT, W,   exec, qdeck bar next
bind = SUPER ALT, B,     exec, qdeck blur toggle

# ==============================================================================
# Hardware Controls (OSD & Media)
# ==============================================================================
# Volume control
bindle = , XF86AudioRaiseVolume, exec, qdeck volume up 5
bindle = , XF86AudioLowerVolume, exec, qdeck volume down 5
bindl  = , XF86AudioMute,        exec, qdeck volume mute
bindl  = , XF86AudioMicMute,     exec, qs ipc call osd inputVolume mute-toggle

# Screen Backlight
bindle = , XF86MonBrightnessUp,   exec, qdeck brightness up 5
bindle = , XF86MonBrightnessDown, exec, qdeck brightness down 5

# Media playback
bindl = , XF86AudioPlay,  exec, playerctl play-pause
bindl = , XF86AudioNext,  exec, playerctl next
bindl = , XF86AudioPrev,  exec, playerctl previous

# Display Refresh Rate & Touchpad
bind  = SUPER SHIFT, R, exec, qdeck refresh-rate toggle
bindl = , XF86TouchpadToggle, exec, qdeck trackpad toggle

# Screenshots
bind = ,      PRINT, exec, qdeck screenshot region
bind = ALT,   PRINT, exec, qdeck screenshot window
bind = SHIFT, PRINT, exec, qdeck screenshot clipboard region
```

---

## QDeck CLI Reference

QDeck provides a unified CLI utility (`qdeck`) to manage the background daemon, trigger UI components, and dispatch IPC calls from scripts or hotkeys:

```
Usage: qdeck [command] [options...]

Core Commands:
  qdeck, qdeck run, qdeck start  Launch QDeck desktop shell runtime daemon
  qdeck stop, qdeck kill         Terminate running QDeck instances cleanly
  qdeck restart, qdeck reload    Restart QDeck daemon and refresh UI
  qdeck status                   Display running status, PID, and IPC connection
  qdeck help, --help, -h         Show help information

Control Center & Widgets:
  qdeck launcher [action]        Toggle or control application launcher
  qdeck powermenu [action]       Toggle power & session menu
  qdeck wallpaper [action]       Toggle wallpaper picker or switch wallpaper
  qdeck theme [action]           Toggle theme switcher or switch active theme
  qdeck bar [mode|next|list]     Switch top bar layout (floating, islands, wide, compact)
  qdeck blur [toggle|on|off]     Toggle dual-alpha compositor blur
  qdeck text-size [size]         Get or adjust system and shell font size

Hardware & System Controls:
  qdeck volume [up|down|mute]    Adjust volume or toggle audio mute
  qdeck brightness [up|down]     Adjust screen backlight
  qdeck osd [options]            Display custom On-Screen Display card
  qdeck notify [options]         Manage desktop notifications & DND mode
  qdeck trackpad [toggle|on|off] Toggle touchpad state via Hyprland IPC
  qdeck wifi-qr                  Generate ASCII QR code for current WiFi network
  qdeck refresh-rate [rate]      Query or toggle monitor refresh rate
  qdeck screenshot [options]     Capture region, window, or monitor screenshot
  qdeck terminal [args...]       Launch floating utility terminal
```

---

## Component Breakdown

```
quickshell/
├── shell.qml                # Root ShellRoot entrypoint & service instantiations
├── bar/                     # Modular status bar & screen variant attachments
├── launcher/                # Application launcher, fuzzy filtering & desktop entries
├── osd/                     # On-screen display overlays (audio, brightness, lockstate)
├── notifications/           # org.freedesktop.Notifications daemon & toast stack
├── polkit/                  # Native PolicyKit authentication agent dialog
├── powermenu/               # Integrated bottom power, theme & wallpaper drawer
├── components/              # Reusable primitives (sliders, cards, buttons, dialogs)
├── services/                # Hardware & IPC services (Audio, Network, Bluetooth, etc.)
├── theme/                   # Theme singletons, color tokens & font scalers
└── widgets/                 # Bar widgets (Workspaces, Audio, Network, Battery, etc.)
```

### 1. Status Bar
Located at `quickshell/bar/Bar.qml`. Automatically mounts onto every connected monitor using Quickshell's `Variants` model bound to `Quickshell.screens`.

- **Left Section**: Hyprland dynamic workspace indicator (`WorkspacesWidget.qml`) and active media pill (`NowBarPill.qml`) with playback controls.
- **Center Section**: Date & time display (`ClockWidget.qml`) with a calendar popup card.
- **Right Section**: Hardware and status pills:
  - **Bluetooth Widget**: Device connection state, paired list, and connection toggles.
  - **Network Widget**: WiFi connection, SSID, signal strength, Ethernet state, IP details, and one-click QR code modal.
  - **Audio Widget**: Volume slider, mute status, output sink switcher, and per-app stream controls.
  - **Monitor Widget**: Backlight control, scaling presets, and refresh rate switcher.
  - **Battery Widget**: Charge percentage, AC power status, and power-profiles-daemon mode selector (Performance, Balanced, Power Saver).

### 2. Application Launcher
Located at `quickshell/launcher/AppLauncher.qml`.
- Scans and indexes standard system and user XDG desktop files (`/usr/share/applications`, `~/.local/share/applications`) via Quickshell's native `DesktopEntries` engine.
- Instant fuzzy query matching powered by `LauncherModel.js`.
- Clean keyboard navigation with `Up`/`Down`, `Enter` to launch, and `Escape` to close.
- Automatically launches terminal-based applications in `kitty`.

### 3. On-Screen Display (OSD)
Located at `quickshell/osd/Osd.qml` and `quickshell/osd/OsdService.qml`.
- Provides an animated floating HUD replacing `swayosd`.
- Reacts to volume changes (with over-amplification indicator >100% and mute icon), microphone input mute, and monitor brightness adjustments.
- Includes toasts for display refresh rate changes (e.g. `144Hz`), touchpad states, and Bluetooth device attachments.
- Integrates with the kernel `/sys/class/leds/` monitor to show instant CapsLock and NumLock toggle cards.

### 4. Desktop Notification Daemon
Located at `quickshell/notifications/Notifications.qml`.
- Full standalone implementation of the Freedesktop Notification specification (`org.freedesktop.Notifications`).
- Supports urgency levels (Low, Normal, and persistent Critical alerts).
- Interactive action buttons and custom timeout management.
- Built-in Do Not Disturb (DND) toggle accessible via the status bar and CLI (`qdeck notify dnd-toggle`).

### 5. Native Polkit Authentication Agent
Located at `quickshell/polkit/Polkit.qml`.
- Built directly on `Quickshell.Services.Polkit` to eliminate external agents like `polkit-gnome` or `hyprpolkitagent`.
- Centered modal dialog with password input masking, user identification, and permission details.
- Features smooth error-shake animations and automatic focus grabbing on invocation.

### 6. Unified Power & Session Control Center
Located at `quickshell/powermenu/PowerMenu.qml`.
- Bottom slide-up drawer with three unified modes:
  1. **Power View**: Lock, Suspend, Restart, Shutdown, and Logout actions with confirmation modal (`PowerConfirmDialog.qml`).
  2. **Theme View**: Interactive carousel for instant desktop color palette switching.
  3. **Wallpaper View**: 16:9 thumbnail preview strip to switch desktop backgrounds live using `awww`.

---

## Configuration & Customization

### Bar Layout Modes

QDeck supports four distinct status bar styles out of the box:

| Mode | Visual Style | Screen Coverage |
| :--- | :--- | :--- |
| `floating` | Default rounded pill floating near the top | Full width minus screen margins |
| `islands` | Three decoupled capsules (workspaces, clock, hardware) | Segmented islands |
| `wide` | Wide centered bar | ~72% screen width |
| `compact` | Shrink-wrapped bar sizing strictly to contents | Auto-sized to content |

Change the layout dynamically without restarting Quickshell:

```bash
# Set specific style
qdeck bar floating
qdeck bar islands
qdeck bar wide
qdeck bar compact

# Cycle to next style
qdeck bar next
```

### Dynamic Text Scaling

QDeck is built on an adaptive typography engine (`quickshell/theme/Fonts.qml` and `Appearance.qml`). Changing the base font size automatically recalculates all padding, icon sizes, capsule widths, and bar heights proportionally.

```bash
# Query current base font size
qdeck text-size

# Set new base font size (between 8 and 32 pixels)
qdeck text-size 13
```

### Dual-Alpha & Compositor Blur

QDeck uses a dual-alpha pipeline:
- Active windows and panels use custom opacity tokens (`Appearance.baseOpacity`, `elevatedOpacity`).
- When blur is enabled, QDeck injects layer-rules into Hyprland targeting `^quickshell-.*` namespaces (`blur = true, blur_popups = true, ignore_alpha = 0.57`).

Toggle blur instantly:

```bash
qdeck blur toggle
qdeck blur on
qdeck blur off
```

### Themes & Color Tokens

Color palettes are stored as TOML files in `~/.config/themes/<theme-name>/colors.toml`. The active theme is resolved via the symlink `~/.config/themes/current`.

Built-in themes:
- **Catppuccin** (`catppuccin`)
- **Tokyo Night** (`tokyo-night`)
- **Gruvbox** (`gruvbox`)
- **Nord** (`nord`)
- **Everforest** (`everforest`)

Switch themes instantly:

```bash
# Switch to Tokyo Night
qdeck theme tokyo-night

# Open visual theme picker
qdeck theme toggle
```

#### Creating a Custom Theme

To create a new theme (e.g. `rose-pine`), create `~/.config/themes/rose-pine/colors.toml`:

```toml
# Primary Accents
accent = "#ebbcba"
selection = "#26233a"
muted = "#6e6a86"

# Surfaces & Backgrounds
background = "#191724"
dark_background = "#1f1d2e"
darker_background = "#14121d"
lighter_background = "#2a283e"

# Typography
foreground = "#e0def4"
dark_foreground = "#908caa"
light_foreground = "#f0effd"
bright_foreground = "#ffffff"

# Semantic Colors
red = "#eb6f92"
yellow = "#f6c177"
orange = "#ea9a97"
green = "#31748f"
cyan = "#9ccfd8"
blue = "#c4a7e7"
magenta = "#ebbcba"
```

Then switch to it with `qdeck theme rose-pine`.

---

## Roadmap & Known Limitations

- [x] Full single-runtime desktop shell with Quickshell.
- [x] Native Freedesktop notification daemon (`org.freedesktop.Notifications`).
- [x] Integrated Polkit authentication agent dialog.
- [x] Dynamic multi-layout status bar (Floating, Islands, Wide, Compact).
- [x] Zero-overhead hardware lockstate detection (CapsLock/NumLock).
- [x] Unified bottom power, theme, and wallpaper drawer.
- [ ] **StatusNotifierItem (SNI) Tray Support**: System tray icons are currently work-in-progress pending upstream Quickshell tray stabilization.
- [ ] **Multi-Monitor Per-Screen Workspaces**: Currently mirrors active workspaces across all displays; individual monitor workspace segregation is planned.
- [ ] **Lock Screen**: Standalone Hyprlock configuration is provided (`hypr/hyprlock.conf`), with a native Quickshell lockscreen module under investigation.

---

## Contributing

Contributions are warmly welcomed! Help make QDeck the premier desktop shell for minimal Arch + Hyprland setups.

- **Theme Presets**: Submit PRs with new color palettes in `themes/` (e.g. Rose Pine, Solarized, Kanagawa, Dracula).
- **QML Optimizations & Bug Fixes**: Assist in refining property bindings, layer-shell surface behaviors, and Wayland fractional scaling quirks.
- **Feature Proposals**: Open a discussion on [GitHub Issues](https://github.com/sudo-ashish/qdeck/issues) before initiating large architectural refactors.

### Development Workflow

1. Fork and clone the repository.
2. Launch QDeck in debug mode directly against your working copy:
   ```bash
   quickshell -p ~/qdeck/quickshell
   ```
3. Test IPC handlers and CLI commands using `~/qdeck/bin/qdeck`.
4. Ensure your shell scripts pass `shellcheck` and bash syntax validation (`bash -n`).

---

## License & Acknowledgments

This project is licensed under the [MIT License](LICENSE).

### Acknowledgments

- [Quickshell](https://git.outfoxxed.me/outfoxxed/quickshell) by **outfoxxed** – The revolutionary Wayland-native QML shell runtime that makes this unified architecture possible.
- [Hyprland](https://hyprland.org/) by **Vaxry** – The dynamic tiling Wayland compositor that powers the visual experience.
- The **Arch Linux** community for creating the ultimate minimal and flexible base distribution.
