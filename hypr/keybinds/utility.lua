---------------------
----   utility   ----
---------------------

hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus --new-window"))

---- SCREENSHOT ----
hl.bind("PRINT", hl.dsp.exec_cmd("qdeck screenshot region"))
hl.bind("ALT + PRINT", hl.dsp.exec_cmd("qdeck screenshot window"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("qdeck screenshot clipboard region"))

---- QDECK CONTROLS ----
hl.bind("SUPER + B", hl.dsp.exec_cmd("qdeck bar toggle"))
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("qdeck bar next"))
hl.bind("SUPER + ALT + B", hl.dsp.exec_cmd("qdeck blur toggle"))

---- APPS ----
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("default-browser"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("tui-launch webapp-create"))
hl.bind("XF86Calculator", hl.dsp.exec_cmd("gnome-calculator"))
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("tui-launch btop"))
