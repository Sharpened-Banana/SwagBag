-- SwagBag grid layout math (pure). Grid view = physical slot order (bag 0, 1-4, 5)
-- flowing through one continuous grid (spec AC3.6).
local _, SB = ...

local Grid = {}
SB.GridLayout = Grid

-- bags: ordered list of { bag = id, size = n }
-- opts: { columns, size, gap, padding }
-- Returns { cells = { {bag, slot, x, y} }, count, rows, width, height }.
-- x grows right, y grows DOWN as negative numbers (WoW TOPLEFT offsets).
function Grid.Compute(bags, opts)
	local cols, size, gap, pad = opts.columns, opts.size, opts.gap, opts.padding
	local step = size + gap
	local cells, i = {}, 0
	for _, b in ipairs(bags) do
		for slot = 1, b.size do
			cells[#cells + 1] = {
				bag = b.bag,
				slot = slot,
				x = pad + (i % cols) * step,
				y = -(pad + math.floor(i / cols) * step),
			}
			i = i + 1
		end
	end
	local rows = math.ceil(i / cols)
	return {
		cells = cells,
		count = i,
		rows = rows,
		width = pad * 2 + cols * size + (cols - 1) * gap,
		height = rows > 0 and (pad * 2 + rows * size + (rows - 1) * gap) or pad * 2,
	}
end

-- Keep a scroll offset inside [0, max(0, childHeight - viewHeight)] (spec 4.4).
function Grid.ClampOffset(offset, childHeight, viewHeight)
	local max = math.max(0, childHeight - viewHeight)
	if offset > max then
		return max
	end
	if offset < 0 then
		return 0
	end
	return offset
end

-- Clamp a window scale to 50-200 % (spec AC1.5).
function Grid.ClampScale(scale)
	return math.max(0.5, math.min(2.0, scale))
end
