--------------------------------------------------------------------------------
-- QDeck: Desktop Shell Keybindings (Launcher, PowerMenu, Theme & Wallpaper)
--------------------------------------------------------------------------------
hl.bind("ALT + SPACE", hl.dsp.exec_cmd("qdeck-launcher"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("qdeck-launcher"))
hl.bind("SUPER + R", hl.dsp.exec_cmd("qdeck-launcher"))
hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("qdeck-powermenu"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("qdeck-wallpaperswitcher"))
hl.bind("SUPER + ALT + SPACE", hl.dsp.exec_cmd("qdeck-themeswitcher"))
hl.bind("SUPER + S", hl.dsp.exec_cmd("qdeck-qshelf"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("qdeck-qshelf"))
hl.bind("ALT + TAB", hl.dsp.exec_cmd("qdeck-spaces toggle"))
hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd("qdeck-spaces prev"))
