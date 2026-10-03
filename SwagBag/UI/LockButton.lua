-- SwagBag's Lock button (week 7, user pick 5): a small plain button at the right end of the bags
-- window's search row. Drag an item onto it (or click it while holding one) to lock or unlock that item;
-- the item goes back where it came from. A click with nothing on the cursor says how, and how many are
-- locked. This is the same drop pattern as a section header (AC4.3): SwagBag never hooks a click on an
-- item button (no click script or click hook of any kind: spec 5.3), so the item's own clicks stay
-- Blizzard's. The item tooltip gets a "Locked" line (Adapter.HookItemTooltip, taint-free).
--   LockButton.Drop() -> line   lock or unlock the item on the cursor (also the Settings > Vendor drop row)
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local LB = { DROP_GUARD = 0.3, WIDTH = 50 }
SB.LockButton = LB

local guardToken, guarded = 0, false

-- The item on the cursor: locked or unlocked, then put back. A refused change keeps it on the cursor.
function LB.Drop()
	local A, Locks = SB.Adapter, SB.Locks
	local itemID = A.CursorItem()
	if not itemID then
		return nil
	end
	local ok, locked = Locks.Toggle(itemID)
	if not ok then
		return locked == "readonly" and L.SETTINGS_READONLY or L.LOCK_INVALID
	end
	A.ClearCursor()
	return (locked and L.LOCK_ADDED or L.LOCK_REMOVED):format(Locks.Name(itemID))
end

-- One press can fire OnReceiveDrag and OnClick together; the click right after a drop is ignored.
local function press()
	local line = LB.Drop()
	if line then
		guardToken = guardToken + 1
		local token = guardToken
		guarded = true
		-- A cosmetic timer: its trap is "none" (ruling R15), so it can never put the bags in Safe Mode.
		SB.Adapter.After(LB.DROP_GUARD, Guard("lock.dropGuard", function()
			if token == guardToken then
				guarded = false
			end
		end, "none"))
		SB.Print(line)
	elseif not guarded then
		SB.Print(L.LOCK_STATE:format(#SB.Locks.List()))
	end
end

local W = SB.BagsWindow
if W and W.frame then
	local b = CreateFrame("Button", nil, W.frame, "UIPanelButtonTemplate")
	b:SetSize(LB.WIDTH, 18)
	b:SetText(L.BTN_LOCK)
	b:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", -8, -31)
	b:SetScript("OnClick", Guard("bags.lockButton", press, "bags"))
	b:SetScript("OnReceiveDrag", Guard("bags.lockDrop", press, "bags"))
	b:SetScript("OnEnter", Guard("bags.lockTip", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.LOCK_TIP_TITLE)
		GameTooltip:AddLine(L.LOCK_TIP_BODY, 1, 1, 1, true)
		GameTooltip:Show()
	end, "bags"))
	b:SetScript("OnLeave", Guard("bags.lockTipHide", function()
		GameTooltip:Hide()
	end, "bags"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
	LB.button = b
end

-- Lock marks follow every change at once.
SB.On("SB_LOCKS_CHANGED", function()
	if SB.Overlays then
		SB.Overlays.RefreshAll()
	end
end, "none")

SB.On("SB_LOGIN", function()
	SB.Adapter.HookItemTooltip(Guard("tooltip.lock", SB.Locks.TooltipLine, "none"))
end, "none")
