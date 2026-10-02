-- SwagBag bags window (spec F1, F3). Three views, switched with the header button
-- without /reload, in or out of combat (AC3.1):
--   "sections" (default)  category sections from Engine/Layout.lua: New on top, Free
--                         at the bottom, collapsible headers remembered per character
--   "list"                the same sections, one row per slot (spec 2.2 v1.3): the slot's own
--                         button, scaled to the row's height, then its name, count, item level
--                         and value (UI/ListRows.lua), each section in the order of
--                         Engine/Sort.lua. Same layout engine, so New, Free, placeholders,
--                         collapse, focus modes and the hover guard work exactly as in "sections"
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
	view = nil, -- sections view: the collapsed lookup W.pos was built with (what is drawn, W4-1)
	drawn = "sections", -- the view the current layout was drawn in (the setting may change before a held layout)
	areaHeld = false, -- a world-started re-stack is waiting for the mouse to leave the items (W4-13)
	placed = {}, -- [button] = "x,y" of its last SetPoint, so unchanged buttons are not touched
	tiled = {}, -- [button] = its tile entry ({ bag, slot, ... }) while it shows a free tile's number (plan D19)
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
	LIST_ROW = 24, -- list view: a row's height, and its slot button's size (the button is scaled to it)
	LIST_GAP = 2, -- list view: the gap between two rows
	LIST_WIDTH = 480, -- list view: the item area's width
	LIST_NEW_ROWS = 8, -- list view: rows New keeps while open, a dungeon's loot (F7; the sections view keeps bags.newRows rows)
	ROW_TEXT_GAP = 4, -- list view: between a row's icon and its texts
	COLUMNS_H = 18, -- list view: the column header bar under the search box
	SCALE_EPSILON = 0.001, -- a button's scale "took" when GetScale() is this close to the wanted one (F6)
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

-- The title and search rows, plus the list view's column bar while the list is drawn (W4-1: the
-- drawn view, never the setting, so a view change held under the mouse keeps the old header room).
function W.HeaderHeight()
	return W.HEADER + (W.drawn == "list" and W.COLUMNS_H or 0)
end

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", 4, -W.HEADER)
scroll:SetPoint("BOTTOMRIGHT", -4, W.FOOTER)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(100, 100)
scroll:SetScrollChild(child)
W.scroll, W.child = scroll, child
SB.Buttons.SetParentFor("bags", child)
-- The list view's rows (UI/ListRows.lua). Without that file (a load failure) the bags show the
-- category view instead of the list. A click on a row's text answers in the title (F24); W.Flash
-- is defined below, so it is looked up when the click comes.
W.rows = SB.ListRows and SB.ListRows.New(child, "bags", function(text)
	W.Flash(text)
end) or nil

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
	W.state, W.pos, W.view, W.sortPending, W.sortSawUpdate, W.dragging = nil, nil, nil, false, false, false
	W.areaHeld, W.scaleWarned = false, false
	W.ClearDropGuard()
	if SB.Focus then
		SB.Focus.WindowClosed() -- peeks and closes end with the bag; pins stay until the mode changes (spec 6.1)
	end
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
-- While a focus mode is active (or modes are paused) its name comes first: "SwagBag — M+ —
-- ilvl 279.4", "SwagBag — Paused" (AC8.5, spec 6.1).
function W.Title()
	local mode = SB.Focus and SB.Focus.Label()
	local ilvl = SB.Config.Get("bags.showIlvl") and SB.Adapter.EquippedItemLevel() or nil
	if mode and ilvl then
		return L.BAGS_TITLE_MODE_ILVL:format(mode, ilvl)
	elseif mode then
		return L.BAGS_TITLE_MODE:format(mode)
	elseif ilvl then
		return L.BAGS_TITLE_ILVL:format(ilvl)
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
-- the resting title. The title ends left of the title buttons (W3-26), so a long flash in a narrow
-- window is cut short with "...": then the whole text also goes to chat, so the answer is never
-- lost (week-4 deferred M4). quiet: the caller answers in chat (or the settings status line)
-- itself, so a cut-short flash adds no second line.
function W.Flash(text, quiet)
	titleToken = titleToken + 1
	local token = titleToken
	flashing = true
	frame.title:SetText(text)
	if not quiet and frame.title.IsTruncated and frame.title:IsTruncated() then
		SB.Print(text)
	end
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
-- The drop fits the window again (week-4 deferred): a grow that waited for the pointer (W4-25) stops
-- retrying while the window is dragged, so the drop starts it again from the new corner.
frame:SetScript("OnDragStop", Guard("bags.dragStop", function()
	W.dragging = false
	frame:StopMovingOrSizing()
	savePosition()
	W.Resize()
end, "bags"))

-- Fit the window around content of width x height (scroll when taller than 75 % of the screen).
-- With keepTop the top-left corner stays put (every resize except open); otherwise the
-- window grows around whatever anchor RestorePosition set.
-- The footer bar (UI/Footer.lua, ruling W4-14) sits under the items: its height (one row or more)
-- is part of the window and the scroll area ends above it, so it never covers an item. While a
-- footer shrink is held (W.footHeld, see W.Resize) every resize keeps the old, taller footer room,
-- so no other path applies the shrink under the mouse.
-- With keepTop the view is also no taller than the room between the top edge and the bottom of
-- the screen (ruling W4-22): the frame is clamped to the screen, and a window that ran past the
-- bottom would be pushed up by the client, moving every item. The scroll area shortens instead.
-- Ruling W4-25: that clamp alone would leave a window opened low unable to grow again. When the
-- wanted view is taller than the room below the top edge and nothing is under the pointer (the
-- mouse is off the window, the cursor is empty), the top edge moves up by the shortfall (up to the
-- 75 % limit and the top of the screen) and the new corner is saved. Otherwise the view is capped
-- as above and W.Resize retries every 300 ms until the pointer leaves (P5).
local function sizeFrame(width, height, keepTop)
	local left, top = frame:GetLeft(), frame:GetTop()
	W.size = { width, height }
	child:SetSize(width, height)
	if not keepTop then
		W.footHeld = false -- opening lays out from scratch
	end
	local foot = W.FOOTER + (SB.Footer and SB.Footer.Layout(width + 8) or 0)
	if W.footHeld and W.foot and foot < W.foot then
		foot = W.foot
	end
	W.foot = foot
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, foot)
	local header = W.HeaderHeight()
	local maxHeight = UIParent:GetHeight() * W.MAX_HEIGHT_FRACTION / frame:GetScale()
	local viewHeight = math.min(height, maxHeight - header - foot)
	local pinned = keepTop and type(left) == "number" and type(top) == "number" and not W.dragging
	local grown = false
	if pinned then
		local shortfall = viewHeight - (top - header - foot)
		if shortfall > 0 then
			if not (frame:IsMouseOver() or scroll:IsMouseOver() or SB.Adapter.CursorItem()) then
				-- Ruling W4-25: nothing is under the pointer, so the whole window may move (P5): the top
				-- edge goes up by the shortfall, never past the top of the screen. The bottom edge stays
				-- on the screen (the room clamp below still holds).
				local screenTop = UIParent:GetHeight() / frame:GetScale()
				local newTop = math.min(top + shortfall, screenTop)
				grown = newTop ~= top
				top = newTop
			else
				-- The window would move under the mouse or a held item: capped as before (W4-22), and
				-- the grow is tried again once the pointer leaves (same pattern as the footer shrink).
				SB.Debounce("bags.grow", W.RETRY, W.Resize, "bags")
			end
		end
		viewHeight = math.max(0, math.min(viewHeight, top - header - foot))
	end
	frame:SetSize(width + 8, viewHeight + header + foot)
	if pinned then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		if grown then
			savePosition() -- a reopen lands where the window is now
		end
	end
	W.ClampScroll()
end

-- The footer's height changed: fit the window again, its top-left corner fixed (C1). A taller
-- footer grows the window downward (or, at the height limit or the bottom of the screen, shortens
-- the scroll area from the bottom), so nothing in the scroll area moves. A shorter one can pull a
-- scrolled view down (the scroll offset is clamped to the taller view), so it waits like any other
-- move while the mouse is over the items or an item is on the cursor (spec 4.2 rule 5), retrying
-- every 300 ms; until then the smaller bar leaves a gap and covers nothing.
function W.Resize()
	if not frame:IsShown() then
		W.footHeld = false
		return
	end
	local foot = W.FOOTER + (SB.Footer and SB.Footer.height or 0)
	if W.foot and foot < W.foot and (scroll:IsMouseOver() or SB.Adapter.CursorItem()) then
		W.footHeld = true
		SB.Debounce("bags.footerResize", W.RETRY, W.Resize, "bags")
		return
	end
	W.footHeld = false
	sizeFrame(W.size[1], W.size[2], true)
end

-- Scaling only resizes the window; nothing is regrouped. The new corner is saved at once, so
-- a reopen lands where the window is now (the saved offsets are in the new scale).
-- quiet: the caller answers itself (the Settings status line), so a cut-short flash adds no chat
-- line (ruling W5-4).
function W.SetScale(scale, quiet)
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
	W.Flash(L.BAGS_SCALE:format(math.floor(scale * 100 + 0.5)), quiet)
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
	-- Three rows (or three icon rows) per notch, in the drawn view's pitch.
	local step = W.drawn == "list" and (W.LIST_ROW + W.LIST_GAP) or (W.SLOT + W.GAP)
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * step * 3)
	W.ClampScroll()
end, "bags"))

---------------------------------------------------------------------------
-- Views and collapse state
---------------------------------------------------------------------------
W.VIEWS = { "sections", "list", "grid" } -- the view button's order: each click shows the next one
local VIEW_NEXT = { sections = "list", list = "grid", grid = "sections" }
local VIEW_BUTTON = { sections = L.VIEW_TO_SECTIONS, list = L.VIEW_TO_LIST, grid = L.VIEW_TO_GRID }
local VIEW_FLASH = { sections = L.VIEW_SECTIONS, list = L.VIEW_LIST, grid = L.VIEW_GRID }

function W.View()
	local v = SB.Config.Get("bags.view")
	if v == "grid" or v == "list" then
		return v
	end
	return "sections"
end

local function isList()
	return W.drawn == "list"
end

-- [sectionId] = true for collapsed sections, saved per character (AC3.2).
function W.Collapsed()
	local ui = SB.Config.UI()
	ui.collapsed = type(ui.collapsed) == "table" and ui.collapsed or {}
	ui.collapsed.bags = type(ui.collapsed.bags) == "table" and ui.collapsed.bags or {}
	return ui.collapsed.bags
end

-- What the layout treats as collapsed: the saved set above, or while a focus mode applies the
-- mode's set with this session's peeks and pins (Engine/Focus.lua). The saved set is never
-- written by a mode, so leaving the mode shows the user's own state again (AC8.2). Asked fresh
-- for every layout and re-stack, never kept across a mode change.
function W.EffectiveCollapsed()
	local own = W.Collapsed()
	return SB.Focus and SB.Focus.CollapsedView(own) or own
end

-- A frozen copy of a collapsed lookup for the sections in st (the only ids Layout reads), so
-- W.view stays what is drawn: a later header toggle or mode switch changes only the live
-- lookup, never the copy (ruling W4-1).
local function snapshot(st, lookup)
	local out = {}
	for _, id in ipairs(st.order) do
		if lookup[id] == true then
			out[id] = true
		end
	end
	return out
end

local function columns()
	return SB.Config.Get("bags.columns")
end

local function positionOpts()
	if isList() then -- one column of rows, each as tall as its (scaled) button
		return { columns = 1, size = W.LIST_ROW, gap = W.LIST_GAP, padding = W.PAD, header = W.SECTION_HEADER,
			sectionGap = W.SECTION_GAP }
	end
	return { columns = columns(), size = W.SLOT, gap = W.GAP, padding = W.PAD, header = W.SECTION_HEADER,
		sectionGap = W.SECTION_GAP }
end

-- Layout.Position for the drawn view. A list is LIST_WIDTH wide (its single column of cells is
-- only an icon wide; the rows' texts fill the rest).
local function position(st, view)
	local pos = SB.Layout.Position(st, positionOpts(), view)
	if isList() then
		pos.width = W.LIST_WIDTH
	end
	return pos
end

-- A row's texts start right of its icon and end at the item area's right edge.
local function rowWidth()
	return W.LIST_WIDTH - 2 * W.PAD - W.LIST_ROW - W.ROW_TEXT_GAP
end

local function scaleIs(button, scale)
	return math.abs((button:GetScale() or 1) - scale) < W.SCALE_EPSILON
end

-- Slot buttons are drawn at row size in the list view and at full size elsewhere. Buttons are not
-- protected (spec 4.1), so this is legal in combat; Buttons.Place keeps offsets in the parent's
-- units at any scale. A button whose scale changes is placed again. Returns false when the scale
-- did not take (F6: the caller must not draw it in a list row, where a full-size button would
-- overlap the next row's icon and a click there could use or sell the wrong item).
local function setScale(button, scale)
	if not scaleIs(button, scale) then
		button:SetScale(scale)
		W.placed[button] = nil
	end
	return scaleIs(button, scale)
end

local function slotScale()
	return isList() and W.LIST_ROW / W.SLOT or 1
end

local function titleButton(text, label, onClick, width)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(width or 72, 18)
	b:SetText(text)
	b:SetScript("OnClick", Guard(label, onClick, "bags"))
	return b
end

-- Config is not initialized while this file loads, so the real label is set in W.Open(). The button
-- names the view a click shows next (sections -> list -> grid -> sections).
W.viewButton = titleButton(L.VIEW_TO_LIST, "bags.viewButton", function()
	W.ToggleView()
end)
W.viewButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)

---------------------------------------------------------------------------
-- The list view's column bar: Name, Count, ilvl, Value over the rows' texts. A click sorts by
-- that column (again: the other way round), saved (bags.list), and the list regroups now or once
-- the mouse leaves the items (P5: re-sorting never moves a row under the mouse). Plain buttons.
-- Preflight a2: the bar starts at frame x 4 + PAD + LIST_ROW + ROW_TEXT_GAP, where the rows' texts
-- start (scroll frame x 4, row x PAD + LIST_ROW + ROW_TEXT_GAP), and uses the rows' own columns.
---------------------------------------------------------------------------
local COLUMN_NAMES = { name = L.LIST_COL_NAME, count = L.LIST_COL_COUNT, ilvl = L.LIST_COL_ILVL,
	value = L.LIST_COL_VALUE }
W.columnsBar = CreateFrame("Frame", nil, frame)
W.columnsBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4 + W.PAD + W.LIST_ROW + W.ROW_TEXT_GAP, -W.HEADER)
W.columnsBar:SetSize(rowWidth(), W.COLUMNS_H)
W.columnsBar:Hide()
W.columnButtons = {}
-- TOC order: Engine/Sort.lua and UI/ListRows.lua load before this file (SwagBag.toc), and each sets
-- SB.Sort / SB.ListRows on its first line, so the bar, SortList, RefreshColumns and /swagbag list
-- use them unguarded.
local barColumns = SB.ListRows.Columns(rowWidth())
for _, id in ipairs(SB.Sort.COLUMNS) do
	local b = CreateFrame("Button", nil, W.columnsBar)
	b:SetPoint("TOPLEFT", W.columnsBar, "TOPLEFT", barColumns[id].x, 0)
	b:SetSize(barColumns[id].width, W.COLUMNS_H)
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.label:SetAllPoints(b)
	b.label:SetJustifyH(id == "name" and "LEFT" or "RIGHT")
	b.label:SetText(COLUMN_NAMES[id])
	b:SetScript("OnClick", Guard("bags.listColumn", function()
		W.SortList(id)
	end, "bags"))
	W.columnButtons[id] = b
end

-- How a direction reads for a column: names A to Z, numbers highest first.
local function direction(by, desc)
	if by == "name" then
		return desc and L.LIST_Z_TO_A or L.LIST_A_TO_Z
	end
	return desc and L.LIST_HIGH_FIRST or L.LIST_LOW_FIRST
end

-- The column the list is sorted by carries a marker: "Value v" (down) or "Value ^" (up).
function W.RefreshColumns()
	local spec = SB.Sort.Spec()
	for id, b in pairs(W.columnButtons) do
		if id == spec.by then
			b.label:SetText((spec.desc and L.LIST_COL_DOWN or L.LIST_COL_UP):format(COLUMN_NAMES[id]))
		else
			b.label:SetText(COLUMN_NAMES[id])
		end
	end
end

-- by: a column; desc: the direction, or nil for a click (the same column flips, another starts at
-- its natural direction, Sort.Next). Saved, answered in the title (P2), and the open list regroups
-- through a full layout held while the mouse is over the items or an item is on the cursor (P5).
-- Returns true, or false (with the reason in the title) while the settings are read-only.
-- quiet: the caller (/swagbag list, so also the Settings rows) answers in chat itself (W.Flash).
function W.SortList(by, desc, quiet)
	local spec = SB.Sort.Next(SB.Sort.Spec(), by)
	if desc ~= nil then
		spec.desc = desc
	end
	if not SB.Sort.Save(spec.by, spec.desc) then
		W.Flash(L.SETTINGS_READONLY, quiet)
		return false
	end
	W.RefreshColumns()
	W.Flash(L.LIST_SORTED:format(COLUMN_NAMES[spec.by], direction(spec.by, spec.desc)), quiet)
	if frame:IsShown() and isList() then
		W.RequestLayout("listsort")
	end
	return true
end

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

-- Overlays (spec F9) follow the record; an empty reagent-bag slot gets its Free cue. In the list
-- view the row's texts follow it too (every repaint of a slot comes through here).
local function overlay(bag, slot)
	local record = W.records[bag] and W.records[bag][slot]
	if SB.Overlays then
		SB.Overlays.Apply(SB.Buttons.Get(bag, slot), record, bag)
	end
	if isList() then
		local button = SB.Buttons.Get(bag, slot)
		if button then
			W.rows.Paint(button, bag, slot, record)
		end
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
			now[button] = t
			if isList() then -- F9: the tile's family, so a reagent bag's row says reagents only
				W.rows.Paint(button, t.bag, t.slot, nil, t.count, t.tile)
			end
		end
	end
	for button, t in pairs(W.tiled) do
		if not now[button] then
			B.SetFreeCount(button, nil)
			if isList() then -- a tile that filled or became a plain empty slot: its row says what it holds now
				W.rows.Paint(button, t.bag, t.slot, W.records[t.bag] and W.records[t.bag][t.slot])
			end
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
			setScale(button, 1)
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

-- Ruling W5-1 (F6 invariant): a list row never shows a full-size button. A slot whose scale did
-- not take (a bag equipped while the list is open) stays hidden, row and all, and a full layout
-- (which draws the list as categories) follows as soon as the mouse allows.
local function showAt(button, c)
	local shown = c.shown and inBag(c)
	if shown and isList() and not scaleIs(button, W.LIST_ROW / W.SLOT) then
		shown = false
		-- W.RETRY, never 0 (ruling W5-3): should the fallback ever fail to take, this asks again
		-- every 300 ms, not every frame.
		SB.Debounce("bags.scale", W.RETRY, function()
			W.RequestLayout("scale")
		end, "bags")
	end
	if shown then
		place(button, c.x, c.y)
		button:Show()
	else
		button:Hide()
	end
	if isList() then -- a spare (hidden, no position) has no row either
		W.rows.Place(button, shown and c.x + W.LIST_ROW + W.ROW_TEXT_GAP, c.y, rowWidth(), W.LIST_ROW, shown)
	end
end

-- Each section header's text, with its total value (spec F10) when that setting is on.
local function headerLabels(pos)
	local H = SB.SectionHeaders
	local totals = H.Totals(W.state, function(bag, slot)
		return W.records[bag] and W.records[bag][slot]
	end) or {}
	local vendor, labels = H.IsVendor(), {}
	local F = SB.Focus
	local focused = F and F.Applies()
	for i, h in ipairs(pos.headers) do
		labels[i] = H.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow, totals[h.id], vendor)
		-- Only on a header drawn open: a peek or pin whose re-stack still waits shows "+" alone.
		local o = focused and not h.collapsed and F.OverrideOf(h.id)
		if o == "peek" then
			labels[i] = labels[i] .. L.HEADER_PEEK
		elseif o == "pin" then
			labels[i] = labels[i] .. L.HEADER_PINNED
		end
	end
	return labels
end

-- Placeholders and headers (a handful) are redrawn whole; they live in this window's child,
-- so nothing another window drew is released.
local function renderExtras(pos)
	local B, H = SB.Buttons, SB.SectionHeaders
	B.ReleasePlaceholders(child)
	local ghosts = {}
	for _, p in ipairs(pos.placeholders) do
		if p.shown then
			B.AcquirePlaceholder(child, p.icon, isList() and W.LIST_ROW or W.SLOT, p.x, p.y)
			ghosts[#ghosts + 1] = { x = p.x + W.LIST_ROW + W.ROW_TEXT_GAP, y = p.y }
		end
	end
	if isList() then -- a placeholder's row says the item moved or was used
		W.rows.Ghosts(ghosts, rowWidth(), W.LIST_ROW)
	end
	H.ReleaseAll(child)
	local labels = headerLabels(pos)
	for i, h in ipairs(pos.headers) do
		H.Acquire(child, h.id, labels[i], W.PAD, h.y, pos.width - 2 * W.PAD)
	end
end

-- A stack's count or an item's price can change a section's total with no button moving:
-- set the header texts in place (only those that differ); nothing is released or acquired.
function W.RefreshHeaders()
	if not (W.state and W.pos and frame:IsShown()) then
		return
	end
	local H = SB.SectionHeaders
	local labels = headerLabels(W.pos)
	for i, h in ipairs(W.pos.headers) do
		H.SetLabel(child, h.id, labels[i])
	end
end

-- F8: in the list view each row's Value follows a price change the same way, texts only (it
-- must add up to its header). Nothing moves and nothing re-sorts: the order changes only with a
-- full layout (open, Reflow, a view change), which waits while the mouse is over the items.
function W.RefreshRows()
	if not (isList() and W.state and frame:IsShown()) then
		return
	end
	W.ForEachSlot(function(button, record, bag, slot)
		if record then -- an empty slot or a free tile has no value
			W.rows.Paint(button, bag, slot, record)
		end
	end)
end

SB.On("SB_PRICES_CHANGED", function()
	W.RefreshHeaders()
	W.RefreshRows()
end, "bags")

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
				if isList() then
					W.rows.Place(button, 0, 0, 0, 0, false)
				end
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
	local scale = slotScale()
	for _, b in ipairs(bags) do
		for slot = 1, b.size do
			local button = B.Get(b.bag, slot)
			if button then -- nil only while combat delays pool growth (spec 4.3: slot invisible)
				setScale(button, scale)
				B.Paint(button, A.GetSlot(b.bag, slot))
				slots[#slots + 1] = { bag = b.bag, slot = slot, record = describe(b.bag, slot) }
			end
		end
	end
	-- The list view lays the slots out in its display order (Engine/Sort.lua): Layout keeps the
	-- order it is given inside each section. Empty slots keep their physical order.
	if isList() then
		slots = SB.Sort.DisplayOrder(slots, SB.Sort.Spec(), SB.Sort.Value)
	end
	-- New is hidden while empty unless bags.newAlways (ruling W4-15); the bank windows never hide it.
	W.state = SB.Layout.Build(slots, SB.Categorizer.Assign, SB.Categories.SectionOrder(),
		{ columns = isList() and 1 or columns(),
			newRows = isList() and W.LIST_NEW_ROWS or SB.Config.Get("bags.newRows"), freeTile = SB.Config.Get("bags.freeTile"),
			family = SB.Adapter.BagFamily, hideEmptyNew = not SB.Config.Get("bags.newAlways") })
	W.view = snapshot(W.state, W.EffectiveCollapsed())
	W.pos = position(W.state, W.view)
	return render()
end

-- F6 (item safety): every slot button is sized before the list is laid out. Returns false when a
-- scale did not take for any button.
local function scaleAll(bags, scale)
	local B, ok = SB.Buttons, true
	for _, b in ipairs(bags) do
		for slot = 1, b.size do
			local button = B.Get(b.bag, slot)
			if button and not setScale(button, scale) then
				ok = false
			end
		end
	end
	return ok
end

-- F6: a button left at full size in a 24 px row would overlap the next row's icon and text, so a
-- click there could use or sell the item of the row above. That layout draws as categories
-- instead, recorded in the error list (never Safe Mode) and said once in chat per opening.
local function listFailed(bags)
	W.drawn = "sections"
	scaleAll(bags, 1)
	SB.ErrorTrap.OnError("bags.listScale", "none", "a slot button's SetScale did not take", nil)
	if not W.scaleWarned then
		W.scaleWarned = true
		SB.Print(L.LIST_SCALE_FALLBACK)
	end
end

-- Full layout: every item to its section (or the physical grid). Called on open and by
-- explicit actions only, never by bag updates in the sections view.
function W.Layout(reason)
	local A, B = SB.Adapter, SB.Buttons
	local t0 = A.ProfileMs()
	W.drawn = W.View()
	if W.drawn == "list" and not W.rows then
		W.drawn = "sections"
	end
	if W.rows then
		W.rows.HideAll()
	end
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
	if isList() and not scaleAll(bags, slotScale()) then
		listFailed(bags)
	end
	-- the column bar shows above a drawn list only (after the F6 check: a fallback draws no bar);
	-- the scroll area starts under it
	if isList() then
		W.RefreshColumns()
		W.columnsBar:Show()
	else
		W.columnsBar:Hide()
	end
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -W.HeaderHeight())
	W.records, W.state, W.pos, W.view, W.areaHeld = {}, nil, nil, nil, false
	B.ReleasePlaceholders(child)
	SB.SectionHeaders.ReleaseAll(child)
	local width, height
	if W.drawn == "grid" then
		width, height = layoutGrid(bags)
	else
		width, height = layoutSections(bags)
	end
	sizeFrame(width, height, reason ~= "open")
	W.stats.lastLayoutMs = A.ProfileMs() - t0
	W.stats.lastLayoutReason = reason
	SB.Emit("SB_BAGS_LAYOUT", reason)
end

-- In the list view a row under the mouse holds its button as well (P5: its text would move too).
local function buttonBusy(bag, slot)
	local button = SB.Buttons.Get(bag, slot)
	return button ~= nil and button:IsShown() and (button:IsMouseOver() or (isList() and W.rows.IsMouseOver(button)))
end
W.ButtonBusy = buttonBusy

-- Search dimming (UI/SearchBox.lua): the button, and in the list view its row (AC5.1: fully dimmed).
function W.SetDimmed(button, dimmed)
	SB.Buttons.SetDimmed(button, dimmed)
	if W.rows then
		W.rows.SetDimmed(button, dimmed)
	end
end

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

-- Collapse/expand re-stack (spec 6.4): same cells, new section offsets, so no button moves
-- relative to its own header. Only the buttons whose position changes are touched. It waits
-- while an item is on the cursor or a button that would move is under the mouse, and retries
-- every 300 ms. A focus-mode switch comes here too: whichever state is current when the retry
-- runs is the one drawn (a switch that waits is never queued behind another). Only a re-stack
-- that runs switches W.view, the lookup ApplyChanges lays out with (ruling W4-1).
-- area = true (a switch the world started, not the user's click): it also waits while the mouse
-- is anywhere over the items, a header, a placeholder or a gap, so no item slides under the
-- pointer (ruling W4-13). While such a switch waits, every re-stack waits the same way, so a
-- header click cannot draw it under the mouse; the click applies with it once the mouse leaves.
-- area = a section id (a peek, close or pin in a focus mode): the same area hold, but only when
-- that clicked header itself would move (an earlier change above it still waits); otherwise only
-- a button that would move holds it, as for any header click.
local function headerY(pos, id)
	for _, h in ipairs(pos.headers) do
		if h.id == id then
			return h.y
		end
	end
end

-- M2 (final review): the settings window (DIALOG strata) sits above the bags, so while the mouse is
-- on it nothing under it can be clicked and the area hold does not apply. Nil-safe: the settings
-- window may not exist (tests, a load failure).
local function overSettings()
	local S = SB.SettingsWindow
	local f = S and S.frame
	return f ~= nil and f:IsShown() and f:IsMouseOver() == true
end

-- Two collapsed lookups (snapshots) draw the same sections.
local function sameView(a, b)
	if not (a and b) then
		return false
	end
	for id in pairs(a) do
		if not b[id] then
			return false
		end
	end
	for id in pairs(b) do
		if not a[id] then
			return false
		end
	end
	return true
end

function W.Restack(area)
	if not W.state then
		return true
	end
	local view = snapshot(W.state, W.EffectiveCollapsed())
	if area == true and sameView(view, W.view) then
		-- M1: the world asked for what is already drawn (or took back a switch still waiting):
		-- nothing moves, so nothing holds and no area hold is left for the next header click.
		W.areaHeld = false
		W.RefreshTitle()
		W.RefreshHeaders()
		return true
	end
	local pos = position(W.state, view)
	local wait = area == true or W.areaHeld
	if not wait and type(area) == "string" and W.pos then
		wait = headerY(W.pos, area) ~= headerY(pos, area)
	end
	local moves = SB.Layout.Moves(W.pos, pos)
	if (wait and ((scroll:IsMouseOver() and not overSettings()) or SB.Adapter.CursorItem())) or anyBusy(moves) then
		W.areaHeld = wait
		SB.Debounce("bags.restack", W.RETRY, function()
			W.Restack(area)
		end, "bags")
		return false
	end
	local oldPos = W.pos
	W.pos, W.view, W.areaHeld = pos, view, false
	local width, height = renderMoved(oldPos, pos)
	sizeFrame(width, height, true)
	SB.Emit("SB_BAGS_UPDATED")
	return true
end

local function flashSection(text, id)
	W.Flash(text:format(SB.Categories.Name(id)))
end

-- The user's own collapse/expand, saved per character (no focus mode applies, or paused). It
-- flips what is DRAWN (W.view), not the saved set: while a mode exit or a pause waits under the
-- mouse, the drawn header is still the mode's, and the user answers what they see (W4-16).
-- Outside such a hold W.view equals the saved set. A held re-stack answers in the title (P2).
function W.ToggleSection(id)
	local set = W.Collapsed()
	local drawn
	if W.view then
		drawn = W.view[id] == true
	else
		drawn = set[id] == true
	end
	set[id] = (not drawn) or nil
	if not W.Restack() then
		flashSection(drawn and L.HEADER_FLASH_OPEN or L.HEADER_FLASH_COLLAPSED, id)
	end
end

-- A left-click on a header. While a focus mode applies it peeks a section drawn collapsed, or
-- closes one drawn open, for this opening of the bag (AC8.3); with "Keep open until the mode
-- changes" a peek pins at once. "Collapsed now" is what is drawn (W.view), so a switch that still
-- waits never turns a close into a peek. The saved collapse state is never written in a mode
-- (AC8.2); without a mode (or paused) the click collapses or expands as before. Every click in a
-- mode answers in the title (P2), also when its re-stack waits for the mouse.
function W.ClickSection(id)
	local F = SB.Focus
	local result = F and F.HeaderClick(id, W.view ~= nil and W.view[id] == true)
	if not result then
		W.ToggleSection(id)
		return
	end
	W.Restack(id)
	if result == "close" then
		flashSection(L.HEADER_FLASH_CLOSED, id)
	elseif F.OverrideOf(id) == "pin" then
		flashSection(L.HEADER_FLASH_KEPT, id)
	else
		flashSection(L.HEADER_FLASH_PEEK, id)
	end
end

-- A right-click on a header while a focus mode applies: keep that section open until the mode
-- changes, or (a second time) give it back to the mode (spec 6.1 pin). Otherwise a plain click.
function W.PinSection(id)
	local F = SB.Focus
	local result = F and F.Pin(id)
	if not result then
		W.ToggleSection(id)
		return
	end
	W.Restack(id)
	flashSection(result == "pin" and L.HEADER_FLASH_KEPT or L.HEADER_FLASH_UNPINNED, id)
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

-- view: "sections" | "list" | "grid". Returns true when the setting changed (the window regroups
-- now, or once the mouse leaves the items), false (with a title flash) while read-only.
-- quiet: the caller answers itself (/swagbag view, the Settings row), so a cut-short flash adds no
-- chat line (ruling W5-4).
function W.SetView(view, quiet)
	if not VIEW_NEXT[view] then
		return false
	end
	if not SB.Config.Set("bags.view", view) then -- read-only settings: nothing changes
		W.Flash(L.SETTINGS_READONLY, quiet)
		return false
	end
	W.viewButton:SetText(VIEW_BUTTON[VIEW_NEXT[view]])
	W.Flash(VIEW_FLASH[view], quiet)
	W.RequestLayout("view")
	return true
end

function W.ToggleView()
	W.SetView(VIEW_NEXT[W.View()])
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

SB.SectionHeaders.onClick = function(id, mouseButton)
	if dropGuard == id then
		return
	end
	if SB.Adapter.CursorItem() then
		W.DropOnSection(id)
	elseif mouseButton == "RightButton" then
		W.PinSection(id)
	else
		W.ClickSection(id)
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
-- Pause / Resume (spec 6.1): one click stops focus modes for this session (until /reload) and
-- the title says "Paused"; the next click switches them back on. Chat confirms both (P2).
function W.TogglePause()
	local F = SB.Focus
	if not F then
		return
	end
	if F.IsPaused() then
		F.Resume()
		SB.Print(L.MODE_RESUMED)
	else
		F.Pause()
		SB.Print(L.MODE_PAUSED)
	end
end

function W.RefreshModeButton()
	W.modeButton:SetText(SB.Focus and SB.Focus.IsPaused() and L.BTN_RESUME or L.BTN_PAUSE)
end

-- Left-click: pause / resume. Right-click: the Focus modes settings page at the active mode's
-- sections (AC8.5). The settings open under ErrorTrap "none": a settings glitch flashes
-- L.SETTINGS_FAILED here and never puts the bags into Safe Mode (W4-5). The tooltip says both.
W.modeButton = titleButton(L.BTN_PAUSE, "bags.modeButton", function(_, mouseButton)
	if mouseButton == "RightButton" then
		local ok = SB.SettingsFocus and
			SB.ErrorTrap.Run("settings.openFromPause", "none", SB.SettingsFocus.Edit, SB.Focus.active[1])
		if not ok then
			W.Flash(L.SETTINGS_FAILED)
		end
	else
		W.TogglePause()
	end
end, 64)
W.modeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
W.modeButton:SetScript("OnEnter", Guard("bags.modeTip", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(L.MODE_TIP_TITLE)
	GameTooltip:AddLine(L.MODE_TIP_LEFT, 1, 1, 1)
	GameTooltip:AddLine(L.MODE_TIP_RIGHT, 1, 1, 1)
	GameTooltip:Show()
end, "bags"))
W.modeButton:SetScript("OnLeave", Guard("bags.modeTipHide", function()
	GameTooltip:Hide()
end, "bags"))
W.modeButton:SetPoint("RIGHT", W.reflowButton, "LEFT", -4, 0)
W.sortButton = titleButton(L.BTN_SORT, "bags.sortButton", function()
	W.Sort()
end, 52)
W.sortButton:SetPoint("RIGHT", W.modeButton, "LEFT", -4, 0)

-- W3-26 parity: the title (and its flashes) ends left of the leftmost SHOWN title button, on one
-- line. leftmost: a button shown left of Sort ("Bank still open", BankWindow.lua), or nil.
function W.BoundTitle(leftmost)
	frame.title:ClearAllPoints()
	frame.title:SetPoint("TOPLEFT", 10, -8)
	frame.title:SetPoint("RIGHT", leftmost or W.sortButton, "LEFT", -6, 0)
end
frame.title:SetJustifyH("LEFT")
frame.title:SetWordWrap(false)
W.BoundTitle(nil)

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
	W.viewButton:SetText(VIEW_BUTTON[VIEW_NEXT[W.View()]])
	W.RefreshModeButton()
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
	-- The drawn view, never a fresh one: a mode switch or collapse held under the mouse must not
	-- be drawn by loot or an emptied slot (ruling W4-1). The held Restack retry applies it.
	-- The first arrival into a hidden New moves every section below, so it also waits while the
	-- mouse is anywhere over the items or an item is on the cursor (W4-15, same rule as W4-13).
	local result = SB.Layout.Apply(st, changes, (busyCheck()), W.view, function()
		return scroll:IsMouseOver() or SB.Adapter.CursorItem() ~= nil
	end)
	newSec = st.sections[SB.Layout.NEW]
	-- New's "+N more below" can change with no button moving, so the headers redraw then too. New
	-- becoming shown (W4-15) always comes with one of the two (Layout.Apply shows it only then).
	if #result.moved > 0 or (newSec and newSec.overflow or 0) ~= overflowBefore then
		result.rendered = true
		local oldPos = W.pos
		W.pos = position(st, W.view)
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
				setScale(button, slotScale()) -- a scale that does not take is kept hidden by showAt (W5-1)
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

-- A focus mode switched, paused or resumed, or a focus setting changed (Engine/Focus.lua): the
-- title and the Pause button follow at once; the sections re-stack, held back while a button
-- that would move is under the mouse or an item is on the cursor. In the grid view there are no
-- sections, so only the title changes. A closed window picks the state up on its next open.
SB.On("SB_FOCUS_CHANGED", function()
	W.RefreshTitle()
	W.RefreshModeButton()
	if frame:IsShown() and W.state then
		W.Restack(true)
	end
end, "bags")

-- /swagbag free tile|all (Core/Commands.lua): regroup now, or once the mouse leaves the items.
SB.On("SB_FREE_TILE_CHANGED", function()
	W.RequestLayout("free")
end, "bags")

-- /swagbag new always|auto (ruling W4-15): New keeps its rows when empty (always), or shows only
-- once something new arrives (auto, the default). Regroups now, or once the mouse leaves the items.
SB.Slash.Register("new", L.HELP_NEW, function(arg)
	arg = (arg or ""):lower()
	if arg ~= "always" and arg ~= "auto" then
		return L.NEW_USAGE:format(SB.Config.Get("bags.newAlways") and "always" or "auto")
	end
	if not SB.Config.Set("bags.newAlways", arg == "always") then
		return L.SETTINGS_READONLY
	end
	W.RequestLayout("new")
	return arg == "always" and L.NEW_MODE_ALWAYS or L.NEW_MODE_AUTO
end, "bags")

-- /swagbag view [sections|list|grid]: show or switch the bags' view (the view button's three views).
SB.Slash.Register("view", L.HELP_VIEW, function(arg)
	arg = (arg or ""):lower()
	if not VIEW_NEXT[arg] then
		return L.VIEW_USAGE:format(W.View())
	end
	if not W.SetView(arg, true) then
		return L.SETTINGS_READONLY
	end
	return VIEW_FLASH[arg]
end, "bags")

-- /swagbag list [name|count|ilvl|value] [asc|desc]: show or set the list view's order (the column
-- bar's clicks, the Settings rows). Without a direction a column starts at its natural one. The
-- answer is this command's chat line (or the Settings status line), so the title flash is quiet.
SB.Slash.Register("list", L.HELP_LIST, function(arg)
	local by, dir = (arg or ""):lower():match("^(%S*)%s*(%S*)$")
	local spec = SB.Sort.Spec()
	if by == "" then
		return L.LIST_STATE:format(COLUMN_NAMES[spec.by], direction(spec.by, spec.desc))
	end
	if not COLUMN_NAMES[by] or not (dir == "" or dir == "asc" or dir == "desc") then
		return L.LIST_USAGE
	end
	local desc
	if dir == "" then
		desc = by ~= "name"
	else
		desc = dir == "desc"
	end
	if not W.SortList(by, desc, true) then
		return L.SETTINGS_READONLY
	end
	local line = L.LIST_SORTED:format(COLUMN_NAMES[by], direction(by, desc))
	if W.View() ~= "list" then
		return { line, L.LIST_NOT_SHOWN }
	end
	return line
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
