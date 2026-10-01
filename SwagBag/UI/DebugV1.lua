-- SwagBag in-game check V1 (optional, spec 4.5 / 11.3): six item buttons that use
-- SetBagID() (the "bagid" attribute) instead of a per-bag parent frame. The user
-- uses items from this strip IN COMBAT three times; /swagbag report then shows
-- whether any action was blocked. v1.0 ships per-bag parents either way.
-- Opt-in only (/swagbag debug v1). Never touches the main button pool.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local V1 = { buttons = {} }
SB.DebugV1 = V1

local strip

local function build()
	strip = CreateFrame("Frame", "SwagBagV1Strip", UIParent, "BackdropTemplate")
	strip:SetSize(6 * 41 + 12, 70)
	strip:SetPoint("TOP", UIParent, "TOP", 0, -140)
	strip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	strip:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
	strip:SetBackdropBorderColor(0.9, 0.7, 0.2, 1)
	strip:SetMovable(true)
	strip:EnableMouse(true)
	strip:RegisterForDrag("LeftButton")
	strip:SetScript("OnDragStart", Guard("v1.dragStart", function()
		strip:StartMoving()
	end))
	strip:SetScript("OnDragStop", Guard("v1.dragStop", function()
		strip:StopMovingOrSizing()
	end))
	local title = strip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", 8, -7)
	title:SetText(L.V1_TITLE)
	local holder = CreateFrame("Frame", nil, strip) -- deliberately NO SetID: buttons rely on SetBagID()
	holder:SetAllPoints(strip)
	for i = 1, 6 do
		local b = CreateFrame("ItemButton", nil, holder, "ContainerFrameItemButtonTemplate")
		b:SetSize(37, 37)
		b:SetPoint("TOPLEFT", holder, "TOPLEFT", 6 + (i - 1) * 41, -26)
		b:Hide()
		V1.buttons[i] = b
	end
	table.insert(UISpecialFrames, "SwagBagV1Strip")
	strip:Hide()
end

-- Fill with up to 6 usable items from the bags. Returns how many.
function V1.Fill()
	local A, n = SB.Adapter, 0
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		for slot = 1, A.NumSlots(bag) do
			local s = A.GetSlot(bag, slot)
			if n < 6 and s and A.IsUsable(s.itemID) then
				n = n + 1
				local b = V1.buttons[n]
				b:SetBagID(bag)
				b:SetID(slot)
				SB.Buttons.Paint(b, s)
				b:Show()
			end
		end
	end
	for i = n + 1, 6 do
		V1.buttons[i]:Hide()
	end
	return n
end

-- Returns the feedback line for /swagbag debug v1. Frames and buttons are only
-- ever created or changed out of combat (queued through SB.OutOfCombat).
function V1.Toggle()
	if SB.Adapter.InCombat() then
		return L.V1_COMBAT
	end
	local line
	SB.OutOfCombat(function()
		if not strip then
			build()
		end
		if strip:IsShown() then
			strip:Hide()
			line = L.V1_HIDDEN
			return
		end
		local n = V1.Fill()
		strip:Show()
		line = L.V1_SHOWN:format(n)
	end, "v1.toggle")
	return line
end
