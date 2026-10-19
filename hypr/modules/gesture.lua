hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

hl.gesture({
	fingers = 4,
	direction = "up",
	action = function()
		hl.exec_cmd("qs ipc call osd outputVolume raise")
	end,
})

hl.gesture({
	fingers = 4,
	direction = "down",
	action = function()
		hl.exec_cmd("qs ipc call osd outputVolume lower")
	end,
})
