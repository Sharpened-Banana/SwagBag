-- SwagBag group view (spec F2, F16, section 4): the contents of the bank window (two groups:
-- character bank and warband bank) and of the guild bank window (one group per tab). A view
-- is a stack of GROUPS in one scroll child. Each group has a header (name, item count,
-- collapse, a tint for "deposits go here") and under it either its own category sections
-- (New, categories, Free: one Engine/Layout.lua state per group) or, in the grid view, its
-- slots in physical order. In the list view (week 8, spec 2.2 v1.3, like the bags window's) each
-- group's sections show one row per slot: the slot's own button scaled to the row's height
-- (SetScale only: a button is never made, reparented or re-ID'd for it), then its name, count,
-- item level and value (UI/ListRows.lua, cfg.rows), each section in Engine/Sort.lua's order. A
-- button whose scale does not take is never drawn in a row (F6): that layout draws as categories
-- instead, recorded under "none" and said once per opening (cfg.onListFailed).
-- While the window is open the bags window's rules hold (spec 4.2, 4.3): a button moves only
-- into New or Free, never while it is under the mouse and never while an item is on the
-- cursor. A group that grows (Free gains a row) pushes the groups below it down; that push
-- waits too while one of the pushed buttons is under the mouse. Held-back work retries 300 ms
-- later through SB.Debounce (no OnUpdate). A redraw touches only the buttons whose cell
-- changed (Layout.Moves), so a 1,290-slot bank stays inside the spec 9 incremental budget.
--   local v = SB.GroupView.New(cfg)
--   v.Layout(reason) -> width, height   full layout (open, Reflow, sort, view toggle)
--   v.RequestLayout(reason) -> bool     the same, held back while anything is on the cursor (CursorBusy)
--                                       or a button that would move is under the mouse (4.3)
--   v.PendingLoaded(changes) -> bool    0.13.3: Inventory LOADED changes; regroups (debounced, held) when one is
--                                       for an item the last full layout put in New because it was pending
--   v.Changes(groupId, list)            live changes { { bag, slot, kind, icon } }, kind
--                                       "left" | "arrived" | "added" | "removed" (Layout.Apply)
--   v.Restack() -> bool                 redraw after a collapse or expand (held back like a move)
--   v.ToggleSection(groupId, sectionId), v.ToggleGroup(groupId)
--   v.Relabel()                         redraw the headers only (nothing moves)
--   v.RefreshTotals()                   section headers' text in place (a count or price changed)
--   v.ForEachSlot(fn)                   fn(button, record, bag, slot) for every slot (search), the stacks
--                                       hidden under a grouped icon included
--   v.PaintStacks()                     stack grouping (0.14.0): each grouped icon's total (and list row) in
--                                       place, after a count changed; nothing moves
--   v.RelightStacks()                   after a search: a grouped icon stays lit while a hidden stack matches
--   v.stacked                           [button] = its pos.stacks entry while it shows a group's total
--   v.Record(bag, slot), v.SetRecord(bag, slot, record), v.GroupOf(bag), v.Size(bag), v.IsOpen()
--   v.Clear()                           window closed: hide the buttons, forget the layout
--   v.drawn                             the view the current layout was drawn in ("sections" |
--                                       "list" | "grid"); the setting may differ while a layout waits
--   v.stats = { lastLayoutMs, lastLayoutReason, phases = { groups, read, categories, positions,
--     drawing } }   the last full layout's time, and where it went (ms; week 6, D20: /swagbag report)
-- cfg = { key = "bank" | "guild", window = ErrorTrap window (default "bank"), child, scroll,
--   button(bag, slot) -> button | nil;  describe(bag, slot) -> record | nil (paints the button),
--   groups() -> { { id, bags = { { bag, size } } } } in display order,
--   groupLabel(groupId, collapsed, count) -> text;  groupTint(groupId) -> true to tint,
--   view() -> "sections" | "list" | "grid";  columns() -> n;  newRows() -> n,
--   rows optional: a ListRows object (UI/ListRows.lua) over cfg.child; without it "list" draws as
--   "sections";  onListFailed() optional: a list fell back to categories (F6),
--   family(bag) optional -> a bag family for the free tile (default Adapter.BagFamily),
--   onResize(width, height, keepTop);  onUpdated() optional, after a redraw while open,
--   onDrop(sectionId) optional: an item dropped on a section header,
--   sectionLabel(groupId, header) optional: header = { id, count, collapsed, overflow },
--   freeTile(view) optional -> true: each group's Free shows one tile per bag family with its
--   number of free slots (Engine/Layout.lua, plan D19; families from cfg.family),
--   stacks() optional -> bool, read at every build (0.14.0): true groups the stacks of one item in each
--   group's sections into one icon with the total (Engine/Stacks.lua; the character and warband banks
--   follow bags.stacks). Groups never mix: one Layout state per group. The guild bank and the alt
--   viewer pass none and never group.
--   hideEmptyNew optional: true, or a function returning a boolean (read at every build), hides each
--   group's New while it is empty (the alt viewer passes true; the bank windows follow bags.newAlways),
--   groupColor(groupId) optional -> r, g, b, a | nil: a faint band behind the whole group, from its header's
--   top to the next group's header (header only while folded); v.bands lists the bands drawn,
--   Week 13, all optional (the guild bank sets none of them and behaves as before; a window owns its own folds):
--   groupClosed(groupId) -> true | false | nil: a boolean decides whether the group is folded, nil falls
--   back to the saved set,
--   toggleGroup(groupId) -> bool: a group-header click asks the window first; true means it handled the
--   click (GroupView only restacks), false toggles the saved set as before,
--   groupInset(groupId) -> px: that group's header is drawn px narrower, leaving room for window controls,
--   groupTip(groupId, header): runs when the mouse enters a group header (leaving hides GameTooltip when
--   the header owns it),
--   onHeaders(list): after every draw with the group headers { id, y, count, collapsed } (y negative from
--   the child's top), and with {} from v.Clear();  v.GroupHeaders() returns the last list }
-- Collapse state is saved per character in ui.collapsed[key .. ":" .. groupId] (sections)
-- and ui.collapsed[key .. ":#"] (whole groups).
local _, SB = ...

local GV = { SLOT = 37, GAP = 4, PAD = 4, SECTION_HEADER = 20, SECTION_GAP = 6, GROUP_HEADER = 22, GROUP_GAP = 8,
	RETRY = 0.3, DROP_GUARD = 0.3,
	LOADED_DELAY = 0.5, -- 0.13.3: data loading for items pending in New regroups this long after the last load
	-- the list view (week 8): the bags window's sizes (UI/BagsWindow.lua), so every list looks the same
	LIST_ROW = 24, LIST_GAP = 2, LIST_WIDTH = 480, LIST_NEW_ROWS = 8, ROW_TEXT_GAP = 4, SCALE_EPSILON = 0.001 }
SB.GroupView = GV

-- Shared by the bank and guild bank windows (week 8): the view button's order (each click shows the
-- next one) and the button's label for it, and a column click's save-and-answer (the bags window keeps
-- its own, with the /swagbag list extras).
GV.VIEW_NEXT = { sections = "list", list = "grid", grid = "sections" }
GV.VIEW_BUTTON = { sections = SB.L.VIEW_TO_SECTIONS, list = SB.L.VIEW_TO_LIST, grid = SB.L.VIEW_TO_GRID }

-- Sort every list by `by` (again: the other way round; Engine/Sort.lua), saved in bags.list. flash(text)
-- answers in the window's title (P2). Returns false while the settings are read-only.
function GV.SortList(by, flash)
	local spec = SB.Sort.Next(SB.Sort.Spec(), by)
	if not SB.Sort.Save(spec.by, spec.desc) then
		flash(SB.L.SETTINGS_READONLY)
		return false
	end
	flash(SB.ListRows.SortedText(spec))
	return true
end

local function keyOf(bag, slot)
	return SB.Layout.Key(bag, slot)
end

function GV.New(cfg)
	assert(cfg.child, "GroupView.New: cfg.child is required")
	local Guard = SB.ErrorTrap.Guard
	local window = cfg.window or "bank" -- the ErrorTrap window of every entry point (spec P6)
	local v = { groups = {}, byId = {}, records = {}, cells = {}, placed = {}, sizes = {}, groupOf = {}, pos = nil,
		redrawPending = false, stats = {}, tiled = {}, drawn = "sections", listFailed = false, pendingNew = {},
		stacked = {}, -- [button] = its pos.stacks entry while it shows a stack group's total (0.14.0)
		dimmed = {} } -- [button] = what the search last set (v.SetDimmed), so a grouped icon can be relit
	local rows = cfg.rows

	-- The view a layout is built for: the setting, with "list" only when there are rows to draw it.
	-- (v.listFailed: a list's scale did not take this visit - F6 - so later layouts draw categories at once
	-- instead of scaling every button again and recording another error each time; v.Clear forgets it.)
	local function wanted()
		local view = cfg.view()
		if view == "list" and (not rows or v.listFailed) then
			return "sections"
		end
		return view
	end

	local function isList()
		return v.drawn == "list"
	end

	-- A row's texts start right of its icon and end at the list's right edge.
	local function rowWidth()
		return GV.LIST_WIDTH - 2 * GV.PAD - GV.LIST_ROW - GV.ROW_TEXT_GAP
	end
	v.RowWidth = rowWidth

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
		local own = cfg.groupClosed and cfg.groupClosed(gid)
		if type(own) == "boolean" then
			return own
		end
		return collapsedFor("#")[gid] == true
	end

	local function positionOpts(top, list)
		if list then -- one column of rows, each as tall as its (scaled) button
			return { columns = 1, size = GV.LIST_ROW, gap = GV.LIST_GAP, padding = GV.PAD, header = GV.SECTION_HEADER,
				sectionGap = GV.SECTION_GAP, top = top }
		end
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
	--   groupHeaders = { { id, y, count, collapsed } }, tiles = { free tile cells },
	--   stacks = { every group's pos.stacks entries }, width, height }
	-- groups/records/view default to the view's own (a full layout positions a candidate first).
	local function positionAll(groups, records, view)
		groups, records, view = groups or v.groups, records or v.records, view or v.drawn
		local list = view == "list"
		local cols = cfg.columns()
		local all = { cells = {}, byKey = {}, placeholders = {}, headers = {}, groupHeaders = {}, tiles = {}, stacks = {},
			width = list and GV.LIST_WIDTH or (GV.PAD * 2 + cols * GV.SLOT + (cols - 1) * GV.GAP) }
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
				pos = SB.Layout.Position(g.state, positionOpts(y, list), col)
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
			for _, e in ipairs(pos.stacks or {}) do -- each group's own (0.14.0): a folded group's are not shown
				e.shown = e.shown and not closed
				all.stacks[#all.stacks + 1] = e
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
	-- A point's offsets are in the button's own scale, so a button drawn smaller (the list) is
	-- offset by x / scale, y / scale to land on the same spot of the scroll child (as Buttons.Place).
	local function place(button, x, y)
		local at = x .. "," .. y
		if v.placed[button] ~= at then
			local scale = button:GetScale() or 1
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x / scale, y / scale)
			v.placed[button] = at
		end
	end

	local function scaleIs(button, scale)
		return math.abs((button:GetScale() or 1) - scale) < GV.SCALE_EPSILON
	end

	-- Buttons are drawn at row size in the list and at full size elsewhere (not protected, spec 4.1:
	-- legal in combat). A button whose scale changes is placed again. False when the scale did not take.
	local function setScale(button, scale)
		if not scaleIs(button, scale) then
			button:SetScale(scale)
			v.placed[button] = nil
		end
		return scaleIs(button, scale)
	end

	local function listScale()
		return GV.LIST_ROW / GV.SLOT
	end

	-- A cell past its bag's current size (a removal still held back) is never shown.
	local function inSize(c)
		return c.slot <= (v.sizes[c.bag] or 0)
	end

	-- Ruling W5-1 for the bank and guild lists (F6): a list row never shows a full-size button. One whose
	-- scale is not the row's stays hidden, row and all, and a full layout follows when the mouse allows.
	local function showAt(button, c)
		local shown = c.shown and inSize(c)
		if shown and isList() and not scaleIs(button, listScale()) then
			shown = false
			SB.Debounce(cfg.key .. ".scale", GV.RETRY, function()
				v.RequestLayout("scale")
			end, window)
		end
		if shown then
			place(button, c.x, c.y)
			button:Show()
		else
			button:Hide()
		end
		if isList() then -- a spare (hidden, no position) has no row either
			rows.Place(button, shown and c.x + GV.LIST_ROW + GV.ROW_TEXT_GAP, c.y, rowWidth(), GV.LIST_ROW, shown)
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
		elseif cfg.toggleGroup and cfg.toggleGroup(gid) then
			v.Restack() -- the window folded it itself: nothing to save
		else
			v.ToggleGroup(gid)
		end
	end

	-- Group headers only; section headers keep their behaviour (no tip).
	function owner.onEnter(id, header)
		if cfg.groupTip and id:sub(1, 1) == "#" then
			cfg.groupTip(id:sub(2), header)
		end
	end
	function owner.onLeave(id, header)
		if cfg.groupTip and id:sub(1, 1) == "#" and GameTooltip:GetOwner() == header then
			GameTooltip:Hide()
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

	-- The group bands (cfg.groupColor): one pooled texture per group on a plain frame sitting at the child's
	-- own level, so the buttons and headers (one level above) draw over it.
	local bandPool = {}
	v.bands = {}
	local function releaseBands()
		for i = #v.bands, 1, -1 do
			local b = v.bands[i]
			b.frame:Hide()
			bandPool[#bandPool + 1] = b
			v.bands[i] = nil
		end
	end
	local function drawBands(pos)
		releaseBands()
		if not cfg.groupColor then
			return
		end
		local child, list = cfg.child, pos.groupHeaders
		for i, g in ipairs(list) do
			local r, gr, b, a = cfg.groupColor(g.id)
			if r then
				local bottom = list[i + 1] and -list[i + 1].y or pos.height
				local height = g.collapsed and GV.GROUP_HEADER or (bottom + g.y)
				local band = table.remove(bandPool)
				if not band then
					local frame = CreateFrame("Frame", nil, child)
					band = { frame = frame, tex = frame:CreateTexture(nil, "BACKGROUND") }
					band.tex:SetAllPoints(frame)
				end
				band.frame:SetParent(child)
				band.frame:SetFrameLevel(child:GetFrameLevel())
				band.frame:ClearAllPoints()
				band.frame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, g.y)
				band.frame:SetSize(pos.width, height)
				band.tex:SetColorTexture(r, gr, b, a)
				band.frame:Show()
				band.id, band.height = g.id, height
				v.bands[#v.bands + 1] = band
			end
		end
	end

	-- Placeholders and headers are few: they are redrawn whole, inside this view's child only.
	local function renderExtras(pos)
		local B, H, child = SB.Buttons, SB.SectionHeaders, cfg.child
		local width = pos.width - 2 * GV.PAD
		B.ReleasePlaceholders(child)
		local ghosts = {}
		for _, p in ipairs(pos.placeholders) do
			if p.shown then
				B.AcquirePlaceholder(child, p.icon, isList() and GV.LIST_ROW or GV.SLOT, p.x, p.y, window, cfg.goneTip)
				ghosts[#ghosts + 1] = { x = p.x + GV.LIST_ROW + GV.ROW_TEXT_GAP, y = p.y }
			end
		end
		if isList() then -- a placeholder's row says the item moved or was used
			rows.Ghosts(ghosts, rowWidth(), GV.LIST_ROW)
		end
		H.ReleaseAll(child)
		drawBands(pos)
		for _, g in ipairs(pos.groupHeaders) do
			local inset = cfg.groupInset and cfg.groupInset(g.id) or 0
			local h = H.Acquire(child, "#" .. g.id, cfg.groupLabel(g.id, g.collapsed, g.count), GV.PAD, g.y,
				width - inset, owner)
			if cfg.groupTint and cfg.groupTint(g.id) then
				H.Tint(h, 0.25, 0.85, 0.35, 0.3)
			end
		end
		local labels = sectionLabels(pos)
		for i, h in ipairs(pos.headers) do
			H.Acquire(child, h.group .. ":" .. h.id, labels[i], GV.PAD, h.y, width, owner)
		end
		v.headers = pos.groupHeaders
	end

	-- The window hears about the headers once v.pos is set, trapped as this window: its error never
	-- leaves a half-drawn view behind.
	local function notifyList(list)
		if cfg.onHeaders then
			SB.ErrorTrap.Run("groupview.onHeaders", window, cfg.onHeaders, list)
		end
	end
	local function notifyHeaders(pos)
		notifyList(pos.groupHeaders)
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
	-- In the list a tile's row says how many are free (and for what); a button that stops being a tile
	-- gets its row's texts back from its record.
	local function paintTiles(pos)
		local now = {}
		for _, t in ipairs(pos.tiles) do
			local button = cfg.button(t.bag, t.slot)
			if button and t.shown and not v.records[keyOf(t.bag, t.slot)] then
				SB.Buttons.SetFreeCount(button, t.count)
				now[button] = t
				if isList() then
					rows.Paint(button, t.bag, t.slot, nil, t.count, t.tile)
				end
			end
		end
		for button, t in pairs(v.tiled) do
			if not now[button] then
				SB.Buttons.SetFreeCount(button, nil)
				if isList() then
					rows.Paint(button, t.bag, t.slot, v.records[keyOf(t.bag, t.slot)])
				end
			end
		end
		v.tiled = now
	end

	local function recordOf(bag, slot)
		return v.records[keyOf(bag, slot)]
	end

	-- Stack grouping (0.14.0), paintTiles' twin (the bags window's paintStacks): each shown group's icon
	-- shows the total (Buttons.SetStack, never Blizzard's count field) and, in the list, its row the total
	-- and the group's value. Every button no longer grouped gets its own number and row back.
	-- O(groups); nothing moves.
	local function paintStacks(pos)
		local B, now = SB.Buttons, {}
		for _, e in ipairs(pos and pos.stacks or {}) do
			local s = e.shown and SB.Stacks.Of(e, recordOf)
			local button = s and cfg.button(e.bag, e.slot)
			if button then
				B.SetStack(button, s)
				now[button] = e
				if isList() then
					rows.Paint(button, e.bag, e.slot, recordOf(e.bag, e.slot), nil, nil, s.total)
				end
			end
		end
		for button, e in pairs(v.stacked) do
			if not now[button] then
				B.SetStack(button, nil)
				if isList() then
					rows.Paint(button, e.bag, e.slot, recordOf(e.bag, e.slot))
				end
			end
		end
		v.stacked = now
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
		paintStacks(pos) -- before the tiles: a former icon that became the free tile keeps the tile's row
		paintTiles(pos)
		v.pos = pos
		notifyHeaders(pos)
	end

	local function hideGone(old, pos)
		for k, c in pairs(old.byKey) do
			if not pos.byKey[k] then
				local button = cfg.button(c.bag, c.slot)
				if button then
					button:Hide()
					if rows then
						rows.Place(button, 0, 0, 0, 0, false)
					end
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
		paintStacks(pos) -- before the tiles: a former icon that became the free tile keeps the tile's row
		paintTiles(pos)
		v.pos = pos
		notifyHeaders(pos)
	end

	---------------------------------------------------------------------------
	-- Rule 5: nothing moves under the mouse or while anything is on the cursor (week 10: a spell waiting
	-- for its target too, Adapter.CursorBusy)
	---------------------------------------------------------------------------
	local function busyCheck()
		local cursor = SB.Adapter.CursorBusy()
		return function(bag, slot)
			if cursor then
				return true
			end
			local b = cfg.button(bag, slot)
			-- in the list a row under the mouse holds its button too (P5: its text would move with it)
			return b ~= nil and b:IsShown() and (b:IsMouseOver() or (isList() and rows.IsMouseOver(b)))
		end, cursor
	end

	-- Week 9: the stacker's P5 check for one slot (Engine/Stacker.lua): an item on the cursor, or the slot's
	-- button (in a list, its row) under the mouse.
	function v.Busy(bag, slot)
		return (busyCheck())(bag, slot)
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
	local function hideNew()
		local h = cfg.hideEmptyNew
		if type(h) == "function" then
			return h() and true or false
		end
		return h
	end

	-- Read every slot into a fresh candidate (groups, records, sizes); nothing is drawn.
	-- b.ms: where the time went (the groups and their buttons, reading the slots, the categories).
	-- view: the view to build (default: the setting's, wanted()); b.view says which.
	local function build(view)
		local A = SB.Adapter
		view = view or wanted()
		local b = { groups = {}, byId = {}, records = {}, sizes = {}, groupOf = {}, view = view, pendingNew = {},
			ms = { groups = 0, read = 0, categories = 0, positions = 0, drawing = 0 } }
		-- 0.13.3: what goes to New because it cannot be categorised yet is remembered (v.PendingLoaded)
		local function assign(record)
			local id = SB.Categorizer.Assign(record)
			if id == nil and record.bag and record.slot then
				b.pendingNew[keyOf(record.bag, record.slot)] = record.itemID
			end
			return id
		end
		local sections = view ~= "grid"
		local list = view == "list"
		local order = sections and SB.Categories.SectionOrder() or nil
		-- 0.14.0: the window's choice, read once per build (no cfg.stacks: the guild bank, the alt viewer)
		local stackKey = sections and cfg.stacks and cfg.stacks() and SB.Stacks.Key or nil
		local t = A.ProfileMs()
		local defs = cfg.groups()
		b.ms.groups = A.ProfileMs() - t
		for _, def in ipairs(defs) do
			local g = { id = def.id, bags = def.bags }
			local slots = {}
			t = A.ProfileMs()
			for _, bag in ipairs(def.bags) do
				b.sizes[bag.bag], b.groupOf[bag.bag] = bag.size, def.id
				for slot = 1, bag.size do
					local button = cfg.button(bag.bag, slot)
					if button then
						local record = cfg.describe(bag.bag, slot)
						b.records[keyOf(bag.bag, slot)] = record
						slots[#slots + 1] = { bag = bag.bag, slot = slot, record = record }
						if list then
							rows.Paint(button, bag.bag, slot, record)
						end
					end
				end
			end
			b.ms.read = b.ms.read + A.ProfileMs() - t
			if sections then
				t = A.ProfileMs()
				if list then -- each section lists its items in the list's order (Engine/Sort.lua)
					local totalOf
					if stackKey then -- a stack group sorts by its total, counted in this group only (0.14.0)
						local keys = {}
						for _, s in ipairs(slots) do
							keys[s] = s.record and stackKey(s.record) or nil
						end
						local totals = SB.Stacks.Totals(slots, function(s)
							return keys[s]
						end)
						totalOf = function(s)
							return keys[s] and totals[keys[s]]
						end
					end
					slots = SB.Sort.DisplayOrder(slots, SB.Sort.Spec(), SB.Sort.Value, totalOf)
				end
				g.state = SB.Layout.Build(slots, assign, order, { columns = list and 1 or cfg.columns(),
					newRows = list and GV.LIST_NEW_ROWS or cfg.newRows(), freeTile = cfg.freeTile and cfg.freeTile(view) or nil,
					family = cfg.family or SB.Adapter.BagFamily, hideEmptyNew = hideNew(), stackKey = stackKey })
				b.ms.categories = b.ms.categories + A.ProfileMs() - t
			end
			b.groups[#b.groups + 1] = g
			b.byId[g.id] = g
		end
		return b
	end

	-- A candidate's positions, timed (b.ms.positions).
	local function positionTimed(b)
		local t = SB.Adapter.ProfileMs()
		local pos = positionAll(b.groups, b.records, b.view)
		b.ms.positions = SB.Adapter.ProfileMs() - t
		return pos
	end

	-- Every button of a candidate at one scale (F6: sized before the list is drawn). False when a
	-- scale did not take for any button.
	local function scaleAll(b, scale)
		local ok = true
		for _, g in ipairs(b.groups) do
			for _, bag in ipairs(g.bags) do
				for slot = 1, bag.size do
					local button = cfg.button(bag.bag, slot)
					if button and not setScale(button, scale) then
						ok = false
					end
				end
			end
		end
		return ok
	end

	-- F6: a full-size button in a 24 px row would cover the next row, so a click there could take or
	-- deposit the wrong item. That layout draws as categories instead: recorded (never Safe Mode), and
	-- the window says it once per opening (cfg.onListFailed).
	local function listFailed(b, held)
		-- A held fallback leaves a drawn list as it is until the retry lands it; drawn categories or grid get their
		-- buttons back at full size at once (week 8 deferred: some were shrunk already, smaller click targets).
		if not held or v.drawn ~= "list" then
			scaleAll(b, 1)
		end
		v.listFailed = true
		SB.ErrorTrap.OnError(cfg.key .. ".listScale", "none", "a slot button's SetScale did not take", nil)
		if cfg.onListFailed then
			cfg.onListFailed()
		end
	end

	-- Make a candidate the view's layout and draw it at pos.
	-- guard (RequestLayout): a fallback to categories moves buttons too, so it waits like any layout
	-- (P5): returns nil, the retry through SB.Debounce, when one of them is under the mouse.
	local function commit(b, pos, reason, t0, guard)
		local t1 = SB.Adapter.ProfileMs()
		if b.view == "list" and not scaleAll(b, listScale()) then
			local fallback = build("sections")
			local fallbackPos = positionTimed(fallback)
			if guard and v.pos and anyBusy(SB.Layout.Moves(v.pos, fallbackPos)) then
				listFailed(b, true)
				SB.Debounce(cfg.key .. ".layout", GV.RETRY, function()
					v.RequestLayout(reason)
				end, window)
				return nil
			end
			listFailed(b)
			b, pos = fallback, fallbackPos
		elseif b.view ~= "list" then
			scaleAll(b, 1)
		end
		local old = v.pos
		v.groups, v.byId, v.records, v.sizes, v.groupOf, v.redrawPending = b.groups, b.byId, b.records, b.sizes,
			b.groupOf, false
		v.pendingNew = b.pendingNew
		v.drawn = b.view
		v.heldKey = nil -- any layout that lands (v.Layout too) ends a held RequestLayout's reason
		if old then
			hideGone(old, pos)
		end
		if rows then -- the rows drawn now are placed again by render (a list), or stay hidden
			rows.HideAll()
		end
		render(pos)
		cfg.onResize(pos.width, pos.height, reason ~= "open")
		local now = SB.Adapter.ProfileMs()
		v.stats.lastLayoutMs = now - t0
		v.stats.lastLayoutReason = reason
		b.ms.drawing = now - t1
		v.stats.phases = b.ms
		return pos.width, pos.height
	end

	function v.Layout(reason)
		local t0 = SB.Adapter.ProfileMs()
		local b = build()
		return commit(b, positionTimed(b), reason, t0)
	end

	-- A full layout while open (Reflow, sort, view toggle, a tab's first answer): held back,
	-- retrying every 300 ms, only while anything is on the cursor (CursorBusy) or a button that would move
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
			pos = positionTimed(b)
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
		if not commit(b, pos, reason, t0, true) then
			return false -- a list fell back to categories and that waits under the mouse (P5)
		end
		if cfg.onUpdated then
			cfg.onUpdated()
		end
		return true
	end

	-- 0.13.3 (the root cause of the Warband bank's New flood at the first visit after a cold client start): data
	-- arriving (Inventory's LOADED changes { { bag, slot, reasons } }) for an item the last full layout put in New
	-- because it could not be categorised yet lays the view out again, LOADED_DELAY after the last such load (a
	-- burst is one regroup), through v.RequestLayout (held like any layout, P5). A load for an item already in its
	-- category, or one after which the item still has no data, regroups nothing. It also waits while the mouse is
	-- over cfg.scroll (the window's item area). Returns true when a regroup was asked for.
	function v.PendingLoaded(changes)
		if not v.pos then
			return false
		end
		local Inv = SB.Inventory
		for _, c in ipairs(changes) do
			local itemID = Inv.Has(c.reasons, Inv.R.LOADED) and v.pendingNew[keyOf(c.bag, c.slot)]
			local s = itemID and Inv.GetSlot(c.bag, c.slot)
			local record = s and v.records[keyOf(c.bag, c.slot)] -- the window refreshed it before calling
			if s and s.itemID == itemID and record and not record.pending then
				local function land()
					if not v.pos then
						return
					end
					-- not started by the player: also waits while the mouse is anywhere over the items (an item
					-- could slide into the empty cell or placeholder under it), as the guild bank and the bags do
					if cfg.scroll and cfg.scroll:IsMouseOver() then
						SB.Debounce(cfg.key .. ".loaded", GV.RETRY, land, window)
						return
					end
					v.RequestLayout("loaded")
				end
				SB.Debounce(cfg.key .. ".loaded", GV.LOADED_DELAY, land, window)
				return true
			end
		end
		return false
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
	-- while one of them is under the mouse or anything is on the cursor (CursorBusy).
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
			-- a held change (the shown stack withdrawn under the mouse) takes the total off at once (0.14.0)
			paintStacks(v.pos)
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
			notifyHeaders(v.pos)
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
			v.restackHeld = true -- the drawing is behind what a window's rule says (a header click waits)
			SB.Debounce(cfg.key .. ".restack", GV.RETRY, v.Restack, window)
			return false
		end
		v.restackHeld = false
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

	-- A live repaint (count, lock, loaded data, an item that arrived or left): in the list the row's texts
	-- follow, in place (nothing moves). A grouped icon's row is v.PaintStacks' (it shows the group's total).
	function v.SetRecord(bag, slot, record)
		v.records[keyOf(bag, slot)] = record
		if isList() and v.pos then
			local button = cfg.button(bag, slot)
			if button and not v.tiled[button] and not v.stacked[button] then
				rows.Paint(button, bag, slot, record)
			end
		end
	end

	-- Prices changed (F8): each row's Value follows, texts only; nothing moves and nothing re-sorts.
	function v.RefreshRows()
		if not (isList() and v.pos) then
			return
		end
		v.ForEachSlot(function(button, record, bag, slot)
			if record then
				rows.Paint(button, bag, slot, record)
			end
		end)
		paintStacks(v.pos) -- a grouped row's value is the whole group's
	end

	-- A count changed with nothing moving (the bank's inventory handler): each group's total follows, in place.
	function v.PaintStacks()
		if v.pos then
			paintStacks(v.pos)
		end
	end

	-- Search dimming: the button, and in the list its row (AC5.1).
	function v.SetDimmed(button, dimmed)
		v.dimmed[button] = dimmed
		SB.Buttons.SetDimmed(button, dimmed)
		if rows then
			rows.SetDimmed(button, dimmed)
		end
	end

	-- After each search (the window's SearchBox afterApply, 0.14.0): a grouped icon stays lit while any of
	-- its hidden stacks matches (`count<10` finds the 7 under the 45's icon). Alpha only; nothing moves.
	function v.RelightStacks()
		for _, e in ipairs(v.pos and v.pos.stacks or {}) do
			local rep = e.shown and cfg.button(e.bag, e.slot)
			if rep and v.dimmed[rep] then
				for _, m in ipairs(e.members) do
					local member = cfg.button(m.bag, m.slot)
					if member and not v.dimmed[member] then
						v.SetDimmed(rep, false)
						break
					end
				end
			end
		end
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
		for button in pairs(v.stacked) do -- each grouped icon gets its own number back (0.14.0)
			SB.Buttons.SetStack(button, nil)
		end
		v.stacked = {}
		v.groups, v.byId, v.pos, v.cells, v.redrawPending, v.heldKey, v.pendingNew = {}, {}, nil, {}, false, nil, {}
		v.listFailed, v.restackHeld = false, false
		SB.Buttons.ReleasePlaceholders(cfg.child)
		SB.SectionHeaders.ReleaseAll(cfg.child)
		releaseBands()
		if rows then
			rows.HideAll()
		end
		v.headers = {}
		notifyList({})
	end

	function v.GroupHeaders()
		return v.headers or {}
	end

	return v
end
