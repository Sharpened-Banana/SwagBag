-- SwagBag at a vendor (week 7, user pick 4): sell gray junk and repair, by themselves, on MERCHANT_SHOW.
--   Vendor.Protected(record, fast) -> bool   never sold by SwagBag (ruling R19): in an equipment set, locked by the
--                                      user (Engine/Locks.lua, Task 5), an item to open or learn
--                                      (Collections.Learn: caches, unlearned toys, mounts, pets, decor,
--                                      knowledge), gear whose look the account has not collected
--                                      (Collections.Uncollected, Task 8), or a gray BoE item an auction source
--                                      (Auctionator or TSM, whichever is loaded, whatever the price source:
--                                      Prices.AuctionValue, week 9 ruling R0) prices above twice the vendor
--   Vendor.Junk() -> { item }          gray items a vendor pays for, not protected, not held by the client
--                                      (being moved or traded), loaded; bags order. item = { bag, slot,
--                                      itemID, link, count, price } (price: copper per unit)
--   Vendor.Room() -> n                 how many more SwagBag may sell this visit with every one still in the
--                                      Buyback tab (BUYBACK minus soldThisVisit)
--   Vendor.Sell(list, kind, after, past) -> ok, why   sell up to Room() of `list` through the mover
--                                      (Engine/Mover.lua); kind "junk" (auto or /swagbag sell junk) or
--                                      "section" (UI/SectionActions.lua); past = true: the user said yes to
--                                      selling past the room (up to BUYBACK more); why "full": no room left
--   Vendor.Repair() -> line | nil      repair as vendor.repair says; the chat line, or nil (nothing to repair)
--   Vendor.Money(copper) -> "1g 23s 4c"
-- Settings: vendor.autoSell (default on) and vendor.repair: "own" (default, your gold) | "guild" (the guild
-- bank first when the guild allows it, else your gold) | "off". Commands: /swagbag sell [on|off|junk],
-- /swagbag repair [own|guild|off]; Settings > Vendor (UI/SettingsVendor.lua).
-- Safety: at most BUYBACK (12) items per vendor visit (ruling R1), because Blizzard's buyback tab keeps only
-- the last 12 sold: the auto-sell, /swagbag sell junk and Sell all share the count, and selling past it needs
-- a second, explicit yes that says the earlier ones leave the Buyback tab. Nothing runs in combat: a vendor
-- opened in combat sells and repairs once combat ends, if it is still open. Each sale goes through the
-- mover, so nothing is sold while an item is on the cursor or its button is under the mouse (P5); right
-- before each sale the slot is looked at again (rulings R2, R20: the vendor still open, the item still not
-- protected). A sold item leaves a placeholder in the open bags (spec 4.3), so nothing else moves. One chat
-- line per run says what was sold and for how much; the repair says its own.
-- A locked item sold by hand (Blizzard's own right-click, which SwagBag does not hook) cannot be stopped:
-- while a vendor is open, a locked item that leaves the bags and shows up in the buyback tab gets one chat
-- line naming it and where to buy it back (Vendor.WatchLocked).
local _, SB = ...

local L = SB.L
local V = { open = false, BUYBACK = 12, soldThisVisit = 0, pastAsked = false }
SB.Vendor = V

function V.Money(copper)
	copper = math.floor(copper or 0)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	if g > 0 then
		return L.VENDOR_MONEY_G:format(g, s, c)
	elseif s > 0 then
		return L.VENDOR_MONEY_S:format(s, c)
	end
	return L.VENDOR_MONEY_C:format(c)
end

-- A gray item that binds when equipped and that an auction source prices above twice what a vendor pays (R19:
-- a gold-maker sells those at the Auction House, not to a vendor). Week 9 ruling R0: every loaded auction
-- source is asked (Auctionator, TSM; the highest answer counts), even when the price source is "Vendor". No
-- auction addon loaded, or none knows the item: no such protection.
local function worthMoreAtAuction(r)
	if r.quality ~= 0 or r.bind ~= "equip" or r.isBound or not SB.Prices then
		return false
	end
	local ah = SB.Prices.AuctionValue(r.link, r.itemID)
	local info = SB.Adapter.GetItemInfo(r.itemID)
	return type(ah) == "number" and ah > 2 * (info and info.sellPrice or 0)
end

-- fast = true: a draw (the overlays' junk coin, week 8) may use cached look answers; the sell path never
-- passes it, so an unknown look is asked again right before each sale.
function V.Protected(r, fast)
	return r.inEquipmentSet == true or (SB.Locks ~= nil and SB.Locks.Has(r.itemID))
		or (SB.Collections ~= nil and (SB.Collections.Learn(r) ~= nil or SB.Collections.Uncollected(r) ~= nil
			or SB.Collections.LookUnknown(r, fast)))
		or worthMoreAtAuction(r)
end

function V.Junk()
	local A, out = SB.Adapter, {}
	for bag, slot, snap in SB.Inventory.Iterate("bags") do
		if snap then
			local r = SB.Items.Describe(bag, slot)
			local info = r and not r.pending and A.GetItemInfo(r.itemID)
			local price = info and info.sellPrice or 0
			if r and r.quality == 0 and not r.hasNoValue and not r.isLocked and price > 0 and not V.Protected(r) then
				out[#out + 1] = { bag = bag, slot = slot, itemID = r.itemID, link = r.link, count = r.count or 1,
					price = price }
			end
		end
	end
	return out
end

function V.Room()
	return math.max(0, V.BUYBACK - V.soldThisVisit)
end

-- Why a run stopped, as the rest of its line ("... so N stayed in your bags.").
local STOP_LINES = { closed = "VENDOR_STOP_CLOSED", combat = "VENDOR_STOP_COMBAT", stuck = "VENDOR_STOP_REFUSED",
	error = "VENDOR_STOP_REFUSED" }

-- A chat line for a finished sale. kind "junk": "Sold 3 junk items for 1g 2s 3c."; "section": "Sold 3
-- items for ...". waiting: items past the room that were not offered this run. A stop names how many
-- stayed (result.left: never 0, never an item used by hand meanwhile; ruling R8).
local function soldLine(result, kind, waiting)
	local n, copper = #result.moved, 0
	for _, it in ipairs(result.moved) do
		copper = copper + (it.price or 0) * (it.count or 1)
	end
	local junk = kind == "junk"
	local stop = STOP_LINES[result.why or ""]
	if n == 0 and not (stop and result.left > 0) and result.kept == 0 and waiting == 0 then
		return nil -- P2: nothing was sold and there is nothing to add: say nothing
	end
	local line
	if n == 1 then
		line = (junk and L.VENDOR_SOLD_JUNK_ONE or L.VENDOR_SOLD_ONE):format(V.Money(copper))
	else
		line = (junk and L.VENDOR_SOLD_JUNK or L.VENDOR_SOLD):format(n, V.Money(copper))
	end
	if stop and result.left > 0 then
		line = line .. " " .. L[stop]:format(result.left)
	elseif result.kept > 0 then
		line = line .. " " .. L.VENDOR_KEPT_MOUSE:format(result.kept)
	end
	if waiting > 0 then
		line = line .. " " .. (junk and L.VENDOR_MORE_JUNK or L.VENDOR_MORE):format(waiting)
	end
	return line
end

-- Right before each sale (R2, R20): the vendor is still open, and the slot's item may still be sold (a lock,
-- an equipment set or another protection added since the list was made skips it).
local function sellable(item)
	if not V.open then
		return "closed"
	end
	local r = SB.Items.Describe(item.bag, item.slot)
	if not r or r.isLocked or V.Protected(r) then
		return "skip"
	end
	return true
end

-- after(result): runs once the sale is over (the auto-sell repairs then). past: see the header.
function V.Sell(list, kind, after, past)
	if not V.open then
		return false, "closed"
	end
	local room = past and V.BUYBACK or V.Room()
	if room == 0 then
		return false, "full"
	end
	local batch = {}
	for i = 1, math.min(#list, room) do
		batch[i] = list[i]
	end
	local waiting = #list - #batch
	return SB.Mover.Start({ items = batch, act = SB.Adapter.SellItem, ready = sellable, still = function()
		return V.open
	end, done = function(result)
		V.soldThisVisit = V.soldThisVisit + #result.moved
		local line = soldLine(result, kind, waiting)
		if line then
			SB.Print(line)
		end
		if after then
			after(result)
		end
	end })
end

-- After the repair call: read the cost again. 0: it worked; still more than 0: it did not finish; nil: the
-- client cannot say, so the line claims nothing.
local function repairResult(cost, paidBy)
	local after = SB.Adapter.RepairCost()
	if after == nil then
		return L.VENDOR_REPAIR_SENT:format(V.Money(cost))
	elseif after > 0 then
		return L.VENDOR_REPAIR_UNFINISHED
	end
	return (paidBy == "guild" and L.VENDOR_REPAIRED_GUILD or paidBy == "ownAfterGuild" and L.VENDOR_REPAIRED_OWN_GUILD
		or L.VENDOR_REPAIRED):format(V.Money(cost))
end

function V.Repair()
	local A = SB.Adapter
	local mode = SB.Config.Get("vendor.repair")
	if mode == "off" then
		return nil
	end
	local cost = A.RepairCost()
	if not cost or cost <= 0 then
		return nil
	end
	local guildTried = false
	if mode == "guild" then
		guildTried = true
		local limit, balance = A.GuildRepairMoney(), A.GuildBankMoney()
		if limit and balance then
			local room = limit < 0 and balance or math.min(limit, balance)
			if room >= cost and A.Repair(true) then
				return repairResult(cost, "guild")
			end
		end
	end
	local money = A.Money()
	if money and money < cost then
		return L.VENDOR_REPAIR_POOR:format(V.Money(cost))
	end
	if A.Repair(false) then
		return repairResult(cost, guildTried and "ownAfterGuild" or "own")
	end
	return L.VENDOR_REPAIR_FAILED
end

local function repairNow()
	local line = V.Repair()
	if line then
		SB.Print(line)
	end
end

-- Repairing never happens in combat: in combat it waits for combat's end (one waiting repair at most) and
-- only goes ahead if the vendor is still open.
local function repairSafely()
	SB.OutOfCombat(function()
		if V.open then
			repairNow()
		end
	end, "vendor.repair", "none")
end

-- Is there anything for the visit to do: junk to sell, or gear to repair?
local function work()
	if SB.Config.Get("vendor.autoSell") and #V.Junk() > 0 then
		return true
	end
	local cost = SB.Config.Get("vendor.repair") ~= "off" and SB.Adapter.RepairCost()
	return type(cost) == "number" and cost > 0
end

-- The vendor opened (or combat ended while it stayed open): sell junk, then repair, so the junk's gold
-- helps pay for the repair. While the stacker runs, the visit waits for it (SB_STACKER_DONE below).
function V.Visit()
	if not V.open then
		return
	end
	if SB.Adapter.InCombat() then
		if work() then -- P2: say it waits only when there is something to wait for (ruling R9)
			SB.Print(L.VENDOR_COMBAT)
		end
		SB.OutOfCombat(V.Visit, "vendor.visit", "none")
		return
	end
	if SB.Stacker and SB.Stacker.Busy() then
		V.visitWaiting = true -- week 9: one run moves items at a time; the visit runs when stacking ends
		return
	end
	if SB.Config.Get("vendor.autoSell") and not SB.Mover.Busy() then
		local junk = V.Junk()
		if #junk > 0 and V.Sell(junk, "junk", repairSafely) then
			return
		end
	end
	repairSafely()
end

-- Where the locked items are while a vendor is open: ["bag:slot"] = { itemID, link }.
V.lockedAt = {}
function V.WatchLocked()
	V.lockedAt = {}
	if not (V.open and SB.Locks) then
		return
	end
	for bag, slot, snap in SB.Inventory.Iterate("bags") do
		if snap and SB.Locks.Has(snap.itemID) then
			V.lockedAt[bag .. ":" .. slot] = { itemID = snap.itemID, link = snap.link }
		end
	end
end

local function inBuyback(link)
	for _, l in ipairs(SB.Adapter.BuybackLinks()) do
		if l == link then
			return true
		end
	end
	return false
end

-- P6: Inventory.Notify runs its listeners inside a "bags" trap; this one has its own "none" trap (ruling
-- R15), so a failure in the warning is recorded and never switches the bags to Safe Mode.
SB.Inventory.OnChanged(SB.ErrorTrap.Guard("vendor.inventory", function(mask, changes)
	if not (V.open and SB.Inventory.Has(mask, SB.Inventory.R.ITEM)) then
		return
	end
	for _, c in ipairs(changes) do
		local was = V.lockedAt[c.bag .. ":" .. c.slot]
		local now = SB.Inventory.GetSlot(c.bag, c.slot)
		if was and not (now and now.itemID == was.itemID) and inBuyback(was.link) then
			SB.Print(L.LOCK_SOLD:format(SB.Locks.Name(was.itemID)))
		end
	end
	V.WatchLocked()
end, "none"))

SB.On("MERCHANT_SHOW", function()
	V.open = true
	V.WatchLocked()
	V.soldThisVisit, V.pastAsked = 0, false -- a new visit: the Buyback tab has room for 12 of SwagBag's again
	V.Visit()
end, "none")

SB.On("MERCHANT_CLOSED", function()
	V.open = false
	V.visitWaiting = false
	V.pastAsked = false
	V.lockedAt = {}
end, "none")

SB.On("SB_LOCKS_CHANGED", V.WatchLocked, "none")

-- Week 9: a vendor opened while the stacker moved items (Engine/Stacker.lua) waited for the run; its visit (the
-- auto-sell, then the repair) runs once the run ends, if the vendor is still open. Never skipped in silence (P2).
SB.On("SB_STACKER_DONE", function()
	if V.visitWaiting then
		V.visitWaiting = false
		V.Visit()
	end
end, "none")

---------------------------------------------------------------------------
-- /swagbag sell and /swagbag repair (P2: every form answers)
---------------------------------------------------------------------------
local function onOff(on)
	return on and L.OVERLAY_ON or L.OVERLAY_OFF
end

local function startJunk()
	if not V.open then
		return L.VENDOR_NOT_OPEN
	end
	local junk = V.Junk()
	if #junk == 0 then
		return L.VENDOR_NO_JUNK
	end
	local past = V.Room() == 0
	if past and not V.pastAsked then
		V.pastAsked = true -- R1: the same command again is the explicit yes
		return L.VENDOR_PAST_JUNK:format(math.min(#junk, V.BUYBACK))
	end
	local ok, why = V.Sell(junk, "junk", nil, past)
	if not ok then
		return why == "combat" and L.VENDOR_COMBAT_NOW or L.MOVER_BUSY
	end
	V.pastAsked = false
	return {} -- P2: the sale's own line, when it ends, is the one answer
end

SB.Slash.Register("sell", L.HELP_SELL, function(arg)
	arg = (arg or ""):lower()
	if arg == "" then
		return L.VENDOR_SELL_STATE:format(onOff(SB.Config.Get("vendor.autoSell")))
	elseif arg == "junk" then
		return startJunk()
	elseif arg ~= "on" and arg ~= "off" then
		return L.VENDOR_SELL_USAGE
	end
	if not SB.Config.Set("vendor.autoSell", arg == "on") then
		return L.SETTINGS_READONLY
	end
	return arg == "on" and L.VENDOR_SELL_ON or L.VENDOR_SELL_OFF
end)

local REPAIR_LINES = { own = "VENDOR_REPAIR_OWN", guild = "VENDOR_REPAIR_GUILD", off = "VENDOR_REPAIR_OFF" }
-- The choice's name as Settings > Vendor shows it (ruling R18: never the stored word).
local REPAIR_NAMES = { own = "SET_VENDOR_REPAIR_OWN", guild = "SET_VENDOR_REPAIR_GUILD", off = "SET_OFF" }

SB.Slash.Register("repair", L.HELP_REPAIR, function(arg)
	arg = (arg or ""):lower()
	if arg == "" then
		local mode = SB.Config.Get("vendor.repair")
		return L.VENDOR_REPAIR_STATE:format(L[REPAIR_NAMES[mode] or REPAIR_NAMES.own])
	elseif not REPAIR_LINES[arg] then
		return L.VENDOR_REPAIR_USAGE
	end
	if not SB.Config.Set("vendor.repair", arg) then
		return L.SETTINGS_READONLY
	end
	return L[REPAIR_LINES[arg]]
end)
