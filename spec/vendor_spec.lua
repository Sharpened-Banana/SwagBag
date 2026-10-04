-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 7 (user pick 4): at a vendor SwagBag sells gray junk (12 at most per vendor visit: Blizzard's buyback
-- keeps 12), never items in an equipment set, items to open or learn, gray BoE items worth more at auction
-- or items held by the client, then repairs with the player's gold (or the guild's, when chosen); nothing in
-- combat; one chat line says what was sold.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local GRAY, GRAY_BOE = 400200, 400201

describe("Vendor (week 7)", function()
	local SB, A, Mover
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Locks.lua"
		files[#files + 1] = "SwagBag/Engine/Collections.lua"
		files[#files + 1] = "SwagBag/Engine/Mover.lua"
		files[#files + 1] = "SwagBag/Engine/Vendor.lua"
		SB = Loader.New(files)
		A, Mover = SB.Adapter, SB.Mover
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- slot 6: Broken Tooth x3, gray
		A.items[Fixtures.JUNK].sellPrice = 1234 -- 12s 34c each
		A.AddItem(GRAY, { name = "Frayed Robe", classID = A.ITEM_CLASS.Armor, subclassID = 1, equipLoc = "INVTYPE_CHEST",
			quality = 0, ilvl = 5, maxStack = 1, bind = "none", sellPrice = 50 })
		A.money = 1000000
		A.collected.defaultLook = true -- gray gear here has a collected look unless a test says otherwise
		SB.Inventory.ScanAll()
	end)

	local function visit()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		A.Advance(Mover.DELAY * 30)
	end

	local function sold()
		local out = {}
		for _, u in ipairs(A.used) do
			if u.kind == "sell" then
				out[#out + 1] = u.slot
			end
		end
		return out
	end

	-- Mutations: Vendor.Protected ignores r.inEquipmentSet; Vendor.Junk drops `not r.isLocked`.
	it("sells gray junk a vendor pays for; never a set piece, an item the client holds, or one worth nothing", function()
		A.Put(0, 7, GRAY, 1, { inSet = true })
		A.Put(0, 8, GRAY, 1, { isLocked = true })
		A.Put(0, 9, GRAY, 1, { hasNoValue = true })
		A.Put(0, 10, GRAY, 1)
		SB.Inventory.ScanAll()
		assert.equal(2, #SB.Vendor.Junk(), "the set piece, the held robe and the worthless one are not listed")
		visit()
		assert.same({ 6, 10 }, sold())
		assert.same({ "Sold 2 junk items for 37s 52c." }, A.Lines(), "3 x 12s 34c + 50c, one chat line")
	end)

	-- Ruling R1: the 12 are per vendor visit, shared by the auto-sell, /swagbag sell junk and Sell all; past them
	-- a second /swagbag sell junk is the explicit yes. Mutations: in Vendor.Sell, `math.min(#list, room)` ->
	-- `#list`; or `local room = past and V.BUYBACK or V.Room()` -> `local room = V.BUYBACK` (a second sale in
	-- the visit would push the first out of the Buyback tab without asking); or the MERCHANT_SHOW handler
	-- keeps the count of the last visit.
	it("sells at most 12 per vendor visit (the buyback tab keeps 12); more needs a second, explicit yes", function()
		A.SetBagSize(1, 20)
		for slot = 1, 9 do
			A.Put(1, slot, GRAY, 1)
		end
		SB.Inventory.ScanAll()
		visit()
		assert.equal(10, #sold(), "the auto-sell: the Broken Tooth and 9 robes")
		for slot = 10, 15 do
			A.Put(1, slot, GRAY, 1)
		end
		SB.Inventory.ScanAll()
		SB.Slash.Dispatch("sell junk")
		A.Advance(Mover.DELAY * 10)
		assert.equal(12, #sold(), "2 more fit in the visit's 12")
		SB.Slash.Dispatch("sell junk")
		A.Advance(Mover.DELAY * 10)
		assert.equal(12, #sold(), "the visit's 12 are used: it asks first")
		SB.Slash.Dispatch("sell junk")
		A.Advance(Mover.DELAY * 10)
		assert.equal(16, #sold(), "the second yes sells the rest")
		assert.same({ "Sold 10 junk items for 41s 52c.", "Sold 2 junk items for 1s 0c. 4 more junk items wait: Blizzard's"
			.. " Buyback tab keeps only the last 12. Type /swagbag sell junk to sell them.", SB.L.VENDOR_PAST_JUNK:format(4),
			"Sold 4 junk items for 2s 0c." }, A.Lines())
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		SB.eventFrame:Fire("MERCHANT_SHOW")
		assert.equal(12, SB.Vendor.Room(), "a new visit: 12 again")
	end)

	-- P2: the command answers once, with the sale's line. Mutation: in Vendor.Visit, drop the vendor.autoSell check.
	it("auto-sell off: nothing is sold by itself; /swagbag sell junk sells at a vendor and refuses elsewhere", function()
		SB.Slash.Dispatch("sell off")
		visit()
		assert.same({}, sold())
		SB.Slash.Dispatch("sell junk")
		A.Advance(Mover.DELAY * 3)
		assert.same({ 6 }, sold())
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		SB.Slash.Dispatch("sell junk")
		assert.same({ SB.L.VENDOR_SELL_OFF, "Sold 1 junk item for 37s 2c.",
			SB.L.VENDOR_NOT_OPEN }, A.Lines())
	end)

	-- Mutation: in Vendor.Repair, skip the `money < cost` check (the call would fail at the vendor).
	it("repairs with your gold after the sale; says when gold is short; Off repairs nothing", function()
		A.repairCost = 52000
		visit()
		assert.same({ "own" }, A.repairs)
		assert.same({ "Sold 1 junk item for 37s 2c.", "Repaired everything for 5g 20s 0c." }, A.Lines())
		A.money = 100
		A.Put(0, 6, Fixtures.JUNK, 1)
		A.repairCost = 52000
		A.printed = {}
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		visit()
		assert.same({ "own" }, A.repairs, "no second repair")
		assert.equal("Repairs cost 5g 20s 0c, more than you carry, so nothing was repaired.", A.Lines()[2])
		SB.Slash.Dispatch("repair off")
		A.money = 1000000
		visit()
		assert.same({ "own" }, A.repairs)
	end)

	-- Review fix 1. Mutation: in repairSafely, call repairNow() at once (no SB.OutOfCombat).
	it("a sale stopped by combat repairs only after combat, and only if the vendor is still open", function()
		for slot = 7, 9 do
			A.Put(0, slot, GRAY, 1)
		end
		SB.Inventory.ScanAll()
		A.repairCost = 52000
		SB.eventFrame:Fire("MERCHANT_SHOW")
		A.combat = true
		A.Advance(Mover.DELAY * 5)
		assert.same({}, A.repairs, "no repair in combat")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.same({ "own" }, A.repairs, "repaired once combat ended")
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		-- the vendor closes while combat holds the repair back
		A.repairCost = 52000
		A.Put(0, 6, Fixtures.JUNK, 1)
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		A.combat = true
		A.Advance(Mover.DELAY * 5)
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.same({ "own" }, A.repairs, "closed vendor: no repair")
	end)

	-- Week 9 (preflight S6): the stacker and the mover never run at once, so a vendor opened during a stacking
	-- run waits for it instead of skipping the sale in silence (P2). Mutations: drop the Stacker.Busy() check in
	-- V.Visit; or the SB_STACKER_DONE listener's V.Visit() call.
	it("a vendor opened during a stacking run sells the junk and repairs once the run ends, if still open", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Stacker.lua")
		A.Put(0, 7, Fixtures.HEALING_POTION, 2) -- slot 1 holds 5: one merge to make
		SB.Inventory.ScanAll()
		A.repairCost = 52000
		assert.truthy(SB.Stacker.Start({ kind = "bags" }))
		SB.eventFrame:Fire("MERCHANT_SHOW")
		assert.same({}, sold(), "the stacker is moving items: the visit waits")
		assert.same({}, A.repairs)
		A.Advance(SB.Stacker.DELAY)
		A.Advance(Mover.DELAY * 5)
		assert.same({ 6 }, sold())
		assert.same({ "own" }, A.repairs)
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		-- the vendor closes before the run ends: nothing happens later
		A.Put(0, 8, Fixtures.HEALING_POTION, 2)
		A.Put(0, 9, GRAY, 1)
		SB.Inventory.ScanAll()
		assert.truthy(SB.Stacker.Start({ kind = "bags" }))
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		A.Advance(SB.Stacker.DELAY * 3)
		A.Advance(Mover.DELAY * 5)
		assert.same({ 6 }, sold())
		assert.same({ "own" }, A.repairs)
	end)

	-- Review fix 2. Mutation: in V.Repair, `local room = limit < 0 and balance or math.min(limit, balance)` ->
	-- `local room = limit < 0 and cost or limit`; in repairResult drop the `after > 0` branch.
	it("guild repair needs the guild bank to hold the cost; the line says whose gold paid; an unfinished repair says so", function()
		SB.Slash.Dispatch("repair guild")
		SB.Slash.Dispatch("sell off")
		local L = SB.L
		local function run(limit, balance)
			A.repairCost, A.guildRepair, A.guildBalance, A.repairs, A.printed = 52000, limit, balance, {}, {}
			SB.eventFrame:Fire("MERCHANT_CLOSED")
			visit()
			return A.repairs, A.Lines()
		end
		local repairs, lines = run(-1, 100)
		assert.same({ "own" }, repairs, "no limit but a poor guild bank")
		assert.same({ L.VENDOR_REPAIRED_OWN_GUILD:format("5g 20s 0c") }, lines)
		repairs = run(100, 1000000)
		assert.same({ "own" }, repairs, "the limit is too low")
		repairs = run(-1, nil)
		assert.same({ "own" }, repairs, "an unknown balance is no guild money")
		repairs, lines = run(60000, 70000)
		assert.same({ "guild" }, repairs)
		assert.same({ "Repaired everything for 5g 20s 0c from the guild bank." }, lines)
		A.repairStays = true
		lines = select(2, run(-1, 1000000))
		assert.same({ L.VENDOR_REPAIR_UNFINISHED }, lines, "gear still needs repair after the call")
		A.repairStays = nil
	end)

	-- Review fix 3. Mutation: in soldLine, drop the `n == 0` early return.
	it("a run where every item was skipped says nothing", function()
		local hovered = true
		SB.BagsWindow = { IsOpen = function() return true end, ButtonBusy = function() return hovered end }
		SB.eventFrame:Fire("MERCHANT_SHOW") -- the Broken Tooth waits: the mouse rests on it
		A.slots[0][6].inSet = true -- and is put in a set meanwhile
		hovered = false
		A.Advance(Mover.DELAY * 5)
		assert.same({}, sold())
		assert.same({}, A.Lines())
	end)

	-- Mutation: in Vendor.Repair, drop the guild branch.
	it("Guild bank first: the guild pays when it allows enough (or has no limit), else your gold", function()
		SB.Slash.Dispatch("repair guild")
		A.repairCost = 52000
		A.guildRepair, A.guildBalance = -1, 1000000
		SB.Slash.Dispatch("sell off")
		visit()
		A.guildRepair, A.repairCost = 100, 52000 -- not enough today
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		visit()
		assert.same({ "guild", "own" }, A.repairs)
		local lines = A.Lines()
		assert.equal("Repaired everything for 5g 20s 0c from the guild bank.", lines[3])
		assert.equal(SB.L.VENDOR_REPAIRED_OWN_GUILD:format("5g 20s 0c"), lines[4])
	end)

	-- Mutation: in Vendor.Visit, drop the A.InCombat() branch.
	it("a vendor opened in combat sells and repairs once combat ends, only if it is still open", function()
		A.combat = true
		A.repairCost = 100
		SB.eventFrame:Fire("MERCHANT_SHOW")
		assert.same({}, sold())
		assert.same({ SB.L.VENDOR_COMBAT }, A.Lines())
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		A.Advance(Mover.DELAY * 3)
		assert.same({ 6 }, sold())
		assert.same({ "own" }, A.repairs)
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		A.Put(0, 6, Fixtures.JUNK, 1)
		A.combat = true
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		A.Advance(Mover.DELAY * 3)
		assert.same({ 6 }, sold(), "the vendor closed during combat: nothing more")
	end)

	-- Ruling R9 (P2: an automatic action with nothing to do says nothing). Mutation: in Vendor.Visit, drop the
	-- `if work() then` around the combat line.
	it("a vendor opened in combat with nothing to sell or repair says nothing", function()
		A.Clear(0, 6)
		SB.Inventory.ScanAll()
		A.combat = true
		SB.eventFrame:Fire("MERCHANT_SHOW")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		A.Advance(Mover.DELAY * 3)
		assert.same({}, A.Lines())
	end)

	-- Mutation: in Vendor.lua, drop `closed = "VENDOR_STOP_CLOSED", ` from STOP_LINES.
	it("a vendor closed mid-run: the line says how many sold and how many stayed", function()
		for slot = 7, 9 do
			A.Put(0, slot, GRAY, 1)
		end
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		A.Advance(Mover.DELAY * 5)
		assert.same({ 6 }, sold())
		assert.same({ "Sold 1 junk item for 37s 2c. The vendor closed, so 3 stayed in your bags." }, A.Lines())
	end)

	-- Ruling R8: the line counts what really stayed. Mutation: in soldLine, `L[stop]:format(result.left)` ->
	-- `L[stop]:format(result.left + result.skipped)` (an item used by hand would count as stayed).
	it("the line never says 0 stayed, and an item used by hand during the run does not count as stayed", function()
		SB.eventFrame:Fire("MERCHANT_SHOW") -- the Broken Tooth sells at once
		SB.eventFrame:Fire("MERCHANT_CLOSED") -- in the same 0.2 s: it was the last one
		A.Advance(Mover.DELAY * 3)
		for slot = 7, 9 do
			A.Put(0, slot, GRAY, 1)
		end
		A.Put(0, 6, Fixtures.JUNK, 1)
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("MERCHANT_SHOW") -- slot 6 sells at once
		A.Clear(0, 7) -- the first robe is used up by hand
		A.Advance(Mover.DELAY) -- the robe in slot 8 sells
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		A.Advance(Mover.DELAY * 3)
		assert.same({ "Sold 1 junk item for 37s 2c.",
			"Sold 2 junk items for 12s 84c. The vendor closed, so 1 stayed in your bags." }, A.Lines())
	end)

	-- Ruling R2: right before each sale the slot is checked again. Mutation: in sellable(), drop
	-- `or V.Protected(r)` (an item put in a set during the run would still be sold).
	it("an item that becomes protected during the run (here: put in an equipment set) is skipped, never sold", function()
		A.Put(0, 7, GRAY, 1)
		A.Put(0, 8, GRAY, 1)
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("MERCHANT_SHOW") -- slot 6 sells at once; the robes wait their turn
		A.slots[0][7].inSet = true
		A.Advance(Mover.DELAY * 10)
		assert.same({ 6, 8 }, sold())
		assert.same({ "Sold 2 junk items for 37s 52c." }, A.Lines())
	end)

	-- Ruling R19 (gold-maker safety). Mutations: Vendor.Protected ignores Collections.Learn; or in
	-- worthMoreAtAuction `ah > 2 *` -> `ah > 1 *` (a gray BoE worth a little more at auction would stay).
	it("never sells an item to open or learn, or a gray BoE worth more than twice its vendor price at auction", function()
		A.AddItem(GRAY_BOE, { name = "Rusted Sabre", classID = A.ITEM_CLASS.Weapon, subclassID = 7,
			equipLoc = "INVTYPE_WEAPON", quality = 0, ilvl = 5, maxStack = 1, bind = "equip", sellPrice = 100 })
		A.AddItem(GRAY_BOE + 1, { name = "Bent Sabre", classID = A.ITEM_CLASS.Weapon, subclassID = 7,
			equipLoc = "INVTYPE_WEAPON", quality = 0, ilvl = 5, maxStack = 1, bind = "equip", sellPrice = 100 })
		A.Put(0, 7, GRAY, 1, { hasLoot = true }) -- something to open
		A.Put(0, 8, GRAY_BOE, 1) -- 5s at auction, 1s at a vendor
		A.Put(0, 9, GRAY_BOE + 1, 1) -- 1s 50c at auction: not worth the trip
		A.auctionator = { prices = { ["item:" .. GRAY_BOE] = 500, ["item:" .. (GRAY_BOE + 1)] = 150 } }
		SB.Inventory.ScanAll()
		visit()
		assert.same({ 6, 9 }, sold())
	end)

	-- Week 9 (user pick 10, ruling R0): every loaded auction source is asked, and any one above twice keeps the
	-- item. Mutation: in P.AuctionValue, `best = math.max(best or v, v)` -> `best = best or v` (Auctionator's 150
	-- would decide).
	it("a gray BoE stays when TSM prices it above twice its vendor price, even while Auctionator answers less", function()
		Loader.LoadFile(SB, "SwagBag/Providers/TSM.lua")
		A.AddItem(GRAY_BOE, { name = "Rusted Sabre", classID = A.ITEM_CLASS.Weapon, subclassID = 7,
			equipLoc = "INVTYPE_WEAPON", quality = 0, ilvl = 5, maxStack = 1, bind = "equip", sellPrice = 100 })
		A.Put(0, 8, GRAY_BOE, 1)
		A.auctionator = { prices = { ["item:" .. GRAY_BOE] = 150 } }
		A.tsm = { prices = { DBMarket = { ["item:" .. GRAY_BOE] = 900 } } }
		SB.Inventory.ScanAll()
		visit()
		assert.same({ 6 }, sold())
	end)

	-- Ruling R0 (gold-maker safety): the protection does not follow the price source. Mutation: in
	-- worthMoreAtAuction, `SB.Prices.AuctionValue(r.link, r.itemID)` -> `SB.Prices.Value(r.link, r.itemID, false)`.
	it("with Vendor chosen, a gray BoE Auctionator prices above twice its vendor price stays; with no auction addon it sells", function()
		A.AddItem(GRAY_BOE, { name = "Rusted Sabre", classID = A.ITEM_CLASS.Weapon, subclassID = 7,
			equipLoc = "INVTYPE_WEAPON", quality = 0, ilvl = 5, maxStack = 1, bind = "equip", sellPrice = 100 })
		A.Put(0, 8, GRAY_BOE, 1)
		A.auctionator = { prices = { ["item:" .. GRAY_BOE] = 500 } }
		SB.Config.Set("prices.source", "vendor")
		assert.same({ 100, "Vendor" }, { SB.Prices.Value("item:" .. GRAY_BOE, GRAY_BOE) }, "the windows show the vendor's")
		SB.Inventory.ScanAll()
		visit()
		assert.same({ 6 }, sold())
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		A.auctionator = nil
		SB.Prices.Invalidate()
		visit()
		assert.same({ 6, 8 }, sold())
	end)

	-- Ruling R19: a gray piece whose look the account lacks is a transmog, not junk. Mutation: Vendor.Protected
	-- drops `or SB.Collections.Uncollected(r) ~= nil`.
	it("never sells gray gear whose look the account has not collected", function()
		A.Put(0, 7, GRAY, 1, { link = "item:400200::look" })
		A.Put(0, 8, GRAY, 1)
		A.collected.looks["item:400200::look"] = false
		A.collected.looks["item:400200"] = true
		SB.Inventory.ScanAll()
		visit()
		assert.same({ 6, 8 }, sold())
	end)

	-- Final review fix 1. Mutations: Collections.LookUnknown always false (an unknown look sells); or the
	-- Vendor.Protected clause for it is dropped; or LookUnknown caches its answer.
	it("gray gear whose look the client cannot say is kept; 'cannot collect' and a collected look sell; never cached", function()
		A.Put(0, 7, GRAY, 1, { link = "item:400200::a" })
		A.Put(0, 8, GRAY, 1, { link = "item:400200::b" })
		A.Put(0, 9, GRAY, 1, { link = "item:400200::c" })
		A.Put(0, 10, GRAY, 1, { link = "item:400200::d" })
		A.collected.looks["item:400200::a"] = "unknown"
		A.collected.looks["item:400200::b"] = "cannot"
		A.collected.looks["item:400200::c"] = true
		A.collected.looks["item:400200::d"] = false
		SB.Inventory.ScanAll()
		local function protected(slot)
			return SB.Vendor.Protected(SB.Items.Describe(0, slot))
		end
		assert.same({ true, false, false, true }, { protected(7), protected(8), protected(9), protected(10) })
		assert.is_nil(SB.Collections.Uncollected(SB.Items.Describe(0, 7)), "unknown: no star")
		A.collected.looks["item:400200::a"] = true -- the client learns the answer: asked again
		assert.falsy(protected(7))
		A.collected.looks["item:400200::a"] = "unknown"
		assert.truthy(protected(7), "an unknown answer is not remembered either way")
		visit()
		assert.same({ 6, 8, 9 }, sold())
	end)

	-- Week 8 (week-7 re-review minor): a ring, necklace or trinket has no look at all, so a gray one is junk
	-- again; other gray gear the client cannot say about stays. Mutation: in Collections.LookUnknown, drop
	-- `or Coll.NO_LOOK[r.equipLoc or ""]`.
	it("gray rings, necklaces and trinkets have no look: sold as junk; a gray robe the client cannot say about stays",
		function()
			for i, loc in ipairs({ "INVTYPE_FINGER", "INVTYPE_NECK", "INVTYPE_TRINKET" }) do
				A.AddItem(400300 + i, { name = "Dull Bauble " .. i, classID = A.ITEM_CLASS.Armor, subclassID = 0,
					equipLoc = loc, quality = 0, ilvl = 5, maxStack = 1, bind = "none", sellPrice = 30 })
				A.Put(0, 6 + i, 400300 + i, 1)
			end
			A.Put(0, 10, GRAY, 1)
			A.collected.defaultLook = nil -- the client has no source for any of them
			SB.Inventory.ScanAll()
			visit()
			assert.same({ 6, 7, 8, 9 }, sold())
			assert.truthy(SB.L.VENDOR_KEEPS:find("cannot tell", 1, true), "what is kept says so")
		end)

	-- Week 8 (controller ruling Q2). A gray robe has an appearance slot, so a link the client hid (secret) or
	-- that is missing is no answer, and the robe stays. Mutation: in Collections.LookUnknown,
	-- `if not link then return true end` -> `return false`, both draw (fast) and sell paths.
	it("a gray robe whose link is secret or missing is not sold (no answer is not 'cannot collect')", function()
		local secretLink = "item:400200::secret"
		A.Put(0, 7, GRAY, 1, { link = secretLink })
		A.Put(0, 8, GRAY, 1)
		SB.Inventory.ScanAll()
		A.IsSecret = function(v) return v == secretLink end
		local secret, missing = SB.Items.Describe(0, 7), SB.Items.Describe(0, 8)
		missing.link = nil
		for _, fast in ipairs({ false, true }) do
			assert.truthy(SB.Vendor.Protected(secret, fast), "secret link, fast=" .. tostring(fast))
			assert.truthy(SB.Vendor.Protected(missing, fast), "missing link, fast=" .. tostring(fast))
		end
	end)

	-- Week 8 (controller ruling Q5). Uncollected's gear branch reads the link through plain(): a secret link
	-- is no answer (no star), never an error, and never reaches the client. Mutation: in Collections.Uncollected,
	-- `local link = plain(r.link)` -> `local link = r.link`.
	it("Uncollected reads a gear link only when it is not secret: no star, no client call", function()
		local secretLink = "item:400200::secret"
		A.Put(0, 7, GRAY, 1, { link = secretLink })
		SB.Inventory.ScanAll()
		A.IsSecret = function(v) return v == secretLink end
		A.collected.looks[secretLink] = false -- would star, if it were read
		local r = SB.Items.Describe(0, 7)
		local before = A.collectionCalls
		assert.is_nil(SB.Collections.Uncollected(r))
		assert.equal(before, A.collectionCalls)
	end)

	-- Week 8 (week-7 re-review minor: Protected on the draw path). Mutation: in Collections.LookUnknown, drop
	-- the `if fast then ... end` branch (every draw of a gray piece would ask the client again).
	it("a draw asks the client about a gray piece's look once per link; every sale check asks again", function()
		A.Put(0, 7, GRAY, 1, { link = "item:400200::a" })
		A.collected.looks["item:400200::a"] = "unknown"
		SB.Inventory.ScanAll()
		local r = SB.Items.Describe(0, 7)
		local before = A.collectionCalls
		for _ = 1, 3 do
			assert.truthy(SB.Vendor.Protected(r, true))
		end
		assert.equal(before + 1, A.collectionCalls, "three draws, one question")
		assert.truthy(SB.Vendor.Protected(r))
		assert.truthy(SB.Vendor.Protected(r))
		assert.equal(before + 3, A.collectionCalls, "the sell path never trusts a cached unknown")
	end)

	-- Week 7 (user pick 5). Mutation: Vendor.Protected ignores SB.Locks.
	it("a locked junk item is never sold, by auto-sell or by /swagbag sell junk", function()
		A.Put(0, 7, GRAY, 1)
		SB.Inventory.ScanAll()
		SB.Locks.Toggle(Fixtures.JUNK)
		visit()
		assert.same({ 7 }, sold())
		SB.Slash.Dispatch("sell junk")
		assert.same({ 7 }, sold())
		assert.equal(SB.L.VENDOR_NO_JUNK, A.Lines()[2])
	end)

	-- Week 7: SwagBag cannot stop Blizzard's own right-click sale, so it says so at once. Mutations: drop
	-- the inBuyback check (an item merely moved would warn); or skip V.WatchLocked on MERCHANT_SHOW.
	it("a locked item sold by hand (it left the bags and is in the buyback tab) gets one warning", function()
		SB.Slash.Dispatch("sell off")
		SB.Locks.Toggle(Fixtures.BOE_RING)
		SB.Locks.Toggle(Fixtures.FLASK)
		visit()
		A.printed = {}
		A.Clear(0, 2) -- the flask moved elsewhere (not in the buyback)
		A.Clear(0, 3) -- the ring was sold by right-click
		A.buyback = { "item:225001::upgradable" }
		SB.Inventory.MarkDirty(0)
		SB.Inventory.Flush("test")
		assert.same({ "You sold Band of the Fallen, which you locked. Buy it back from the vendor's Buyback tab if that"
			.. " was a mistake." }, A.Lines())
	end)

	-- Ruling R2: a lock set while the item waits its turn stops its sale. Mutation: Vendor.Protected ignores
	-- SB.Locks.
	it("an item locked during the run (dropped on Lock while it waits its turn) is never sold", function()
		A.Put(0, 7, GRAY, 1)
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("MERCHANT_SHOW") -- slot 6 sells at once; the robe waits its turn
		SB.Locks.Toggle(GRAY)
		A.Advance(Mover.DELAY * 10)
		assert.same({ 6 }, sold())
		assert.same({ "Sold 1 junk item for 37s 2c." }, A.Lines())
	end)

	-- P6 (ruling R15). Mutation: the locked-item listener's trap window `end, "none"))` -> `end, "bags"))`.
	it("a failure in the locked-item watch is recorded under none, never Safe Mode", function()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		local real = SB.Vendor.WatchLocked
		SB.Vendor.WatchLocked = function()
			error("boom")
		end
		SB.Inventory.Notify(SB.Inventory.R.ITEM, {})
		SB.Vendor.WatchLocked = real
		local e = SB.ErrorTrap.Recent()[1]
		assert.same({ "vendor.inventory", "none" }, { e.label, e.window })
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	-- P2, ruling R18 (the state names the choice as the settings window does). Mutations: /swagbag repair accepts
	-- any word; or the state line prints the stored word (`L[REPAIR_NAMES[mode] or REPAIR_NAMES.own]` ->
	-- `tostring(mode)`).
	it("/swagbag sell and /swagbag repair answer every form; read-only settings refuse", function()
		SB.Slash.Dispatch("sell")
		SB.Slash.Dispatch("sell maybe")
		SB.Slash.Dispatch("repair")
		SB.Slash.Dispatch("repair sometimes")
		SB.Config.readOnly = true
		SB.Slash.Dispatch("repair off")
		SB.Slash.Dispatch("sell off")
		local L = SB.L
		assert.same({ L.VENDOR_SELL_STATE:format("on"), L.VENDOR_SELL_USAGE, L.VENDOR_REPAIR_STATE:format("Your gold"),
			L.VENDOR_REPAIR_USAGE, L.SETTINGS_READONLY, L.SETTINGS_READONLY }, A.Lines())
		assert.equal("own", SB.Config.Get("vendor.repair"))
	end)
end)

describe("Settings: vendor page (week 7)", function()
	local SB, SW, ran
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		SB.Config.Init(nil, nil)
		Fake.Install()
		ran = {}
		for _, name in ipairs({ "sell", "repair", "lock" }) do
			SB.Slash.Register(name, "test", function(arg)
				ran[#ran + 1] = name .. " " .. arg
				return "ran " .. name .. " " .. arg
			end)
		end
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/Engine/Locks.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsVendor.lua")
		SW = SB.SettingsWindow
		SW.Show("vendor")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- P1 / P2. Mutation: in the repair row's apply, always run "repair own".
	it("defaults first (On; Your gold), each click runs the command and answers in the status line", function()
		local shown = {}
		for i = 1, SW.used.buttons do
			shown[i] = { SW.buttons[i].text, SW.selected[SW.buttons[i]] == true }
		end
		assert.same({ { "On", true }, { "Off", false }, { "Your gold", true }, { "Guild bank first", false },
			{ "Off", false }, { "Drop an item here", false }, { "List them", false }, { "Unlock all", false } }, shown)
		Fake.Fire(SW.buttons[2], "OnClick")
		Fake.Fire(SW.buttons[4], "OnClick")
		assert.same({ "sell off", "repair guild" }, ran)
		assert.equal("ran repair guild", SW.lastStatus)
	end)

	-- Week 7 (user pick 5). Mutation: in lockDrop, drop the DROP_ECHO check (the click half of the press
	-- would replace the answer with "Pick up an item first").
	it("the lock drop row locks the item on the cursor; the click half of the same press keeps the answer", function()
		local A = SB.Adapter
		Fixtures.Install(A)
		Loader.LoadFile(SB, "SwagBag/UI/LockButton.lua")
		local drop
		for i = 1, SW.used.buttons do
			if SW.buttons[i].text == SB.L.SET_LOCK_DROP then
				drop = SW.buttons[i]
			end
		end
		A.cursor = { itemID = Fixtures.FLASK, link = "item:212283" }
		Fake.Fire(drop, "OnReceiveDrag")
		Fake.Fire(drop, "OnClick")
		assert.truthy(SB.Locks.Has(Fixtures.FLASK))
		assert.equal(SB.L.LOCK_ADDED:format("Flask of Alchemical Chaos"), SW.lastStatus)
		A.Advance(1)
		Fake.Fire(drop, "OnClick")
		assert.equal(SB.L.SET_WATCH_DROP_EMPTY, SW.lastStatus)
	end)

	-- Final review fix 2. Mutation: the page's Unlock all button runs "lock clear" straight to Locks.Clear.
	it("Unlock all asks first; the second press within 10 seconds unlocks; each press answers once", function()
		local A = SB.Adapter
		Fixtures.Install(A)
		SB.Locks.Toggle(Fixtures.FLASK)
		local unlock
		for i = 1, SW.used.buttons do
			if SW.buttons[i].text == SB.L.SET_LOCK_CLEAR then
				unlock = SW.buttons[i]
			end
		end
		Fake.Fire(unlock, "OnClick")
		assert.same({ true, SB.L.LOCK_CLEAR_ASK_ONE }, { SB.Locks.Has(Fixtures.FLASK), SW.lastStatus })
		Fake.Fire(unlock, "OnClick")
		assert.same({ false, SB.L.LOCK_CLEARED_ONE }, { SB.Locks.Has(Fixtures.FLASK), SW.lastStatus })
	end)

	-- Ruling R17. Mutation: the page's SB_LOCKS_CHANGED listener never re-draws (`if SW.IsOpen() then` ->
	-- `if false then`).
	it("Locked items: N follows a lock made anywhere while the page is open", function()
		local function count()
			for i = 1, SW.used.labels do
				local n = (SW.labels[i].text or ""):match("^Locked items: (%d+)$")
				if n then
					return tonumber(n)
				end
			end
		end
		assert.equal(0, count())
		SB.Locks.Toggle(Fixtures.FLASK)
		assert.equal(1, count())
	end)
end)
