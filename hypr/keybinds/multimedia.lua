-- Volume (Quickshell OSD IPC)
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("qs ipc call osd outputVolume raise"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("qs ipc call osd outputVolume lower"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("qs ipc call osd outputVolume mute-toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("qs ipc call osd inputVolume mute-toggle"),
	{ locked = true, repeating = true }
)

-- Fine Volume Adjustments (1%)
hl.bind(
	"ALT + XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("qs ipc call osd outputVolume raise-fine"),
	{ locked = true, repeating = true }
)
hl.bind(
	"ALT + XF86AudioLowerVolume",
	hl.dsp.exec_cmd("qs ipc call osd outputVolume lower-fine"),
	{ locked = true, repeating = true }
)

-- Brightness (Quickshell OSD IPC)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs ipc call osd brightness raise"), { locked = true, repeating = true })
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("qs ipc call osd brightness lower"),
	{ locked = true, repeating = true }
)
hl.bind(
	"ALT + XF86MonBrightnessUp",
	hl.dsp.exec_cmd("qs ipc call osd brightness raise-fine"),
	{ locked = true, repeating = true }
)
hl.bind(
	"ALT + XF86MonBrightnessDown",
	hl.dsp.exec_cmd("qs ipc call osd brightness lower-fine"),
	{ locked = true, repeating = true }
)

-- Media keys (using playerctl)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Touchpad / Trackpad toggle
hl.bind("XF86TouchpadToggle", hl.dsp.exec_cmd("qdeck-trackpad toggle"), { locked = true })
hl.bind("XF86TouchpadOn", hl.dsp.exec_cmd("qdeck-trackpad on"), { locked = true })
hl.bind("XF86TouchpadOff", hl.dsp.exec_cmd("qdeck-trackpad off"), { locked = true })

-- Refresh rate toggle (Quickshell OSD IPC)
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("qdeck-refresh-rate toggle"), { locked = true })
