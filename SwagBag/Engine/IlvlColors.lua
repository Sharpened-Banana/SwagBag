-- SwagBag item-level colors (0.17, spec 3). The rule behind overlays.ilvlColors / overlays.ilvlSteps: an
-- item level takes the color of the highest step it reaches; below the lowest step it stays white. Steps are
-- written "680:green,690:blue,700:purple" (at most 4), colors come from a fixed palette (Blizzard's quality
-- colors). Pure apart from the settings read in For.
--   IlvlColors.PALETTE      name -> { r, g, b } (gray white green blue purple orange); .ORDER the names in that order
--   IlvlColors.MAX          steps kept (4); .MIN_LEVEL / .MAX_LEVEL the levels a step may have (1 .. 9999)
--   IlvlColors.Parse(text) -> steps          { { level, color } } in text order; a part that is not
--                                            <integer>:<palette name>, or out of range, is dropped; the first MAX
--                                            kept; a non-string gives {}
--   IlvlColors.Format(steps) -> text         the text Parse reads back
--   IlvlColors.Pick(steps, level) -> r, g, b | nil
--                                            the color of the highest step whose level <= level; steps sorted by
--                                            level (ties: the earlier row wins; the caller's table is untouched);
--                                            nil below the lowest step
--   IlvlColors.For(level) -> r, g, b | nil   nil unless overlays.ilvlColors is true; else Pick over the parsed
--                                            overlays.ilvlSteps (parse and sort cached until SB_CONFIG_CHANGED)
--   IlvlColors.Fill(equipped) -> steps       the first-time steps: floor(equipped) green, +10 blue, +20 purple;
--                                            {} when equipped is not a positive number
local _, SB = ...

local IC = {}
SB.IlvlColors = IC

IC.PALETTE = {
	gray = { 0.62, 0.62, 0.62 }, white = { 1, 1, 1 }, green = { 0.12, 1, 0 }, blue = { 0, 0.44, 0.87 },
	purple = { 0.64, 0.21, 0.93 }, orange = { 1, 0.5, 0 },
}
IC.ORDER = { "gray", "white", "green", "blue", "purple", "orange" }
IC.MAX = 4
IC.MIN_LEVEL = 1
IC.MAX_LEVEL = 9999

function IC.Parse(text)
	local steps = {}
	if type(text) ~= "string" then
		return steps
	end
	for part in text:gmatch("[^,]+") do
		local level, color = part:match("^%s*(%d+)%s*:%s*(%a+)%s*$")
		level = tonumber(level)
		color = color and color:lower()
		if level and level >= IC.MIN_LEVEL and level <= IC.MAX_LEVEL and IC.PALETTE[color] then
			steps[#steps + 1] = { level = level, color = color }
			if #steps >= IC.MAX then
				break
			end
		end
	end
	return steps
end

function IC.Format(steps)
	local parts = {}
	for _, s in ipairs(steps or {}) do
		parts[#parts + 1] = s.level .. ":" .. s.color
	end
	return table.concat(parts, ",")
end

-- The steps ordered by level for reading, the row number in each (table.sort is not stable, so it breaks a
-- tie: the earlier row wins). The caller's table is untouched.
local function sortSteps(steps)
	local sorted = {}
	for i, s in ipairs(steps) do
		sorted[i] = { level = s.level, color = s.color, row = i }
	end
	table.sort(sorted, function(a, b)
		if a.level ~= b.level then
			return a.level < b.level
		end
		return a.row > b.row -- the earlier row sorts last of its level, so it is the one reached
	end)
	return sorted
end

local function pickSorted(sorted, level)
	local hit
	for _, s in ipairs(sorted) do
		if s.level <= level then
			hit = s
		end
	end
	local rgb = hit and IC.PALETTE[hit.color]
	if rgb then
		return rgb[1], rgb[2], rgb[3]
	end
	return nil
end

function IC.Pick(steps, level)
	if type(level) ~= "number" or type(steps) ~= "table" then
		return nil
	end
	return pickSorted(sortSteps(steps), level)
end

local cache -- { steps = parsed, sorted = the same ordered for Pick }; dropped on SB_CONFIG_CHANGED

function IC.For(level)
	if SB.Config.Get("overlays.ilvlColors") ~= true then
		return nil
	end
	if not cache then
		local steps = IC.Parse(SB.Config.Get("overlays.ilvlSteps"))
		cache = { steps = steps, sorted = sortSteps(steps) }
	end
	if type(level) ~= "number" then
		return nil
	end
	return pickSorted(cache.sorted, level)
end

function IC.Fill(equipped)
	if type(equipped) ~= "number" or equipped ~= equipped or equipped < 1 then
		return {}
	end
	local base = math.floor(equipped)
	return { { level = base, color = "green" }, { level = base + 10, color = "blue" },
		{ level = base + 20, color = "purple" } }
end

SB.On("SB_CONFIG_CHANGED", function()
	cache = nil
end, "none")
