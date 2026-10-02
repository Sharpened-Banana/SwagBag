-- SwagBag group view (spec F2, F16, section 4): the contents of the bank window (two groups:
-- character bank and warband bank) and of the guild bank window (one group per tab). A view
-- is a stack of GROUPS in one scroll child. Each group has a header (name, item count,
-- collapse, a tint for "deposits go here") and under it either its own category sections
-- (New, categories, Free: one Engine/Layout.lua state per group) or, in the grid view, its
-- slots in physical order.
-- While the window is open the bags window's rules hold (spec 4.2, 4.3): a button moves only
-- into New or Free, never while it is under the mouse and never while an item is on the
-- cursor. A group that grows (Free gains a row) pushes the groups below it down; that push
-- waits too while one of the pushed buttons is under the mouse. Held-back work retries 300 ms
-- later through SB.Debounce (no OnUpdate). A redraw touches only the buttons whose cell
-- changed (Layout.Moves), so a 1,290-slot bank stays inside the spec 9 incremental budget.
--   local v = SB.GroupView.New(cfg)
--   v.Layout(reason) -> width, height   full layout (open, Reflow, sort, view toggle)
--   v.RequestLayout(reason) -> bool     the same, held back while an item is on the cursor
--                                       or a button that would move is under the mouse (4.3)
--   v.Changes(groupId, list)            live changes { { bag, slot, kind, icon } }, kind
--                                       "left" | "arrived" | "added" | "removed" (Layout.Apply)
--   v.Restack() -> bool                 redraw after a collapse or expand (held back like a move)
--   v.ToggleSection(groupId, sectionId), v.ToggleGroup(groupId)
--   v.Relabel()                         redraw the headers only (nothing moves)
--   v.RefreshTotals()                   section headers' text in place (a count or price changed)
--   v.ForEachSlot(fn)                   fn(button, record, bag, slot) for every slot (search)
--   v.Record(bag, slot), v.SetRecord(bag, slot, record), v.GroupOf(bag), v.Size(bag), v.IsOpen()
--   v.Clear()                           window closed: hide the buttons, forget the layout
-- cfg = { key = "bank" | "guild", window = ErrorTrap window (default "bank"), child, scroll,
--   button(bag, slot) -> button | nil;  describe(bag, slot) -> record | nil (paints the button),
--   groups() -> { { id, bags = { { bag, size } } } } in display order,
--   groupLabel(groupId, collapsed, count) -> text;  groupTint(groupId) -> true to tint,
--   view() -> "sections" | "grid";  columns() -> n;  newRows() -> n,
--   onResize(width, height, keepTop);  onUpdated() optional, after a redraw while open,
--   onDrop(sectionId) optional: an item dropped on a section header,
--   sectionLabel(groupId, header) optional: header = { id, count, collapsed, overflow },
--   freeTile() optional -> true: each group's Free shows one tile per bag family with its
--   number of free slots (Engine/Layout.lua, plan D19; families from Adapter.BagFamily),
--   hideEmptyNew optional: true hides each group's New while it is empty (the alt viewer, where
--   nothing ever arrives) }
-- Collapse state is saved per character in ui.collapsed[key .. ":" .. groupId] (sections)
-- and ui.collapsed[key .. ":#"] (whole groups).
local _, SB = ...

local GV = { SLOT = 37, GAP = 4, PAD = 4, SECTION_HEADER = 20, SECTION_GAP = 6, GROUP_HEADER = 22, GROUP_GAP = 8,
	RETRY = 0.3, DROP_GUARD = 0.3 }
SB.GroupView = GV

local function keyOf(bag, slot)
	return SB.Layout.Key(bag, slot)
end

function GV.New(cfg)
	assert(cfg.child, "GroupView.New: cfg.child is required")
	local Guard = SB.ErrorTrap.Guard
	local window = cfg.window or "bank" -- the ErrorTrap window of every entry point (spec P6)
	local v = { groups = {}, byId = {}, records = {}, cells = {}, placed = {}, sizes = {}, groupOf = {}, pos = nil,
		redrawPending = false, stats = {}, tiled = {} }

	-- Collapse sets, saved per character.
	local function collapsedFor(id)
		local ui = SB.Config.UI()
		ui.collapsed = type(ui.collapsed) == "table" and ui.collapsed or {}
		local k = cfg.key .. ":" .. id
		ui.collapsed[k] = type(ui.collapsed[k]) == "table" and ui.collapsed[k] or {}
		return ui.collapsed[k]
	end
	v.Collapsed = collapsedFor

	local function groupClosed(gid)
		return collapsedFor("#")[gid] == true
	end

	local function positionOpts(top)
		return { columns = cfg.columns(), size = GV.SLOT, gap = GV.GAP, padding = GV.PAD, header = GV.SECTION_HEADER,
			sectionGap = GV.SECTION_GAP, top = top }
	end

	local function gridPos(g, top)
		local grid = SB.GridLayout.Compute(g.bags, { columns = cfg.columns(), size = GV.SLOT, gap = GV.GAP,
			padding = GV.PAD })
		local pos = { cells = {}, placeholders = {}, headers = {}, height = top + grid.height }
		for _, c in ipairs(grid.cells) do
			pos.cells[#pos.cells + 1] = { bag = c.bag, slot = c.slot, x = c.x, y = c.y - top, shown = true }
		end
		return pos
	end

	-- Pixel positions of every group, stacked top to bottom. Combined result:
	-- { cells, byKey, placeholders, headers = { { group, id, y, count, overflow, collapsed } },
	--   groupHeaders = { { id, y, count, collapsed } }, tiles = { free tile cells }, width, height }
	-- groups/records default to the view's own (a full layout positions a candidate first).
	local function positionAll(groups, records)
		groups, records = groups or v.groups, records or v.records
		local cols = cfg.columns()
		local all = { cells = {}, byKey = {}, placeholders = {}, headers = {}, groupHeaders = {}, tiles = {},
			width = GV.PAD * 2 + cols * GV.SLOT + (cols - 1) * GV.GAP }
		local y = 0
		for _, g in ipairs(groups) do
			local closed = groupClosed(g.id)
			local header = { id = g.id, y = -y, count = 0, collapsed = closed }
			all.groupHeaders[#all.groupHeaders + 1] = header
			y = y + GV.GROUP_HEADER
			local pos
			if g.state then
				local col = collapsedFor(g.id)
				if closed then
					col = {}
					for _, sid in ipairs(g.state.order) do
						col[sid] = true
					end
				end
				pos = SB.Layout.Position(g.state, positionOpts(y), col)
			else
				pos = gridPos(g, y)
			end
			for _, c in ipairs(pos.cells) do
				c.shown = c.shown and not closed
				all.cells[#all.cells + 1] = c
				all.byKey[keyOf(c.bag, c.slot)] = c
				if records[keyOf(c.bag, c.slot)] then
					header.count = header.count + 1
				end
			end
			for _, p in ipairs(pos.placeholders) do
				p.shown = p.shown and not closed
				all.placeholders[#all.placeholders + 1] = p
			end
			for _, t in ipairs(pos.tiles or {}) do -- the same tables as their cells (shown follows)
				all.tiles[#all.tiles + 1] = t
			end
			if not closed then
				for _, h in ipairs(pos.headers) do
					h.group = g.id
					all.headers[#all.headers + 1] = h
				end
				y = pos.height
			end
			y = y + GV.GROUP_GAP
		end
		all.height = y
		return all
	end

	---------------------------------------------------------------------------
	-- Drawing
	---------------------------------------------------------------------------
	local function place(button, x, y)
		local at = x .. "," .. y
		if v.placed[button] ~= at then
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x, y)
			v.placed[button] = at
		end
	end

	-- A cell past its bag's current size (a removal still held back) is never shown.
	local function inSize(c)
		return c.slot <= (v.sizes[c.bag] or 0)
	end

	local function showAt(button, c)
		if c.shown and inSize(c) then
			place(button, c.x, c.y)
			button:Show()
		else
			button:Hide()
		end
	end

	-- Header clicks: collapse; with an item on the cursor (or dragged onto a section header)
	-- the item is dropped (cfg.onDrop). A group header is not a drop target: a click on it
	-- always collapses or expands the group (W3-24). The click that follows a drop on the
	-- same header in one press is ignored for DROP_GUARD seconds, as in the bags window.
	local dropGuard, dropToken = nil, 0
	local function parseId(id)
		if id:sub(1, 1) == "#" then
			return id:sub(2), nil
		end
		return id:match("^(.-):(.*)$")
	end

	local function drop(id)
		dropToken = dropToken + 1
		local token = dropToken
		dropGuard = id
		SB.Adapter.After(GV.DROP_GUARD, Guard(cfg.key .. ".dropGuard", function()
			if token == dropToken then
				dropGuard = nil
			end
		end, window))
		local _, sid = parseId(id)
		if sid and cfg.onDrop then
			cfg.onDrop(sid)
		end
	end

	local owner = { window = window } -- header clicks and drops trap errors as this window (W3-22)
	function owner.onClick(id)
		if dropGuard == id then
			return
		end
		local gid, sid = parseId(id)
		-- a group header is not a drop target (W3-24), nor a section header in a view with no
		-- onDrop (the guild bank): the click collapses or expands as a plain click (W3-40)
		if sid and cfg.onDrop and SB.Adapter.CursorItem() then
			drop(id)
			return
		end
		if sid then
			v.ToggleSection(gid, sid)
		else
			v.ToggleGroup(gid)
		end
	end

	-- A view with no onDrop (the guild bank) takes no drops, so a drag onto its header sets no
	-- guard: the click that follows is a plain click (it used to be swallowed for 0.3 s).
	function owner.onDrop(id)
		local _, sid = parseId(id)
		if sid and cfg.onDrop and dropGuard ~= id then
			drop(id)
		end
	end

	local function sectionLabel(gid, h, totals, vendor)
		if cfg.sectionLabel then
			return cfg.sectionLabel(gid, h)
		end
		return SB.SectionHeaders.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow,
			totals[gid] and totals[gid][h.id], vendor)
	end

	-- Each group's section totals (spec F10), or none when switched off.
	local function groupTotals()
		local totals = {}
		for _, g in ipairs(v.groups) do
			totals[g.id] = SB.SectionHeaders.Totals(g.state, v.Record)
		end
		return totals
	end

	local function sectionLabels(pos)
		local totals, vendor, labels = groupTotals(), SB.SectionHeaders.IsVendor(), {}
		for i, h in ipairs(pos.headers) do
			labels[i] = sectionLabel(h.group, h, totals, vendor)
		end
		return labels
	end

	-- Placeholders and headers are few: they are redrawn whole, inside this view's child only.
	local function renderExtras(pos)
		local B, H, child = SB.Buttons, SB.SectionHeaders, cfg.child
		local width = pos.width - 2 * GV.PAD
		B.ReleasePlaceholders(child)
		for _, p in ipairs(pos.placeholders) do
			if p.shown then
				B.AcquirePlaceholder(child, p.icon, GV.SLOT, p.x, p.y, window)
			end
		end
		H.ReleaseAll(child)
		for _, g in ipairs(pos.groupHeaders) do
			local h = H.Acquire(child, "#" .. g.id, cfg.groupLabel(g.id, g.collapsed, g.count), GV.PAD, g.y, width, owner)
			if cfg.groupTint and cfg.groupTint(g.id) then
				H.Tint(h, 0.25, 0.85, 0.35, 0.3)
			end
		end
		local labels = sectionLabels(pos)
		for i, h in ipairs(pos.headers) do
			H.Acquire(child, h.group .. ":" .. h.id, labels[i], GV.PAD, h.y, width, owner)
		end
	end

	local function cellsOf(pos)
		local cells = {}
		for _, c in ipairs(pos.cells) do
			if inSize(c) then
				cells[#cells + 1] = c
			end
		end
		return cells
	end

	-- The free tiles' numbers (plan D19): a tile shows its family's free-slot count while it
	-- really is empty (a drop held under the mouse shows the item); other numbers are cleared.
	local function paintTiles(pos)
		local now = {}
		for _, t in ipairs(pos.tiles) do
			local button = cfg.button(t.bag, t.slot)
			if button and t.shown and not v.records[keyOf(t.bag, t.slot)] then
				SB.Buttons.SetFreeCount(button, t.count)
				now[button] = true
			end
		end
		for button in pairs(v.tiled) do
			if not now[button] then
				SB.Buttons.SetFreeCount(button, nil)
			end
		end
		v.tiled = now
	end

	local function render(pos)
		for _, c in ipairs(pos.cells) do
			local button = cfg.button(c.bag, c.slot)
			if button then
				showAt(button, c)
			end
		end
		v.cells = cellsOf(pos)
		renderExtras(pos)
		paintTiles(pos)
		v.pos = pos
	end

	local function hideGone(old, pos)
		for k, c in pairs(old.byKey) do
			if not pos.byKey[k] then
				local button = cfg.button(c.bag, c.slot)
				if button then
					button:Hide()
				end
			end
		end
	end

	local function renderMoved(old, pos)
		for _, k in ipairs(SB.Layout.Moves(old, pos)) do
			local c = pos.byKey[k]
			local button = cfg.button(c.bag, c.slot)
			if button then
				showAt(button, c)
			end
		end
		hideGone(old, pos)
		v.cells = cellsOf(pos)
		renderExtras(pos)
		paintTiles(pos)
		v.pos = pos
	end

	---------------------------------------------------------------------------
	-- Rule 5: nothing moves under the mouse or while an item is on the cursor
	---------------------------------------------------------------------------
	local function busyCheck()
		local cursor = SB.Adapter.CursorItem() ~= nil
		return function(bag, slot)
			if cursor then
				return true
			end
			local b = cfg.button(bag, slot)
			return b ~= nil and b:IsShown() and b:IsMouseOver()
		end, cursor
	end

	local function anyBusy(keys)
		local busy, cursor = busyCheck()
		if cursor then
			return true
		end
		for _, k in ipairs(keys) do
			if busy(math.floor(k / 1000), k % 1000) then
				return true
			end
		end
		return false
	end

	---------------------------------------------------------------------------
	-- Full layout
	---------------------------------------------------------------------------
	-- Read every slot into a fresh candidate (groups, records, sizes); nothing is drawn.
	local function build()
		local b = { groups = {}, byId = {}, records = {}, sizes = {}, groupOf = {} }
		local sections = cfg.view() ~= "grid"
		local order = sections and SB.Categories.SectionOrder() or nil
		for _, def in ipairs(cfg.groups()) do
			local g = { id = def.id, bags = def.bags }
			local slots = {}
			for _, bag in ipairs(def.bags) do
				b.sizes[bag.bag], b.groupOf[bag.bag] = bag.size, def.id
				for slot = 1, bag.size do
					if cfg.button(bag.bag, slot) then
						local record = cfg.describe(bag.bag, slot)
						b.records[keyOf(bag.bag, slot)] = record
						slots[#slots + 1] = { bag = bag.bag, slot = slot, record = record }
					end
				end
			end
			if sections then
				g.state = SB.Layout.Build(slots, SB.Categorizer.Assign, order, { columns = cfg.columns(),
					newRows = cfg.newRows(), freeTile = cfg.freeTile and cfg.freeTile() or nil,
					family = SB.Adapter.BagFamily, hideEmptyNew = cfg.hideEmptyNew })
			end
			b.groups[#b.groups + 1] = g
			b.byId[g.id] = g
		end
		return b
	end

	-- Make a candidate the view's layout and draw it at pos.
	local function commit(b, pos, reason, t0)
		local old = v.pos
		v.groups, v.byId, v.records, v.sizes, v.groupOf, v.redrawPending = b.groups, b.byId, b.records, b.sizes,
			b.groupOf, false
		v.heldKey = nil -- any layout that lands (v.Layout too) ends a held RequestLayout's reason
		if old then
			hideGone(old, pos)
		end
		render(pos)
		cfg.onResize(pos.width, pos.height, reason ~= "open")
		v.stats.lastLayoutMs = SB.Adapter.ProfileMs() - t0
		v.stats.lastLayoutReason = reason
		return pos.width, pos.height
	end

	function v.Layout(reason)
		local t0 = SB.Adapter.ProfileMs()
		local b = build()
		return commit(b, positionAll(b.groups, b.records), reason, t0)
	end

	-- A full layout while open (Reflow, sort, view toggle, a tab's first answer): held back,
	-- retrying every 300 ms, only while an item is on the cursor or a button that would move
	-- is under the mouse -- the same guard as a redraw or a re-stack (W3-38, spec 4.2 rule 5).
	-- While the button that held it is still under the mouse, a retry only re-arms: it does not
	-- read every slot again (week-3 final review), so a held layout costs nothing while it waits.
	-- The cursor is checked again on every retry. Accepted cost (preflight c2): a hold may outlast
	-- its reason by one mouse-leave -- if new data would no longer move that button, the layout
	-- still waits until the mouse leaves it. The guard is only ever stricter, never weaker (P5).
	function v.RequestLayout(reason)
		if not v.pos then
			return false
		end
		local t0 = SB.Adapter.ProfileMs()
		local busy, held = busyCheck()
		if not held and v.heldKey then
			held = busy(math.floor(v.heldKey / 1000), v.heldKey % 1000)
		end
		local b, pos
		if not held then
			b = build()
			pos = positionAll(b.groups, b.records)
			v.heldKey = nil
			for _, k in ipairs(SB.Layout.Moves(v.pos, pos)) do
				if busy(math.floor(k / 1000), k % 1000) then
					v.heldKey, held = k, true
					break
				end
			end
		end
		if held then
			SB.Debounce(cfg.key .. ".layout", GV.RETRY, function()
				v.RequestLayout(reason)
			end, window)
			return false
		end
		commit(b, pos, reason, t0)
		if cfg.onUpdated then
			cfg.onUpdated()
		end
		return true
	end

	---------------------------------------------------------------------------
	-- Live changes (spec 4.3)
	---------------------------------------------------------------------------
	local function applyGroup(g, list)
		if not g.state then
			return { moved = {}, deferred = 0 }
		end
		return SB.Layout.Apply(g.state, list, (busyCheck()), collapsedFor(g.id))
	end

	local function overflowOf(g)
		local new = g.state and g.state.sections[SB.Layout.NEW]
		return new and new.overflow or 0
	end

	-- Redraw. Buttons that would shift with no change of their own (a group above grew) wait
	-- while one of them is under the mouse or an item is on the cursor.
	local function redraw(exempt)
		local pos = positionAll()
		local others = {}
		for _, k in ipairs(SB.Layout.Moves(v.pos, pos)) do
			if not exempt[k] then
				others[#others + 1] = k
			end
		end
		if anyBusy(others) then
			v.redrawPending = true
			v.stats.heldRedraws = (v.stats.heldRedraws or 0) + 1
			SB.Debounce(cfg.key .. ".retry", GV.RETRY, v.Retry, window)
			return false
		end
		v.redrawPending = false
		renderMoved(v.pos, pos)
		cfg.onResize(pos.width, pos.height, true)
		if cfg.onUpdated then
			cfg.onUpdated()
		end
		return true
	end

	function v.Changes(gid, list)
		local g = v.byId[gid]
		if not (g and v.pos) then
			return
		end
		local before = overflowOf(g)
		local res = applyGroup(g, list)
		local exempt = {}
		for _, k in ipairs(res.moved) do
			exempt[k] = true
		end
		local drawn = false
		if #res.moved > 0 or overflowOf(g) ~= before or v.redrawPending then
			drawn = redraw(exempt)
		end
		if not drawn then
			paintTiles(v.pos) -- a held drop shows its item; one picked back up, its number again
		end
		if res.deferred > 0 then
			SB.Debounce(cfg.key .. ".retry", GV.RETRY, v.Retry, window)
		end
	end

	-- 300 ms after something was held back: every group's waiting changes, then the redraw.
	function v.Retry()
		if not v.pos then
			return
		end
		local exempt, again, any = {}, false, v.redrawPending
		for _, g in ipairs(v.groups) do
			if g.state and #g.state.deferred > 0 then
				local res = applyGroup(g, {})
				for _, k in ipairs(res.moved) do
					exempt[k] = true
				end
				any = any or #res.moved > 0
				again = again or res.deferred > 0
			end
		end
		if any then
			redraw(exempt)
		end
		if again then
			SB.Debounce(cfg.key .. ".retry", GV.RETRY, v.Retry, window)
		end
	end

	---------------------------------------------------------------------------
	-- Collapse
	---------------------------------------------------------------------------
	-- Redraw only the headers (a new deposit target, a renamed tab): nothing moves.
	function v.Relabel()
		if v.pos then
			renderExtras(v.pos)
		end
	end

	-- A count or a price changed a section's total with nothing moving: set the section
	-- headers' texts in place (only those that differ). Group headers and pools are untouched.
	function v.RefreshTotals()
		if not v.pos then
			return
		end
		local labels = sectionLabels(v.pos)
		for i, h in ipairs(v.pos.headers) do
			SB.SectionHeaders.SetLabel(cfg.child, h.group .. ":" .. h.id, labels[i])
		end
	end

	function v.Restack()
		if not v.pos then
			return true
		end
		local pos = positionAll()
		if anyBusy(SB.Layout.Moves(v.pos, pos)) then
			SB.Debounce(cfg.key .. ".restack", GV.RETRY, v.Restack, window)
			return false
		end
		renderMoved(v.pos, pos)
		v.redrawPending = false -- positionAll drew every group's current state
		cfg.onResize(pos.width, pos.height, true)
		if cfg.onUpdated then
			cfg.onUpdated()
		end
		return true
	end

	function v.ToggleSection(gid, sid)
		local set = collapsedFor(gid)
		set[sid] = not set[sid] or nil
		return v.Restack()
	end

	function v.ToggleGroup(gid)
		local set = collapsedFor("#")
		set[gid] = not set[gid] or nil
		return v.Restack()
	end

	---------------------------------------------------------------------------
	-- Access
	---------------------------------------------------------------------------
	function v.ForEachSlot(fn)
		for _, c in ipairs(v.cells) do
			local button = cfg.button(c.bag, c.slot)
			if button then
				fn(button, v.records[keyOf(c.bag, c.slot)], c.bag, c.slot)
			end
		end
	end

	function v.Record(bag, slot)
		return v.records[keyOf(bag, slot)]
	end

	function v.SetRecord(bag, slot, record)
		v.records[keyOf(bag, slot)] = record
	end

	function v.GroupOf(bag)
		return v.groupOf[bag]
	end

	function v.Size(bag)
		return v.sizes[bag]
	end

	function v.IsOpen()
		return v.pos ~= nil
	end

	function v.Clear()
		if v.pos then
			for _, c in ipairs(v.pos.cells) do
				local button = cfg.button(c.bag, c.slot)
				if button then
					button:Hide()
				end
			end
		end
		v.groups, v.byId, v.pos, v.cells, v.redrawPending, v.heldKey = {}, {}, nil, {}, false, nil
		SB.Buttons.ReleasePlaceholders(cfg.child)
		SB.SectionHeaders.ReleaseAll(cfg.child)
	end

	return v
end
