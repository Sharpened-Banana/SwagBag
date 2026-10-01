-- SwagBag sections layout (spec 4, F3). Pure Lua: no frames, no WoW calls.
-- A layout STATE says which section each slot button is in, at which cell index:
--   state = { columns, newRows, order = { "new", ..., "free" },
--             sections = { [id] = { id, cells = { [i] = cell }, size, capacity?, overflow } },
--             where = { [key] = { section = id, index = i } }, deferred = {}, needsReflow }
--   cell  = { bag, slot }  (a slot button)  |  { bag, slot, placeholder = true, icon }
--   Cells may have holes (nil) so that nothing after them ever shifts.
-- Layout.Build(slots, assign, order, opts)   full layout (open, Reflow, sort, view toggle)
--   slots: physical order { { bag, slot, record } } (record nil = empty slot)
--   assign(record) -> section id, or nil (pending -> New); empty slots go to Free.
--   order: section ids in display order; New is forced first and Free last.
--   opts: { columns, newRows }
-- Layout.Position(state, opts, collapsed) -> pos   pixel positions (TOPLEFT offsets, y down
--   negative). Collapsing changes section offsets only, so expanding returns every item
--   to the same cell (spec 6.4). New always shows its header and newRows reserved rows.
--   opts: { columns, size, gap, padding, header, sectionGap }
--   pos = { cells = { {bag, slot, x, y, shown} } (display order), byKey = { [key] = cell },
--           placeholders = { {bag, slot, icon, x, y, shown} }, headers = { {id, y, count,
--           overflow, collapsed} }, width, height }
-- Layout.Moves(oldPos, newPos) -> keys whose button position changes (hover guard, 4.2 #5)
local _, SB = ...

local Layout = { NEW = "new", FREE = "free" }
SB.Layout = Layout

-- Numeric key for a (bag, slot): bags are 0-16 and slots 1-98.
function Layout.Key(bag, slot)
	return bag * 1000 + slot
end

local function section(st, id)
	local sec = st.sections[id]
	if not sec then
		sec = { id = id, cells = {}, size = 0, overflow = 0 }
		st.sections[id] = sec
	end
	return sec
end

-- Put a cell at the end of a section. Returns its index.
local function append(st, id, cell)
	local sec = section(st, id)
	sec.size = sec.size + 1
	sec.cells[sec.size] = cell
	if not cell.placeholder then
		st.where[Layout.Key(cell.bag, cell.slot)] = { section = id, index = sec.size }
	end
	return sec.size
end
Layout.Append = append

function Layout.Build(slots, assign, order, opts)
	local cols = opts.columns
	local st = { columns = cols, newRows = opts.newRows or 2, order = { Layout.NEW }, sections = {}, where = {},
		deferred = {}, needsReflow = false }
	local known = { [Layout.NEW] = true, [Layout.FREE] = true }
	for _, id in ipairs(order) do
		if not known[id] then
			known[id] = true
			st.order[#st.order + 1] = id
		end
	end
	st.order[#st.order + 1] = Layout.FREE
	for _, s in ipairs(slots) do
		local id
		if s.record == nil then
			id = Layout.FREE
		else
			id = assign(s.record) or Layout.NEW
		end
		if not known[id] then -- an id missing from the order still gets a section (before Free)
			known[id] = true
			table.insert(st.order, #st.order, id)
		end
		append(st, id, { bag = s.bag, slot = s.slot })
	end
	local new = section(st, Layout.NEW)
	new.capacity = math.max(st.newRows, math.ceil(new.size / cols)) * cols
	return st
end

local function countButtons(sec)
	local n = 0
	for i = 1, sec.size do
		local cell = sec.cells[i]
		if cell and not cell.placeholder then
			n = n + 1
		end
	end
	return n
end

function Layout.Position(st, opts, collapsed)
	collapsed = collapsed or {}
	local cols, size, gap, pad = opts.columns, opts.size, opts.gap, opts.padding
	local step = size + gap
	local pos = { cells = {}, byKey = {}, placeholders = {}, headers = {} }
	local y = pad
	for _, id in ipairs(st.order) do
		local sec = st.sections[id]
		local visible = id == Layout.NEW or (sec ~= nil and sec.size > 0)
		if visible then
			sec = sec or { cells = {}, size = 0, overflow = 0 }
			local closed = collapsed[id] == true
			pos.headers[#pos.headers + 1] = { id = id, y = -y, count = countButtons(sec), overflow = sec.overflow,
				collapsed = closed }
			y = y + opts.header
			local slots = sec.size
			if id == Layout.NEW then
				slots = math.max(sec.capacity or st.newRows * cols, sec.size)
			end
			local rows = closed and 0 or math.ceil(slots / cols)
			for i = 1, sec.size do
				local cell = sec.cells[i]
				if cell then
					local entry = {
						bag = cell.bag,
						slot = cell.slot,
						x = pad + ((i - 1) % cols) * step,
						y = -(y + math.floor((i - 1) / cols) * step),
						shown = not closed,
					}
					if cell.placeholder then
						entry.icon = cell.icon
						pos.placeholders[#pos.placeholders + 1] = entry
					else
						pos.cells[#pos.cells + 1] = entry
						pos.byKey[Layout.Key(cell.bag, cell.slot)] = entry
					end
				end
			end
			if rows > 0 then
				y = y + rows * step - gap
			end
			y = y + opts.sectionGap
		end
	end
	pos.width = pad * 2 + cols * size + (cols - 1) * gap
	pos.height = y + pad
	return pos
end

-- Keys of buttons that are shown in both layouts but at different coordinates, or that
-- become hidden/shown. Used to hold back a re-stack while one of them is under the cursor.
function Layout.Moves(oldPos, newPos)
	local out = {}
	for key, b in pairs(newPos.byKey) do
		local a = oldPos and oldPos.byKey[key]
		if not a or a.x ~= b.x or a.y ~= b.y or a.shown ~= b.shown then
			out[#out + 1] = key
		end
	end
	table.sort(out)
	return out
end
