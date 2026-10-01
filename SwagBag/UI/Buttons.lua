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

-- info: SB.Adapter.GetSlot(bag, slot) result, or nil for an empty slot.
function Buttons.Paint(button, info)
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

SB.On("SB_LOGIN", function()
	Buttons.CreateAll()
end, "bags")
