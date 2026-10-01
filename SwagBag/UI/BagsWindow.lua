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
	state = nil, -- sections view: Layout state while open (nil when closed or in grid view)
	pos = nil, -- sections view: last Layout.Position result
	placed = {}, -- [button] = "x,y" of its last SetPoint, so unchanged buttons are not touched
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
	W.state, W.pos = nil, nil
	SB.Buttons.ReleasePlaceholders()
	SB.Emit("SB_BAGS_CLOSED")
end, "bags"))

---------------------------------------------------------------------------
-- Title feedback, position and scale
---------------------------------------------------------------------------
local titleToken = 0

-- Show text in the title for 1.5 s (feedback for header buttons and scaling, P2).
function W.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("bags.flash", function()
		if token == titleToken then
			frame.title:SetText(L.BAGS_TITLE)
		end
	end, "bags"))
end

function W.RestorePosition()
	local p = SB.Config.UI().positions.bags
	frame:ClearAllPoints()
	if type(p) == "table" and p[1] then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 100)
	end
end

local function savePosition()
	local point, _, relPoint, x, y = frame:GetPoint(1)
	SB.Config.UI().positions.bags = { point, relPoint, x, y }
end

frame:SetScript("OnDragStart", Guard("bags.dragStart", function()
	frame:StartMoving()
end, "bags"))
frame:SetScript("OnDragStop", Guard("bags.dragStop", function()
	frame:StopMovingOrSizing()
	savePosition()
end, "bags"))

-- Fit the window around content of width x height (scroll when taller than 75 % of the screen).
local function sizeFrame(width, height)
	W.size = { width, height }
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * W.MAX_HEIGHT_FRACTION / frame:GetScale()
	local viewHeight = math.min(height, maxHeight - W.HEADER - W.FOOTER)
	frame:SetSize(width + 8, viewHeight + W.HEADER + W.FOOTER)
	W.ClampScroll()
end

-- Scaling only resizes the window; nothing is regrouped.
function W.SetScale(scale)
	scale = SB.GridLayout.ClampScale(scale)
	SB.Config.Set("bags.scale", scale)
	frame:SetScale(scale)
	W.Flash(L.BAGS_SCALE:format(math.floor(scale * 100 + 0.5)))
	if frame:IsShown() then
		sizeFrame(W.size[1], W.size[2])
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

local function titleButton(text, label, onClick)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(72, 18)
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

local function describe(bag, slot)
	W.records[bag] = W.records[bag] or {}
	local record = SB.Items.Describe(bag, slot)
	W.records[bag][slot] = record
	return record
end

local function place(button, x, y)
	local at = x .. "," .. y
	if W.placed[button] ~= at then
		SB.Buttons.Place(button, x, y)
		W.placed[button] = at
	end
end

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
	return g.width, g.height
end

-- Put buttons, placeholders and headers where W.pos says. Returns width, height.
local function render()
	local B, H, pos = SB.Buttons, SB.SectionHeaders, W.pos
	W.cells = {}
	for _, c in ipairs(pos.cells) do
		local button = B.Get(c.bag, c.slot)
		if button then
			if c.shown then
				place(button, c.x, c.y)
				button:Show()
			else
				button:Hide()
			end
			W.cells[#W.cells + 1] = c
		end
	end
	B.ReleasePlaceholders()
	for _, p in ipairs(pos.placeholders) do
		if p.shown then
			B.AcquirePlaceholder(child, p.icon, W.SLOT, p.x, p.y)
		end
	end
	H.ReleaseAll()
	for _, h in ipairs(pos.headers) do
		H.Acquire(child, h.id, H.Label(SB.Categories.Name(h.id), h.count, h.collapsed, h.overflow), W.PAD, h.y,
			pos.width - 2 * W.PAD)
	end
	return pos.width, pos.height
end
W.Render = render

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
		{ columns = columns(), newRows = SB.Config.Get("bags.newRows") })
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
	B.ReleasePlaceholders()
	SB.SectionHeaders.ReleaseAll()
	local width, height
	if W.View() == "grid" then
		width, height = layoutGrid(bags)
	else
		width, height = layoutSections(bags)
	end
	sizeFrame(width, height)
	W.stats.lastLayoutMs = A.ProfileMs() - t0
	W.stats.lastLayoutReason = reason
	SB.Emit("SB_BAGS_LAYOUT", reason)
end

local function buttonBusy(bag, slot)
	local button = SB.Buttons.Get(bag, slot)
	return button ~= nil and button:IsShown() and button:IsMouseOver()
end
W.ButtonBusy = buttonBusy

-- Spec 4.2 rule 5 for a re-stack: wait while an item is on the cursor or one of the
-- buttons that would move is under the mouse.
local function anyBusy(keys)
	if SB.Adapter.CursorItem() then
		return true
	end
	for _, key in ipairs(keys) do
		if buttonBusy(math.floor(key / 1000), key % 1000) then
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
	sizeFrame(render())
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

SB.SectionHeaders.onClick = function(id)
	W.ToggleSection(id)
end

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
	W.viewButton:SetText(W.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
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
-- Live updates while open
---------------------------------------------------------------------------
SB.Inventory.OnChanged(Guard("bags.inventory", function(mask, changes)
	if not frame:IsShown() then
		return
	end
	local Inv, B, A = SB.Inventory, SB.Buttons, SB.Adapter
	if Inv.Has(mask, Inv.R.SIZE) then
		W.Layout("size")
		return
	end
	if Inv.Has(mask, Inv.R.COOLDOWN) then
		W.ForEachSlot(function(button, record)
			if record and button.UpdateCooldown then
				pcall(button.UpdateCooldown, button, record.icon)
			end
		end)
	end
	local touched = false
	for _, c in ipairs(changes) do
		local button = B.Get(c.bag, c.slot)
		if B.KindOf(c.bag) == "bags" and button and button:IsShown() then
			B.Paint(button, A.GetSlot(c.bag, c.slot))
			describe(c.bag, c.slot)
			touched = true
		end
	end
	if touched then
		SB.Emit("SB_BAGS_UPDATED")
	end
end, "bags"))
