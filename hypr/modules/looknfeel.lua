-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
	general = {
		gaps_in = 2,
		gaps_out = 4,
		border_size = 0,
		resize_on_border = true,
		allow_tearing = false,

		layout = "dwindle",
	},

	decoration = {
		rounding = 10,
		rounding_power = 10,

		-- Change transparency of focused and unfocused windows
		active_opacity = 0.95,
		inactive_opacity = 0.88,

		shadow = {
			enabled = false,
			range = 4,
			render_power = 3,
		},

		blur = {
			enabled = true,
			size = 6,
			passes = 4,
			vibrancy = 0.45,
			contrast = 2,
			brightness = 0.8,
			new_optimizations = true,
			popups = true,
			popups_ignorealpha = 0.2,
		},

		glow = {
			enabled = false,
		},
	},

	animations = {
		enabled = true,
	},
})

hl.config({
	dwindle = {
		preserve_split = true, -- You probably want this
	},
})

hl.config({
	master = {
		new_status = "master",
	},
})

hl.config({
	scrolling = {
		fullscreen_on_one_column = true,
	},
})
