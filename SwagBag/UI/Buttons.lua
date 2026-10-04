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

-- Each window registers its scroll child here at load time ("bags"; "bank" and "warband"
-- share the bank window's). A kind without a window gets a hidden holder frame. Bag frames
-- made before the call move to the new parent, out of combat; only the bag frames move,
-- their item buttons stay parented to them (spec 4.1).
function Buttons.SetParentFor(kind, frame)
	Buttons.parents[kind] = frame
	SB.OutOfCombat(function()
		for bag, f in pairs(Buttons.frames) do
			if kindOf(bag) == kind and f:GetParent() ~= frame then
				f:SetParent(frame)
				f:SetAllPoints(frame)
			end
		end
	end, "buttons.parent." .. kind, kind == "bags" and "bags" or "bank")
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

-- SwagBag's own slot background under the item (a texture region on the button, as since week 1).
-- The theme (UI/Theme.lua) restyles it; the Blizzard theme is the atlas below.
local function addBackground(button)
	local bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
	bg:SetAllPoints(button)
	if not pcall(bg.SetAtlas, bg, "bags-item-slot64") then
		bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
	end
	if SB.Theme then
		SB.Theme.Slot(bg)
	end
end

local function createButton(bag, slot)
	local b = CreateFrame("ItemButton", nil, bagFrame(bag), "ContainerFrameItemButtonTemplate")
	b:SetID(slot)
	addBackground(b)
	-- Blizzard's blue "new item" glow (W4-15, newglow-diagnosis.md): hovering a slot clears the
	-- client's flag for it, as Blizzard's bags do. A post-hook, so the template's own OnEnter, its
	-- tooltip and item use are untouched; legal in combat. Window "none": a glow is cosmetic and
	-- never takes the bags away. Final review item 6: the hover also marks the item seen (first, so nothing
	-- after it can skip it): it leaves New at the next open or Reflow, never now (Engine/Inventory.lua).
	b:HookScript("OnEnter", SB.ErrorTrap.Guard("buttons.newGlow", function(self)
		if SB.Inventory then
			SB.Inventory.Seen(self:GetParent():GetID(), self:GetID())
		end
		Buttons.ClearGlow(self)
		SB.Adapter.ClearNewItem(self:GetParent():GetID(), self:GetID())
	end, "none"))
	b:Hide()
	if SB.Skins then -- week 9: Masque's skin, when it is loaded (out of combat: buttons are only made then)
		SB.Skins.Add(kindOf(bag), b)
	end
	Buttons.buttons[bag][slot] = b
	Buttons.stats.count = Buttons.stats.count + 1
	return b
end

-- Ensure `bag` has at least n buttons. In combat the growth is queued (policy); several
-- requests for one bag during combat keep the largest.
Buttons.pendingGrow = {} -- [bag] = largest size asked for during combat
function Buttons.EnsureCapacity(bag, n)
	if SB.Adapter.InCombat() then
		Buttons.pendingGrow[bag] = math.max(Buttons.pendingGrow[bag] or 0, n)
		SB.OutOfCombat(function()
			local want = Buttons.pendingGrow[bag]
			Buttons.pendingGrow[bag] = nil
			if want then
				Buttons.EnsureCapacity(bag, want)
			end
		end, "buttons.grow." .. bag, kindOf(bag) == "bags" and "bags" or "bank")
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
	Buttons.EnsureBankTabs()
	Buttons.stats.createMs = A.ProfileMs() - t0
	Buttons.created = true
	SB.Emit("SB_BUTTONS_READY")
end

-- Buttons for every purchased bank tab: max(size, 98) per tab (spec 4.1). Runs at login and
-- whenever the bank opens, so a tab bought after login gets its buttons too.
function Buttons.EnsureBankTabs()
	local A = SB.Adapter
	for _, kind in ipairs({ "bank", "warband" }) do
		for _, bag in ipairs(A.GetBagIDs(kind)) do
			local want = math.max(A.NumSlots(bag), A.BANK_TAB_CAPACITY)
			if Buttons.Count(bag) < want then
				Buttons.EnsureCapacity(bag, want)
			end
		end
	end
end

function Buttons.Get(bag, slot)
	local list = Buttons.buttons[bag]
	return list and list[slot]
end

function Buttons.Count(bag)
	return #(Buttons.buttons[bag] or {})
end

-- Coordinates are TOPLEFT offsets inside the window's scroll child, in its units. A point's
-- offsets are in the button's own scale, so a button drawn smaller (the list view) is offset by
-- x / scale, y / scale to land on the same spot.
function Buttons.Place(button, x, y)
	local scale = button:GetScale() or 1
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", x / scale, y / scale)
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
	Buttons.ClearGlow(button)
end

-- Hide the template's new-item glow (W4-15). Methods only: no field on Blizzard's button is
-- written, and the template's UpdateNewItem is never called. SwagBag's own "New" is a section.
local GLOW_TEXTURES = { "NewItemTexture", "BattlepayItemTexture" }
local GLOW_ANIMS = { "flashAnim", "newitemglowAnim" }
function Buttons.ClearGlow(button)
	for _, name in ipairs(GLOW_TEXTURES) do
		local t = button[name]
		if type(t) == "table" and t.Hide then
			t:Hide()
		end
	end
	for _, name in ipairs(GLOW_ANIMS) do
		local a = button[name]
		if type(a) == "table" and a.Stop then
			a:Stop()
		end
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
local placeholderParent = {} -- [placeholder] = the frame it was acquired in
local placeholderWindow = {} -- [placeholder] = the ErrorTrap window of its scripts (W3-23)
Buttons.PLACEHOLDER_ALPHA = 0.5

local placeholderText = {} -- [placeholder] = the tooltip text its window gave it (nil: the bags')

local function placeholderTip(self)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(placeholderText[self] or SB.L.PLACEHOLDER_TIP, 1, 1, 1, 1, true)
	GameTooltip:Show()
end

local function hideTip()
	if not GameTooltip then
		return
	end
	GameTooltip:Hide()
end

local function createPlaceholder(parent)
	local p = CreateFrame("Frame", nil, parent)
	p:EnableMouse(true)
	p.icon = p:CreateTexture(nil, "ARTWORK")
	p.icon:SetAllPoints(p)
	p.icon:SetDesaturated(true)
	p:SetAlpha(Buttons.PLACEHOLDER_ALPHA)
	-- Errors are trapped as the window that acquired the placeholder (W3-23, spec P6).
	local function trap(label, fn)
		return function(self)
			SB.ErrorTrap.Run(label, placeholderWindow[self] or "bags", fn, self)
		end
	end
	p:SetScript("OnEnter", trap("placeholder.enter", placeholderTip))
	p:SetScript("OnMouseDown", trap("placeholder.click", placeholderTip))
	p:SetScript("OnLeave", trap("placeholder.leave", hideTip))
	return p
end

-- A shown placeholder of `size` at TOPLEFT offset (x, y) inside parent. window: the ErrorTrap
-- window of its scripts (default "bags"). tip: the tooltip text for a window whose items regroup when
-- it closes (the bank's, the guild bank's); the bags' placeholders say "close the bag" (L.PLACEHOLDER_TIP).
function Buttons.AcquirePlaceholder(parent, icon, size, x, y, window, tip)
	local p = table.remove(Buttons.placeholderPool) or createPlaceholder(parent)
	p:SetParent(parent)
	placeholderParent[p], placeholderWindow[p], placeholderText[p] = parent, window, tip
	p:SetSize(size, size)
	p.icon:SetTexture(icon)
	p:ClearAllPoints()
	p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	p:Show()
	Buttons.placeholdersInUse[#Buttons.placeholdersInUse + 1] = p
	return p
end

-- Release the placeholders inside parent; every placeholder when parent is nil. Windows pass
-- their own scroll child, so the bags window never releases the bank window's placeholders.
function Buttons.ReleasePlaceholders(parent)
	for i = #Buttons.placeholdersInUse, 1, -1 do
		local p = Buttons.placeholdersInUse[i]
		if parent == nil or placeholderParent[p] == parent then
			p:Hide()
			placeholderParent[p], placeholderWindow[p], placeholderText[p] = nil, nil, nil
			table.remove(Buttons.placeholdersInUse, i)
			Buttons.placeholderPool[#Buttons.placeholderPool + 1] = p
		end
	end
end

SB.On("SB_LOGIN", function()
	Buttons.CreateAll()
end, "bags")

-- A login that failed half-way switched the bags to Safe Mode; switching it off tries again
-- (EnsureCapacity carries on where it stopped).
SB.On("SB_SAFEMODE_CHANGED", function(_, window, on)
	if window == "bags" and not on and not Buttons.created then
		Buttons.CreateAll()
	end
end, "bags")

SB.On("BANKFRAME_OPENED", function()
	Buttons.EnsureBankTabs()
end, "bank")

-- Blizzard's bags clear the new-item flag of every slot when they close (W4-15): so does SwagBag,
-- per slot, for the window that closed. Recorded only on error (cosmetic).
SB.On("SB_BAGS_CLOSED", function()
	SB.Adapter.ClearNewItems(SB.Adapter.GetBagIDs("bags"))
end, "none")

SB.On("SB_BANK_CLOSED", function()
	local A, ids = SB.Adapter, {}
	for _, kind in ipairs({ "bank", "warband" }) do
		for _, bag in ipairs(A.GetBagIDs(kind)) do
			ids[#ids + 1] = bag
		end
	end
	A.ClearNewItems(ids)
end, "none")
