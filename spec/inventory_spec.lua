local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua", "SwagBag/Engine/Inventory.lua",
}

describe("Inventory", function()
	local SB, A, Inv, R, calls
	before_each(function()
		SB = Loader.New(FILES)
		A, Inv = SB.Adapter, SB.Inventory
		R = Inv.R
		Fixtures.SmallBags(A)
		SB.Emit("SB_LOGIN")
		Fixtures.Settle(SB) -- the login settle is over (hotfix 0.11.1)
		calls = {}
		Inv.OnChanged(function(mask, changes) calls[#calls + 1] = { mask = mask, changes = changes } end)
	end)

	local function fire(event, ...)
		SB.eventFrame:Fire(event, ...)
	end

	it("Has and Or combine reason flags without bit operators", function()
		local m = Inv.Or(R.COUNT, R.ITEM)
		assert.equal(3, m)
		assert.truthy(Inv.Has(m, R.ITEM))
		assert.falsy(Inv.Has(m, R.SIZE))
		assert.equal(3, Inv.Or(m, R.COUNT))
	end)

	it("DiffSlot tells ITEM from COUNT from nothing", function()
		local a = { itemID = 1, link = "x", count = 1 }
		assert.equal(0, Inv.DiffSlot(nil, nil))
		assert.equal(R.ITEM, Inv.DiffSlot(nil, a))
		assert.equal(R.ITEM, Inv.DiffSlot(a, { itemID = 2, link = "y", count = 1 }))
		assert.equal(R.COUNT, Inv.DiffSlot(a, { itemID = 1, link = "x", count = 4 }))
		assert.equal(0, Inv.DiffSlot(a, { itemID = 1, link = "x", count = 1 }))
	end)

	it("the login scan fills the model without marking anything new", function()
		assert.equal(16, Inv.Size(0))
		assert.equal(Fixtures.HEALING_POTION, Inv.GetSlot(0, 1).itemID)
		assert.is_nil(Inv.GetSlot(0, 16))
		assert.falsy(Inv.IsNew(0, 1))
	end)

	it("BAG_UPDATE only marks dirty; BAG_UPDATE_DELAYED flushes once after 50 ms", function()
		A.Put(0, 1, Fixtures.HEALING_POTION, 4)
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE", 0)
		assert.equal(0, #calls)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.04)
		assert.equal(0, #calls)
		A.Advance(0.02)
		assert.equal(1, #calls)
		assert.equal(R.COUNT, calls[1].mask)
		assert.same({ { bag = 0, slot = 1, reasons = R.COUNT } }, calls[1].changes)
		assert.equal("delayed", Inv.lastFlush)
		A.Advance(1)
		assert.equal(1, #calls, "the failsafe must not flush a second time")
	end)

	it("the 250 ms failsafe flushes when BAG_UPDATE_DELAYED never comes", function()
		A.Clear(0, 6)
		fire("BAG_UPDATE", 0)
		A.Advance(0.2)
		assert.equal(0, #calls)
		A.Advance(0.1)
		assert.equal(1, #calls)
		assert.equal(R.ITEM, calls[1].mask)
		assert.equal("failsafe", Inv.lastFlush)
	end)

	it("an item arriving after login is new; leaving clears it", function()
		A.Put(0, 12, Fixtures.HERB, 10)
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
		assert.truthy(Inv.IsNew(0, 12))
		A.Clear(0, 12)
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
		assert.falsy(Inv.IsNew(0, 12))
	end)

	it("a bag size change reports SIZE and updates the stored size", function()
		A.SetBagSize(1, 4)
		fire("BAG_UPDATE", 1)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
		assert.equal(1, #calls)
		assert.truthy(Inv.Has(calls[1].mask, R.SIZE))
		assert.equal(4, Inv.Size(1))
	end)

	it("late DELAYED: if DELAYED comes after failsafe timeout, DELAYED flushes and lastFlush is failsafe", function()
		A.Put(0, 2, Fixtures.HEALING_POTION, 2)
		fire("BAG_UPDATE", 0)
		A.Advance(0.24)
		assert.equal(0, #calls)
		A.Advance(0.01)
		assert.equal(1, #calls, "failsafe should have flushed")
		assert.equal("failsafe", Inv.lastFlush)
		A.Advance(0.15)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
		assert.equal(1, #calls, "DELAYED debounce still fires but has no changes to report")
		assert.equal("failsafe", Inv.lastFlush, "lastFlush unchanged from earlier failsafe")
	end)

	it("multi-bag storm: multiple BAG_UPDATEs across bags coalesce to one flush with sorted changes", function()
		A.SetBagSize(1, 16)
		A.Put(0, 1, Fixtures.HEALING_POTION, 3)
		A.Put(1, 2, Fixtures.HERB, 5)
		A.Put(0, 3, Fixtures.ORE, 1)
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE", 1)
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE", 1)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
		assert.equal(1, #calls, "all updates coalesced to one flush")
		local changes = calls[1].changes
		assert.equal(3, #changes)
		assert.equal(0, changes[1].bag)
		assert.equal(1, changes[1].slot)
		assert.equal(0, changes[2].bag)
		assert.equal(3, changes[2].slot)
		assert.equal(1, changes[3].bag)
		assert.equal(2, changes[3].slot)
		assert.equal("delayed", Inv.lastFlush)
	end)

	it("ITEM_LOCK_CHANGED reports LOCK for that slot and updates the snapshot", function()
		A.slots[0][1].isLocked = true
		fire("ITEM_LOCK_CHANGED", 0, 1)
		assert.equal(R.LOCK, calls[1].mask)
		assert.same({ { bag = 0, slot = 1, reasons = R.LOCK } }, calls[1].changes)
		assert.equal(true, Inv.GetSlot(0, 1).isLocked)
		fire("ITEM_LOCK_CHANGED", 16, nil)
		assert.equal(1, #calls, "equipment-slot locks are ignored")
	end)

	it("BAG_UPDATE_COOLDOWN reports COOLDOWN without rescanning", function()
		fire("BAG_UPDATE_COOLDOWN")
		assert.equal(R.COOLDOWN, calls[1].mask)
		assert.same({}, calls[1].changes)
	end)

	it("item data arriving for a pending item reports LOADED for its slots", function()
		A.Put(0, 7, Fixtures.UNLOADED, 1)
		A.Put(0, 8, Fixtures.UNLOADED, 1)
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
		Inv.MarkPending(Fixtures.UNLOADED)
		fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		local last = calls[#calls]
		assert.equal(R.LOADED, last.mask)
		assert.same({ { bag = 0, slot = 7, reasons = R.LOADED }, { bag = 0, slot = 8, reasons = R.LOADED } }, last.changes)
		local n = #calls
		fire("GET_ITEM_INFO_RECEIVED", Fixtures.UNLOADED, true)
		assert.equal(n, #calls, "only once per pending item")
	end)

	it("item data load failure (success=false) leaves the item pending and emits no LOADED", function()
		A.Put(0, 9, Fixtures.UNLOADED, 1)
		fire("BAG_UPDATE", 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
		Inv.MarkPending(Fixtures.UNLOADED)
		local n = #calls
		fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, false)
		assert.equal(n, #calls, "no LOADED event on failure")
		assert.truthy(Inv.pending[Fixtures.UNLOADED], "item remains pending")
		fire("ITEM_DATA_LOAD_RESULT", Fixtures.UNLOADED, true)
		assert.equal(n + 1, #calls, "LOADED fires when it succeeds")
		assert.falsy(Inv.pending[Fixtures.UNLOADED], "item no longer pending")
	end)

	it("Iterate walks every slot of a kind in bag order", function()
		A.SetBagSize(1, 2)
		Inv.ScanBag(1)
		local seen = 0
		local last
		for bag, slot in Inv.Iterate("bags") do
			seen = seen + 1
			last = bag .. ":" .. slot
		end
		assert.equal(18, seen)
		assert.equal("1:2", last)
	end)

	it("a listener error is trapped and flips bags to Safe Mode", function()
		Inv.OnChanged(function() error("listener broke") end)
		fire("BAG_UPDATE_COOLDOWN")
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.equal("inventory.listener", SB.ErrorTrap.Recent()[1].label)
	end)
	-- Final review M5. Mutation: drop the pcall around the loop in Inv.ScanKind.
	it("ScanKind puts Inv.scanned back even when a bag scan errors, and still raises the error", function()
		assert.truthy(Inv.scanned)
		Inv.ScanBag = function() error("scan broke") end
		local ok, err = pcall(Inv.ScanKind, "bags")
		assert.falsy(ok)
		assert.truthy(tostring(err):find("scan broke", 1, true))
		assert.equal(true, Inv.scanned)
	end)

	-- Final review item 6 (the user's rule, spec AC3.3): what came into the bags stays unseen until hovered.
	local function flush(bag)
		fire("BAG_UPDATE", bag or 0)
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
	end

	-- Mutation: in markUnseen, `(after[id] or 0) > (before[id] or 0)` -> `true` (a move or split is unseen too).
	it("an item that comes into the bags is unseen until Seen; a move or a split inside the bags is not", function()
		A.Put(0, 12, Fixtures.HERB, 10) -- looted
		flush()
		assert.truthy(Inv.IsUnseen(0, 12))
		A.Clear(0, 3) -- the ring dragged to another slot
		A.Put(0, 13, Fixtures.BOE_RING, 1)
		A.Put(0, 1, Fixtures.HEALING_POTION, 3) -- two potions split off
		A.Put(0, 14, Fixtures.HEALING_POTION, 2)
		flush()
		assert.falsy(Inv.IsUnseen(0, 13), "a move")
		assert.falsy(Inv.IsUnseen(0, 14), "a split")
		Inv.Seen(0, 12)
		assert.falsy(Inv.IsUnseen(0, 12), "hovered")
		assert.truthy(Inv.IsNew(0, 12), "the `new` search keyword keeps its own session rule")
	end)

	-- Mutation: in markUnseen, drop the `carried` branch (an unseen item moved by Blizzard's sort is seen).
	it("an unseen item moved inside the bags stays unseen in its new slot; one that leaves is no longer unseen", function()
		A.Put(0, 12, Fixtures.HERB, 10)
		flush()
		A.Clear(0, 12)
		A.Put(0, 15, Fixtures.HERB, 10)
		flush()
		assert.falsy(Inv.IsUnseen(0, 12))
		assert.truthy(Inv.IsUnseen(0, 15))
		A.Clear(0, 15)
		flush()
		assert.falsy(Inv.IsUnseen(0, 15))
		A.Put(0, 15, Fixtures.JUNK, 3) -- the same slot gets a stack of junk the bags already hold more of
		flush()
		assert.truthy(Inv.IsUnseen(0, 15))
	end)

	-- Mutation: in markUnseen, drop `set[c.bag] and` (a bank deposit or a bank item would be unseen).
	it("only the bags count: a bank slot never holds an unseen item; the login scan marks nothing", function()
		A.bagIDs.bank = { 6 }
		A.SetBagSize(6, 4)
		A.Put(6, 1, Fixtures.HERB, 5) -- in one flush: herbs into the bank and into the bags
		A.Put(0, 12, Fixtures.HERB, 1)
		fire("BAG_UPDATE", 6)
		flush()
		assert.truthy(Inv.IsUnseen(0, 12))
		assert.falsy(Inv.IsUnseen(6, 1), "the bank's slot")
		Inv.ScanAll()
		assert.falsy(Inv.IsUnseen(0, 12), "a new session (login or /reload) starts with nothing unseen")
	end)

	-- Midnight's secret values (the user's report: looted inside a Mythic+ key). An item whose ID reads secret
	-- reads as an empty slot; once readable it arrives, unseen. Mutation: in Inventory.Flush, drop the
	-- `markUnseen(all, set, before)` call (the item would skip New, as before this fix).
	it("an item whose ID was secret when it came is unseen once it becomes readable, in combat too", function()
		A.combat = true
		A.Put(0, 12, Fixtures.HERB, 4, { secretID = true })
		flush()
		assert.falsy(Inv.IsUnseen(0, 12), "nothing readable yet")
		A.slots[0][12].secretID = nil
		flush()
		assert.truthy(Inv.IsUnseen(0, 12))
	end)
end)

-- Hotfix 0.11.1 (the user's report: after a fresh client start, `- New (133)`, every item in the bags in New).
-- What is in the bags when the player gets control is never unseen: at PLAYER_LOGIN the client may not have
-- filled the bags yet, and around a loading screen (login, /reload, zoning into or out of an instance) slots can
-- read empty or secret and then fill again. Spec AC3.3.
describe("Inventory: login and loading screens never flood New", function()
	local SB, A, Inv
	before_each(function()
		SB = Loader.New(FILES)
		A, Inv = SB.Adapter, SB.Inventory
		Fixtures.SmallBags(A)
		A.SetBagSize(1, 4)
		A.Put(1, 1, Fixtures.HERB, 20)
		A.Put(1, 2, Fixtures.BOE_RING, 1)
	end)

	local function fire(event, ...)
		SB.eventFrame:Fire(event, ...)
	end

	local function flushAll()
		for _, bag in ipairs(A.GetBagIDs("bags")) do
			fire("BAG_UPDATE", bag)
		end
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
	end

	local function unseenCount()
		local n = 0
		for _ in pairs(Inv.unseen) do
			n = n + 1
		end
		return n
	end

	local function newCount()
		local n = 0
		for _ in pairs(Inv.newSet) do
			n = n + 1
		end
		return n
	end

	-- The client's bag data is not there yet: every slot of the backpack reads empty (its size is known).
	local function hideBackpack()
		local saved = A.slots[0]
		A.slots[0] = {}
		return function()
			A.slots[0] = saved
		end
	end

	local function enterWorld(isLogin, isReload)
		fire("PLAYER_ENTERING_WORLD", isLogin == true, isReload == true)
	end

	local function settle()
		A.Advance(Inv.SETTLE_QUIET + 0.1)
	end

	-- (a) Mutation: in Inventory.lua canArrive, `return not Inv.settling or ...` -> `return true` (no settle).
	it("fresh login: the bags read empty at PLAYER_LOGIN and fill after it: nothing is unseen or new", function()
		local restore = hideBackpack()
		SB.Emit("SB_LOGIN")
		enterWorld(true, false)
		restore()
		flushAll()
		assert.equal(0, unseenCount(), "what was in the bags at login")
		assert.equal(0, newCount(), "the `new` keyword too")
		settle()
		A.Put(0, 12, Fixtures.HERB, 3) -- looted after the settle
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 12), "a real arrival after the settle is still unseen (d)")
		assert.equal(1, unseenCount())
	end)

	-- (a) The bags fill during the loading screen, between PLAYER_LOGIN and PLAYER_ENTERING_WORLD.
	-- Mutation: in Inventory.ScanAll, do not start the settle (Inv.settling stays false until the world loads).
	it("fresh login: bags that fill before the loading screen ends are not unseen", function()
		local restore = hideBackpack()
		SB.Emit("SB_LOGIN")
		restore()
		flushAll()
		assert.equal(0, unseenCount())
		A.Advance(5)
		flushAll()
		enterWorld(true, false)
		settle()
		assert.equal(0, unseenCount())
		A.Put(0, 12, Fixtures.HERB, 3)
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 12))
	end)

	-- (a) An equipped bag whose size reads 0 at login and whose contents come in later, whenever that is: a bag
	-- can be put on only when it is empty, so what a bag holds when its size first reads is not an arrival.
	-- Mutation: in Inventory.ScanBag, drop the `fresh` flag (a bag's late contents arrive).
	it("a bag whose size reads 0 at login and fills later, even after the settle, adds nothing to New", function()
		A.SetBagSize(1, 0)
		SB.Emit("SB_LOGIN")
		enterWorld(true, false)
		settle()
		A.Advance(30)
		A.SetBagSize(1, 4)
		flushAll()
		assert.equal(20, Inv.GetSlot(1, 1).count)
		assert.equal(0, unseenCount())
		assert.equal(0, newCount())
	end)

	-- A bag holding items cannot be taken off, so a size that reads 0 while the model holds items is unreadable,
	-- not an empty bag: its items are kept, and they are not new when the size reads again.
	-- Mutation: in Inventory.ScanBag, drop the unreadable-size guard.
	it("a bag's size reading 0 for a moment while it holds items neither empties it nor floods New", function()
		SB.Emit("SB_LOGIN")
		enterWorld(true, false)
		settle()
		A.SetBagSize(1, 0)
		flushAll()
		assert.equal(4, Inv.Size(1))
		assert.equal(Fixtures.HERB, Inv.GetSlot(1, 1).itemID)
		settle()
		A.SetBagSize(1, 4)
		flushAll()
		assert.equal(0, unseenCount())
	end)

	-- (b) Midnight: a slot whose item ID reads secret is not empty. Its last known item stays; when it reads
	-- again with the same item, nothing came. Mutation: in Inventory.ScanBag, drop the SlotIsSecret check (a
	-- secret slot reads as empty, as before the hotfix).
	it("a slot that goes secret and readable again with the same item is not unseen", function()
		SB.Emit("SB_LOGIN")
		enterWorld(true, false)
		settle()
		A.slots[0][1].secretID = true -- the healing potions, in a Mythic+ key
		flushAll()
		assert.equal(Fixtures.HEALING_POTION, Inv.GetSlot(0, 1).itemID, "kept while secret")
		A.slots[0][1].secretID = nil
		flushAll()
		assert.falsy(Inv.IsUnseen(0, 1))
		assert.falsy(Inv.IsNew(0, 1))
		A.slots[0][1].secretID = true
		flushAll()
		A.Put(0, 1, Fixtures.HERB, 2, { secretID = true }) -- the potions drunk, herbs looted into the slot, all secret
		flushAll()
		A.slots[0][1].secretID = nil
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 1), "what came while the slot was secret")
	end)

	-- (b) /reload (or a login) inside a key: what a secret slot holds at the login scan is not known, and it was
	-- there before the session: not new when it reads. Mutation: in Inventory.ScanBag, record every secret slot as
	-- "known" (never "base").
	it("a slot that is secret at the login scan is not unseen when it reads, after the settle too", function()
		A.slots[0][1].secretID = true
		SB.Emit("SB_LOGIN")
		enterWorld(false, true)
		settle()
		A.slots[0][1].secretID = nil
		flushAll()
		assert.equal(Fixtures.HEALING_POTION, Inv.GetSlot(0, 1).itemID)
		assert.falsy(Inv.IsUnseen(0, 1))
	end)

	-- (b) The intent of week 9 stays: an item looted while secret arrives when it reads, even if that is during
	-- the settle after zoning out of the instance. Mutation: in markUnseen, never let a change arrive while
	-- settling (drop the `c.revealed == "known"` case).
	it("an item looted while secret is unseen when it reads, even during the settle after zoning out", function()
		SB.Emit("SB_LOGIN")
		enterWorld(true, false)
		settle()
		A.Put(0, 12, Fixtures.HERB, 4, { secretID = true })
		flushAll()
		assert.falsy(Inv.IsUnseen(0, 12), "nothing readable yet")
		enterWorld(false, false) -- the key is over: out of the instance
		A.slots[0][12].secretID = nil
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 12))
	end)

	-- (c) Zoning (a loading screen): slots read empty, then fill again. Nothing comes; what was unseen stays
	-- unseen. Mutations: delete the PLAYER_ENTERING_WORLD handler in Inventory.lua; or mutation (a) above.
	it("zoning: bags that read empty and fill again add nothing to New", function()
		SB.Emit("SB_LOGIN")
		enterWorld(true, false)
		settle()
		A.Put(0, 12, Fixtures.HERB, 4) -- looted before the zone
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 12))
		enterWorld(false, false)
		local restore = hideBackpack()
		flushAll()
		restore()
		flushAll()
		assert.equal(1, unseenCount())
		settle()
		A.Put(0, 13, Fixtures.JUNK, 1)
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 13), "after the settle, arrivals are unseen again")
	end)

	-- (c) Mutation: in Inventory.Flush, drop the settle's carry pool (an unseen item that read empty during the
	-- loading screen and came back in a later flush would be seen).
	it("zoning: an unseen item that reads empty and comes back in a later flush stays unseen", function()
		SB.Emit("SB_LOGIN")
		enterWorld(true, false)
		settle()
		A.Put(0, 12, Fixtures.HERB, 4)
		flushAll()
		enterWorld(false, false)
		local restore = hideBackpack()
		flushAll()
		assert.falsy(Inv.IsUnseen(0, 12), "not there now")
		restore()
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 12), "back, still unseen")
	end)

	-- (c) The settle ends at last even if the bags keep changing. Mutation: in Inventory.Flush, drop the cap check.
	it("a settle that keeps getting flushes ends at the cap", function()
		SB.Emit("SB_LOGIN")
		enterWorld(true, false)
		for _ = 1, math.ceil(Inv.SETTLE_MAX / 1) + 1 do
			A.Put(0, 15, Fixtures.JUNK, 1)
			flushAll()
			A.Advance(0.5)
			A.Clear(0, 15)
			flushAll()
			A.Advance(0.5)
		end
		assert.falsy(Inv.settling)
		A.Put(0, 12, Fixtures.HERB, 3)
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 12))
	end)

	-- Fix round 1, item 1: a "known" secret slot (loot in a key) that reads empty for a moment during the settle
	-- after zoning out keeps its marker. Mutation: in Inventory.ScanBag, clear Inv.hidden[k] on every readable
	-- read (`if not secret then`), as in dfaa81e.
	it("loot taken while secret that reads empty for a moment while zoning out is unseen when it reads", function()
		SB.Emit("SB_LOGIN")
		Fixtures.Settle(SB)
		A.Put(0, 12, Fixtures.HERB, 4, { secretID = true })
		flushAll()
		enterWorld(false, false)
		local loot = A.slots[0][12]
		A.slots[0][12] = nil -- the loading screen: the slot reads empty
		flushAll()
		loot.secretID = nil
		A.slots[0][12] = loot
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 12))
		assert.truthy(Inv.IsNew(0, 12))
	end)

	-- A "base" marker kept through an empty read does not outlive the settle: later loot into that slot arrives.
	-- Mutation: in Inv.EndSettle, drop the loop that forgets the markers of slots held through an empty read.
	it("a slot secret at login that reads empty during the settle takes real loot afterwards", function()
		A.slots[0][1].secretID = true
		SB.Emit("SB_LOGIN")
		enterWorld(true, false)
		A.slots[0][1] = nil -- the potions are gone (read empty) during the settle
		flushAll()
		settle()
		A.Put(0, 1, Fixtures.HERB, 2)
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 1))
	end)

	-- Item 2: each flush during the settle waits SETTLE_QUIET again. Mutation: in Inventory.Flush, delete the
	-- Inv.Quiet() call.
	it("the settle waits for the bags to be quiet: a flush restarts the wait", function()
		SB.Emit("SB_LOGIN")
		enterWorld(true, false)
		local restore = hideBackpack()
		A.Advance(2.5)
		flushAll() -- still empty
		A.Advance(2.5) -- 5 s after the world loaded, 2.6 s after the last flush
		assert.truthy(Inv.settling)
		restore()
		flushAll()
		assert.equal(0, unseenCount())
	end)

	-- Item 2: a quiet timer from an earlier settle does not end a newer one. Mutation: in Inv.Quiet, drop the
	-- `gen == settleGen` check.
	it("a quiet timer from an earlier settle does not end a newer settle", function()
		SB.Emit("SB_LOGIN")
		enterWorld(true, false)
		A.Advance(2)
		enterWorld(false, false) -- another loading screen
		A.Advance(1.5) -- the first settle's timer has fired
		assert.truthy(Inv.settling)
		local restore = hideBackpack()
		flushAll()
		restore()
		flushAll()
		assert.equal(0, unseenCount())
	end)

	-- Item 2: if the world never loads, the login settle ends SETTLE_LOGIN_MAX after the login scan.
	-- Mutation: in Inv.Settle, use math.huge instead of Inv.SETTLE_LOGIN_MAX.
	it("without PLAYER_ENTERING_WORLD the login settle ends at its cap", function()
		SB.Emit("SB_LOGIN")
		A.Advance(Inv.SETTLE_LOGIN_MAX - 1)
		A.Put(0, 12, Fixtures.HERB, 3)
		flushAll()
		assert.falsy(Inv.IsUnseen(0, 12), "still the login settle")
		A.Advance(2)
		A.Put(0, 13, Fixtures.JUNK, 1)
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 13))
	end)

	-- Item 3: outside a settle, a flush that would bring in more than half the stacks now in the bags, and at least
	-- FLOOD_MIN of them, is the client's late data: it marks nothing. Mutation: in markUnseen, drop the flood guard.
	local function fillBag(bag, size, n, id)
		A.SetBagSize(bag, size)
		for slot = 1, n do
			A.Put(bag, slot, id, 1)
		end
	end

	it("late login data after the settle: a flush that fills most of the bags marks nothing", function()
		fillBag(2, 30, 30, Fixtures.ORE)
		local saved1, saved2 = A.slots[1], A.slots[2]
		A.slots[1], A.slots[2] = {}, {}
		SB.Emit("SB_LOGIN")
		Fixtures.Settle(SB)
		A.slots[1], A.slots[2] = saved1, saved2 -- 32 of 38 stacks read only now
		flushAll()
		assert.equal(0, unseenCount())
		assert.equal(0, newCount())
		A.Put(0, 12, Fixtures.HERB, 3)
		flushAll()
		assert.truthy(Inv.IsUnseen(0, 12), "the next real loot still arrives")
	end)

	it("a 20-stack mailbox Take-All into well-filled bags still arrives", function()
		fillBag(2, 30, 30, Fixtures.ORE) -- 38 stacks
		fillBag(3, 30, 0, Fixtures.ORE)
		SB.Emit("SB_LOGIN")
		Fixtures.Settle(SB)
		for slot = 1, 20 do
			A.Put(3, slot, Fixtures.HERB, 1)
		end
		flushAll() -- 20 of 58 stacks: not more than half
		assert.equal(20, unseenCount())
	end)

	-- Item 4: the `new` keyword keeps an item through a settle like New does. Mutation: in markUnseen, drop the
	-- settle's new-keyword carry pool.
	it("zoning: an item new this session that reads empty and comes back is still new", function()
		SB.Emit("SB_LOGIN")
		Fixtures.Settle(SB)
		A.Put(0, 12, Fixtures.HERB, 4)
		flushAll()
		assert.truthy(Inv.IsNew(0, 12))
		enterWorld(false, false)
		local restore = hideBackpack()
		flushAll()
		assert.falsy(Inv.IsNew(0, 12))
		restore()
		flushAll()
		assert.truthy(Inv.IsNew(0, 12), "back, still new")
		assert.falsy(Inv.IsNew(0, 1), "what was there before is not")
	end)
end)

-- Inv.SeenAll (/swagbag new seen).
describe("Inventory: SeenAll", function()
	local SB, A, Inv
	before_each(function()
		SB = Loader.New(FILES)
		A, Inv = SB.Adapter, SB.Inventory
		Fixtures.SmallBags(A)
		A.SetBagSize(1, 4)
		A.Put(1, 1, Fixtures.HERB, 20)
		A.Put(1, 2, Fixtures.BOE_RING, 1)
	end)

	local function fire(event, ...)
		SB.eventFrame:Fire(event, ...)
	end

	local function flushAll()
		for _, bag in ipairs(A.GetBagIDs("bags")) do
			fire("BAG_UPDATE", bag)
		end
		fire("BAG_UPDATE_DELAYED")
		A.Advance(0.1)
	end

	-- Mutations: in Inv.SeenAll, drop `Inv.unseen = {}`; drop the ClearNewItems call; clear newSet for every bag.
	it("SeenAll marks every unseen item seen, clears the bags' new keyword and the client's flags", function()
		SB.Emit("SB_LOGIN")
		Fixtures.Settle(SB)
		A.Put(0, 12, Fixtures.HERB, 3)
		A.Put(0, 13, Fixtures.JUNK, 1)
		flushAll()
		Inv.newSet["13:1"] = true -- a bank slot's `new` stays
		assert.equal(2, Inv.SeenAll())
		assert.same({}, Inv.unseen)
		assert.same({ ["13:1"] = true }, Inv.newSet)
		assert.same(A.GetBagIDs("bags"), A.newClearedBags[#A.newClearedBags])
	end)
end)
