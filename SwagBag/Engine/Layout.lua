-- SwagBag sections layout (spec 4, F3). Pure Lua: no frames, no WoW calls.
-- A layout STATE says which section each slot button is in, at which cell index:
--   state = { columns, newRows, order = { "new", ..., "free" },
--             sections = { [id] = { id, cells = { [i] = cell }, size, capacity?, overflow } },
--             where = { [key] = { section = id, index = i } }, deferred = {}, needsReflow,
--             tiles = nil | { family, families = { f }, cell = { [f] = i }, spares = { [f] = { key } },
--                             of = { [key] = f } } }
--   cell  = { bag, slot }  (a slot button)  |  { bag, slot, placeholder = true, icon }
--   Cells may have holes (nil) so that nothing after them ever shifts.
-- Layout.Build(slots, assign, order, opts)   full layout (open, Reflow, sort, view toggle)
--   slots: { { bag, slot, record } } in the order each section lists them (physical, or the list's
--     display order); empty slots in physical order (record nil = empty slot)
--   assign(record) -> section id, or nil (pending -> New); empty slots go to Free.
--   order: section ids in display order; New is forced first and Free last.
--   opts: { columns, newRows, freeTile, family, hideEmptyNew }
--     hideEmptyNew: an empty New is not drawn (no header, no reserved rows) until something
--       arrives (ruling W4-15, every window unless bags.newAlways); state.newShown says which
--     freeTile: Free shows ONE tile per bag family instead of every empty slot (plan D19)
--     family(bag) -> key: empty slots of one family hold the same items (default: all "any").
--       Called only when a slot JOINS the layout (Build, "added"); the answer is kept in
--       tiles.of[key] and used from then on, so a bag swapped or taken off while open (its
--       family changes before its slots are "removed") still finds its own tile (W3-21).
-- Layout.Position(state, opts, collapsed) -> pos   pixel positions (TOPLEFT offsets, y down
--   negative). Collapsing changes section offsets only, so expanding returns every item
--   to the same cell (spec 6.4). New shows its header and newRows reserved rows, except while
--   state.newShown is false (hideEmptyNew and nothing has arrived since the last Build).
--   opts: { columns, size, gap, padding, header, sectionGap, top, order }   top: y offset where the
--   layout starts (a window that stacks several layouts, default 0); height includes it.
--   order: the section ids in the order to draw them (default state.order). A focus mode's "front"
--   style passes Focus.SectionOrder(state.order): each section moves whole, with its header (W10).
--   pos = { cells = { {bag, slot, x, y, shown} } (display order), byKey = { [key] = cell },
--           placeholders = { {bag, slot, icon, x, y, shown} }, headers = { {id, y, count,
--           overflow, collapsed} }, width, height }
--   With the free tile (plan D19) a tile's cell entry also has tile = family and count = that
--   family's free slots, pos.tiles lists the tile entries, and each spare is a cell entry
--   { bag, slot, shown = false, spare = family } with no x or y.
-- Layout.Moves(oldPos, newPos) -> keys whose button position changes (hover guard, 4.2 #5)
-- Layout.Apply(state, changes, isBusy, collapsed, areaBusy) -> result   while the window is open
--   areaBusy() -> true while the mouse is over the items or an item is on the cursor (nil: never).
--   The first "arrived" change while New is hidden shows New, which moves every section below:
--   it waits in state.deferred while areaBusy() (P5, W4-13). Once shown, New stays shown until
--   the next Build, even if it empties (nothing jumps while the window is open).
--   changes: { { bag, slot, kind, icon } } in order. kind:
--     "left"    the slot is now empty        "arrived" a different item is now in the slot
--     "added"   the slot is new (bag grew)   "removed" the slot no longer exists
--   isBusy(bag, slot) -> true while that button must not move (spec 4.2 rule 5: under the
--     mouse, or an item on the cursor). Its changes wait in state.deferred, in order, and
--     the next Apply retries them (the window calls Apply(state, {}) 300 ms later).
--   result = { moved = { keys }, placeholders = n, overflowed = n, deferred = n }
-- Transitions (spec 4.3 table):
--   left    + button in a category section -> placeholder (old icon) in its cell, button to Free's end
--   left    + button in Free or New        -> stays (repaint only)
--   arrived + button in a category section -> placeholder in its cell, button to New's next cell
--   arrived + button in Free               -> to New's next cell; its Free cell becomes a hole
--   arrived + button in New                -> stays (repaint only)
--   New full (its reserved rows) or collapsed -> the button goes to Free's end instead (one
--     already in Free stays put) and New's header counts it ("+N more below")
--   added -> a new button at Free's end;  removed -> its cell becomes a hole
-- Nothing else ever moves, so no other button changes position. Any placeholder, move or
-- hole sets state.needsReflow; the next full Build (close + open, Reflow, sort) clears it.
-- Free tile (opts.freeTile, plan D19). Free's cells hold one TILE per family -- a real empty
-- slot button, its family's first in physical order -- plus any filled button that overflowed
-- New. Every other empty button is a SPARE: it has no cell (where = { section = "free", spare
-- = family }) and Position reports it hidden. A family keeps its tile cell for the whole
-- layout. With the tile, these transitions replace the ones above:
--   the tile arrived  -> to New (or it stays, filled, when New is full); the family's first
--                        spare takes the tile cell (Free's end when the cell is still taken),
--                        shown. This SWAP moves two buttons: it waits while either is busy.
--   the tile removed  -> the same swap
--   a spare arrived   -> to New (Free's end when New is full), shown
--   any button that becomes empty (in a section: placeholder as above; in New; in a filled
--   Free cell) and an added slot -> its family's last spare, hidden; or, when the family
--   has no tile, its tile (in the family's tile cell when that is a hole, else Free's end)
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

---------------------------------------------------------------------------
-- Free tile (plan D19)
---------------------------------------------------------------------------
local function bagOf(key)
	return math.floor(key / 1000)
end

-- The family a key was given when it joined the layout (W3-21: never looked up again).
local function familyOf(st, key)
	return st.tiles.of[key]
end

-- A key joins the layout (Build or "added"): the only place opts.family is called.
local function join(st, key, bag)
	local f = st.tiles.family(bag)
	st.tiles.of[key] = f
	return f
end

-- The key of family f's tile, or nil (no tile cell yet, or the cell is a hole).
local function tileKey(st, f)
	local i = st.tiles.cell[f]
	local free = st.sections[Layout.FREE]
	local c = i and free and free.cells[i]
	return c and Layout.Key(c.bag, c.slot) or nil
end

local function isTile(st, key, w)
	return st.tiles ~= nil and w.section == Layout.FREE and w.index ~= nil
		and w.index == st.tiles.cell[familyOf(st, key)]
end

-- Put an empty button into its family: a spare when the family has a tile, else the tile
-- (in the family's tile cell when that is a hole, otherwise at Free's end).
function Layout.ToFamily(st, key, cell)
	local t = st.tiles
	local f = familyOf(st, key) or join(st, key, cell.bag)
	if not t.spares[f] then
		t.spares[f] = {}
		t.families[#t.families + 1] = f
	end
	if tileKey(st, f) then
		local list = t.spares[f]
		list[#list + 1] = key
		st.where[key] = { section = Layout.FREE, spare = f }
		return
	end
	local free = section(st, Layout.FREE)
	local i = t.cell[f]
	if i and free.cells[i] == nil then
		free.cells[i] = cell
		st.where[key] = { section = Layout.FREE, index = i }
	else
		t.cell[f] = append(st, Layout.FREE, cell)
	end
end

-- Family f's first spare takes Free's cell i (a hole), or Free's end when i is nil, and is
-- the family's tile from now on. Returns its key, or nil when the family has no spare left.
local function promote(st, f, i)
	local list = st.tiles.spares[f]
	local key = list and table.remove(list, 1)
	if not key then
		st.tiles.cell[f] = i
		return nil
	end
	local cell = { bag = bagOf(key), slot = key % 1000 }
	if i then
		section(st, Layout.FREE).cells[i] = cell
		st.where[key] = { section = Layout.FREE, index = i }
	else
		st.tiles.cell[f] = append(st, Layout.FREE, cell)
	end
	return key
end

-- Number of spares (hidden empty buttons) of every family together.
local function spareCount(st)
	local n = 0
	for _, list in pairs(st.tiles and st.tiles.spares or {}) do
		n = n + #list
	end
	return n
end

function Layout.Build(slots, assign, order, opts)
	local cols = opts.columns
	local st = { columns = cols, newRows = opts.newRows or 2, order = { Layout.NEW }, sections = {}, where = {},
		deferred = {}, needsReflow = false }
	if opts.freeTile then
		st.tiles = { family = opts.family or function()
			return "any"
		end, families = {}, cell = {}, spares = {}, of = {} }
	end
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
		if st.tiles then
			join(st, Layout.Key(s.bag, s.slot), s.bag)
		end
		if id == Layout.FREE and st.tiles then
			Layout.ToFamily(st, Layout.Key(s.bag, s.slot), { bag = s.bag, slot = s.slot })
		else
			append(st, id, { bag = s.bag, slot = s.slot })
		end
	end
	local new = section(st, Layout.NEW)
	new.capacity = math.max(st.newRows, math.ceil(new.size / cols)) * cols
	-- Ruling W4-15: with hideEmptyNew an empty New is not drawn until something arrives; without it
	-- (bags.newAlways) New always keeps its header and rows.
	st.newShown = not opts.hideEmptyNew or new.size > 0
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
	local pos = { cells = {}, byKey = {}, placeholders = {}, headers = {}, tiles = {} }
	local y = (opts.top or 0) + pad
	for _, id in ipairs(opts.order or st.order) do
		local sec = st.sections[id]
		local visible
		if id == Layout.NEW then
			visible = st.newShown ~= false
		else
			visible = sec ~= nil and sec.size > 0
		end
		if visible then
			sec = sec or { cells = {}, size = 0, overflow = 0 }
			local closed = collapsed[id] == true
			local count = countButtons(sec)
			if id == Layout.FREE then
				count = count + spareCount(st)
			end
			pos.headers[#pos.headers + 1] = { id = id, y = -y, count = count, overflow = sec.overflow,
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
						local f = id == Layout.FREE and st.tiles and familyOf(st, Layout.Key(cell.bag, cell.slot))
						if f and st.tiles.cell[f] == i then
							entry.tile, entry.count = f, 1 + #st.tiles.spares[f]
							pos.tiles[#pos.tiles + 1] = entry
						end
					end
				end
			end
			if id == Layout.FREE and st.tiles then -- spares: hidden, and never given a position
				for _, f in ipairs(st.tiles.families) do
					for _, key in ipairs(st.tiles.spares[f]) do
						local entry = { bag = bagOf(key), slot = key % 1000, shown = false, spare = f }
						pos.cells[#pos.cells + 1] = entry
						pos.byKey[key] = entry
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

-- Remove a button from its cell (leaving a hole). Returns where it was and the cell.
local function take(st, key)
	local w = st.where[key]
	st.where[key] = nil
	if w.spare then
		local list = st.tiles.spares[w.spare]
		for n = 1, #list do
			if list[n] == key then
				table.remove(list, n)
				break
			end
		end
		return w, { bag = bagOf(key), slot = key % 1000 }
	end
	local sec = st.sections[w.section]
	local cell = sec.cells[w.index]
	sec.cells[w.index] = nil
	return w, cell
end

local function newHasRoom(st, collapsed)
	local new = section(st, Layout.NEW)
	return not collapsed[Layout.NEW] and new.size < (new.capacity or st.newRows * st.columns)
end

-- New's "+N more below" is the size of a set of slot keys, so a slot that arrives again
-- is not counted twice and one that leaves or is removed stops counting.
local function overflow(st, result, key)
	local new = section(st, Layout.NEW)
	new.overflowKeys = new.overflowKeys or {}
	if not new.overflowKeys[key] then
		new.overflowKeys[key] = true
		new.overflow = new.overflow + 1
		result.overflowed = result.overflowed + 1
	end
end

local function clearOverflow(st, key)
	local new = section(st, Layout.NEW)
	if new.overflowKeys and new.overflowKeys[key] then
		new.overflowKeys[key] = nil
		new.overflow = new.overflow - 1
	end
end

-- The transitions with the free tile (see the header). Returns the keys that moved.
local function applyTile(st, ch, collapsed, result, key, w)
	if ch.kind == "added" then
		join(st, key, ch.bag)
		Layout.ToFamily(st, key, { bag = ch.bag, slot = ch.slot })
		return { key }
	elseif ch.kind == "removed" then
		clearOverflow(st, key)
		local tile, f = isTile(st, key, w), familyOf(st, key)
		take(st, key)
		st.tiles.of[key] = nil -- a slot that comes back is a new join
		return { key, tile and promote(st, f, w.index) or nil }
	elseif ch.kind == "left" then
		clearOverflow(st, key)
		if w.spare or isTile(st, key, w) then
			return {} -- already an empty slot of Free: repaint only
		end
		local old, cell = take(st, key)
		if old.section ~= Layout.FREE and old.section ~= Layout.NEW then
			st.sections[old.section].cells[old.index] = { bag = ch.bag, slot = ch.slot, placeholder = true, icon = ch.icon }
			result.placeholders = result.placeholders + 1
		end
		Layout.ToFamily(st, key, cell)
		return { key }
	elseif ch.kind ~= "arrived" or w.section == Layout.NEW then
		return {}
	end
	local tile = isTile(st, key, w)
	local room = newHasRoom(st, collapsed)
	if w.section == Layout.FREE and not (w.spare or tile) then -- a filled button that overflowed New
		if not room then
			overflow(st, result, key)
			return {}
		end
		clearOverflow(st, key)
	elseif w.section ~= Layout.FREE then -- a category section: placeholder in its cell
		local old, cell = take(st, key)
		st.sections[old.section].cells[old.index] = { bag = ch.bag, slot = ch.slot, placeholder = true, icon = ch.icon }
		result.placeholders = result.placeholders + 1
		if room then
			append(st, Layout.NEW, cell)
		else
			append(st, Layout.FREE, cell)
			overflow(st, result, key)
		end
		return { key }
	elseif not room and tile then -- it stays, filled; the next spare is the tile, at Free's end
		overflow(st, result, key)
		return { promote(st, familyOf(st, key), nil) }
	end
	local _, cell = take(st, key)
	if room then
		clearOverflow(st, key)
		append(st, Layout.NEW, cell)
	else -- a spare, and New is full: shown at Free's end
		append(st, Layout.FREE, cell)
		overflow(st, result, key)
	end
	return { key, tile and promote(st, familyOf(st, key), w.index) or nil }
end

local function applyOne(st, ch, collapsed, result)
	local key = Layout.Key(ch.bag, ch.slot)
	if st.tiles and (st.where[key] or ch.kind == "added") then
		if ch.kind == "added" and st.where[key] then
			return
		end
		local moved = applyTile(st, ch, collapsed, result, key, st.where[key])
		for _, k in ipairs(moved) do
			result.moved[#result.moved + 1] = k
		end
		if #moved > 0 then
			st.needsReflow = true
		end
		return
	end
	local w = st.where[key]
	if ch.kind == "added" then
		if not w then
			append(st, Layout.FREE, { bag = ch.bag, slot = ch.slot })
			result.moved[#result.moved + 1] = key
			st.needsReflow = true
		end
		return
	end
	if not w then
		return
	end
	local id = w.section
	if ch.kind == "removed" then
		clearOverflow(st, key)
		take(st, key)
	elseif ch.kind == "left" then
		clearOverflow(st, key)
		if id == Layout.FREE or id == Layout.NEW then
			return
		end
		local old, cell = take(st, key)
		st.sections[id].cells[old.index] = { bag = ch.bag, slot = ch.slot, placeholder = true, icon = ch.icon }
		result.placeholders = result.placeholders + 1
		append(st, Layout.FREE, cell)
	elseif ch.kind == "arrived" then
		if id == Layout.NEW then
			return
		end
		if id == Layout.FREE then
			if not newHasRoom(st, collapsed) then
				overflow(st, result, key)
				return
			end
			clearOverflow(st, key) -- it found room in New: no longer counted as "more below"
			local _, cell = take(st, key)
			append(st, Layout.NEW, cell)
		else
			local old, cell = take(st, key)
			st.sections[id].cells[old.index] = { bag = ch.bag, slot = ch.slot, placeholder = true, icon = ch.icon }
			result.placeholders = result.placeholders + 1
			if newHasRoom(st, collapsed) then
				append(st, Layout.NEW, cell)
			else
				append(st, Layout.FREE, cell)
				overflow(st, result, key)
			end
		end
	else
		return
	end
	st.needsReflow = true
	result.moved[#result.moved + 1] = key
end

-- Free tile: a change that makes the tile fill or go away hands its cell to the family's first
-- spare. Returns that spare's key, so the swap waits while either button is busy.
local function partner(st, ch)
	if not st.tiles or (ch.kind ~= "arrived" and ch.kind ~= "removed") then
		return nil
	end
	local key = Layout.Key(ch.bag, ch.slot)
	local w = st.where[key]
	if not (w and isTile(st, key, w)) then
		return nil
	end
	return st.tiles.spares[familyOf(st, key)][1]
end

-- Change tables passed to Apply must not be reused or mutated afterwards: deferred entries
-- keep references to them.
function Layout.Apply(st, changes, isBusy, collapsed, areaBusy)
	collapsed = collapsed or {}
	local result = { moved = {}, placeholders = 0, overflowed = 0, deferred = 0 }
	local queue = st.deferred
	for _, ch in ipairs(changes or {}) do
		queue[#queue + 1] = ch
	end
	st.deferred = {}
	local held = {}
	for _, ch in ipairs(queue) do
		local key = Layout.Key(ch.bag, ch.slot)
		local spare = partner(st, ch)
		-- The first arrival into a hidden New shows it and moves every section below (W4-15).
		local opensNew = st.newShown == false and ch.kind == "arrived"
		if held[key] or (isBusy and (isBusy(ch.bag, ch.slot) or (spare and isBusy(bagOf(spare), spare % 1000))))
			or (opensNew and areaBusy and areaBusy()) then
			held[key] = true -- later changes of a held slot wait too, so order is kept
			st.deferred[#st.deferred + 1] = ch
		else
			-- New shows only when the arrival lands in it or counts in its "+N more below": a slot the
			-- layout does not know adds nothing, so no empty "- New (0)" appears.
			local known, before = st.where[key] ~= nil, st.sections[Layout.NEW].size
			applyOne(st, ch, collapsed, result)
			if opensNew and (known or st.sections[Layout.NEW].size > before) then
				st.newShown = true
			end
		end
	end
	result.deferred = #st.deferred
	return result
end
