-- SwagBag button pool (spec 4.1). One ContainerFrameItemButtonTemplate button per
-- physical (bag, slot), created at login behind the loading screen, parented to a
-- per-bag frame (SetID(bag)) PERMANENTLY. Buttons are never reparented, destroyed
-- or re-SetID'd; they move only with ClearAllPoints + SetPoint. Item use, drag,
-- split and tooltips are Blizzard's own template handlers; we add no click scripts.
local _, SB = ...

local Buttons = {
	frames = {}, -- [bag] = plain Frame with SetID(bag)
	buttons = {}, -- [bag][slot] = ItemButton
	parents = {}, -- [kind] = frame the bag frames of that kind live under
	holders = {},
	stats = { count = 0, createMs = 0 },
	created = false,
	DIM_ALPHA = 0.2,
}
SB.Buttons = Buttons

-- kind "bags" | "bank" | "warband" for a bag ID.
local function kindOf(bag)
	local loc = SB.Adapter.BagKind(bag)
	if loc == "bank" or loc == "warband" then
		return loc
	end
	return "bags"
end
Buttons.KindOf = kindOf

-- The bags window registers its scroll child here at load time. Bank kinds get a
-- hidden holder frame until the bank window exists (week 3).
function Buttons.SetParentFor(kind, frame)
	Buttons.parents[kind] = frame
end

local function parentFor(kind)
	if Buttons.parents[kind] then
		return Buttons.parents[kind]
	end
	local h = Buttons.holders[kind]
	if not h then
		h = CreateFrame("Frame", nil, UIParent)
		h:SetSize(1, 1)
		h:Hide()
		Buttons.holders[kind] = h
	end
	return h
end

local function bagFrame(bag)
	local f = Buttons.frames[bag]
	if f then
		return f
	end
	local parent = parentFor(kindOf(bag))
	f = CreateFrame("Frame", nil, parent)
	f:SetID(bag)
	f:SetAllPoints(parent)
	f.IsCombinedBagContainer = function()
		return false
	end
	Buttons.frames[bag] = f
	Buttons.buttons[bag] = {}
	return f
end

local function addBackground(button)
	local bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
	bg:SetAllPoints(button)
	if not pcall(bg.SetAtlas, bg, "bags-item-slot64") then
		bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
	end
end

local function createButton(bag, slot)
	local b = CreateFrame("ItemButton", nil, bagFrame(bag), "ContainerFrameItemButtonTemplate")
	b:SetID(slot)
	addBackground(b)
	b:Hide()
	Buttons.buttons[bag][slot] = b
	Buttons.stats.count = Buttons.stats.count + 1
	return b
end

-- Ensure `bag` has at least n buttons. In combat the growth is queued (policy).
function Buttons.EnsureCapacity(bag, n)
	if SB.Adapter.InCombat() then
		SB.OutOfCombat(function()
			Buttons.EnsureCapacity(bag, n)
		end, "buttons.grow." .. bag, "bags")
		return 0
	end
	bagFrame(bag)
	local list = Buttons.buttons[bag]
	local made = 0
	for slot = #list + 1, n do
		createButton(bag, slot)
		made = made + 1
	end
	return made
end

-- Create the whole pool: bags 0-5 at 38 each, purchased bank tabs at 98 each.
function Buttons.CreateAll()
	if Buttons.created then
		return
	end
	local A = SB.Adapter
	if A.InCombat() then
		SB.OutOfCombat(Buttons.CreateAll, "buttons.createAll", "bags")
		return
	end
	local t0 = A.ProfileMs()
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		Buttons.EnsureCapacity(bag, math.max(A.NumSlots(bag), A.BAG_CAPACITY))
	end
	for _, kind in ipairs({ "bank", "warband" }) do
		for _, bag in ipairs(A.GetBagIDs(kind)) do
			Buttons.EnsureCapacity(bag, math.max(A.NumSlots(bag), A.BANK_TAB_CAPACITY))
		end
	end
	Buttons.stats.createMs = A.ProfileMs() - t0
	Buttons.created = true
	SB.Emit("SB_BUTTONS_READY")
end

function Buttons.Get(bag, slot)
	local list = Buttons.buttons[bag]
	return list and list[slot]
end

function Buttons.Count(bag)
	return #(Buttons.buttons[bag] or {})
end

-- Coordinates are TOPLEFT offsets inside the window's scroll child.
function Buttons.Place(button, x, y)
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x, y)
end

-- info: SB.Adapter.GetSlot(bag, slot) result, or nil for an empty slot. A filled button never
-- shows a free tile's number (plan D19).
function Buttons.Paint(button, info)
	if info then
		Buttons.SetFreeCount(button, nil)
	end
	SetItemButtonTexture(button, info and info.icon or nil)
	SetItemButtonCount(button, info and info.count or 0)
	SetItemButtonQuality(button, info and info.quality or nil, info and info.link or nil)
	SetItemButtonDesaturated(button, info ~= nil and info.isLocked)
	if button.UpdateCooldown then
		pcall(button.UpdateCooldown, button, info and info.icon or nil)
	end
end

-- Full dim: alpha on the whole button covers icon, border, count and glows.
function Buttons.SetDimmed(button, dimmed)
	button:SetAlpha(dimmed and Buttons.DIM_ALPHA or 1)
end

-- The free tile (plan D19): n in large white text in the middle of an empty slot button; nil
-- hides it. A font string on the button itself, made the first time (no frame: allowed in
-- combat), kept in a side table rather than a field on Blizzard's button.
Buttons.freeCounts = setmetatable({}, { __mode = "k" })
function Buttons.SetFreeCount(button, n)
	local fs = Buttons.freeCounts[button]
	if n == nil then
		if fs then
			fs:Hide()
		end
		return
	end
	if not fs then
		fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		fs:SetPoint("CENTER", button, "CENTER", 0, 0)
		fs:SetTextColor(1, 1, 1)
		Buttons.freeCounts[button] = fs
	end
	fs:SetText(n)
	fs:Show()
end

---------------------------------------------------------------------------
-- Placeholders (spec 4.1, 4.2 rule 3): pooled plain Frames showing the icon of an
-- item that moved or was used. A placeholder never responds to item interaction: it
-- has no click, drag or drop script; mouse-down only shows a tooltip (check V4).
-- Plain frames, so creating one in combat is allowed (ruling P9).
---------------------------------------------------------------------------
Buttons.placeholderPool, Buttons.placeholdersInUse = {}, {}
Buttons.PLACEHOLDER_ALPHA = 0.5

local function placeholderTip(self)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(SB.L.PLACEHOLDER_TIP, 1, 1, 1, 1, true)
	GameTooltip:Show()
end

local function hideTip()
	if not GameTooltip then
		return
	end
	GameTooltip:Hide()
end

local function createPlaceholder(parent)
	local Guard = SB.ErrorTrap.Guard
	local p = CreateFrame("Frame", nil, parent)
	p:EnableMouse(true)
	p.icon = p:CreateTexture(nil, "ARTWORK")
	p.icon:SetAllPoints(p)
	p.icon:SetDesaturated(true)
	p:SetAlpha(Buttons.PLACEHOLDER_ALPHA)
	p:SetScript("OnEnter", Guard("placeholder.enter", placeholderTip, "bags"))
	p:SetScript("OnMouseDown", Guard("placeholder.click", placeholderTip, "bags"))
	p:SetScript("OnLeave", Guard("placeholder.leave", hideTip, "bags"))
	return p
end

-- A shown placeholder of `size` at TOPLEFT offset (x, y) inside parent.
function Buttons.AcquirePlaceholder(parent, icon, size, x, y)
	local p = table.remove(Buttons.placeholderPool) or createPlaceholder(parent)
	p:SetParent(parent)
	p:SetSize(size, size)
	p.icon:SetTexture(icon)
	p:ClearAllPoints()
	p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	p:Show()
	Buttons.placeholdersInUse[#Buttons.placeholdersInUse + 1] = p
	return p
end

function Buttons.ReleasePlaceholders()
	for i = #Buttons.placeholdersInUse, 1, -1 do
		local p = Buttons.placeholdersInUse[i]
		p:Hide()
		Buttons.placeholdersInUse[i] = nil
		Buttons.placeholderPool[#Buttons.placeholderPool + 1] = p
	end
end

SB.On("SB_LOGIN", function()
	Buttons.CreateAll()
end, "bags")
