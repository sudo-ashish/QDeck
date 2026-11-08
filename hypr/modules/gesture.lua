hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

local delta_accumulator = 0
-- Higher = less sensitive (requires longer swipe)
-- Lower  = more sensitive (faster volume change)
local THRESHOLD = 25

local function change_volume(delta)
	delta_accumulator = delta_accumulator + delta

	if delta_accumulator <= -THRESHOLD then
		hl.exec_cmd("qs ipc call osd outputVolume raise-fine")
		delta_accumulator = 0
	elseif delta_accumulator >= THRESHOLD then
		hl.exec_cmd("qs ipc call osd outputVolume lower-fine")
		delta_accumulator = 0
	end
end

hl.gesture({
	fingers = 4,
	direction = "vertical",
	---@diagnostic disable-next-line: assign-type-mismatch
	action = {
		update = function(e)
			change_volume(e.delta.y)
		end,
		["end"] = function()
			delta_accumulator = 0
		end,
		cancel = function()
			delta_accumulator = 0
		end,
	},
})