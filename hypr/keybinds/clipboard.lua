--------------------------------------------------------------------------------
-- QDeck: Universal Clipboard & Shortcuts (Omarchy-inspired Hyprland Native Dispatch)
--
-- Global Shortcuts:
--   SUPER + A              -> Select all (Ctrl+A)
--   SUPER + C              -> Universal copy (Ctrl+C / Ctrl+Shift+C in terminal)
--   SUPER + V              -> Universal paste (Ctrl+V / Ctrl+Shift+V in terminal)
--   SUPER + X              -> Universal cut (Ctrl+X)
--   SUPER + CTRL + V       -> Open QDeck clipboard manager
--   SUPER + CTRL + SHIFT + V -> Clear QDeck clipboard history
--------------------------------------------------------------------------------

-- Established terminal emulators in QDeck (matches bin/qdeck-launch-terminal & tiling.lua)
local terminal_classes = {
	kitty = true,
	foot = true,
	alacritty = true,
	ghostty = true,
	wezterm = true,
	["org.wezfurlong.wezterm"] = true,
	["gnome-terminal"] = true,
	["xfce4-terminal"] = true,
	xterm = true,
	["floating-terminal"] = true,
}

-- Check if any layer-shell surface currently has keyboard focus (e.g. Quickshell modals)
local function is_layer_focused()
	local ok, layers = pcall(function()
		return hl.get_layers()
	end)
	if ok and type(layers) == "table" then
		for _, l in ipairs(layers) do
			if l.mapped and l.keyboard_interactivity and l.keyboard_interactivity > 0 then
				return true
			end
		end
	end
	return false
end

-- Terminal detection inspecting window tags and project classifications
local function is_terminal()
	-- If a layer-shell surface (like Quickshell text input) has focus, use GUI shortcuts
	if is_layer_focused() then
		return false
	end

	local win = hl.get_active_window()
	if not win then
		return false
	end

	-- Check Hyprland window tags
	if win.tags then
		if type(win.tags) == "table" then
			for _, t in ipairs(win.tags) do
				if t:lower() == "terminal" then
					return true
				end
			end
		elseif type(win.tags) == "string" and win.tags:lower():find("terminal") then
			return true
		end
	end

	-- Check window class / initial_class against QDeck terminal classifications
	local cls = (win.class or ""):lower()
	local init_cls = (win.initial_class or ""):lower()

	if terminal_classes[cls] or terminal_classes[init_cls] then
		return true
	end

	-- Check for tui wrapper windows (e.g. tui-btop, tui-webapp-create)
	if cls:sub(1, 4) == "tui-" or init_cls:sub(1, 4) == "tui-" then
		return true
	end

	return false
end

-- Reentrancy tracking to prevent sticking or infinite loops
local active_keys = {}

-- Reliable synthetic key injection using Hyprland native send_key_state and one-shot timer
local function send_key(mods, key_name, fallback_code)
	local combo_id = (mods or "") .. "+" .. (key_name or "")
	if active_keys[combo_id] then
		-- Already dispatched and waiting for release timer, drop duplicate triggers
		return
	end
	active_keys[combo_id] = true

	local target_key = key_name
	-- Try keysym first; fallback to physical evdev/xkb keycode if keysym resolution fails (non-Latin layouts)
	local ok = pcall(function()
		hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = target_key, state = "down" }))
	end)

	if not ok and fallback_code then
		target_key = fallback_code
		pcall(function()
			hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = target_key, state = "down" }))
		end)
	end

	-- Release key after 50ms using Hyprland one-shot timer
	hl.timer(function()
		pcall(function()
			hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = target_key, state = "up" }))
		end)
		active_keys[combo_id] = nil
	end, { timeout = 50, type = "oneshot" })
end

--------------------------------------------------------------------------------
-- Universal Clipboard Bindings
--------------------------------------------------------------------------------

-- SUPER + A: Select all (CTRL + A for both normal apps and terminals)
hl.bind("SUPER + A", function()
	send_key("CTRL", "A", "code:38")
end, { desc = "Universal Select All" })

-- SUPER + C: Universal copy (CTRL + SHIFT + C for terminals, CTRL + C for normal apps)
hl.bind("SUPER + C", function()
	local mods = is_terminal() and "CTRL,SHIFT" or "CTRL"
	send_key(mods, "C", "code:54")
end, { desc = "Universal Copy" })

-- SUPER + V: Universal paste (CTRL + SHIFT + V for terminals, CTRL + V for normal apps)
hl.bind("SUPER + V", function()
	local mods = is_terminal() and "CTRL,SHIFT" or "CTRL"
	send_key(mods, "V", "code:55")
end, { desc = "Universal Paste" })

-- SUPER + X: Universal cut (CTRL + X for both normal apps and terminals)
hl.bind("SUPER + X", function()
	send_key("CTRL", "X", "code:53")
end, { desc = "Universal Cut" })

-- SUPER + CTRL + V: Open QDeck clipboard manager
hl.bind("SUPER + CTRL + V", hl.dsp.exec_cmd("qdeck-clipboard"), { desc = "Open QDeck Clipboard Manager" })

-- SUPER + CTRL + SHIFT + V: Clear QDeck clipboard history
hl.bind("SUPER + CTRL + SHIFT + V", hl.dsp.exec_cmd("qdeck-clipboard clear"), { desc = "Clear QDeck Clipboard History" })
