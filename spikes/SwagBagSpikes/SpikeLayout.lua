-- =====================================================================
-- THROWAWAY SPIKE CODE  -  SwagBagSpikes / SpikeLayout.lua
-- Spike D: "sections" view with stable layout + placeholders.
-- Contract being tested (from the critique, Issue 1):
--   * Real slot buttons never change parent; only SetPoint moves them.
--   * When a slot's item leaves, a NON-secure placeholder frame keeps its
--     spot; the real button (which now shows whatever is in that slot)
--     moves to "Free" (empty) or to the "New" strip (different item).
--   * Nothing moves while the cursor is over it or holding an item.
--   * Reflow (button, or closing the window) regroups everything.
-- After every update it checks the invariant "every button inside a
-- category section shows the item that section was built for".
-- =====================================================================
local _, ns = ...

ns.RegisterSpike("D_LAYOUT", "Sections view: placeholders keep layout stable", "D",
	"Whether the placeholder model works on real slot-bound buttons (and in combat); grid/sections toggle cost")

local Pool = ns.Pool
local L = { snap = {}, pos = {}, placeholders = {}, phFree = {}, newCount = 0, freeCount = 0, freeBaseY = 0 }
ns.Layout = L

local COLS, SIZE, GAP = Pool.COLS, Pool.SIZE, Pool.GAP
local ORDER = { "Usable", "Other", "Junk" }
local NEW_ROWS = 2

local function Categorize(info)
	if not info then return "Free" end
	local ok, name, spellID = pcall(C_Item.GetItemSpell, info.itemID)
	if ok and (name or spellID) then return "Usable" end
	if info.quality == 0 then return "Junk" end
	return "Other"
end

local function ItemAt(bag, slot)
	local ok, id = pcall(C_Container.GetContainerItemID, bag, slot)
	if ok and not ns.IsSecret(id) then return id end
	return nil
end

---------------------------------------------------------------------------
-- Placeholders (plain frames; no secure template, no item interaction)
---------------------------------------------------------------------------
local function GetPlaceholder()
	local ph = table.remove(L.phFree)
	if not ph then
		ph = CreateFrame("Frame", nil, Pool.child)
		ph:SetSize(SIZE, SIZE)
		ph:SetFrameLevel(2)
		ph.icon = ph:CreateTexture(nil, "ARTWORK")
		ph.icon:SetAllPoints()
		ph.icon:SetDesaturated(true)
		ph.icon:SetAlpha(0.35)
		ph.border = ph:CreateTexture(nil, "OVERLAY")
		ph.border:SetAllPoints()
		ph.border:SetColorTexture(1, 1, 1, 0.08)
		ph:EnableMouse(true)
		ph:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("Placeholder (spike D)")
			GameTooltip:AddLine("This item moved or was used. Click does nothing.", 1, 1, 1, true)
			GameTooltip:Show()
		end)
		ph:SetScript("OnLeave", function() GameTooltip:Hide() end)
		ph:SetScript("OnMouseDown", function()
			ns.Mark("placeholderClick")
			ns.Spike("D_LAYOUT").data.placeholderClicks = (ns.Spike("D_LAYOUT").data.placeholderClicks or 0) + 1
			ns.Check("D_LAYOUT", "placeholderClickIsHarmless", true, "click on placeholder handled by plain frame")
		end)
	end
	ph:Show()
	L.placeholders[#L.placeholders + 1] = ph
	return ph
end

function L.HidePlaceholders()
	for _, ph in ipairs(L.placeholders) do ph:Hide(); L.phFree[#L.phFree + 1] = ph end
	L.placeholders = {}
end

---------------------------------------------------------------------------
-- Positions
---------------------------------------------------------------------------
local function XY(i, baseY) -- i is 0-based index within a section
	return 4 + (i % COLS) * (SIZE + GAP), baseY - math.floor(i / COLS) * (SIZE + GAP)
end

local function SectionHeader(key, text, y)
	local h = Pool.Header("sec" .. key)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", Pool.child, "TOPLEFT", 4, y)
	h:SetText(text)
	h:Show()
end

local function Move(b, x, y)
	Pool.PlaceAt(b, x, y)
	L.pos[b] = { x, y }
end

local function FreeSlotXY()
	local x, y = XY(L.freeCount, L.freeBaseY)
	L.freeCount = L.freeCount + 1
	return x, y
end

local function NewSlotXY()
	if L.newCount >= NEW_ROWS * COLS then
		-- overflow goes to the end of Free (never shifts anything)
		L.newOverflow = (L.newOverflow or 0) + 1
		return FreeSlotXY()
	end
	local x, y = XY(L.newCount, L.newBaseY)
	L.newCount = L.newCount + 1
	return x, y
end

---------------------------------------------------------------------------
-- Full layout (out of combat ideally; also tried in combat and recorded)
---------------------------------------------------------------------------
function L.Full(reason)
	if not Pool.created then Pool.CreateAll() end
	local t0 = debugprofilestop()
	L.HidePlaceholders()
	Pool.HideAllHeaders()
	L.snap, L.pos = {}, {}
	-- bank tabs are not part of the sections spike
	for bag, f in pairs(Pool.bagFrames) do f:SetShown(bag >= 0 and bag <= 5) end

	local lists = { Usable = {}, Other = {}, Junk = {}, Free = {} }
	for _, bag in ipairs(ns.BAGS) do
		local n = ns.NumSlots(bag)
		local btns = Pool.buttons[bag] or {}
		if n > #btns and not ns.InCombat() then Pool.EnsureCapacity(bag, n) btns = Pool.buttons[bag] end
		for slot = 1, #btns do
			local b = btns[slot]
			if slot <= n then
				local info = Pool.UpdateButton(b)
				local cat = Categorize(info)
				table.insert(lists[cat], b)
				L.snap[b] = { itemID = info and info.itemID or nil, cat = cat }
				b:Show()
			else
				b:Hide()
			end
		end
	end

	local y = -4
	SectionHeader("New", "New (items that arrived while open)", y)
	y = y - 14
	L.newBaseY, L.newCount, L.newOverflow = y, 0, 0
	y = y - NEW_ROWS * (SIZE + GAP) - 4
	for _, cat in ipairs(ORDER) do
		local list = lists[cat]
		if #list > 0 then
			SectionHeader(cat, cat .. " (" .. #list .. ")", y)
			y = y - 14
			for i, b in ipairs(list) do
				local x, yy = XY(i - 1, y)
				Move(b, x, yy)
			end
			y = y - math.ceil(#list / COLS) * (SIZE + GAP) - 4
		end
	end
	SectionHeader("Free", "Free (empty slots; drop items here)", y)
	y = y - 14
	L.freeBaseY, L.freeCount = y, 0
	for _, b in ipairs(lists.Free) do
		local x, yy = FreeSlotXY()
		Move(b, x, yy)
	end
	Pool.child:SetHeight(-y + (math.ceil((#lists.Free + 24) / COLS) + 1) * (SIZE + GAP))
	Pool.ClampScroll()
	Pool.mode = "sections"
	L.needsReflow = false

	local ms = debugprofilestop() - t0
	local d = ns.Spike("D_LAYOUT").data
	d.fullLayouts = (d.fullLayouts or 0) + 1
	d.maxFullLayoutMs = math.max(d.maxFullLayoutMs or 0, ms)
	if ns.InCombat() then d.fullLayoutsInCombat = (d.fullLayoutsInCombat or 0) + 1 end
	ns.Log("layoutSections", { ms = ms, reason = reason })
	ns.Check("D_LAYOUT", "sectionsBuilt", true, ("%.1f ms (%s)"):format(ms, tostring(reason)))
	if reason == "user" then
		local key = ns.InCombat() and "toggleViewInCombat" or "toggleViewOutOfCombat"
		local start = GetTime()
		C_Timer.After(1, function()
			local blocked = ns.BlockedMineSince(start)
			ns.Check("D_LAYOUT", key, blocked == 0, { ms = ms, blocked = blocked })
		end)
	end
	Pool.SetStatus(("Sections view: layout %.1f ms%s"):format(ms, ns.InCombat() and " (in combat)" or ""))
end

local function AnyHovered()
	if GetCursorInfo() then return true, "cursorHoldsItem" end
	for b in pairs(L.snap) do
		if b:IsVisible() and b:IsMouseOver() then return true, "hover" end
	end
	return false
end

function L.Reflow()
	local hovered, why = AnyHovered()
	if hovered then
		ns.Log("reflowDeferred", { why = why })
		local d = ns.Spike("D_LAYOUT").data
		d.reflowDeferrals = (d.reflowDeferrals or 0) + 1
		C_Timer.After(0.3, function() ns.Try("Layout.Reflow", L.Reflow) end)
		return
	end
	L.Full("reflow")
end

---------------------------------------------------------------------------
-- Incremental update (BAG_UPDATE_DELAYED while open)
---------------------------------------------------------------------------
local retryQueued = false
function L.Incremental()
	if Pool.mode ~= "sections" then return end
	local t0 = debugprofilestop()
	local moves, deferred, staleUnderCursor = 0, 0, 0
	local cursorBusy = GetCursorInfo() ~= nil
	for _, bag in ipairs(ns.BAGS) do
		local n = ns.NumSlots(bag)
		local btns = Pool.buttons[bag] or {}
		for slot = 1, math.min(n, #btns) do
			local b = btns[slot]
			local snap = L.snap[b]
			local cur = ItemAt(bag, slot)
			if not snap then
				-- bag grew while open: treat as Free arrival
				snap = { itemID = nil, cat = "Free" }
				L.snap[b] = snap
				local x, y = FreeSlotXY()
				Move(b, x, y)
				b:Show()
			end
			if snap.itemID ~= cur then
				if cursorBusy or b:IsMouseOver() then
					deferred = deferred + 1
					if snap.cat ~= "Free" and snap.cat ~= "New" then staleUnderCursor = staleUnderCursor + 1 end
				else
					if snap.itemID and snap.cat ~= "Free" and snap.cat ~= "New" then
						local ph = GetPlaceholder()
						local p = L.pos[b]
						ph:ClearAllPoints()
						ph:SetPoint("TOPLEFT", Pool.child, "TOPLEFT", p[1], p[2])
						local okI, icon = pcall(C_Item.GetItemIconByID, snap.itemID)
						ph.icon:SetTexture(okI and icon or 134400)
					end
					local x, y
					if cur then x, y = NewSlotXY(); snap.cat = "New" else x, y = FreeSlotXY(); snap.cat = "Free" end
					Move(b, x, y)
					snap.itemID = cur
					moves = moves + 1
					L.needsReflow = true
				end
			end
			Pool.UpdateButton(b)
		end
	end

	-- invariant: buttons in category sections show the item the section was built for
	local violations = 0
	for b, snap in pairs(L.snap) do
		if snap.cat ~= "Free" and snap.cat ~= "New" and b:IsShown() then
			local cur = ItemAt(b.sbsBag, b.sbsSlot)
			if cur ~= snap.itemID then violations = violations + 1 end
		end
	end

	local ms = debugprofilestop() - t0
	local inCombat = ns.InCombat()
	local d = ns.Spike("D_LAYOUT").data
	d.updates = (d.updates or 0) + 1
	d.moves = (d.moves or 0) + moves
	d.deferred = (d.deferred or 0) + deferred
	d.staleUnderCursor = (d.staleUnderCursor or 0) + staleUnderCursor
	d.maxIncrementalMs = math.max(d.maxIncrementalMs or 0, ms)
	d.newOverflow = L.newOverflow
	ns.Log("layoutIncremental", { ms = ms, moves = moves, deferred = deferred, violations = violations })

	if moves > 0 then
		local start = GetTime()
		C_Timer.After(1, function()
			local blocked = ns.BlockedMineSince(start)
			if inCombat then
				ns.Check("D_LAYOUT", "movesInCombatWork", blocked == 0, { moves = moves, blocked = blocked, ms = ms })
			else
				ns.Check("D_LAYOUT", "movesOutOfCombatWork", blocked == 0, { moves = moves, blocked = blocked, ms = ms })
			end
		end)
		ns.Check("D_LAYOUT", "noWrongItemInSection", violations == 0, { violations = violations, deferredUnderCursor = deferred })
	end
	if deferred > 0 then
		ns.Check("D_LAYOUT", "hoverGuardDeferred", nil, { deferred = deferred, staleUnderCursor = staleUnderCursor,
			note = "button under cursor kept its spot but now shows a different item until the mouse leaves" })
		if not retryQueued then
			retryQueued = true
			C_Timer.After(0.3, function() retryQueued = false; ns.Try("Layout.Incremental", L.Incremental) end)
		end
	end
	Pool.SetStatus(("Sections: update %.1f ms, moved %d, deferred %d%s"):format(ms, moves, deferred,
		L.needsReflow and "  |cffffff00(Reflow available)|r" or ""))
end

-- Rule: reflow on close (out of combat only).
table.insert(Pool.onHideCallbacks, function()
	if Pool.mode == "sections" and L.needsReflow and not ns.InCombat() then
		ns.Log("reflowOnClose", {})
		L.HidePlaceholders()
		L.needsReflow = false
		L.reflowOnNextOpen = true
	end
end)

ns.Command("sections", "switch spike bag to sections view (spike D)", function() Pool.Show(); L.Full("user") end)
ns.commands.d = ns.commands.sections
ns.Command("grid", "switch spike bag to grid view", function() Pool.Show(); Pool.LayoutGrid("user") end)
ns.Command("reflow", "regroup sections now", function() L.Reflow() end)
