-- SwagBag lock warnings (week 10; the user: "Will locking prevent disenchanting or similar as well?", then
-- "Make it"). Disenchanting, milling, prospecting, the scrapper and the delete box are Blizzard's own flows: an
-- addon that tried to cancel them would taint them ("Interface action failed because of an AddOn"). So SwagBag
-- never blocks, cancels, clicks, hides or changes anything there (no click hook of any kind, spec 5.3). It
-- warns instead, for the items the user locked (Engine/Locks.lua):
--   a locked item's tooltip gets a red line under its "Locked" line while a spell waits for its target (any
--   spell: SpellIsTargeting names none, and a click would cast it on the item);
--   Blizzard's delete box for a locked item (DELETE_ITEM_CONFIRM, the item still on the cursor) gets one red
--   chat line, and SwagBag's own small note just above the box (its own frame; the box itself is never touched).
--   The scrapper: SwagBag cannot refuse an item there (a right-click on a bag item is Blizzard's own
--   UseContainerItem; stopping it would need a click hook, spec 5.3). So while it is open a locked item's
--   tooltip says a right-click can put it in, and a locked item that lands in a scrapper slot gets one red chat line.
-- One switch for every warning: locks.warn (default on).
--   LW.On() -> bool
--   LW.TooltipText() -> the red tooltip line for a locked item right now, or nil
--   LW.OnDelete(), LW.ShowNote(), LW.CheckDelete()   the delete box's warning; LW.note (made at SB_LOGIN)
--   LW.CheckScrapper()   the scrapper's chat line; LW.scrapper (open), LW.scrapWarned (itemID -> true)
local _, SB = ...

local L = SB.L
local LW = { NOTE_WIDTH = 300, NOTE_HEIGHT = 24, scrapper = false, scrapWarned = {} }
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
	if LW.scrapper then
		return L.LOCK_WARN_SCRAP
	end
	return nil
end

-- The delete box: Blizzard asks with DELETE_ITEM_CONFIRM while the item is still on the cursor (its Yes deletes
-- the cursor's item, its No puts it back). ITEM_LOCK_CHANGED (No, Esc) and BAG_UPDATE_DELAYED (Yes) say when the
-- item has left; no CURSOR_CHANGED listener (it fires all the time, in combat too).
function LW.OnDelete()
	local A = SB.Adapter
	local itemID = A.CursorItem()
	if not (itemID and LW.On() and SB.Locks.Has(itemID)) then
		return
	end
	LW.deleting = itemID
	SB.Print(L.LOCK_WARN_DELETE:format(SB.Locks.Name(itemID)))
	-- Blizzard shows its box from its own handler of the same event: the note looks for it a moment later.
	A.After(0, SB.ErrorTrap.Guard("lockwarn.note", LW.ShowNote, "none"))
end

local note

-- A plain frame of SwagBag's own, never a child of the box and never taking the mouse. Made once at SB_LOGIN.
local function makeNote()
	if note then
		return
	end
	note = CreateFrame("Frame", nil, UIParent)
	note:SetFrameStrata("DIALOG")
	note:SetSize(LW.NOTE_WIDTH, LW.NOTE_HEIGHT)
	local bg = note:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(note)
	bg:SetColorTexture(0, 0, 0, 0.8)
	local text = note:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER", note, "CENTER", 0, 0)
	text:SetTextColor(1, 0.27, 0.27)
	text:SetText(L.LOCK_WARN_NOTE)
	note.text = text
	note:Hide()
	LW.note = note
end

function LW.ShowNote()
	local A = SB.Adapter
	if not note or not LW.deleting or A.CursorItem() ~= LW.deleting then
		return
	end
	local popup = A.DeletePopup()
	if not popup then
		return -- the box was not found (renamed by a patch?): the chat line has said it
	end
	note:ClearAllPoints()
	note:SetPoint("BOTTOM", popup, "TOP", 0, 4)
	note:Show()
end

-- The item left the cursor (deleted by Yes, put back by No or Esc), or Blizzard's box is gone: the note goes.
function LW.CheckDelete()
	if LW.deleting and (SB.Adapter.CursorItem() ~= LW.deleting or not SB.Adapter.DeletePopup()) then
		LW.deleting = nil
		if note then
			note:Hide()
		end
	end
end

SB.On("DELETE_ITEM_CONFIRM", LW.OnDelete, "none")
SB.On("ITEM_LOCK_CHANGED", LW.CheckDelete, "none")
SB.On("BAG_UPDATE_DELAYED", LW.CheckDelete, "none")

SB.On("SB_LOGIN", function()
	SB.OutOfCombat(makeNote, "lockwarn.makeNote", "none")
end, "none")

-- The scrapper: open between PLAYER_INTERACTION_MANAGER_FRAME_SHOW and _HIDE for its interaction.
SB.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
	if SB.Adapter.IsScrapper(kind) then
		LW.scrapper, LW.scrapWarned = true, {}
	end
end, "none")
SB.On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind)
	if SB.Adapter.IsScrapper(kind) then
		LW.scrapper, LW.scrapWarned = false, {}
	end
end, "none")

-- One line per locked item that lands in a slot; said again only after it was taken out and put back.
function LW.CheckScrapper()
	if not LW.scrapper then return end
	local seen = {}
	for _, id in ipairs(SB.Adapter.ScrapperItemIDs()) do
		if LW.On() and SB.Locks.Has(id) and not LW.scrapWarned[id] and not seen[id] then
			SB.Print(L.LOCK_WARN_SCRAP_ADDED:format(SB.Locks.Name(id)))
		end
		seen[id] = true
	end
	LW.scrapWarned = seen
end

SB.On("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED", LW.CheckScrapper, "none")
