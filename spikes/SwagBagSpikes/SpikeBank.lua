-- =====================================================================
-- THROWAWAY SPIKE CODE  -  SwagBagSpikes / SpikeBank.lua
-- Spike B (critique B, bank half) + Spike E (storage measurement).
--  * Reads BankFrame:GetActiveBankType() / BankPanel state - READ ONLY.
--  * Right-click deposit from spike-bag buttons: where does the item land
--    (character vs warband) depending on Blizzard's selected tab?
--  * "Tiny mode": BankFrame reparented to a 0.001-scale frame (Bagnon's
--    approach) so it stays "shown" (bank stays open, active bank type is
--    still valid) but is invisible; Blizzard's own tab buttons
--    (BankFrame.TabSystem) are moved onto a holder so the user clicks
--    REAL Blizzard tabs. Restored on close.
--  * ESC behaviour: records what closes and whether the bank interaction
--    really ends.
--  * Optional taint probe: calls BankFrame:SetTab() from addon code (the
--    thing we believe taints item use) - only when the user clicks it.
-- Test items: up to 3 cheap, unbound items (gray junk / cheap trade goods)
-- that are allowed in BOTH bank types; marked 1/2/3 in the spike bag.
-- =====================================================================
local _, ns = ...

ns.RegisterSpike("B_BANK", "Bank: right-click deposit routing, tiny-mode fallback, ESC", "B (bank half)",
	"Whether bank + warband bank can be in the MVP, and the one-window/Blizzard-tab model")
ns.RegisterSpike("E_STORAGE", "Storage size: full links vs aggregated counts", "E",
	"Cross-character store format and budget (replaces the 12 KB / 300 KB guesses)")

local Pool = ns.Pool
local B = { candidates = {}, counts = {}, tiny = false }
ns.Bank = B
ns.bankOpen = false

local function BankTypeActive()
	if not BankFrame or not BankFrame.GetActiveBankType then return "noAPI" end
	local ok, bt = pcall(BankFrame.GetActiveBankType, BankFrame)
	if not ok then return "error" end
	return ns.BankTypeName(bt)
end
B.BankTypeActive = BankTypeActive

local function InteractionState()
	local out = {}
	local api = C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType
	local PIT = Enum and Enum.PlayerInteractionType
	if api and PIT then
		for _, k in ipairs({ "Banker", "AccountBanker", "CharacterBanker" }) do
			if PIT[k] then
				local ok, v = pcall(api, PIT[k])
				if ok then out[k] = v else out[k] = "error" end -- `ok and v or` turns false into "error"
			end
		end
	end
	return out
end

local function BankSnapshot()
	local snap = {
		activeBankType = BankTypeActive(),
		bankFrameShown = BankFrame and BankFrame:IsShown(),
		bankFrameVisible = BankFrame and BankFrame:IsVisible(),
		bankPanelShown = BankPanel and BankPanel:IsShown(),
		interaction = InteractionState(),
		tinyMode = B.tiny,
	}
	if C_Bank then
		local ok, types = pcall(C_Bank.FetchViewableBankTypes)
		snap.viewableBankTypes = ok and types or "error"
		for _, kind in ipairs({ "Character", "Account" }) do
			local bt = Enum.BankType[kind]
			local okU, canUse = pcall(C_Bank.CanUseBank, bt)
			snap["canUse" .. kind] = okU and canUse or "error"
			local tabs = ns.PurchasedTabs(kind)
			snap["tabs" .. kind] = tabs
			local sizes = {}
			for _, bag in ipairs(tabs) do sizes[#sizes + 1] = ns.NumSlots(bag) end
			snap["tabSizes" .. kind] = sizes
		end
	end
	return snap
end

---------------------------------------------------------------------------
-- Test items
---------------------------------------------------------------------------
local MAX_SELL = 50000 -- 5 gold vendor price cap

function B.PickCandidates()
	if not Pool.created then return end
	for _, c in ipairs(B.candidates) do
		local b = Pool.buttons[c.bag] and Pool.buttons[c.bag][c.slot]
		if b then Pool.TagButton(b, nil) end
	end
	B.candidates = {}
	local list, seen = {}, {}
	for _, bag in ipairs(ns.BAGS) do
		for slot = 1, ns.NumSlots(bag) do
			local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
			if ok and info and not info.isBound and (info.quality or 9) <= 1 and not seen[info.itemID] then
				local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
				local okA, allowA = pcall(C_Bank.IsItemAllowedInBankType, Enum.BankType.Account, loc)
				local okC, allowC = pcall(C_Bank.IsItemAllowedInBankType, Enum.BankType.Character, loc)
				local sell = select(11, C_Item.GetItemInfo(info.itemID)) or 0
				if okA and allowA and okC and allowC and sell <= MAX_SELL then
					seen[info.itemID] = true
					list[#list + 1] = { itemID = info.itemID, name = info.itemName, quality = info.quality, sell = sell, bag = bag, slot = slot }
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.quality ~= b.quality then return a.quality < b.quality end
		if a.sell ~= b.sell then return a.sell < b.sell end
		return a.itemID < b.itemID
	end)
	for i = 1, math.min(3, #list) do B.candidates[i] = list[i] end
	B.MarkCandidates()
	ns.Data("B_BANK", "testItems", B.candidates)
	B.counts = B.CountAll()
	return B.candidates
end

function B.MarkCandidates()
	-- re-find each candidate's current bag slot and tag it
	for _, b in ipairs(Pool.all) do if b.sbsTag then Pool.TagButton(b, nil) end end
	for i, c in ipairs(B.candidates) do
		for _, bag in ipairs(ns.BAGS) do
			for slot = 1, ns.NumSlots(bag) do
				if C_Container.GetContainerItemID(bag, slot) == c.itemID then
					local b = Pool.buttons[bag] and Pool.buttons[bag][slot]
					if b then Pool.TagButton(b, tostring(i)) end
				end
			end
		end
	end
end

function B.CandidateText()
	if #B.candidates == 0 then return "|cffff4444No suitable cheap test item found.|r Bring 1-3 gray junk items or cheap trade goods (unbound) and click 'Pick test items'." end
	local parts = {}
	for i, c in ipairs(B.candidates) do
		parts[#parts + 1] = ("%d = %s"):format(i, tostring(c.name or c.itemID))
	end
	return "Test items (marked with yellow numbers in the spike bag): " .. table.concat(parts, ", ")
end

local function CountIn(bags, itemID)
	local n = 0
	for _, bag in ipairs(bags) do
		for slot = 1, ns.NumSlots(bag) do
			if C_Container.GetContainerItemID(bag, slot) == itemID then
				local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
				n = n + ((ok and info and info.stackCount) or 1)
			end
		end
	end
	return n
end

function B.CountAll()
	local out = {}
	for i, c in ipairs(B.candidates) do
		out[i] = {
			Bags = CountIn(ns.BAGS, c.itemID),
			Character = ns.bankOpen and CountIn(ns.PurchasedTabs("Character"), c.itemID) or nil,
			Account = ns.bankOpen and CountIn(ns.PurchasedTabs("Account"), c.itemID) or nil,
		}
	end
	return out
end

local function DetectMovement()
	if #B.candidates == 0 or not ns.bankOpen then return end
	local now = B.CountAll()
	for i, c in ipairs(B.candidates) do
		local before, after = B.counts[i] or {}, now[i]
		local dBags = (after.Bags or 0) - (before.Bags or 0)
		local dChar = (after.Character or 0) - (before.Character or 0)
		local dAcct = (after.Account or 0) - (before.Account or 0)
		if dBags ~= 0 or dChar ~= 0 or dAcct ~= 0 then
			local landed = (dChar > 0 and "Character") or (dAcct > 0 and "Account") or (dBags > 0 and "Bags") or "gone?"
			local step = ns.GuideCurrentStep and ns.GuideCurrentStep() or nil
			local rec = {
				item = i, itemID = c.itemID, dBags = dBags, dChar = dChar, dAcct = dAcct, landed = landed,
				activeBankTypeNow = BankTypeActive(), tinyMode = B.tiny, step = step and step.id, combat = ns.InCombat(),
				lastOp = ns.lastOp, focus = ns.FocusLabel(),
			}
			local viaSpike = type(rec.focus) == "string" and rec.focus:find("^pool:") ~= nil
			rec.viaSpikeButton = viaSpike
			local d = ns.Spike("B_BANK").data
			d.movements = d.movements or {}
			table.insert(d.movements, ns.Safe(rec))
			ns.Log("bankMovement", rec)
			ns.Print(("B_BANK: test item %d moved -> %s (Blizzard active tab: %s%s)"):format(i, landed, rec.activeBankTypeNow, B.tiny and ", tiny mode" or ""))
			-- deposit consistency: landed where Blizzard's active tab says
			if landed == "Character" or landed == "Account" then
				ns.Check("B_BANK", "depositMatchesActiveTab" .. (B.tiny and "_tiny" or "_normal"), landed == rec.activeBankTypeNow, rec)
			end
			if step and step.expectLanding then
				ns.Check("B_BANK", "step_" .. step.id, landed == step.expectLanding, rec)
				if ns.GuideMarkDone then ns.GuideMarkDone(step.id) end
			end
			if landed == "Bags" and viaSpike then
				ns.Check("B_BANK", "withdrawViaSpikeButtons", true, rec)
			end
		end
	end
	B.counts = now
end

---------------------------------------------------------------------------
-- Tiny mode (hide Blizzard bank but keep it "shown") + proxy tabs
---------------------------------------------------------------------------
local tinyParent = CreateFrame("Frame", nil, UIParent)
tinyParent:SetScale(0.001)
tinyParent:SetSize(1, 1)
tinyParent:SetPoint("BOTTOMLEFT")
local tabHolder = ns.MakeWindow("SwagBagSpikesBankTabs", "Blizzard bank tabs (moved here by spike B)", 360, 70)
tabHolder:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180)
tabHolder.closeButton:Hide()

local saved = {}
local function SavePoints(f)
	local pts = {}
	for i = 1, f:GetNumPoints() do pts[i] = { f:GetPoint(i) } end
	return pts
end
local function RestorePoints(f, pts)
	f:ClearAllPoints()
	for _, p in ipairs(pts) do f:SetPoint(unpack(p)) end
end

function B.SetTiny(on)
	if not BankFrame then return end
	if ns.InCombat() then ns.Print("tiny mode switch skipped: in combat") return end
	local start = GetTime()
	ns.Mark("bank:tiny:" .. tostring(on))
	local ok, err = pcall(function()
		if on and not B.tiny then
			saved.parent = BankFrame:GetParent()
			BankFrame:SetParent(tinyParent)
			local ts = BankFrame.TabSystem
			if ts then
				saved.tsParent = ts:GetParent()
				saved.tsPoints = SavePoints(ts)
				ts:SetParent(tabHolder)
				ts:ClearAllPoints()
				ts:SetPoint("TOPLEFT", tabHolder, "TOPLEFT", 10, -28)
			end
			tabHolder:Show()
			B.tiny = true
		elseif not on and B.tiny then
			local ts = BankFrame.TabSystem
			if ts and saved.tsParent then
				ts:SetParent(saved.tsParent)
				RestorePoints(ts, saved.tsPoints)
			end
			BankFrame:SetParent(saved.parent or UIParent)
			tabHolder:Hide()
			B.tiny = false
		end
	end)
	ns.context.bankTinyUsed = ns.context.bankTinyUsed or on
	local snap = BankSnapshot()
	ns.Data("B_BANK", on and "afterTinyOn" or "afterTinyOff", snap)
	C_Timer.After(1, function()
		local blocked = ns.BlockedMineSince(start)
		ns.Check("B_BANK", on and "tinyModeOn" or "tinyModeOff", ok and blocked == 0 and (not on or snap.bankFrameShown == true),
			{ err = err, blocked = blocked, activeBankType = snap.activeBankType, bankFrameShown = snap.bankFrameShown })
	end)
end

---------------------------------------------------------------------------
-- ESC test
---------------------------------------------------------------------------
local escRegistered = false
function B.RegisterEsc()
	if escRegistered then return end
	tinsert(UISpecialFrames, "SwagBagSpikesPoolWindow")
	escRegistered = true
	ns.context.escRegistered = true
	ns.Data("B_BANK", "escRegisteredAt", date("%H:%M:%S"))
end

local escWatch
function B.StartEscWatch()
	B.RegisterEsc()
	escWatch = { started = GetTime(), events = {} }
end
local function EscEvent(name, extra)
	if not escWatch then return end
	local e = { name = name, ms = debugprofilestop(), t = GetTime() }
	if extra then for k, v in pairs(extra) do e[k] = v end end
	table.insert(escWatch.events, ns.Safe(e))
end
table.insert(Pool.onHideCallbacks, function() EscEvent("spikeBagHidden") end)

---------------------------------------------------------------------------
-- Optional taint probe (deliberately writes Blizzard bank state)
---------------------------------------------------------------------------
function B.TaintProbe()
	if not BankFrame or not BankFrame.SetTab or not BankFrame.accountBankTabID then ns.Print("taint probe: BankFrame API not found") return end
	ns.Mark("bank:taintProbe:SetTab(account)")
	ns.context.taintProbeDone = true
	local ok, err = pcall(BankFrame.SetTab, BankFrame, BankFrame.accountBankTabID)
	ns.Data("B_BANK", "taintProbe", { ok = ok, err = err, activeAfter = BankTypeActive() })
	ns.Print("Taint probe done. Now right-click test item in the spike bag, then (away from the bank) your Hearthstone. Then /reload.")
end

---------------------------------------------------------------------------
-- Spike E: storage measurement
---------------------------------------------------------------------------
local function Measure(label, bags)
	local fullLen, aggLen, slots, used = 0, 0, 0, 0
	local agg = {}
	for _, bag in ipairs(bags) do
		for slot = 1, ns.NumSlots(bag) do
			slots = slots + 1
			local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
			if ok and info and info.hyperlink and not ns.IsSecret(info.hyperlink) then
				used = used + 1
				-- full: "bag:slot:link;count\n"
				fullLen = fullLen + #(bag .. ":" .. slot .. ":" .. info.hyperlink .. ";" .. (info.stackCount or 1)) + 1
				agg[info.itemID] = (agg[info.itemID] or 0) + (info.stackCount or 1)
			end
		end
	end
	local unique = 0
	for id, n in pairs(agg) do
		unique = unique + 1
		aggLen = aggLen + #(id .. ":" .. n) + 1
	end
	local r = { slots = slots, used = used, uniqueItems = unique, fullLinksBytes = fullLen, aggregatedBytes = aggLen }
	ns.Data("E_STORAGE", label, r)
	return r
end

local function MeasureAll(where)
	local bags = Measure("bags_" .. where, ns.BAGS)
	if where == "bank" then
		local ch = Measure("characterBank", ns.PurchasedTabs("Character"))
		local ac = Measure("warbandBank", ns.PurchasedTabs("Account"))
		local perChar = bags.fullLinksBytes + ch.fullLinksBytes
		local perCharAgg = bags.aggregatedBytes + ch.aggregatedBytes
		ns.Data("E_STORAGE", "perCharacterEstimate", {
			fullLinksBytes = perChar, aggregatedBytes = perCharAgg,
			x25chars_fullKB = perChar * 25 / 1024, x25chars_aggKB = perCharAgg * 25 / 1024,
			warbandOnce_fullKB = ac.fullLinksBytes / 1024,
			note = "raw string bytes; SavedVariables file overhead adds roughly 20-40%",
		})
		ns.Check("E_STORAGE", "measuredWithBank", true, ("per char: links %.1f KB vs counts %.1f KB"):format(perChar / 1024, perCharAgg / 1024))
		ns.Summary("E_STORAGE", ("per character: full links %.1f KB, aggregated %.1f KB; warband %.1f KB"):format(perChar / 1024, perCharAgg / 1024, ac.fullLinksBytes / 1024))
	else
		ns.Check("E_STORAGE", "measuredBags", nil, bags)
		-- is bank content readable away from the bank? (offline cache question)
		local readable = 0
		for _, bag in ipairs(ns.CHAR_TABS_ALL) do readable = readable + ns.NumSlots(bag) end
		ns.Data("E_STORAGE", "characterBankSlotsReadableAwayFromBank", readable)
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns.On("BANKFRAME_OPENED", function()
	ns.bankOpen = true
	ns.context.bankVisited = true
	local t0 = debugprofilestop()
	C_Timer.After(0.3, function()
		local snap = BankSnapshot()
		local d = ns.Spike("B_BANK").data
		d.opens = (d.opens or 0) + 1
		if d.opens == 1 then d.firstOpen = ns.Safe(snap) end
		d.lastOpen = ns.Safe(snap)
		ns.Check("B_BANK", "readActiveBankTypeWithoutWriting", snap.activeBankType ~= "noAPI" and snap.activeBankType ~= "error", snap.activeBankType)
		if d.opens >= 2 and ns.context.bankTinyUsed then
			ns.Check("B_BANK", "blizzardBankNormalAfterRestore", snap.bankFrameVisible == true and not B.tiny,
				{ visible = snap.bankFrameVisible, parentIsUIParent = BankFrame:GetParent() == UIParent })
		end
		-- tab size assumption (98) check
		local sizes = {}
		for _, kind in ipairs({ "Character", "Account" }) do
			for _, bag in ipairs(ns.PurchasedTabs(kind)) do sizes[#sizes + 1] = ns.NumSlots(bag) end
		end
		ns.Data("A_POOL", "realBankTabSizes", sizes)
		if #B.candidates == 0 then B.PickCandidates() end
		B.counts = B.CountAll()
		if Pool.win:IsShown() then
			if Pool.mode == "grid" then Pool.LayoutGrid("bank open") end
			B.MarkCandidates()
		end
		MeasureAll("bank")
		ns.Data("B_BANK", "openHandlingMs", debugprofilestop() - t0)
	end)
end)

ns.On("BANKFRAME_CLOSED", function()
	EscEvent("BANKFRAME_CLOSED", { interaction = InteractionState() })
	ns.bankOpen = false
	ns.Log("bankClosed", { interaction = InteractionState(), tiny = B.tiny })
	if B.tiny then ns.OutOfCombat("Bank.untiny", function() B.SetTiny(false) end) end
	if Pool.win:IsShown() and Pool.mode == "grid" then
		ns.OutOfCombat("Pool.LayoutGrid", function() Pool.LayoutGrid("bank closed") end)
	end
	if escWatch then
		C_Timer.After(1, function()
			if not escWatch then return end
			local after = InteractionState()
			local stillOpen = false
			for _, v in pairs(after) do if v == true then stillOpen = true end end
			ns.Data("B_BANK", "escTest", { events = escWatch.events, interactionAfter1s = after })
			ns.Check("B_BANK", "escClosesBankInteraction", not stillOpen, { interactionAfter1s = after })
			escWatch = nil
		end)
	end
end)

ns.On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, ptype)
	EscEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", { type = ptype })
end)
ns.OnLogin(function()
	if BankFrame then
		BankFrame:HookScript("OnHide", function() EscEvent("BankFrame.OnHide") end)
	end
	-- bag contents aren't populated at PLAYER_LOGIN; measure once things settle
	C_Timer.After(10, function() MeasureAll("login") end)
end)

local pend = false
ns.On("BAG_UPDATE_DELAYED", function()
	if pend then return end
	pend = true
	C_Timer.After(0.1, function()
		pend = false
		ns.Try("Bank.DetectMovement", DetectMovement)
		if Pool.win:IsShown() and #B.candidates > 0 then B.MarkCandidates() end
	end)
end)

-- Hearthstone / item use after bank steps: annotate via context flags.
table.insert(ns.useListeners, function(rec)
	if not ns.context.bankVisited or ns.bankOpen then return end
	if rec.variant ~= "pool" then return end
	local name = ns.context.taintProbeDone and "itemUseAfterTaintProbe" or "itemUseAfterBankTests"
	if rec.blocked then
		ns.Check("B_BANK", name, false, rec)
	elseif rec.strong then
		ns.Check("B_BANK", name, true, rec)
	end
end)

ns.Command("bank", "print current bank state (spike B)", function()
	local s = BankSnapshot()
	ns.Print(("bank open: %s, active type: %s, tiny: %s"):format(tostring(ns.bankOpen), tostring(s.activeBankType), tostring(B.tiny)))
end)
ns.commands.b = ns.commands.bank
ns.Command("tiny", "toggle Blizzard bank tiny mode (at the bank)", function() B.SetTiny(not B.tiny) end)
ns.Command("storage", "measure storage now (spike E)", function() MeasureAll(ns.bankOpen and "bank" or "login") ns.Print("storage measured") end)
ns.commands.e = ns.commands.storage
