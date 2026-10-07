-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The bank window's contents (spec F2): the Character bank and Warband bank groups over the
-- real engine and button pool, deposits and withdrawals while open (spec 4.3), the deposit
-- highlight, Sort per bank type, Reflow, its own search, and the first-open budget.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")
local Big = dofile("spec/fixtures/big.lua")

local function blizzardBank()
	local bf = Fake.New("Frame", UIParent)
	bf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	bf.TabSystem = Fake.New("Frame", bf)
	bf.TabSystem.tabs = { Fake.New("Button", bf.TabSystem), Fake.New("Button", bf.TabSystem) }
	return bf
end

describe("BankWindow contents", function()
	local SB, A, BW, B, bf
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		Fake.Install()
		Env.PaintGlobals()
		bf = blizzardBank()
		A.frames.BankFrame = bf
		A.activeBankType = "bank"
		BW = Env.LoadBank(SB)
		B = SB.Buttons
		SB.Emit("SB_LOGIN") -- the pool and the session scan; the bank reads 0 slots away from a banker
		Fixtures.Settle(SB) -- hotfix 0.11.1: the login settle is over, items can arrive
		A.SetBagSize(6, 8)
		A.SetBagSize(12, 8)
		A.Put(6, 1, Fixtures.HEALING_POTION, 5)
		A.Put(6, 2, Fixtures.HERB, 20)
		A.Put(12, 1, Fixtures.ORE, 10)
		A.Put(12, 2, Fixtures.BOE_RING, 1)
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function openBank()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
	end

	local function bankUpdate(bag)
		SB.eventFrame:Fire("BAG_UPDATE", bag)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
	end

	local function header(id)
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.sectionId == id then
				return h
			end
		end
	end

	local function countChurn()
		local H, n = SB.SectionHeaders, { acquired = 0, released = 0 }
		local acquire, release = H.Acquire, H.ReleaseAll
		H.Acquire = function(...) n.acquired = n.acquired + 1 return acquire(...) end
		H.ReleaseAll = function(...) n.released = n.released + 1 return release(...) end
		return n
	end

	local function labels()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.shown then
				out[#out + 1] = h.text.text
			end
		end
		return out
	end

	local function at(bag, slot)
		local p = B.Get(bag, slot).points
		p = p[#p]
		return { p[4], p[5] }
	end

	it("a bank visit shows Character bank on top and Warband bank below, each with its own sections", function()
		openBank()
		assert.same({ "- Character bank (2)  - right-clicked items land here", "- Warband bank (2)",
			"- New (0)", "- Consumables (1)", "- Herbs (1)", "- Free (6)",
			"- New (0)", "- BoE gear (1)", "- Ore (1)", "- Free (6)" }, labels())
		assert.truthy(B.Get(6, 1).shown)
		assert.equal(BW.child, B.frames[6].parent, "the bank tab's bag frame lives in the bank window")
		assert.equal(16, #BW.view.cells)
		assert.equal("open", BW.view.stats.lastLayoutReason)
	end)

	it("bank items get their overlays (the BoE ring's item level and badge)", function()
		SB.Config.Set("overlays.bind", true) -- the badge is off by default since week 6
		openBank()
		local r = SB.Overlays.regions[B.Get(12, 2)]
		assert.same({ "285", "BoE" }, { r.topLeft.text, r.bind.text })
	end)

	-- Fix round 1: the click only relabels. Mutation: v.Relabel() -> v.Layout("target") in BW.RefreshTarget.
	it("the group that receives deposits is tinted; a tab click moves the highlight to the other group", function()
		openBank()
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#bank").bg.calls.SetColorTexture)
		A.Put(6, 5, Fixtures.FLASK, 2) -- a deposit: one item in New
		bankUpdate(6)
		local before = { at(6, 1), at(6, 2), at(6, 5), at(12, 1), at(12, 2) }
		A.activeBankType = "warband"
		Fake.Fire(bf.TabSystem.tabs[2], "OnClick")
		A.Advance(0)
		assert.same(before, { at(6, 1), at(6, 2), at(6, 5), at(12, 1), at(12, 2) }, "a tab click moves nothing")
		assert.equal("open", BW.view.stats.lastLayoutReason, "no layout ran")
		assert.equal("- Character bank (3)", header("#bank").text.text)
		assert.equal("- Warband bank (2)  - right-clicked items land here", header("#warband").text.text)
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#warband").bg.calls.SetColorTexture)
	end)

	it("bank section headers show each category's total value (F10)", function()
		A.items[Fixtures.HERB].sellPrice = 1500
		A.auctionator = { prices = { ["item:" .. Fixtures.ORE] = 9000 } }
		SB.Prices.Invalidate()
		openBank()
		assert.equal("- Herbs (1) - 3g", header("bank:c_herbs").text.text, "20 herbs at the vendor price, no vendor label")
		assert.equal("- Ore (1) - 9g", header("warband:c_ore").text.text, "10 ore at 90s")
	end)

	it("new Auctionator prices update the bank headers in place (W3-36)", function()
		A.items[Fixtures.HERB].sellPrice = 1500
		openBank()
		local frameBefore = header("bank:c_herbs")
		local churn = countChurn()
		A.auctionator = { prices = { [A.GetSlot(6, 2).link] = 90000 } }
		A.auctionatorCallback()
		A.Advance(0.5)
		assert.equal("- Herbs (1) - 180g", header("bank:c_herbs").text.text)
		assert.equal(frameBefore, header("bank:c_herbs"))
		assert.same({ acquired = 0, released = 0 }, churn)
	end)

	-- Mutation: delete the `v.RefreshTotals()` call in the bank's BAG_UPDATE handler.
	it("a stack's count changing with nothing moving updates the bank header's total (F10)", function()
		A.items[Fixtures.HERB].sellPrice = 1500
		openBank()
		assert.equal("- Herbs (1) - 3g vendor", header("bank:c_herbs").text.text)
		local frameBefore, pool, stats = header("bank:c_herbs"), #SB.SectionHeaders.pool, BW.view.pos
		local churn = countChurn()
		A.Put(6, 2, Fixtures.HERB, 40)
		bankUpdate(6)
		assert.same({ acquired = 0, released = 0 }, churn)
		assert.equal("- Herbs (1) - 6g vendor", header("bank:c_herbs").text.text)
		assert.equal(frameBefore, header("bank:c_herbs"), "the same header frame, set in place")
		assert.equal(pool, #SB.SectionHeaders.pool, "nothing released or acquired")
		assert.equal(stats, BW.view.pos, "no layout ran, no redraw: the position table is the same")
	end)

	-- Week 8 (week-7 deferred: the top-% line was worked out before the bank's contents arrived). Mutations:
	-- delete the SB.Emit("SB_BANK_CHANGED") in the bank's BAG_UPDATE handler; or delete the Overlays'
	-- SB_BANK_CHANGED listener.
	it("'your top X %' is worked out again when the bank's contents change during the visit", function()
		SB.Config.Set("prices.worth", "top")
		SB.Config.Set("prices.worthTop", 10) -- three stacks: the most valuable one
		A.items[Fixtures.HERB].sellPrice = 1000 -- 20: 20000
		A.items[Fixtures.ORE].sellPrice = 100 -- 10: 1000
		A.items[Fixtures.HEALING_POTION].sellPrice = 100 -- 5: 500
		A.items[Fixtures.FLASK].sellPrice = 900000
		openBank()
		A.Advance(SB.Overlays.WORTH_DELAY)
		assert.equal(20000, SB.Overlays.worthMin, "the herbs")
		A.Put(6, 2, Fixtures.HERB, 40) -- a stack grows: nothing moves
		bankUpdate(6)
		A.Advance(SB.Overlays.WORTH_DELAY)
		assert.equal(40000, SB.Overlays.worthMin, "the bigger herb stack")
		A.Put(6, 5, Fixtures.FLASK, 1) -- a deposit
		bankUpdate(6)
		A.Advance(SB.Overlays.WORTH_DELAY)
		assert.equal(900000, SB.Overlays.worthMin, "the flask")
		assert.truthy(SB.Overlays.regions[B.Get(6, 5)].glow.shown)
	end)

	-- Controller ruling Q11. Mutation: in Overlays.RefreshWorth delete the
	-- `if onlyIfMoved and Ov.worthMin == before then return end` early return.
	it("a bank change that leaves the top-% line where it was does not redraw the windows; one that moves it does once", function()
		SB.Config.Set("prices.worth", "top")
		SB.Config.Set("prices.worthTop", 10)
		A.items[Fixtures.HERB].sellPrice = 1000 -- 20: 20000
		A.items[Fixtures.ORE].sellPrice = 100
		A.items[Fixtures.HEALING_POTION].sellPrice = 100
		A.items[Fixtures.FLASK].sellPrice = 900000
		openBank()
		A.Advance(SB.Overlays.WORTH_DELAY)
		assert.equal(20000, SB.Overlays.worthMin)
		local redraws = 0
		local refreshAll = SB.Overlays.RefreshAll
		SB.Overlays.RefreshAll = function(...)
			redraws = redraws + 1
			return refreshAll(...)
		end
		A.Put(6, 5, Fixtures.ORE, 1) -- a cheap deposit: the line stays
		bankUpdate(6)
		A.Advance(SB.Overlays.WORTH_DELAY)
		assert.equal(20000, SB.Overlays.worthMin, "the line did not move")
		assert.equal(0, redraws, "so no window was redrawn")
		A.Put(6, 6, Fixtures.FLASK, 1) -- a dear deposit: the line moves
		bankUpdate(6)
		A.Advance(SB.Overlays.WORTH_DELAY)
		assert.equal(900000, SB.Overlays.worthMin)
		assert.equal(1, redraws, "the windows were redrawn once")
		SB.Overlays.RefreshAll = refreshAll
	end)

	-- Controller ruling Q5. Mutation: in Overlays' SB_BANK_CHANGED listener delete
	-- `and SB.Config.Get("prices.worth") == "top"`.
	it("a fixed amount does not depend on the bank's contents: a bank change works nothing out again", function()
		SB.Config.Set("prices.worth", "gold")
		SB.Config.Set("prices.worthGold", 5)
		openBank()
		A.Advance(SB.Overlays.WORTH_DELAY)
		local calls = 0
		local refreshWorth = SB.Overlays.RefreshWorth
		SB.Overlays.RefreshWorth = function(...)
			calls = calls + 1
			return refreshWorth(...)
		end
		A.Put(6, 5, Fixtures.FLASK, 1)
		bankUpdate(6)
		A.Advance(SB.Overlays.WORTH_DELAY)
		assert.equal(0, calls, "no recomputation in fixed-gold mode")
		SB.Overlays.RefreshWorth = refreshWorth
	end)

	it("a deposit shows in that group's New; nothing else moves", function()
		openBank()
		local before = { at(6, 1), at(6, 2), at(12, 1), at(12, 2) }
		A.Put(6, 5, Fixtures.FLASK, 2) -- a bag item right-clicked into the character bank
		bankUpdate(6)
		assert.equal(header("bank:new").points[1][5] - 20, at(6, 5)[2], "first cell of New")
		assert.same(before, { at(6, 1), at(6, 2), at(12, 1), at(12, 2) })
		assert.equal("- Character bank (3)  - right-clicked items land here", header("#bank").text.text)
	end)

	-- The free slot's number on a button (nil: none), plan D19.
	local function number(bag, slot)
		local fs = B.freeCounts[B.Get(bag, slot)]
		return fs and fs.shown and tonumber(fs.text) or nil
	end

	it("a withdrawal leaves a placeholder in its group; the slot joins that group's free slots (its tile's number)",
		function()
			openBank()
			assert.same({ 6, 6 }, { number(6, 3), number(12, 3) }, "one tile per group: its first empty slot")
			A.Clear(6, 2)
			bankUpdate(6)
			assert.equal(1, #B.placeholdersInUse)
			assert.falsy(B.Get(6, 2).shown, "the emptied slot is a hidden free slot of the bank group")
			assert.equal("- Free (7)", header("bank:free").text.text)
			assert.same({ 7, 6 }, { number(6, 3), number(12, 3) })
			A.Clear(12, 2)
			bankUpdate(12)
			assert.equal(2, #B.placeholdersInUse)
			assert.equal("- Free (7)", header("warband:free").text.text, "the warband item went to the warband's Free")
			assert.same({ 7, 7 }, { number(6, 3), number(12, 3) })
		end)

	-- Week 6, user request 4: the free tile in the bank. Every tab of a group shares one tile (bank tabs
	-- are family "any", reagent-filtered tabs too: the client reports no bag family for them), in the
	-- character bank and the warband bank alike. Mutation: in GroupView's build(), pass
	-- `family = function(bag) return bag end` (one tile per tab).
	it("each group's tabs share one free tile with the group's number: character bank and warband bank", function()
		A.bagIDs.bank, A.bagIDs.warband = { 6, 7 }, { 12, 13 }
		A.SetBagSize(7, 4)
		A.SetBagSize(13, 4)
		SB.Buttons.EnsureBankTabs()
		openBank()
		assert.same({ 10, 10 }, { number(6, 3), number(12, 3) }, "6 + 4 free slots in each group, one number")
		for slot = 1, 4 do
			assert.falsy(B.Get(7, slot).shown, "the second character tab's empties are spares")
			assert.falsy(B.Get(13, slot).shown, "the second warband tab's empties are spares")
		end
		assert.equal("- Free (10)", header("warband:free").text.text)
	end)

	-- Plan D19. Mutations: delete `freeTile = function() ... end` from the bank's GroupView cfg; delete
	-- the bank window's SB_FREE_TILE_CHANGED handler.
	it("the bank follows bags.freeTile: one tile per group by default, every free slot after /swagbag free all",
		function()
			openBank()
			assert.same({ true, false }, { B.Get(6, 3).shown, B.Get(6, 4).shown })
			SB.Config.Set("bags.freeTile", false) -- what /swagbag free all does (Core/Commands.lua)
			SB.Emit("SB_FREE_TILE_CHANGED")
			for slot = 3, 8 do
				assert.truthy(B.Get(6, slot).shown, "bank slot " .. slot)
			end
			assert.is_nil(number(6, 3))
		end)

	it("Sort bank sorts the character bank and regroups after the bank settles; Sort warband sorts the warband", function()
		openBank()
		Fake.Fire(BW.sortBankButton, "OnClick")
		assert.same({ "bank" }, A.bankSorts)
		assert.equal(SB.L.SORT_STARTED, BW.frame.title.text)
		A.Put(6, 1, Fixtures.HERB, 20)
		A.Put(6, 2, Fixtures.HEALING_POTION, 5)
		bankUpdate(6)
		A.Advance(0.3)
		assert.equal("sort", BW.view.stats.lastLayoutReason)
		assert.equal(0, #B.placeholdersInUse)
		Fake.Fire(BW.sortWarbandButton, "OnClick")
		assert.same({ "bank", "warband" }, A.bankSorts)
	end)

	-- Week 9 (user pick 8): item safety. Mutations: in BW.Sort, skip the Stacker.SortButton branch; or start the
	-- stacker with kind "warband" for either button.
	it("with sort stacks, Sort bank stacks the character bank only; the warband bank is never touched", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Stacker.lua")
		SB.Config.Set("sort.mode", "stacks")
		A.Put(6, 3, Fixtures.HEALING_POTION, 4)
		A.Put(12, 3, Fixtures.ORE, 5)
		openBank()
		Fake.Fire(BW.sortBankButton, "OnClick")
		assert.same({}, A.bankSorts)
		assert.same({ { 6, 3, 6, 1 } }, A.stackMoves)
		assert.equal(SB.L.STACK_STARTED, BW.frame.title.text)
		A.Advance(SB.Stacker.DELAY)
		assert.same({ SB.L.STACK_DONE:format(1, 0) }, A.Lines())
		assert.equal("sort", BW.view.stats.lastLayoutReason)
		Fake.Fire(BW.sortWarbandButton, "OnClick")
		A.Advance(SB.Stacker.DELAY)
		assert.same({ 6, 3, 6, 1 }, A.stackMoves[1])
		assert.same({ 12, 3, 12, 1 }, A.stackMoves[2], "the warband bank's own ore, in the warband bank")
		assert.same({ 9, 15 }, { A.GetSlot(6, 1).count, A.GetSlot(12, 1).count })
	end)

	-- Week 9: the bank closing stops a stacking run, and the line says so even when the closed bank's slots read
	-- empty (preflight S4). Mutations: in the Sort button's still(), return true; or in Stacker's step, judge the
	-- move in flight before the stop (`if stop then` -> `if stop and not m then`).
	it("closing the bank stops stacking before the next move", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Stacker.lua")
		SB.Config.Set("sort.mode", "stacks")
		A.Put(6, 3, Fixtures.HEALING_POTION, 4)
		A.Put(6, 4, Fixtures.HERB, 5)
		openBank()
		Fake.Fire(BW.sortBankButton, "OnClick")
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		A.Advance(SB.Stacker.DELAY)
		assert.equal(1, #A.stackMoves)
		assert.same({ SB.L.STACK_STOP_CLOSED:format(1, 0) }, A.Lines())
		-- the same with the closed bank's slots reading empty, as the client may answer
		A.Put(6, 5, Fixtures.HERB, 2)
		openBank()
		Fake.Fire(BW.sortBankButton, "OnClick")
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		local get = A.GetSlot
		A.GetSlot = function(bag, slot)
			if bag >= 6 then
				return nil
			end
			return get(bag, slot)
		end
		A.Advance(SB.Stacker.DELAY)
		A.GetSlot = get
		assert.equal(2, #A.stackMoves)
		assert.equal(SB.L.STACK_STOP_CLOSED:format(0, 0), A.Lines()[2])
	end)

	it("a second Sort during a settle keeps the first sort's regroup; a sort that changes nothing stops waiting", function()
		openBank()
		Fake.Fire(BW.sortBankButton, "OnClick")
		A.Clear(6, 1)
		bankUpdate(6)
		Fake.Fire(BW.sortWarbandButton, "OnClick")
		A.Advance(BW.SORT_TIMEOUT + 0.1)
		assert.equal("sort", BW.view.stats.lastLayoutReason)
		assert.falsy(BW.sortPending)
		Fake.Fire(BW.sortBankButton, "OnClick")
		A.Advance(BW.SORT_TIMEOUT + 0.1)
		assert.falsy(BW.sortPending)
		BW.view.stats.lastLayoutReason = "marker"
		A.Put(6, 7, Fixtures.JUNK, 1)
		bankUpdate(6)
		A.Advance(1)
		assert.equal("marker", BW.view.stats.lastLayoutReason, "no regroup after the sort timed out")
	end)

	it("sorting in combat shows feedback and does nothing, now or after combat (W11)", function()
		openBank()
		A.combat = true
		Fake.Fire(BW.sortBankButton, "OnClick")
		assert.same({}, A.bankSorts)
		assert.equal(SB.L.SORT_AFTER_COMBAT, BW.frame.title.text)
		assert.equal(0, SB.OutOfCombatPending())
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		A.Advance(5)
		assert.same({}, A.bankSorts)
	end)

	it("a failing bank sort says so, records the error, and never claims it started", function()
		openBank()
		A.SortBank = function() return false, "boom" end
		Fake.Fire(BW.sortBankButton, "OnClick")
		assert.equal(SB.L.SORT_UNAVAILABLE, BW.frame.title.text)
		assert.equal("boom", SB.ErrorTrap.Recent()[1].message)
		assert.falsy(SB.SafeMode.IsOn("bank"))
		assert.falsy(BW.sortPending)
	end)

	-- W3-38: held only while a button that would move is under the mouse.
	it("Reflow regroups, but waits while a button that would move is under the mouse", function()
		openBank()
		A.Clear(6, 2)
		bankUpdate(6)
		BW.scroll.mouseOver = true
		B.Get(6, 3).mouseOver = true -- below the gap 6/2 left: Reflow moves it up
		Fake.Fire(BW.reflowButton, "OnClick")
		assert.equal(SB.L.REFLOW_WAITING, BW.frame.title.text)
		assert.equal(1, #B.placeholdersInUse)
		B.Get(6, 3).mouseOver = false
		BW.scroll.mouseOver = false
		A.Advance(0.3)
		assert.equal(0, #B.placeholdersInUse)
		assert.equal("reflow", BW.view.stats.lastLayoutReason)
	end)

	it("the bank's search box dims bank slots only; the bags search is separate", function()
		openBank()
		BW.searchBox.editBox:SetText("ore")
		Fake.Fire(BW.searchBox.editBox, "OnTextChanged")
		A.Advance(0.2)
		assert.equal(1, B.Get(12, 1).alpha)
		assert.equal(B.DIM_ALPHA, B.Get(6, 1).alpha)
		assert.equal("", SB.Search.text, "the bags window's search is untouched")
	end)

	it("the grid view shows each group in physical order", function()
		SB.Config.Set("bank.view", "grid")
		openBank()
		assert.same({ "- Character bank (2)  - right-clicked items land here", "- Warband bank (2)" }, labels())
		assert.equal(SB.L.VIEW_TO_SECTIONS, BW.viewButton.text)
		Fake.Fire(BW.viewButton, "OnClick")
		assert.equal("sections", SB.Config.Get("bank.view"))
		assert.equal(10, #labels())
	end)

	-- Preflight a11: headers take right-clicks for focus pins; the bank view ignores the button, so a
	-- right-click is a plain click there. Mutation: GroupView owner.onClick returns on "RightButton".
	it("a right-click on a bank section header collapses it like a left-click (a11)", function()
		openBank()
		header("bank:c_herbs").scripts.OnClick(header("bank:c_herbs"), "RightButton")
		assert.equal("+ Herbs (1)", header("bank:c_herbs").text.text)
		header("bank:c_herbs").scripts.OnClick(header("bank:c_herbs"), "RightButton")
		assert.equal("- Herbs (1)", header("bank:c_herbs").text.text)
	end)

	it("closing the bank forgets the layout; the next visit rebuilds it and keeps collapse state", function()
		openBank()
		header("bank:c_herbs").scripts.OnClick(header("bank:c_herbs"))
		A.Clear(6, 1)
		bankUpdate(6)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		assert.falsy(BW.view.IsOpen())
		assert.equal(0, #B.placeholdersInUse)
		openBank()
		assert.equal("+ Herbs (1)", header("bank:c_herbs").text.text)
		assert.equal(0, #B.placeholdersInUse)
	end)

	it("what is already in the bank at a visit is not marked new", function()
		openBank()
		assert.equal(false, BW.view.Record(6, 1).isNew)
		assert.equal(false, BW.view.Record(12, 2).isNew)
		A.Put(6, 5, Fixtures.FLASK, 1)
		bankUpdate(6)
		assert.equal(true, BW.view.Record(6, 5).isNew, "a deposit during the visit is new")
	end)

	-- Ruling W3-25. Mutation: drop the newSet clearing in Inv.ScanKind (visit = true).
	it("a deposit made during one visit is not new at the next visit", function()
		openBank()
		A.Put(6, 5, Fixtures.FLASK, 1)
		bankUpdate(6)
		assert.equal(true, BW.view.Record(6, 5).isNew)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		openBank()
		assert.equal(false, BW.view.Record(6, 5).isNew, "the last visit's deposit is just bank contents now")
	end)

	-- Ruling W3-25. Mutation: delete the Inventory.FlushKinds call in the BANK_TAB_SETTINGS_UPDATED handler.
	it("a deposit still waiting on the flush when a bank tab changes stays new", function()
		openBank()
		A.Put(6, 5, Fixtures.FLASK, 1)
		SB.eventFrame:Fire("BAG_UPDATE", 6) -- dirty; the 50 ms flush has not run yet
		SB.eventFrame:Fire("BANK_TAB_SETTINGS_UPDATED")
		assert.equal(true, BW.view.Record(6, 5).isNew, "a deposit during the visit is new")
		assert.truthy(B.Get(6, 5).shown)
	end)

	-- Ruling W3-27. Mutation: delete the SB.OutOfCombat(... "bank.grownLayout" ...) call in bagsOf.
	it("a bank tab bought in combat gets its buttons after combat and the bank is laid out again", function()
		openBank()
		A.combat = true
		A.bagIDs.bank = { 6, 7 }
		A.SetBagSize(7, 4)
		A.Put(7, 1, Fixtures.JUNK, 2)
		bankUpdate(7)
		assert.equal(0, B.Count(7), "no buttons are created in combat")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal("grow", BW.view.stats.lastLayoutReason)
		assert.truthy(B.Get(7, 1).shown)
	end)

	it("a bank tab bought during the visit gets its buttons and the bank is laid out again", function()
		openBank()
		A.bagIDs.bank = { 6, 7 }
		A.SetBagSize(7, 4)
		A.Put(7, 1, Fixtures.JUNK, 2)
		bankUpdate(7)
		assert.equal(98, B.Count(7))
		assert.equal("size", BW.view.stats.lastLayoutReason)
		assert.truthy(B.Get(7, 1).shown)
	end)

	it("a bank tab change during the visit (BANK_TAB_SETTINGS_UPDATED) lays the bank out again", function()
		openBank()
		A.bagIDs.warband = { 12, 13 }
		A.SetBagSize(13, 98)
		A.Put(13, 1, Fixtures.BOE_RING, 1)
		SB.eventFrame:Fire("BANK_TAB_SETTINGS_UPDATED")
		assert.equal("tabs", BW.view.stats.lastLayoutReason)
		assert.truthy(B.Get(13, 1).shown)
		assert.equal(false, BW.view.Record(13, 1).isNew, "not new: it was there when the tab appeared")
	end)

	-- Mutation: delete the Apply in the in-place (no ITEM reason) branch of the bank's live refresh.
	it("a count-only change on a bank slot re-draws that button's overlays in place", function()
		openBank()
		local applied = {}
		local apply = SB.Overlays.Apply
		SB.Overlays.Apply = function(button, ...)
			applied[button] = (applied[button] or 0) + 1
			return apply(button, ...)
		end
		A.Put(6, 2, Fixtures.HERB, 25)
		bankUpdate(6)
		SB.Overlays.Apply = apply
		assert.equal(1, applied[B.Get(6, 2)])
	end)

	it("an item dropped on a bank section header goes to the bags window's drag-to-assign", function()
		openBank()
		A.cursor = { itemID = Fixtures.JUNK }
		header("bank:c_herbs").scripts.OnReceiveDrag(header("bank:c_herbs"))
		assert.same({ "c_herbs" }, SB.BagsWindow.dropped)
	end)

	-- Week 6, D20. Mutation: describe reads the slot again for the record (Items.Describe(bag, slot)).
	it("a bank layout reads each slot once, for the button and the record", function()
		openBank()
		local get, reads = A.GetSlot, {}
		A.GetSlot = function(bag, slot)
			local k = bag * 1000 + slot
			reads[k] = (reads[k] or 0) + 1
			return get(bag, slot)
		end
		BW.Layout("reflow")
		local n = 0
		for k, times in pairs(reads) do
			n = n + 1
			assert.equal(1, times, "slot " .. k)
		end
		assert.equal(16, n, "both groups' 8 slots")
		assert.equal(5, BW.view.Record(6, 1).count, "the record still has the item")
	end)

	-- Week 6, D20: /swagbag report shows where the bank layout's time goes. Mutation: drop
	-- `v.stats.phases = b.ms` in GroupView's commit.
	it("a bank layout records its parts: tabs, reading, categories, positions, drawing", function()
		local ms = 0
		A.ProfileMs = function()
			ms = ms + 1 -- every reading of the clock is 1 ms later
			return ms
		end
		openBank()
		local p = BW.view.stats.phases
		local sum = 0
		for _, part in ipairs({ "groups", "read", "categories", "positions", "drawing" }) do
			assert.truthy(type(p[part]) == "number" and p[part] > 0, part)
			sum = sum + p[part]
		end
		assert.truthy(sum <= BW.view.stats.lastLayoutMs, "the parts fit inside the whole")
	end)

	it("the first visit to a full bank (1,078 slots) is laid out within 80 ms (spec 9)", function()
		Big.Install(A)
		local t0 = os.clock()
		openBank()
		local ms = (os.clock() - t0) * 1000
		assert.equal(1078, #BW.view.cells)
		assert.truthy(ms <= 80, ("first bank open took %.1f ms"):format(ms))
	end)

	-- Spec 6.3: at the bank everything stays open. The bank window follows only the user's own
	-- collapse state; no focus mode ever collapses it. Mutation: in GroupView's collapsedFor,
	-- return SB.Focus.CollapsedView(set) when SB.Focus exists. (The guild bank window is the same
	-- GroupView, so this pins it too.)
	it("a focus mode never collapses the bank window's sections", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Focus.lua")
		SB.Focus.SetSignal("challengeMode", true)
		openBank()
		local shown = labels()
		assert.truthy(#shown > 0, "the bank window drew its sections")
		for _, text in ipairs(shown) do
			assert.equal("-", text:sub(1, 1), text)
		end
	end)
	-- Week 13 Task 2: Deposit warbound and With reagents on the Warband header.
	local function warbandY()
		for _, h in ipairs(BW.view.GroupHeaders()) do
			if h.id == "warband" then
				return h.y
			end
		end
	end

	local function topRight(f)
		for _, p in ipairs(f.points) do
			if p[1] == "TOPRIGHT" then
				return p
			end
		end
	end

	-- Mutation: anchor the button to the frame's row 3 (SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -54)).
	it("Deposit warbound sits on the Warband bank's header", function()
		openBank()
		local b = BW.depositButton
		assert.equal(BW.child, b:GetParent())
		local p = topRight(b)
		assert.equal(BW.child, p[2])
		assert.truthy(math.abs(p[5] - warbandY()) <= 2, "its y is the warband header's")
		assert.truthy(warbandY() ~= 0, "and the header is below the Character bank's")
		assert.truthy(b.shown)
	end)

	-- Mutation: place the controls once (skip the SetPoint when already placed).
	it("the controls follow the header when the group above folds", function()
		openBank()
		local before = warbandY()
		BW.view.ToggleGroup("bank")
		A.Advance(0.06)
		local after = warbandY()
		assert.truthy(after > before, "the warband header moved up (y is negative from the top)")
		assert.truthy(math.abs(topRight(BW.depositButton)[5] - after) <= 2)
		assert.truthy(BW.depositButton.shown)
	end)

	-- Mutation: groupInset returns 0.
	it("the warband header leaves room for the controls", function()
		openBank()
		assert.equal(header("#bank").w - BW.DEPOSIT_W, header("#warband").w)
		assert.equal(BW.DEPOSIT_W, 236)
	end)

	-- Mutation: DepositControlsShown always returns true.
	it("narrow bank hides the header controls", function()
		SB.Config.Set("bank.columns", 4)
		openBank()
		assert.truthy(BW.child:GetWidth() - 8 < BW.DEPOSIT_W + BW.HEADER_LABEL_MIN)
		assert.equal(false, BW.DepositControlsShown())
		assert.falsy(BW.depositButton.shown)
		assert.falsy(BW.reagentsBox.shown)
		assert.falsy(BW.reagentsLabel.shown)
		assert.equal(header("#bank").w, header("#warband").w, "the header keeps its whole width")
	end)

	-- Mutation: leave the Close path to the frame alone (onHeaders({}) from v.Clear is ignored).
	it("the controls hide with the window and come back on reopen", function()
		openBank()
		assert.truthy(BW.depositButton.shown and BW.reagentsBox.shown)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		assert.falsy(BW.depositButton.shown)
		assert.falsy(BW.reagentsBox.shown)
		assert.falsy(BW.reagentsLabel.shown)
		openBank()
		assert.truthy(BW.depositButton.shown and BW.reagentsBox.shown and BW.reagentsLabel.shown)
	end)

	-- Ruling P2. Mutation: drop the SetFrameLevel calls in BW.PlaceDepositControls.
	it("the controls sit above the warband header's frame level, so the header never eats their clicks", function()
		openBank()
		local level = header("#warband"):GetFrameLevel()
		assert.truthy(BW.depositButton:GetFrameLevel() > level)
		assert.truthy(BW.reagentsBox:GetFrameLevel() > level)
		assert.equal(BW.depositButton, BW.reagentsLabel:GetParent(), "the label is drawn with the button")
	end)

	-- Mutation: showReagents ignores reagentsKnown (a placed box shows although the game cannot say).
	it("a game that cannot say the reagents choice keeps the box and label hidden, even when the header moves", function()
		A.DepositReagents = function() return nil end
		openBank()
		assert.truthy(BW.depositButton.shown)
		assert.falsy(BW.reagentsBox.shown)
		BW.view.ToggleGroup("bank")
		A.Advance(0.06)
		assert.falsy(BW.reagentsBox.shown)
		assert.falsy(BW.reagentsLabel.shown)
	end)
	-- Review fix. Mutation: drop the warbandDrawn() test in sizeFrame (it redraws on every resize).
	it("with no warband header drawn, a plain relayout does not redraw the headers", function()
		local wide = SB.Config.Get("bank.columns")
		SB.Config.Set("bank.columns", 4)
		openBank() -- narrow: the last warband draw used no room
		BW.view.GroupHeaders = function() return { { id = "bank", y = 0, count = 1, collapsed = false } } end
		local n, relabel = 0, BW.view.Relabel
		BW.view.Relabel = function(...) n = n + 1 return relabel(...) end
		SB.Config.Set("bank.columns", wide) -- wide now, with no warband header in the list
		BW.Reflow("reflow")
		BW.view.Restack()
		assert.equal(0, n)
	end)

	-- Review fix. Mutation: DepositControlsShown ignores the width after the first draw (cached).
	it("changing bank.columns on an open window hides the controls when narrow and shows them again", function()
		openBank()
		assert.truthy(BW.depositButton.shown)
		local wide = SB.Config.Get("bank.columns")
		SB.Config.Set("bank.columns", 4)
		BW.Reflow("reflow")
		assert.falsy(BW.depositButton.shown)
		assert.falsy(BW.reagentsBox.shown)
		assert.equal(header("#bank").w, header("#warband").w)
		SB.Config.Set("bank.columns", wide)
		BW.Reflow("reflow")
		assert.truthy(BW.depositButton.shown and BW.reagentsBox.shown)
		assert.equal(header("#bank").w - BW.DEPOSIT_W, header("#warband").w)
	end)
end)

describe("Bags and bank windows open together (Review Focus 1)", function()
	local SB, A, B, W, BW
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		Fake.Install()
		Env.PaintGlobals()
		A.frames.BankFrame = blizzardBank()
		A.activeBankType = "bank"
		for _, path in ipairs({ "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/ListRows.lua",
			"SwagBag/UI/BagsWindow.lua",
			"SwagBag/UI/SearchBox.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua" }) do
			Loader.LoadFile(SB, path)
		end
		B, W, BW = SB.Buttons, SB.BagsWindow, SB.BankWindow
		SB.Emit("SB_LOGIN")
		A.SetBagSize(6, 8)
		A.SetBagSize(12, 8)
		A.Put(6, 1, Fixtures.HERB, 20)
		A.Put(12, 1, Fixtures.ORE, 10)
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	local function bankHeaders()
		local n = 0
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.shown and h.sectionId:find("[#:]") then
				n = n + 1
			end
		end
		return n
	end

	it("a bags redraw (Reflow, a bag change) never takes the bank window's headers or placeholders", function()
		W.Open()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		local headers = bankHeaders()
		assert.truthy(headers >= 8)
		A.Clear(6, 1) -- a withdrawal leaves a placeholder in the bank window
		SB.eventFrame:Fire("BAG_UPDATE", 6)
		A.Put(0, 10, Fixtures.HERB, 20) -- ... and the herb lands in the bags
		SB.eventFrame:Fire("BAG_UPDATE", 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
		local bankPlaceholder = B.placeholdersInUse[1]
		assert.truthy(bankPlaceholder and bankPlaceholder.shown)
		assert.equal(BW.child, bankPlaceholder.parent, "the withdrawal's placeholder is the bank window's")
		W.Reflow("reflow")
		assert.equal(headers, bankHeaders(), "the bank's headers survived the bags regroup")
		assert.truthy(bankPlaceholder.shown, "and so did its placeholder")
		BW.Reflow("reflow")
		assert.truthy(#SB.SectionHeaders.inUse > headers, "the bags window kept its headers too")
	end)

	-- Fix round 1, the reverse direction. Mutation: B.ReleasePlaceholders() (no parent) in GroupView's
	-- renderExtras.
	it("a bank redraw (Reflow) never takes the bags window's placeholders", function()
		W.Open()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		A.Clear(0, 1) -- a bags withdrawal (used or moved) leaves a placeholder in the bags window
		SB.eventFrame:Fire("BAG_UPDATE", 0)
		SB.eventFrame:Fire("BAG_UPDATE_DELAYED")
		A.Advance(0.06)
		local bagsPlaceholder
		for _, p in ipairs(B.placeholdersInUse) do
			if p.parent == W.child then
				bagsPlaceholder = p
			end
		end
		assert.truthy(bagsPlaceholder and bagsPlaceholder.shown, "the bags window has a placeholder")
		assert.truthy(BW.Reflow("reflow"))
		assert.truthy(bagsPlaceholder.shown, "the bags placeholder survived the bank regroup")
		local still = false
		for _, p in ipairs(B.placeholdersInUse) do
			still = still or p == bagsPlaceholder
		end
		assert.truthy(still, "and it is still in use")
	end)

end)

describe("Bags title and bank at once (week 13 Task 3)", function()
	local SB, A, W
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		Fake.Install()
		Env.PaintGlobals()
		A.frames.BankFrame = blizzardBank()
		A.activeBankType = "warband"
		for _, path in ipairs({ "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/ListRows.lua",
			"SwagBag/UI/BagsWindow.lua",
			"SwagBag/UI/SearchBox.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua" }) do
			Loader.LoadFile(SB, path)
		end
		W = SB.BagsWindow
		SB.Emit("SB_LOGIN")
		A.SetBagSize(6, 8)
		A.SetBagSize(12, 8)
	end)

	after_each(function()
		Fake.Uninstall()
		Env.ClearPaintGlobals()
	end)

	it("the target group says right-clicked items land there", function()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		local text
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.shown and h.sectionId == "#warband" then
				text = h.text.text
			end
		end
		local L = SB.L
		assert.equal(L.BANK_GROUP_TARGET, text:sub(-#L.BANK_GROUP_TARGET))
		assert.equal("  - right-clicked items land here", L.BANK_GROUP_TARGET)
	end)

	-- Mutation: delete the SB_BANK_TARGET listener in BagsWindow.lua.
	it("the bags title says where right-click goes at the bank", function()
		local L = SB.L
		SB.Emit("SB_BANK_TARGET", "warband")
		assert.equal(L.BAGS_TITLE_BANK:format(L.BANK_GROUP_WARBAND), W.Title())
		SB.Emit("SB_BANK_TARGET", "bank")
		assert.equal(L.BAGS_TITLE_BANK:format(L.BANK_GROUP_BANK), W.Title())
		SB.Emit("SB_BANK_TARGET", nil)
		assert.equal(L.BAGS_TITLE, W.Title())
	end)

	it("the bags title on screen follows the bank visit", function()
		local L = SB.L
		W.Open()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		assert.equal(L.BAGS_TITLE_BANK:format(L.BANK_GROUP_WARBAND), W.frame.title.text)
	end)

	-- Mutation: delete the Emit in BW.OnBankClosed.
	it("closing the bank clears the bags title", function()
		local L = SB.L
		W.Open()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		assert.equal("warband", W.bankTarget)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		assert.is_nil(W.bankTarget)
		assert.equal(L.BAGS_TITLE, W.frame.title.text)
	end)
end)
