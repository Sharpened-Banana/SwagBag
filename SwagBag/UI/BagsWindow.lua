-- SwagBag bags window, GRID view (spec F1, AC3.6). Movable, Ctrl+wheel scale
-- 50-200 %, remembers its position per character, closes on Esc, scrolls with a
-- clamped offset, and stays hidden until its layout is complete.
local _, SB = ...

local L = SB.L
local W = {
	records = {}, -- [bag][slot] = item record (Items.Describe) for shown slots
	cells = {}, -- last GridLayout cells
	stats = {},
	SLOT = 37,
	GAP = 4,
	PAD = 4,
	HEADER = 58, -- title row + search row
	FOOTER = 6,
	MAX_HEIGHT_FRACTION = 0.75,
	SCALE_STEP = 0.05,
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

-- Esc, the X button and W.Close() all hide the frame; listeners forget per-open state.
-- Alt+Z hides UIParent, which fires OnHide while the frame itself is still shown: ignore it.
frame:SetScript("OnHide", SB.ErrorTrap.Guard("bags.hide", function(self)
	if self:IsShown() then
		return
	end
	SB.Emit("SB_BAGS_CLOSED")
end, "bags"))

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

---------------------------------------------------------------------------
-- Position and scale
---------------------------------------------------------------------------
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

frame:SetScript("OnDragStart", SB.ErrorTrap.Guard("bags.dragStart", function()
	frame:StartMoving()
end, "bags"))
frame:SetScript("OnDragStop", SB.ErrorTrap.Guard("bags.dragStop", function()
	frame:StopMovingOrSizing()
	savePosition()
end, "bags"))

local titleToken = 0
local function showScaleFeedback(scale)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(L.BAGS_SCALE:format(math.floor(scale * 100 + 0.5)))
	SB.Adapter.After(1.5, SB.ErrorTrap.Guard("bags.scaleTitle", function()
		if token == titleToken then
			frame.title:SetText(L.BAGS_TITLE)
		end
	end, "bags"))
end

function W.SetScale(scale)
	scale = SB.GridLayout.ClampScale(scale)
	SB.Config.Set("bags.scale", scale)
	frame:SetScale(scale)
	showScaleFeedback(scale)
	if frame:IsShown() then
		W.Layout("scale")
	end
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", SB.ErrorTrap.Guard("bags.wheel", function(_, delta)
	if IsControlKeyDown() then
		W.SetScale(SB.Config.Get("bags.scale") + delta * W.SCALE_STEP)
		return
	end
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (W.SLOT + W.GAP) * 3)
	W.ClampScroll()
end, "bags"))

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
	W.records[bag][slot] = SB.Items.Describe(bag, slot)
end

function W.Layout(reason)
	local A, B = SB.Adapter, SB.Buttons
	local t0 = A.ProfileMs()
	local bags = bagList()
	local sizeOf = {}
	for _, b in ipairs(bags) do
		sizeOf[b.bag] = b.size
		if B.Count(b.bag) < b.size then
			B.EnsureCapacity(b.bag, b.size)
		end
	end
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		for slot = (sizeOf[bag] or 0) + 1, B.Count(bag) do
			B.Get(bag, slot):Hide()
		end
	end
	local g = SB.GridLayout.Compute(bags, { columns = SB.Config.Get("bags.columns"), size = W.SLOT, gap = W.GAP, padding = W.PAD })
	W.records, W.cells = {}, g.cells
	for _, c in ipairs(g.cells) do
		local button = B.Get(c.bag, c.slot)
		if button then
			B.Place(button, c.x, c.y)
			B.Paint(button, A.GetSlot(c.bag, c.slot))
			describe(c.bag, c.slot)
			button:Show()
		end
	end
	child:SetSize(g.width, g.height)
	local maxHeight = UIParent:GetHeight() * W.MAX_HEIGHT_FRACTION / frame:GetScale()
	local viewHeight = math.min(g.height, maxHeight - W.HEADER - W.FOOTER)
	frame:SetSize(g.width + 8, viewHeight + W.HEADER + W.FOOTER)
	W.ClampScroll()
	W.stats.lastLayoutMs = A.ProfileMs() - t0
	W.stats.lastLayoutReason = reason
	SB.Emit("SB_BAGS_LAYOUT", reason)
end

-- fn(button, record-or-nil, bag, slot) for every slot currently in the grid.
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
SB.Inventory.OnChanged(SB.ErrorTrap.Guard("bags.inventory", function(mask, changes)
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
