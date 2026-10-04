-- SwagBag lock warnings (week 10; the user: "Will locking prevent disenchanting or similar as well?", then
-- "Make it"). Disenchanting, milling, prospecting, the scrapper and the delete box are Blizzard's own flows: an
-- addon that tried to cancel them would taint them ("Interface action failed because of an AddOn"). So SwagBag
-- never blocks, cancels, clicks, hides or changes anything there (no click hook of any kind, spec 5.3). It
-- warns instead, for the items the user locked (Engine/Locks.lua):
--   a locked item's tooltip gets a red line under its "Locked" line while a spell waits for its target (any
--   spell: SpellIsTargeting names none, and a click would cast it on the item);
-- One switch for every warning: locks.warn (default on).
--   LW.On() -> bool
--   LW.TooltipText() -> the red tooltip line for a locked item right now, or nil
local _, SB = ...

local L = SB.L
local LW = {}
SB.LockWarnings = LW

function LW.On()
	return SB.Config.Get("locks.warn") == true
end

function LW.TooltipText()
	if not LW.On() then
		return nil
	end
	if SB.Adapter.SpellTargeting() then
		return L.LOCK_WARN_SPELL
	end
	return nil
end
