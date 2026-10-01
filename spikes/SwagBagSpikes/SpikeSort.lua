-- =====================================================================
-- THROWAWAY SPIKE CODE  -  SwagBagSpikes / SpikeSort.lua
-- Spike C: are the sort APIs callable from an addon button click?
--   C_Container.SortBags()             (bags)
--   C_Container.SortBank(bankType)     (12.x bank; Character / Account)
--   C_Container.SortBankBags()         (older name, if still present)
--   C_Container.SortAccountBankBags()  (older name, if still present)
-- Each is called from an insecure addon OnClick (hardware event), inside
-- pcall. We record return values, errors, blocked-action events, and
-- whether slot contents actually changed within 6 seconds.
-- NOTE: sorting really rearranges your bags/bank (same as Blizzard's broom).
-- =====================================================================
local _, ns = ...

ns.RegisterSpike("C_SORT", "Sort APIs callable from addon buttons", "C",
	"Delegate physical sort to Blizzard (button in SwagBag) vs build own sorter / hide sort")

local Sort = {}
ns.Sort = Sort

local function Fingerprint(bags)
	local parts = {}
	for _, bag in ipairs(bags) do
		for slot = 1, ns.NumSlots(bag) do
			parts[#parts + 1] = tostring(C_Container.GetContainerItemID(bag, slot) or 0)
		end
	end
	return table.concat(parts, ","), #parts
end

local function Attempt(label, fnPath, args, bags)
	local fn = ns.Resolve(fnPath)
	if type(fn) ~= "function" then
		ns.Check("C_SORT", label, nil, { missing = fnPath })
		ns.Print(label .. ": function not present in this build")
		return
	end
	if bags ~= ns.BAGS and not ns.bankOpen then
		ns.Print(label .. ": open the bank first")
		return
	end
	local before, nSlots = Fingerprint(bags)
	local start = GetTime()
	local inCombat = ns.InCombat()
	local updates = 0
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("BAG_UPDATE")
	watcher:SetScript("OnEvent", function() updates = updates + 1 end)
	local t0 = debugprofilestop()
	local res = { pcall(fn, unpack(args or {})) }
	local callMs = debugprofilestop() - t0
	ns.Print(label .. ": called, waiting 6 s to see if anything moved...")
	C_Timer.After(6, function()
		watcher:UnregisterAllEvents()
		local after = Fingerprint(bags)
		local blocked = ns.BlockedMineSince(start)
		local rec = {
			fn = fnPath, ok = res[1], ret1 = ns.Safe(res[2]), err = (not res[1]) and ns.Safe(tostring(res[2])) or nil,
			callMs = callMs, bagUpdateEvents = updates, contentsChanged = before ~= after, slotsChecked = nSlots,
			blocked = blocked, combat = inCombat,
		}
		local d = ns.Spike("C_SORT").data
		d[label] = rec
		local pass
		if not res[1] or blocked > 0 then pass = false
		elseif before ~= after or updates > 0 then pass = true
		else pass = nil end -- no error, but nothing changed (maybe already sorted)
		local key = label .. (inCombat and "_inCombat" or "")
		ns.Check("C_SORT", key, pass, rec)
		if pass == nil then ns.Print(label .. ": no error, but nothing moved (already sorted?)") end
	end)
end

function Sort.Bags() Attempt("SortBags", "C_Container.SortBags", {}, ns.BAGS) end

function Sort.BankCharacter()
	Attempt("SortBank_Character", "C_Container.SortBank", { Enum.BankType.Character }, ns.PurchasedTabs("Character"))
end

function Sort.BankAccount()
	Attempt("SortBank_Account", "C_Container.SortBank", { Enum.BankType.Account }, ns.PurchasedTabs("Account"))
end

function Sort.Legacy()
	Attempt("SortBankBags_legacy", "C_Container.SortBankBags", {}, ns.PurchasedTabs("Character"))
	C_Timer.After(7, function() Attempt("SortAccountBankBags_legacy", "C_Container.SortAccountBankBags", {}, ns.PurchasedTabs("Account")) end)
end

ns.OnLogin(function()
	for _, p in ipairs({ "C_Container.SortBags", "C_Container.SortBank", "C_Container.SortBankBags", "C_Container.SortAccountBankBags" }) do
		ns.Data("C_SORT", "present_" .. p, type(ns.Resolve(p)))
	end
end)

ns.Command("sortbags", "call C_Container.SortBags() (spike C)", Sort.Bags)
ns.commands.c = ns.commands.sortbags
ns.Command("sortbank", "call C_Container.SortBank for character, then warband (at bank)", function()
	Sort.BankCharacter()
	C_Timer.After(7, Sort.BankAccount)
end)
