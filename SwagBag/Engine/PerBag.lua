-- SwagBag per-bag view positions (0.17, spec 4). Pure Lua: no frames, no WoW calls.
-- One section per bag (or bank tab), each with a header, in the order given. Pixel math follows
-- Layout.Position for a category section, so a bag section looks like one: the header sits at the
-- current y, the first row of slots starts `header` below it, a section's slots take
-- rows * (size + gap) - gap, and `sectionGap` follows each section; `padding` goes above the first
-- section and below the last.
-- PerBag.Compute(bags, opts, collapsed) -> pos
--   bags: { { bag, size } } in display order; a bag of size 0 (no bag equipped, tab not bought) has no section.
--   opts: { columns, size, gap, padding, header, sectionGap, top }   top: y offset where the layout starts
--     (default 0); height includes it. Each bag's grid comes from SB.GridLayout.Compute.
--   collapsed: { [PerBag.Id(bag)] = true } -- the header stays, the cells are shown = false and the
--     section takes no grid height (the cells keep the positions they have when expanded).
--   pos = { cells = { {bag, slot, x, y, shown} }, headers = { {id, bag, y, collapsed, size} }, width, height }
--     y is negative (TOPLEFT offsets); width is the grid width for opts.columns.
-- PerBag.Id(bag) -> "bag:" .. bag   the section id, also the collapse key
-- PerBag.IsId(id) -> bool   a bags-view section id (no category behind it)
-- PerBag.Free(has, bag, size) -> n   the bag's empty slots; has(bag, slot) -> truthy when the slot holds an item
-- PerBag.Physical(view) -> bool   the views in physical slot order ("grid", "bags"): no Layout state, so no New,
--   Free, stack grouping, free tile or focus, and live changes repaint in place
-- PerBag.Label(name, size, free, collapsed) -> text   the header text, with the same "-" / "+" collapse
--   mark SB.SectionHeaders.Label puts in front
local _, SB = ...

local PerBag = {}
SB.PerBag = PerBag

function PerBag.Id(bag)
	return "bag:" .. bag
end

function PerBag.IsId(id)
	return type(id) == "string" and id:sub(1, 4) == "bag:"
end

function PerBag.Free(has, bag, size)
	local free = 0
	for slot = 1, size do
		if not has(bag, slot) then
			free = free + 1
		end
	end
	return free
end

function PerBag.Physical(view)
	return view == "grid" or view == "bags"
end

function PerBag.Label(name, size, free, collapsed)
	return (collapsed and "+" or "-") .. " " .. SB.L.PERBAG_HEADER:format(name, size, free)
end

function PerBag.Compute(bags, opts, collapsed)
	collapsed = collapsed or {}
	local pad = opts.padding
	local pos = { cells = {}, headers = {} }
	local y = (opts.top or 0) + pad
	for _, b in ipairs(bags) do
		if b.size > 0 then
			local id = PerBag.Id(b.bag)
			local closed = collapsed[id] == true
			pos.headers[#pos.headers + 1] = { id = id, bag = b.bag, y = -y, collapsed = closed, size = b.size }
			y = y + opts.header
			local grid = SB.GridLayout.Compute({ { bag = b.bag, size = b.size } }, opts)
			for _, c in ipairs(grid.cells) do
				-- The grid starts its first row at -padding; this section's first row is at -y.
				pos.cells[#pos.cells + 1] = { bag = c.bag, slot = c.slot, x = c.x, y = c.y + pad - y, shown = not closed }
			end
			if not closed then
				y = y + grid.rows * (opts.size + opts.gap) - opts.gap
			end
			y = y + opts.sectionGap
			pos.width = grid.width
		end
	end
	pos.width = pos.width or pad * 2 + opts.columns * opts.size + (opts.columns - 1) * opts.gap
	pos.height = y + pad
	return pos
end
