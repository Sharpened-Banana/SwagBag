-- SwagBag bags window (spec F1, F3). Two views, switched with the header button
-- without /reload, in or out of combat (AC3.1):
--   "sections" (default)  category sections from Engine/Layout.lua: New on top, Free
--                         at the bottom, collapsible headers remembered per character
--   "grid"                one grid in physical slot order (AC3.6)
-- Movable, Ctrl+wheel scale 50-200 %, remembers its position per character, closes on
-- Esc, scrolls with a clamped offset (spec 4.4), and stays hidden until laid out.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local W = {
	records = {}, -- [bag][slot] = item record (Items.Describe) for every slot in the view
	cells = {}, -- { {bag, slot, ...} } every slot in the view, shown or collapsed (search dims these)
	sizes = {}, -- [bag] = number of slots laid out
	stats = {},
	sortSawUpdate = false, -- a bag update arrived since the pending Sort began
	sortPending = false, -- a Sort was pressed and its bag updates are still settling
	state = nil, -- sections view: Layout state while open (nil when closed or in grid view)
	pos = nil, -- sections view: last Layout.Position result
	placed = {}, -- [button] = "x,y" of its last SetPoint, so unchanged buttons are not touched
	tiled = {}, -- [button] = true while it shows a free tile's number (plan D19)
	size = { 100, 100 }, -- last content width, height
	SLOT = 37,
	GAP = 4,
	PAD = 4,
	HEADER = 58, -- title row + search row
	FOOTER = 6,
	SECTION_HEADER = 20,
	SECTION_GAP = 6,
	MAX_HEIGHT_FRACTION = 0.75,
	SCALE_STEP = 0.05,
	RETRY = 0.3, -- spec 4.2 rule 5: held-back moves retry 300 ms later
	SORT_SETTLE = 0.3, -- regroup this long after the last bag update of a sort
	SORT_TIMEOUT = 1.5, -- a sort that never changes anything stops waiting after this long (W3)
	DROP_GUARD = 0.3, -- the click that follows a drop on the same header is ignored for this long
}
SB.BagsWindow = W

local frame = CreateFrame("Frame", "SwagBagBagsWindow", UIParent, "BackdropTemplate")
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:Hide()
if frame.SetDontSavePosition then
	frame:SetDontSavePosition(true) -- SwagBag keeps its own saved position
end
W.frame = frame
table.insert(UISpecialFrames, "SwagBagBagsWindow")

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", 10, -8)
frame.title:SetText(L.BAGS_TITLE)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", 4, -W.HEADER)
scroll:SetPoint("BOTTOMRIGHT", -4, W.FOOTER)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(100, 100)
scroll:SetScrollChild(child)
W.scroll, W.child = scroll, child
SB.Buttons.SetParentFor("bags", child)

function W.ClampScroll()
	scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll(), child:GetHeight(), scroll:GetHeight()))
end

-- Esc, the X button and W.Close() all hide the frame. Spec 4.3 "window closes":
-- placeholders are released and the layout is forgotten; the next open lays out fully.
-- Alt+Z hides UIParent, which fires OnHide while the frame itself is still shown: that guard
-- stays first. A view toggle or reopen can emit SB_BAGS_CLOSED mid-frame, so the reset below
-- is idempotent and the next Open always rebuilds everything from scratch.
frame:SetScript("OnHide", Guard("bags.hide", function(self)
	if self:IsShown() then
		return
	end
	W.state, W.pos, W.sortPending, W.sortSawUpdate, W.dragging = nil, nil, false, false, false
	W.ClearDropGuard()
	SB.Buttons.ReleasePlaceholders(child)
	SB.Emit("SB_BAGS_CLOSED")
end, "bags"))

---------------------------------------------------------------------------
-- Title feedback, position and scale
---------------------------------------------------------------------------
local titleToken = 0
local flashing = false

-- The title at rest: "SwagBag — ilvl 279.4" (the average item level the character wears,
-- one decimal) while bags.showIlvl is on and the client answers; otherwise "SwagBag" (D18).
function W.Title()
	if SB.Config.Get("bags.showIlvl") then
		local ilvl = SB.Adapter.EquippedItemLevel()
		if ilvl then
			return L.BAGS_TITLE_ILVL:format(ilvl)
		end
	end
	return L.BAGS_TITLE
end

-- Shows the resting title, unless a flash is up (the flash puts the resting title back).
function W.RefreshTitle()
	if not flashing then
		frame.title:SetText(W.Title())
	end
end

-- Show text in the title for 1.5 s (feedback for header buttons and scaling, P2), then
-- the resting title.
function W.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	flashing = true
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("bags.flash", function()
		if token == titleToken then
			flashing = false
			frame.title:SetText(W.Title())
		end
	end, "bags"))
end

-- A gear swap changes the item level in the title. SB.On skips an event the client does
-- not know, so a missing PLAYER_AVG_ITEM_LEVEL_UPDATE costs nothing.
local function itemLevelChanged()
	if frame:IsShown() then
		W.RefreshTitle()
	end
end
SB.On("PLAYER_EQUIPMENT_CHANGED", itemLevelChanged, "bags")
SB.On("PLAYER_AVG_ITEM_LEVEL_UPDATE", itemLevelChanged, "bags")

function W.RestorePosition()
	local p = SB.Config.UI().positions.bags
	frame:ClearAllPoints()
	if type(p) == "table" and p[1] then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 100)
	end
end

-- Saved as the top-left corner so a reopen lands where the window was. Old saved tables
-- (a point plus offsets) are still accepted by RestorePosition as they are.
local function savePosition()
	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top then
		SB.Config.UI().positions.bags = { "TOPLEFT", "BOTTOMLEFT", left, top }
	end
end

-- While the window is being dragged nothing re-anchors it (a scale change or a resize waits
-- for the drop; the drop saves the new corner).
frame:SetScript("OnDragStart", Guard("bags.dragStart", function()
	W.dragging = true
	frame:StartMoving()
end, "bags"))
frame:SetScript("OnDragStop", Guard("bags.dragStop", function()
	W.dragging = false
	frame:StopMovingOrSizing()
	savePosition()
end, "bags"))

-- Fit the window around content of width x height (scroll when taller than 75 % of the screen).
-- With keepTop the top-left corner stays put (every resize except open); otherwise the
-- window grows around whatever anchor RestorePosition set.
local function sizeFrame(width, height, keepTop)
	local left, top = frame:GetLeft(), frame:GetTop()
	W.size = { width, height }
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * W.MAX_HEIGHT_FRACTION / frame:GetScale()
	local viewHeight = math.min(height, maxHeight - W.HEADER - W.FOOTER)
	frame:SetSize(width + 8, viewHeight + W.HEADER + W.FOOTER)
	if keepTop and left and top and not W.dragging then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	end
	W.ClampScroll()
end

-- Scaling only resizes the window; nothing is regrouped. The new corner is saved at once, so
-- a reopen lands where the window is now (the saved offsets are in the new scale).
function W.SetScale(scale)
	scale = SB.GridLayout.ClampScale(scale)
	SB.Config.Set("bags.scale", scale)
	-- Offsets are in the frame's own scale, so keep the corner's screen position across the change.
	local oldScale, left, top = frame:GetScale(), frame:GetLeft(), frame:GetTop()
	frame:SetScale(scale)
	if left and top and frame:IsShown() and not W.dragging then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * oldScale / scale, top * oldScale / scale)
		savePosition()
	end
	W.Flash(L.BAGS_SCALE:format(math.floor(scale * 100 + 0.5)))
	if frame:IsShown() then
		sizeFrame(W.size[1], W.size[2], true)
	end
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("bags.wheel", function(_, delta)
	if IsControlKeyDown() then
		W.SetScale(SB.Config.Get("bags.scale") + delta * W.SCALE_STEP)
		return
	end
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (W.SLOT + W.GAP) * 3)
	W.ClampScroll()
end, "bags"))

---------------------------------------------------------------------------
-- Views and collapse state
---------------------------------------------------------------------------
function W.View()
	return SB.Config.Get("bags.view") == "grid" and "grid" or "sections"
end

-- [sectionId] = true for collapsed sections, saved per character (AC3.2).
function W.Collapsed()
	local ui = SB.Config.UI()
	ui.collapsed = type(ui.collapsed) == "table" and ui.collapsed or {}
	ui.collapsed.bags = type(ui.collapsed.bags) == "table" and ui.collapsed.bags or {}
	return ui.collapsed.bags
end

local function columns()
	return SB.Config.Get("bags.columns")
end

local function positionOpts()
	return { columns = columns(), size = W.SLOT, gap = W.GAP, padding = W.PAD, header = W.SECTION_HEADER,
		sectionGap = W.SECTION_GAP }
end

local function titleButton(text, label, onClick, width)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(width or 72, 18)
	b:SetText(text)
	b:SetScript("OnClick", Guard(label, onClick, "bags"))
	return b
end

-- Config is not initialized while this file loads, so the real label is set in W.Open().
W.viewButton = titleButton(L.VIEW_TO_GRID, "bags.viewButton", function()
	W.ToggleView()
end)
W.viewButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local function bagList()
	local A, list = SB.Adapter, {}
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		local n = A.NumSlots(bag)
		if n > 0 then
			list[#list + 1] = { bag = bag, size = n }
		end
	end
	return list
end

-- Overlays (spec F9) follow the record; an empty reagent-bag slot gets its Free cue.
local function overlay(bag, slot)
	if SB.Overlays then
		SB.Overlays.Apply(SB.Buttons.Get(bag, slot), W.records[bag] and W.records[bag][slot], bag)
	end
end

local function describe(bag, slot)
	W.records[bag] = W.records[bag] or {}
	local record = SB.Items.Describe(bag, slot)
	if record and not record.icon then -- a pending item has no slot icon yet: placeholders still need one
		record.icon = (SB.Adapter.GetItemInstant(record.itemID) or {}).icon
	end
	W.records[bag][slot] = record
	overlay(bag, slot)
	return record
end

-- Count, lock, cooldown and loaded-data changes: refresh the record only while the slot still
-- holds the same item. An emptied slot keeps the record the layout was built from, so its
-- placeholder keeps its icon even if a lock event arrives before the bag flush.
local function refreshRecord(bag, slot)
	local old = W.records[bag] and W.records[bag][slot]
	local fresh = SB.Items.Describe(bag, slot)
	if old and fresh and fresh.itemID == old.itemID then
		fresh.icon = fresh.icon or old.icon
		W.records[bag][slot] = fresh
		overlay(bag, slot)
	end
end

local function place(button, x, y)
	local at = x .. "," .. y
	if W.placed[button] ~= at then
		SB.Buttons.Place(button, x, y)
		W.placed[button] = at
	end
end

-- The free tile's number (plan D19): each family's tile shows how many empty slots the family
-- has, but only while the tile really is empty (a drop that waits under the mouse shows the
-- item and no number). Every other button's number is cleared.
local function paintTiles(pos)
	local B, now = SB.Buttons, {}
	for _, t in ipairs(pos and pos.tiles or {}) do
		local button = B.Get(t.bag, t.slot)
		if button and t.shown and not (W.records[t.bag] and W.records[t.bag][t.slot]) then
			B.SetFreeCount(button, t.count)
			now[button] = true
		end
	end
	for button in pairs(W.tiled) do
		if not now[button] then
			B.SetFreeCount(button, nil)
		end
	end
	W.tiled = now
end

-- The grid is the physical order (AC3.6): every empty slot is shown there, no tile.
local function layoutGrid(bags)
	local A, B = SB.Adapter, SB.Buttons
	local g = SB.GridLayout.Compute(bags, { columns = columns(), size = W.SLOT, gap = W.GAP, padding = W.PAD })
	W.cells = g.cells
	for _, c in ipairs(g.cells) do
		local button = B.Get(c.bag, c.slot)
		if button then
			place(button, c.x, c.y)
			B.Paint(button, A.GetSlot(c.bag, c.slot))
			describe(c.bag, c.slot)
			button:Show()
		end
	end
	paintTiles(nil)
	return g.width, g.height
end

-- A cell whose slot is past the bag's current size (the bag shrank and the "removed" change
-- is still held back) is never shown.
local function inBag(c)
	return c.slot <= (W.sizes[c.bag] or 0)
end

local function showAt(button, c)
	if c.shown and inBag(c) then
		place(button, c.x, c.y)
		button:Show()
	else
		button:Hide()
	end
end

-- Each section header's text, with its total value (spec F10) when that setting is on.
local function headerLabels(pos)
	local H = SB.SectionHeaders
	local totals = H.Totals(W.state, function(bag, slot)
		return W.records[bag] and W.records[bag][slot]
	end) or {}
	local vendor, labels = H.IsVendor(), {}
	for i, h in ipairs(pos.headers) do
		labels[i] = H.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow, totals[h.id], vendor)
	end
	return labels
end

-- Placeholders and headers (a handful) are redrawn whole; they live in this window's child,
-- so nothing another window drew is released.
local function renderExtras(pos)
	local B, H = SB.Buttons, SB.SectionHeaders
	B.ReleasePlaceholders(child)
	for _, p in ipairs(pos.placeholders) do
		if p.shown then
			B.AcquirePlaceholder(child, p.icon, W.SLOT, p.x, p.y)
		end
	end
	H.ReleaseAll(child)
	local labels = headerLabels(pos)
	for i, h in ipairs(pos.headers) do
		H.Acquire(child, h.id, labels[i], W.PAD, h.y, pos.width - 2 * W.PAD)
	end
	W.headerSig = table.concat(labels, "\n")
end

-- A stack's count or an item's price can change a section's total with no button moving:
-- redraw the headers (only) when their text would differ.
function W.RefreshHeaders()
	if W.state and W.pos and table.concat(headerLabels(W.pos), "\n") ~= W.headerSig then
		renderExtras(W.pos)
	end
end

local function cellsOf(pos)
	local cells = {}
	for _, c in ipairs(pos.cells) do
		if inBag(c) then
			cells[#cells + 1] = c
		end
	end
	return cells
end

-- Put buttons, placeholders and headers where W.pos says. Returns width, height.
local function render()
	local B, pos = SB.Buttons, W.pos
	W.cells = {}
	for _, c in ipairs(pos.cells) do
		local button = B.Get(c.bag, c.slot)
		if button then
			showAt(button, c)
			if inBag(c) then
				W.cells[#W.cells + 1] = c
			end
		end
	end
	renderExtras(pos)
	paintTiles(pos)
	return pos.width, pos.height
end
W.Render = render

-- After Layout.Apply only the buttons whose cell changed are touched (Layout.Moves), plus the
-- placeholders, the headers and the free tiles' numbers: a few frame calls however many slots
-- the window holds (spec 9).
local function renderMoved(oldPos, newPos)
	local B = SB.Buttons
	for _, key in ipairs(SB.Layout.Moves(oldPos, newPos)) do
		local c = newPos.byKey[key]
		local button = B.Get(c.bag, c.slot)
		if button then
			showAt(button, c)
		end
	end
	for key, c in pairs(oldPos.byKey) do
		if not newPos.byKey[key] then -- a removed slot (the bag shrank)
			local button = B.Get(c.bag, c.slot)
			if button then
				button:Hide()
			end
		end
	end
	W.cells = cellsOf(newPos)
	renderExtras(newPos)
	paintTiles(newPos)
	return newPos.width, newPos.height
end

local function layoutSections(bags)
	local A, B = SB.Adapter, SB.Buttons
	local slots = {}
	for _, b in ipairs(bags) do
		for slot = 1, b.size do
			local button = B.Get(b.bag, slot)
			if button then -- nil only while combat delays pool growth (spec 4.3: slot invisible)
				B.Paint(button, A.GetSlot(b.bag, slot))
				slots[#slots + 1] = { bag = b.bag, slot = slot, record = describe(b.bag, slot) }
			end
		end
	end
	W.state = SB.Layout.Build(slots, SB.Categorizer.Assign, SB.Categories.SectionOrder(),
		{ columns = columns(), newRows = SB.Config.Get("bags.newRows"), freeTile = SB.Config.Get("bags.freeTile"),
			family = SB.Adapter.BagFamily })
	W.pos = SB.Layout.Position(W.state, positionOpts(), W.Collapsed())
	return render()
end

-- Full layout: every item to its section (or the physical grid). Called on open and by
-- explicit actions only, never by bag updates in the sections view.
function W.Layout(reason)
	local A, B = SB.Adapter, SB.Buttons
	local t0 = A.ProfileMs()
	local bags = bagList()
	W.sizes = {}
	for _, b in ipairs(bags) do
		W.sizes[b.bag] = b.size
		if B.Count(b.bag) < b.size then
			B.EnsureCapacity(b.bag, b.size)
		end
	end
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		for slot = (W.sizes[bag] or 0) + 1, B.Count(bag) do
			B.Get(bag, slot):Hide()
		end
	end
	W.records, W.state, W.pos = {}, nil, nil
	B.ReleasePlaceholders(child)
	SB.SectionHeaders.ReleaseAll(child)
	local width, height
	if W.View() == "grid" then
		width, height = layoutGrid(bags)
	else
		width, height = layoutSections(bags)
	end
	sizeFrame(width, height, reason ~= "open")
	W.stats.lastLayoutMs = A.ProfileMs() - t0
	W.stats.lastLayoutReason = reason
	SB.Emit("SB_BAGS_LAYOUT", reason)
end

local function buttonBusy(bag, slot)
	local button = SB.Buttons.Get(bag, slot)
	return button ~= nil and button:IsShown() and button:IsMouseOver()
end
W.ButtonBusy = buttonBusy

-- Spec 4.2 rule 5, one definition for every move: busyCheck() returns isBusy(bag, slot),
-- true while an item is on the cursor or that button is under the mouse (the cursor is
-- read once), plus whether the cursor holds an item.
local function busyCheck()
	local cursor = SB.Adapter.CursorItem() ~= nil
	return function(bag, slot)
		return cursor or buttonBusy(bag, slot)
	end, cursor
end

-- A re-stack waits while an item is on the cursor or one of the buttons that would move
-- is under the mouse.
local function anyBusy(keys)
	local busy, cursor = busyCheck()
	if cursor then
		return true
	end
	for _, key in ipairs(keys) do
		if busy(math.floor(key / 1000), key % 1000) then
			return true
		end
	end
	return false
end

-- Collapse/expand re-stack (spec 6.4): same cells, new section offsets.
function W.Restack()
	if not W.state then
		return true
	end
	local pos = SB.Layout.Position(W.state, positionOpts(), W.Collapsed())
	if anyBusy(SB.Layout.Moves(W.pos, pos)) then
		SB.Debounce("bags.restack", W.RETRY, W.Restack, "bags")
		return false
	end
	W.pos = pos
	local width, height = render()
	sizeFrame(width, height, true)
	SB.Emit("SB_BAGS_UPDATED")
	return true
end

function W.ToggleSection(id)
	local set = W.Collapsed()
	set[id] = not set[id] or nil
	W.Restack()
end

-- A full layout moves many buttons, so it waits while an item is on the cursor or the
-- mouse is over the items (spec 4.3: Reflow/sort "guarded by rule 5"), retrying every 300 ms.
function W.RequestLayout(reason)
	if not frame:IsShown() then
		return false
	end
	if SB.Adapter.CursorItem() or scroll:IsMouseOver() then
		SB.Debounce("bags.layout", W.RETRY, function()
			W.RequestLayout(reason)
		end, "bags")
		return false
	end
	W.Layout(reason)
	return true
end

function W.SetView(view)
	SB.Config.Set("bags.view", view)
	W.viewButton:SetText(view == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	W.Flash(view == "grid" and L.VIEW_GRID or L.VIEW_SECTIONS)
	W.RequestLayout("view")
end

function W.ToggleView()
	W.SetView(W.View() == "grid" and "sections" or "grid")
end

-- Reflow button (spec 4.3): regroup now, or as soon as the mouse leaves the items.
function W.Reflow(reason)
	if not frame:IsShown() then
		return false
	end
	local done = W.RequestLayout(reason or "reflow")
	W.Flash(done and L.REFLOW_DONE or L.REFLOW_WAITING)
	return done
end

-- Sort button (AC2.7, spec 5.5): Blizzard's own sort moves items physically, and it is only
-- known to work from a click. In combat nothing is queued: Sort says so and does nothing,
-- the user presses it again (W11). Bag updates during the sort follow spec 4.3 as usual;
-- SORT_SETTLE after the last one the window regroups (a guarded full layout). If the sort
-- changes nothing, the timeout below still clears sortPending (W3).
function W.Sort()
	local A = SB.Adapter
	if A.InCombat() then
		W.Flash(L.SORT_AFTER_COMBAT)
		return false
	end
	local ok, err = A.SortBags()
	if not ok then
		if err ~= nil then
			SB.ErrorTrap.OnError("bags.sort", "none", tostring(err), A.Stack())
		end
		W.Flash(L.SORT_UNAVAILABLE)
		return false
	end
	if not W.sortPending then
		W.sortSawUpdate = false
	end
	W.sortPending = frame:IsShown()
	if W.sortPending then
		-- A second Sort replaces a running settle; if the first sort already changed bags, its
		-- regroup still happens when this timeout ends.
		SB.Debounce("bags.sortSettle", W.SORT_TIMEOUT, function()
			local saw = W.sortSawUpdate
			W.sortPending, W.sortSawUpdate = false, false
			if saw then
				W.Reflow("sort")
			end
		end, "bags")
	end
	W.Flash(L.SORT_STARTED)
	return true
end

local function itemName(itemID, link)
	local info = SB.Adapter.GetItemInfo(itemID)
	if info and info.name then
		return info.name
	end
	return (type(link) == "string" and link:match("%[(.-)%]")) or tostring(itemID)
end

-- A click on a header can follow its drop (the client sends both for one press), and the
-- cursor is empty by then: for DROP_GUARD seconds after a drop on a header, the next
-- click or drop on that same header is ignored, so one press runs one drop and never a collapse.
local dropGuard, dropToken = nil, 0
function W.ClearDropGuard()
	dropGuard, dropToken = nil, dropToken + 1
end

-- AC4.3: an item dropped on a header (or clicked onto it) joins that section's manual
-- list. Order: read the cursor, add, confirm in chat, and only then put the item back (a
-- refused drop keeps it on the cursor). It moves into the section on the next open or
-- Reflow, never under the cursor (P5).
function W.DropOnSection(id)
	local A, C = SB.Adapter, SB.Categories
	local itemID, link = A.CursorItem()
	if not itemID then
		return false
	end
	dropToken = dropToken + 1
	local token = dropToken
	dropGuard = id
	A.After(W.DROP_GUARD, Guard("bags.dropGuard", function()
		if token == dropToken then
			dropGuard = nil
		end
	end, "bags"))
	if id == C.NEW or id == C.FREE then
		SB.Print(L.DROP_NOT_HERE:format(C.Name(id)))
		return false
	end
	if not C.AddToList(id, itemID) then
		SB.Print(SB.Config.readOnly and L.DROP_READONLY or L.DROP_INVALID)
		return false
	end
	SB.Print(L.DROP_ADDED:format(itemName(itemID, link), C.Name(id)))
	A.ClearCursor()
	return true
end

SB.SectionHeaders.onClick = function(id)
	if dropGuard == id then
		return
	end
	if SB.Adapter.CursorItem() then
		W.DropOnSection(id)
	else
		W.ToggleSection(id)
	end
end
SB.SectionHeaders.onDrop = function(id)
	if dropGuard ~= id then
		W.DropOnSection(id)
	end
end

W.reflowButton = titleButton(L.BTN_REFLOW, "bags.reflowButton", function()
	W.Reflow("reflow")
end, 60)
W.reflowButton:SetPoint("RIGHT", W.viewButton, "LEFT", -4, 0)
W.sortButton = titleButton(L.BTN_SORT, "bags.sortButton", function()
	W.Sort()
end, 52)
W.sortButton:SetPoint("RIGHT", W.reflowButton, "LEFT", -4, 0)

-- fn(button, record-or-nil, bag, slot) for every slot in the view (collapsed ones too).
function W.ForEachSlot(fn)
	local B = SB.Buttons
	for _, c in ipairs(W.cells) do
		local button = B.Get(c.bag, c.slot)
		if button then
			fn(button, W.records[c.bag] and W.records[c.bag][c.slot], c.bag, c.slot)
		end
	end
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
function W.IsOpen()
	return frame:IsShown()
end

function W.Open()
	if SB.SafeMode.IsOn("bags") or not SB.Buttons.created then
		return false
	end
	if frame:IsShown() then
		return true
	end
	W.RestorePosition()
	frame:SetScale(SB.GridLayout.ClampScale(SB.Config.Get("bags.scale")))
	W.sortPending, W.sortSawUpdate = false, false
	W.viewButton:SetText(W.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	W.RefreshTitle()
	frame:Show()
	W.Layout("open")
	return true
end

function W.Close()
	frame:Hide()
end

function W.Toggle()
	if frame:IsShown() then
		W.Close()
	else
		W.Open()
	end
end

---------------------------------------------------------------------------
-- Live updates while open (spec 4.3)
--   grid view:     repaint in place; a bag that changes size lays the grid out again
--   sections view: count, lock, cooldown and loaded data repaint in place; an emptied
--                  slot or a different item goes through Layout.Apply (placeholder, New,
--                  Free); a bag that grows or shrinks adds or removes Free slots. A button
--                  under the mouse, or every button while an item is on the cursor, waits
--                  and retries 300 ms later (spec 4.2 rule 5). No OnUpdate anywhere.
---------------------------------------------------------------------------
-- Apply transitions to the open sections layout and redraw. Returns Layout.Apply's result.
function W.ApplyChanges(changes)
	local st = W.state
	if not st then
		return nil
	end
	local newSec = st.sections[SB.Layout.NEW]
	local overflowBefore = newSec and newSec.overflow or 0
	local result = SB.Layout.Apply(st, changes, (busyCheck()), W.Collapsed())
	newSec = st.sections[SB.Layout.NEW]
	-- New's "+N more below" can change with no button moving, so the headers redraw then too.
	if #result.moved > 0 or (newSec and newSec.overflow or 0) ~= overflowBefore then
		result.rendered = true
		local oldPos = W.pos
		W.pos = SB.Layout.Position(st, positionOpts(), W.Collapsed())
		local width, height = renderMoved(oldPos, W.pos)
		sizeFrame(width, height, true)
	end
	if result.deferred > 0 then
		SB.Debounce("bags.retry", W.RETRY, function()
			local retried = W.ApplyChanges({})
			if retried and retried.rendered then
				SB.Emit("SB_BAGS_UPDATED")
			end
		end, "bags")
	end
	return result
end

-- Slots added or removed since the last layout (a bag was equipped or taken off).
local function sizeChanges()
	local A, B, out = SB.Adapter, SB.Buttons, {}
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		local old, new = W.sizes[bag] or 0, A.NumSlots(bag)
		if new > B.Count(bag) then
			B.EnsureCapacity(bag, new) -- queued until combat ends; the slot stays invisible meanwhile
		end
		for slot = old + 1, new do
			local button = B.Get(bag, slot)
			if button then
				B.Paint(button, A.GetSlot(bag, slot))
				describe(bag, slot)
				out[#out + 1] = { bag = bag, slot = slot, kind = "added" }
			end
		end
		for slot = new + 1, old do
			local button = B.Get(bag, slot)
			if button then
				button:Hide()
			end
			if W.records[bag] then
				W.records[bag][slot] = nil
			end
			out[#out + 1] = { bag = bag, slot = slot, kind = "removed" }
		end
		W.sizes[bag] = new
	end
	return out
end

SB.Inventory.OnChanged(Guard("bags.inventory", function(mask, changes)
	if not frame:IsShown() then
		return
	end
	local Inv, B, A = SB.Inventory, SB.Buttons, SB.Adapter
	-- Sort settle: regroup SORT_SETTLE after the LAST update (rule 5 applies). A cooldown-only
	-- event is not a bag change and does not count.
	if W.sortPending and (Inv.Has(mask, Inv.R.COUNT) or Inv.Has(mask, Inv.R.ITEM) or Inv.Has(mask, Inv.R.SIZE)
		or Inv.Has(mask, Inv.R.LOCK) or Inv.Has(mask, Inv.R.LOADED)) then
		W.sortSawUpdate = true
		SB.Debounce("bags.sortSettle", W.SORT_SETTLE, function()
			W.sortPending, W.sortSawUpdate = false, false
			W.Reflow("sort")
		end, "bags")
	end
	if not W.state and Inv.Has(mask, Inv.R.SIZE) then
		W.RequestLayout("size") -- grid view: the grid is the physical order; guarded by rule 5
		return
	end
	local touched = false
	if Inv.Has(mask, Inv.R.COOLDOWN) then
		W.ForEachSlot(function(button, record)
			if record and button.UpdateCooldown then
				pcall(button.UpdateCooldown, button, record.icon)
			end
		end)
		-- A cooldown/usable search must not go stale; never a rescan otherwise (spec 9).
		if SB.Search and SB.Search.NeedsVolatileRefresh() then
			W.ForEachSlot(function(_, record)
				if record then
					SB.Items.RefreshVolatile(record)
				end
			end)
			touched = true
		end
	end
	local moves = {}
	if W.state and Inv.Has(mask, Inv.R.SIZE) then
		moves = sizeChanges()
		touched = touched or #moves > 0
	end
	for _, c in ipairs(changes) do
		local button = B.Get(c.bag, c.slot)
		if B.KindOf(c.bag) == "bags" and button and c.slot <= (W.sizes[c.bag] or 0) then
			local old = W.records[c.bag] and W.records[c.bag][c.slot]
			B.Paint(button, A.GetSlot(c.bag, c.slot))
			touched = true
			if not Inv.Has(c.reasons, Inv.R.ITEM) then
				refreshRecord(c.bag, c.slot)
			else
				local record = describe(c.bag, c.slot)
				-- Same itemID, new link (keystone level, enchant, gem): repaint in place; the
				-- item is re-categorized on the next open or Reflow (W12).
				local sameItem = old and record and old.itemID == record.itemID
				if W.state and not sameItem and (record or old) then
					moves[#moves + 1] = { bag = c.bag, slot = c.slot, kind = record and "arrived" or "left",
						icon = old and old.icon }
				end
			end
		end
	end
	local applied
	if W.state and (#moves > 0 or #W.state.deferred > 0) then
		applied = W.ApplyChanges(moves)
	end
	if W.state and not (applied and applied.rendered) then
		-- Repaint tiles: a held drop picked back up shows its number again at once (Paint hides
		-- the number on a filled button but never restores it). A redraw already did it.
		paintTiles(W.pos)
	end
	if touched then
		W.RefreshHeaders()
		SB.Emit("SB_BAGS_UPDATED")
	end
end, "bags"))

-- /swagbag free tile|all (Core/Commands.lua): regroup now, or once the mouse leaves the items.
SB.On("SB_FREE_TILE_CHANGED", function()
	W.RequestLayout("free")
end, "bags")

-- A bag equipped, taken off or swapped (W3-21). A swap for a bag of the same size changes no
-- slot count, but its empty slots may now be another family (a herb bag for a plain bag), so
-- the window regroups: a full layout, guarded by rule 5 (it waits while the mouse is over the
-- items or an item is on the cursor). Debounced so the bag's own updates land first. SB.On
-- skips an event the client does not know.
W.BAG_CHANGE_DELAY = 0.1
SB.On("BAG_CONTAINER_UPDATE", function()
	if frame:IsShown() then
		SB.Debounce("bags.container", W.BAG_CHANGE_DELAY, function()
			W.RequestLayout("bags")
		end, "bags")
	end
end, "bags")
