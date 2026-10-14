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
		SB.Config.Set("bags.newAlways", true) -- these tests were written with New always drawn (0.13.1: it hides while empty by default)
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
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
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

	-- Fix round 1: the click only redraws the headers. Mutation: BW.view.Restack() -> BW.view.Layout("target") in BW.RefreshTarget.
	it("the group that receives deposits is tinted; a tab click moves the highlight to the other group", function()
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
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
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
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
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
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
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
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
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
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
		BW.Sort("bank")
		assert.same({ "bank" }, A.bankSorts)
		assert.equal(SB.L.SORT_STARTED, BW.frame.title.text)
		A.Put(6, 1, Fixtures.HERB, 20)
		A.Put(6, 2, Fixtures.HEALING_POTION, 5)
		bankUpdate(6)
		A.Advance(0.3)
		assert.equal("sort", BW.view.stats.lastLayoutReason)
		assert.equal(0, #B.placeholdersInUse)
		BW.Sort("warband")
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
		BW.Sort("bank")
		assert.same({}, A.bankSorts)
		assert.same({ { 6, 3, 6, 1 } }, A.stackMoves)
		assert.equal(SB.L.STACK_STARTED, BW.frame.title.text)
		A.Advance(SB.Stacker.DELAY)
		assert.same({ SB.L.STACK_DONE:format(1, 0) }, A.Lines())
		assert.equal("sort", BW.view.stats.lastLayoutReason)
		BW.Sort("warband")
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
		BW.Sort("bank")
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		A.Advance(SB.Stacker.DELAY)
		assert.equal(1, #A.stackMoves)
		assert.same({ SB.L.STACK_STOP_CLOSED:format(1, 0) }, A.Lines())
		-- the same with the closed bank's slots reading empty, as the client may answer
		A.Put(6, 5, Fixtures.HERB, 2)
		openBank()
		BW.Sort("bank")
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
		BW.Sort("bank")
		A.Clear(6, 1)
		bankUpdate(6)
		BW.Sort("warband")
		A.Advance(BW.SORT_TIMEOUT + 0.1)
		assert.equal("sort", BW.view.stats.lastLayoutReason)
		assert.falsy(BW.sortPending)
		BW.Sort("bank")
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
		BW.Sort("bank")
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
		BW.Sort("bank")
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
		BW.Reflow("reflow")
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
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
		SB.Config.Set("bank.view", "grid")
		openBank()
		assert.same({ "- Character bank (2)  - right-clicked items land here", "- Warband bank (2)" }, labels())
		BW.SetView("sections")
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
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
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
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
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
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
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

	-- Week 13 Task 4: one bank at a time, following the selected tab ("Both banks" in Settings).
	local function shownSlots(bag)
		local out = {}
		for slot = 1, 8 do
			if B.Get(bag, slot).shown then
				out[#out + 1] = slot
			end
		end
		return out
	end

	local OPEN = 3 -- an open group of these fixtures shows two items and its free tile

	local function switchTab(kind)
		A.activeBankType = kind
		Fake.Fire(bf.TabSystem.tabs[kind == "warband" and 2 or 1], "OnClick")
		A.Advance(0)
	end

	local function clickGroup(id)
		header("#" .. id).scripts.OnClick(header("#" .. id))
	end

	local function copy(t)
		local out = {}
		for k, val in pairs(t or {}) do
			out[k] = val
		end
		return out
	end

	-- Mutation: cfg.groupClosed returns nil (the saved set decides: both open).
	it("only the bank you deposit into is open", function()
		local L = SB.L
		openBank()
		assert.equal(OPEN, #shownSlots(6), "the bank's cells are shown")
		assert.same({}, shownSlots(12), "every warband cell is hidden")
		assert.equal(L.BANK_GROUP_LABEL:format("+", L.BANK_GROUP_WARBAND, 2) .. L.BANK_GROUP_FOLDED,
			header("#warband").text.text)
		assert.equal("  - click to show", L.BANK_GROUP_FOLDED)
	end)

	it("switching the tab switches the open bank", function()
		openBank()
		switchTab("warband")
		assert.equal(OPEN, #shownSlots(12))
		assert.same({}, shownSlots(6))
		assert.equal(SB.L.BANK_GROUP_LABEL:format("+", SB.L.BANK_GROUP_BANK, 2) .. SB.L.BANK_GROUP_FOLDED,
			header("#bank").text.text)
	end)

	-- P5. Mutation: BW.RefreshTarget calls BW.view.Layout("target") instead of BW.view.Restack().
	it("a target switch under the mouse waits", function()
		openBank()
		B.Get(6, 1).mouseOver = true -- the bank would fold: this button would hide
		switchTab("warband")
		assert.truthy(B.Get(6, 1).shown, "held: the cells stay")
		assert.same({}, shownSlots(12))
		B.Get(6, 1).mouseOver = false
		A.Advance(0.3)
		assert.same({}, shownSlots(6), "the fold lands once the mouse leaves")
		assert.equal(OPEN, #shownSlots(12))
	end)

	-- P2: the click answers by the group opening. Mutation: cfg.toggleGroup returns false (the saved set flips).
	it("clicking the folded bank shows it until the tab changes", function()
		openBank()
		local before = copy(SB.Config.UI().collapsed["bank:#"])
		clickGroup("warband")
		assert.equal(OPEN, #shownSlots(12), "warband opens")
		assert.equal(OPEN, #shownSlots(6), "and the bank stays open")
		assert.equal(SB.L.BANK_GROUP_LABEL:format("-", SB.L.BANK_GROUP_WARBAND, 2), header("#warband").text.text)
		assert.same(before, copy(SB.Config.UI().collapsed["bank:#"]), "the saved set is unchanged")
		switchTab("warband")
		switchTab("bank")
		assert.same({}, shownSlots(12), "after a tab switch and back, warband is folded again")
		assert.same(before, copy(SB.Config.UI().collapsed["bank:#"]))
	end)

	it("clicking the open bank folds it", function()
		openBank()
		clickGroup("bank")
		assert.same({}, shownSlots(6))
		assert.same({}, shownSlots(12))
		assert.is_nil(SB.Config.UI().collapsed["bank:#"] and SB.Config.UI().collapsed["bank:#"].bank)
		clickGroup("bank")
		assert.equal(OPEN, #shownSlots(6))
	end)

	-- Review Focus 1. Mutation: BW.Folded drops the `BW.target ~= nil` test (no target: everything folds).
	it("no known target shows both banks", function()
		A.activeBankType = nil
		openBank()
		assert.equal(OPEN, #shownSlots(6))
		assert.equal(OPEN, #shownSlots(12))
		assert.equal("- Character bank (2)", header("#bank").text.text)
		assert.equal("- Warband bank (2)", header("#warband").text.text)
		for _, id in ipairs({ "#bank", "#warband" }) do
			assert.truthy(header(id).bg.calls.SetColorTexture[2] ~= 0.85, id .. " is not tinted")
		end
	end)

	-- Mutation: BW.Show() always returns "one".
	it("Both banks brings back today's layout", function()
		SB.Config.Set("bank.show", "both")
		openBank()
		assert.equal(OPEN, #shownSlots(6))
		assert.equal(OPEN, #shownSlots(12))
		assert.equal("- Warband bank (2)", header("#warband").text.text)
		clickGroup("warband") -- folds through the saved set, as before
		assert.equal(true, SB.Config.UI().collapsed["bank:#"].warband)
		assert.same({}, shownSlots(12))
		assert.equal("+ Warband bank (2)", header("#warband").text.text)
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		openBank()
		assert.same({}, shownSlots(12), "the saved fold of warband is respected")
		assert.equal(OPEN, #shownSlots(6))
	end)

	-- Review Focus 5. Mutation: cfg.toggleGroup writes the saved set (v.Collapsed("#")[gid] = ...).
	it("one-bank folds never touch the saved collapse set", function()
		SB.Config.UI().collapsed = { ["bank:#"] = { warband = true } }
		A.activeBankType = "warband"
		openBank()
		assert.equal(OPEN, #shownSlots(12), "the target wins over the saved fold")
		assert.same({}, shownSlots(6))
		clickGroup("bank") -- a peek
		clickGroup("warband") -- a fold of the target
		assert.equal(OPEN, #shownSlots(6))
		assert.same({}, shownSlots(12))
		SB.Slash.Dispatch("bank both")
		assert.same({}, shownSlots(12), "warband is folded again from the saved set")
		assert.equal(OPEN, #shownSlots(6))
		assert.same({ warband = true }, copy(SB.Config.UI().collapsed["bank:#"]))
	end)

	-- Final review fix 2. Mutation: BW.Folded returns nil when no target is known (the saved set decides).
	it("one mode with no known target ignores the saved folds; a click peeks", function()
		SB.Config.UI().collapsed = { ["bank:#"] = { warband = true } }
		A.activeBankType = nil
		openBank()
		assert.equal(OPEN, #shownSlots(6))
		assert.equal(OPEN, #shownSlots(12), "the saved fold is ignored")
		assert.equal("- Warband bank (2)", header("#warband").text.text)
		clickGroup("warband") -- folds for this view only
		assert.same({}, shownSlots(12))
		assert.equal(true, BW.peek.warband)
		assert.same({ warband = true }, copy(SB.Config.UI().collapsed["bank:#"]), "the saved set is unchanged")
		assert.equal(SB.L.BANK_GROUP_LABEL:format("+", SB.L.BANK_GROUP_WARBAND, 2) .. SB.L.BANK_GROUP_FOLDED,
			header("#warband").text.text)
		clickGroup("warband")
		assert.equal(OPEN, #shownSlots(12))
		assert.is_nil(BW.peek.warband)
		assert.same({ warband = true }, copy(SB.Config.UI().collapsed["bank:#"]))
	end)

	-- Final review fix 3. Mutation: groupLabel reads BW.Folded(id) for the suffix (a held restack mislabels).
	it("a label redrawn during a held target switch matches what is drawn", function()
		local L = SB.L
		openBank()
		B.Get(6, 1).mouseOver = true
		switchTab("warband") -- held: the bank stays drawn open, the warband stays drawn folded
		BW.view.Relabel()
		assert.equal(L.BANK_GROUP_LABEL:format("+", L.BANK_GROUP_WARBAND, 2) .. L.BANK_GROUP_TARGET .. L.BANK_GROUP_FOLDED,
			header("#warband").text.text, "drawn folded: the sign and the suffix agree")
		assert.equal(L.BANK_GROUP_LABEL:format("-", L.BANK_GROUP_BANK, 2), header("#bank").text.text)
		B.Get(6, 1).mouseOver = false
		A.Advance(0.3)
		assert.equal(L.BANK_GROUP_LABEL:format("-", L.BANK_GROUP_WARBAND, 2) .. L.BANK_GROUP_TARGET,
			header("#warband").text.text)
	end)

	-- Final review fix 3. Mutation: toggleGroup drops the held/redrawPending guard.
	it("a header click while a restack is held does nothing in one mode", function()
		openBank()
		B.Get(6, 1).mouseOver = true
		switchTab("warband") -- held
		clickGroup("bank")
		assert.same({}, BW.peek)
		assert.same({}, copy(SB.Config.UI().collapsed["bank:#"]), "and the saved set is not written either")
		B.Get(6, 1).mouseOver = false
		A.Advance(0.3)
		assert.same({}, BW.peek)
		assert.same({}, shownSlots(6), "the switch landed; the click did not peek")
		BW.view.redrawPending = true
		clickGroup("bank")
		assert.same({}, BW.peek)
		assert.same({}, copy(SB.Config.UI().collapsed["bank:#"]))
		BW.view.redrawPending = false
		clickGroup("bank")
		assert.equal(true, BW.peek.bank)
	end)

	-- Final review fix 6. Mutation: the one/both branch leaves BW.peek alone.
	it("/swagbag bank one and both forget a peek", function()
		openBank()
		clickGroup("warband")
		assert.equal(true, BW.peek.warband)
		SB.Slash.Dispatch("bank both")
		assert.same({}, BW.peek)
		clickGroup("warband") -- both mode: the saved fold, not a peek
		assert.same({}, BW.peek)
		SB.Slash.Dispatch("bank one")
		assert.same({}, BW.peek)
		assert.same({}, shownSlots(12), "one mode starts from the rule again")
	end)

	local function search(t)
		BW.searchBox.editBox:SetText(t)
		Fake.Fire(BW.searchBox.editBox, "OnTextChanged")
		A.Advance(0.2)
	end

	-- Mutation: the setDimmed wrapper counts dimmed buttons too (or nothing).
	it("a search counts matches in each bank; a bank with none never says found", function()
		local L = SB.L
		openBank()
		search("ore")
		local text = header("#warband").text.text
		assert.equal(L.BANK_GROUP_FOUND:format(1), text:sub(-#L.BANK_GROUP_FOUND:format(1)))
		assert.equal("  - 1 found", L.BANK_GROUP_FOUND:format(1))
		assert.same({ bank = 0, warband = 1 }, BW.found)
		assert.equal("- Character bank (2)  - right-clicked items land here", header("#bank").text.text,
			"a bank with no match never says found")
		search("")
		assert.is_nil(BW.found)
		assert.equal(L.BANK_GROUP_LABEL:format("+", L.BANK_GROUP_WARBAND, 2) .. L.BANK_GROUP_FOLDED,
			header("#warband").text.text)
	end)

	-- 0.13.5 (the user's "search for trinket doesn't grab trinkets"): a search opens the banks that hold a match.
	-- Mutation: BW.Folded drops the search rule (a match in the folded bank stays hidden).
	it("0.13.5: a search opens the folded bank that holds a match; clearing it folds it back", function()
		local L = SB.L
		openBank()
		assert.same({}, shownSlots(12))
		search("ore")
		assert.equal(OPEN, #shownSlots(12), "warband opens")
		assert.equal(OPEN, #shownSlots(6), "the target stays open")
		assert.equal(1, B.Get(12, 1).alpha, "the ore is not dimmed")
		assert.equal(B.DIM_ALPHA, B.Get(12, 2).alpha, "the ring is")
		assert.equal(L.BANK_GROUP_LABEL:format("-", L.BANK_GROUP_WARBAND, 2) .. L.BANK_GROUP_FOUND:format(1),
			header("#warband").text.text, "open, and it says how many it found")
		search("")
		assert.same({}, shownSlots(12), "folded back")
		assert.equal(L.BANK_GROUP_LABEL:format("+", L.BANK_GROUP_WARBAND, 2) .. L.BANK_GROUP_FOLDED,
			header("#warband").text.text)
	end)

	-- Mutation: BW.Folded opens a group for any active search (found[gid] > 0 not checked).
	it("0.13.5: only a bank with a match opens", function()
		local L = SB.L
		openBank()
		search("finger")
		assert.equal(OPEN, #shownSlots(12), "the ring is in warband: it opens")
		assert.same({ bank = 0, warband = 1 }, BW.found)
		search("potion")
		assert.same({}, shownSlots(12), "only the character bank matches: warband folds again")
		assert.equal(OPEN, #shownSlots(6))
		assert.equal(L.BANK_GROUP_LABEL:format("-", L.BANK_GROUP_BANK, 2) .. L.BANK_GROUP_TARGET .. L.BANK_GROUP_FOUND:format(1),
			header("#bank").text.text, "the open bank says found too")
	end)

	-- 0.13.6 (the user: "trink" does not find trinkets). Mutation: the bank search compiles without { prefix = true }.
	it("0.13.6: typing trink in the bank's search box lights the trinket and opens its bank", function()
		A.AddItem(777001, { name = "Charm of X", classID = A.ITEM_CLASS.Armor, subclassID = 0,
			equipLoc = "INVTYPE_TRINKET", quality = 4, ilvl = 280, maxStack = 1, bind = "pickup" })
		A.Put(12, 3, 777001, 1)
		openBank()
		bankUpdate(12)
		assert.same({}, shownSlots(12))
		search("trink")
		assert.equal(OPEN + 1, #shownSlots(12), "warband holds the trinket (three items and the free tile): it opens")
		assert.equal(1, B.Get(12, 3).alpha, "the trinket is lit")
		assert.equal(B.DIM_ALPHA, B.Get(12, 2).alpha, "the ring is dimmed")
		assert.same({ bank = 0, warband = 1 }, BW.found)
	end)

	-- P5. Mutation: BW.ApplySearch calls BW.view.Layout("search") instead of BW.view.Restack().
	it("0.13.5: a search that would move a button under the mouse waits, then lands", function()
		switchTab("warband")
		openBank()
		assert.same({}, shownSlots(6))
		B.Get(12, 1).mouseOver = true -- the bank above would open: this button would move down
		local before = at(12, 1)
		search("potion")
		assert.same({}, shownSlots(6), "held")
		assert.same(before, at(12, 1), "nothing moved")
		B.Get(12, 1).mouseOver = false
		A.Advance(0.3)
		assert.equal(OPEN, #shownSlots(6), "the bank opens once the mouse leaves")
	end)

	-- Mutation: BW.Folded applies the search rule in "both" mode too.
	it("0.13.5: in both mode a search changes no fold and never touches the saved set", function()
		SB.Config.Set("bank.show", "both")
		SB.Config.UI().collapsed = { ["bank:#"] = { warband = true } }
		openBank()
		assert.same({}, shownSlots(12))
		search("ore")
		assert.same({}, shownSlots(12), "the saved fold decides")
		BW.view.Restack() -- any redraw during the search (a deposit, a tab click) still reads the saved fold
		assert.same({}, shownSlots(12))
		assert.same({ warband = true }, copy(SB.Config.UI().collapsed["bank:#"]))
		search("")
		assert.same({ warband = true }, copy(SB.Config.UI().collapsed["bank:#"]))
	end)

	-- P2. Mutation: cfg.toggleGroup ignores BW.searchClosed (the click flips a peek the search rule overrides).
	it("0.13.5: a header click folds a search-opened bank until the search text changes", function()
		local L = SB.L
		openBank()
		local before = copy(SB.Config.UI().collapsed["bank:#"])
		search("ore")
		assert.equal(OPEN, #shownSlots(12))
		clickGroup("warband")
		assert.same({}, shownSlots(12), "the click folds it")
		assert.equal(L.BANK_GROUP_LABEL:format("+", L.BANK_GROUP_WARBAND, 2) .. L.BANK_GROUP_FOLDED .. L.BANK_GROUP_FOUND:format(1),
			header("#warband").text.text, "folded: it still says how many it found")
		bankUpdate(12) -- a plain re-apply of the same search keeps the fold
		assert.same({}, shownSlots(12))
		search("bismuth")
		assert.equal(OPEN, #shownSlots(12), "a new search text forgets the click")
		assert.same(before, copy(SB.Config.UI().collapsed["bank:#"]), "nothing saved")
		assert.same({}, BW.peek)
	end)

	-- Mutation: BW.ApplySearch restacks whenever a search is active (not only when the opened set changes).
	it("0.13.5: one search change gives one restack, and no loop", function()
		openBank()
		local n, restack = 0, BW.view.Restack
		BW.view.Restack = function(...)
			n = n + 1
			return restack(...)
		end
		search("ore")
		assert.equal(1, n, "opening warband")
		search("bismuth")
		assert.equal(1, n, "the same banks match: nothing to restack")
		search("")
		assert.equal(2, n, "clearing folds it back")
	end)

	-- Mutation: cfg.toggleGroup writes the saved set for a search-opened group.
	it("0.13.5: a search never writes the saved collapse set", function()
		openBank()
		local before = copy(SB.Config.UI().collapsed["bank:#"])
		search("ore")
		clickGroup("warband")
		clickGroup("warband")
		search("")
		assert.same(before, copy(SB.Config.UI().collapsed["bank:#"]))
	end)

	-- Mutation: cfg.groupTip unset (no tooltip).
	it("group headers explain the two banks", function()
		local L = SB.L
		openBank()
		local lines = {}
		GameTooltip.AddLine = function(_, text)
			lines[#lines + 1] = text
		end
		GameTooltip.ClearLines = function()
			lines = {}
		end
		header("#warband").scripts.OnEnter(header("#warband"))
		assert.equal(L.BANK_GROUP_WARBAND, GameTooltip.text)
		assert.same({ L.TIP_GROUP_WARBAND, L.TIP_GROUP_CLICK_SHOW }, lines)
		assert.truthy(GameTooltip.shown)
		lines = {}
		header("#bank").scripts.OnEnter(header("#bank"))
		assert.equal(L.BANK_GROUP_BANK, GameTooltip.text)
		assert.same({ L.TIP_GROUP_BANK, L.TIP_GROUP_CLICK_HIDE }, lines)
	end)

	-- P2. Mutation: the slash's one/both branch returns its answer without restacking an open window.
	it("/swagbag bank one and both save and answer", function()
		local L = SB.L
		openBank()
		local n, restack = 0, BW.view.Restack
		BW.view.Restack = function(...)
			n = n + 1
			return restack(...)
		end
		SB.Slash.Dispatch("bank both")
		assert.equal("both", SB.Config.Get("bank.show"))
		assert.equal(OPEN, #shownSlots(12), "the open window restacks")
		SB.Slash.Dispatch("bank one")
		assert.equal("one", SB.Config.Get("bank.show"))
		assert.same({}, shownSlots(12))
		assert.equal(2, n)
		SB.Config.readOnly = true
		SB.Slash.Dispatch("bank both")
		assert.equal("one", SB.Config.Get("bank.show"))
		assert.same({ L.BANK_SHOW_BOTH, L.BANK_SHOW_ONE, L.SETTINGS_READONLY }, A.Lines())
	end)

	-- 0.13.3 (the root cause of the Warband bank's New (219) at the first visit after a cold client start): an item
	-- whose data had not loaded at the last full layout waits in its group's New; its data arriving regroups the
	-- bank (debounced, held like any layout), so it leaves New for its category by itself.
	local PENDING = { 239001, 239002, 239003, 239004, 239005 }
	local function load(id, success)
		A.items[id] = { name = "Robe " .. id, classID = A.ITEM_CLASS.Armor, subclassID = 0, quality = 3,
			equipLoc = "INVTYPE_CHEST", ilvl = 280, maxStack = 1, bind = "equip" }
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", id, success ~= false)
	end
	local function putPending()
		SB.Config.Set("bank.show", "both")
		for i, id in ipairs(PENDING) do
			A.AddItem(id, { classID = A.ITEM_CLASS.Armor, subclassID = 0, equipLoc = "INVTYPE_CHEST", pending = true })
			A.Put(12, 2 + i, id, 1)
		end
	end

	-- Mutation: in BankWindow's inventory handler, drop the v.PendingLoaded(changes) call.
	it("0.13.3: Warband items pending at the visit leave New for their category once their data loads", function()
		putPending()
		openBank()
		assert.same({ "- Character bank (2)  - right-clicked items land here", "- Warband bank (7)",
			"- New (0)", "- Consumables (1)", "- Herbs (1)", "- Free (6)",
			"- New (5)", "- BoE gear (1)", "- Ore (1)", "- Free (1)" }, labels())
		for _, id in ipairs(PENDING) do
			load(id)
		end
		assert.equal("- New (5)", labels()[7], "debounced: not yet")
		A.Advance(SB.GroupView.LOADED_DELAY)
		assert.same({ "- Character bank (2)  - right-clicked items land here", "- Warband bank (7)",
			"- New (0)", "- Consumables (1)", "- Herbs (1)", "- Free (6)",
			"- New (0)", "- BoE gear (6)", "- Ore (1)", "- Free (1)" }, labels())
		assert.equal("loaded", BW.view.stats.lastLayoutReason)
	end)

	-- Mutation: in GroupView's PendingLoaded, call v.Layout("loaded") instead of v.RequestLayout("loaded").
	it("0.13.3: that bank regroup waits while a button that would move is under the mouse, then lands", function()
		putPending()
		openBank()
		B.Get(12, 3).mouseOver = true
		for _, id in ipairs(PENDING) do
			load(id)
		end
		A.Advance(SB.GroupView.LOADED_DELAY + SB.GroupView.RETRY * 2)
		assert.equal("- New (5)", labels()[7], "held under the mouse")
		B.Get(12, 3).mouseOver = false
		A.Advance(SB.GroupView.RETRY)
		assert.equal("- New (0)", labels()[7], "landed once the mouse left")
	end)

	-- Not started by the player: it also waits while the mouse rests over the bank's items with no button that
	-- would move under it. Mutation: in PendingLoaded's land, drop the cfg.scroll:IsMouseOver() check.
	it("0.13.3: that bank regroup also waits while the mouse is anywhere over the bank's items, then lands", function()
		putPending()
		openBank()
		BW.scroll.mouseOver = true -- over a gap: no button that would move is under it
		for _, id in ipairs(PENDING) do
			load(id)
		end
		A.Advance(SB.GroupView.LOADED_DELAY + SB.GroupView.RETRY * 3)
		assert.equal("- New (5)", labels()[7], "held while the mouse is over the items")
		BW.scroll.mouseOver = false
		A.Advance(SB.GroupView.RETRY)
		assert.equal("- New (0)", labels()[7], "landed once the mouse left")
		assert.equal("loaded", BW.view.stats.lastLayoutReason)
	end)

	-- Mutation: in GroupView's PendingLoaded, drop `and not record.pending`.
	it("0.13.3: a bank load after which the item still has no data lays nothing out", function()
		putPending()
		openBank()
		local layouts, request = 0, BW.view.RequestLayout
		BW.view.RequestLayout = function(reason)
			layouts = layouts + 1
			return request(reason)
		end
		SB.eventFrame:Fire("ITEM_DATA_LOAD_RESULT", PENDING[1], true) -- success, but the data is still missing
		A.Advance(SB.GroupView.LOADED_DELAY + SB.GroupView.RETRY)
		assert.equal(0, layouts)
		assert.equal("- New (5)", labels()[7])
		assert.same({ loads = 1, regroups = 0, stillPending = 1, filled = 0 }, BW.view.newStats, "0.14.1: the report counts it")
	end)

	-- Mutation: in GroupView's PendingLoaded, drop the pendingNew lookup (every LOADED regroups).
	it("0.13.3: a load for a bank item already in its category, or a failed load, lays nothing out", function()
		putPending()
		openBank()
		local layouts, request = 0, BW.view.RequestLayout
		BW.view.RequestLayout = function(reason)
			layouts = layouts + 1
			return request(reason)
		end
		SB.Inventory.MarkPending(Fixtures.ORE)
		SB.eventFrame:Fire("GET_ITEM_INFO_RECEIVED", Fixtures.ORE, true)
		load(PENDING[1], false)
		A.Advance(SB.GroupView.LOADED_DELAY + SB.GroupView.RETRY)
		assert.equal(0, layouts)
		assert.equal("- New (5)", labels()[7])
	end)

	-- Mutation: in GroupView's PendingLoaded, call v.RequestLayout at once instead of through SB.Debounce.
	it("0.13.3: a burst of bank loads gives exactly one layout", function()
		putPending()
		openBank()
		local n, request = 0, BW.view.RequestLayout
		BW.view.RequestLayout = function(reason)
			n = n + 1
			return request(reason)
		end
		for _, id in ipairs(PENDING) do
			load(id)
			A.Advance(0.1)
		end
		A.Advance(SB.GroupView.LOADED_DELAY)
		assert.equal(1, n)
		assert.equal("- New (0)", labels()[7])
	end)

	-- 0.14.1 (the root cause of the Warband bank's New flood at the first visit after a full game restart): the
	-- client sends a warband tab's contents AFTER BANKFRAME_OPENED. The tab reads empty at the visit's scan and the
	-- first layout, then a bag update fills it: every stack came in as a live "arrived" change, so it went to New
	-- like a deposit and stayed there (no data load concerns it, so 0.13.3's regroup never ran). Now what fills a tab
	-- that read empty at the visit's start, and did not come from the bags, is the client's late data: the bank
	-- regroups (debounced and held like the "loaded" regroup) and it joins its categories.
	local function lateWarband()
		SB.Config.Set("bank.show", "both")
		A.Clear(12, 1)
		A.Clear(12, 2)
		openBank()
		A.Put(12, 1, Fixtures.ORE, 10)
		A.Put(12, 2, Fixtures.BOE_RING, 1)
	end

	-- Mutation: in Inventory's markLate, never set c.late; or in BankWindow's handler drop the RegroupSoon("filled") call.
	it("0.14.1: a Warband tab whose contents arrive after the bank opened joins its categories, not New", function()
		lateWarband()
		assert.same({ "- Character bank (2)  - right-clicked items land here", "- Warband bank (0)",
			"- New (0)", "- Consumables (1)", "- Herbs (1)", "- Free (6)",
			"- New (0)", "- Free (8)" }, labels())
		bankUpdate(12)
		assert.equal("- New (2)", labels()[7], "shown at once where a live change puts it")
		-- the report's line (Core/Report.lua): why New holds them, and the late-data regroup asked for
		assert.same({ pending = 0, undecided = 0, arrived = 2 }, BW.view.NewReasons())
		assert.same({ loads = 0, regroups = 1, stillPending = 0, filled = 1 }, BW.view.newStats)
		A.Advance(SB.GroupView.LOADED_DELAY)
		assert.same({ "- Character bank (2)  - right-clicked items land here", "- Warband bank (2)",
			"- New (0)", "- Consumables (1)", "- Herbs (1)", "- Free (6)",
			"- New (0)", "- BoE gear (1)", "- Ore (1)", "- Free (6)" }, labels())
		assert.equal("filled", BW.view.stats.lastLayoutReason)
	end)

	-- Late contents that are still loading: the "filled" regroup puts them in New as pending, then their loads regroup.
	it("0.14.1: late Warband contents whose data is still loading leave New once it loads", function()
		lateWarband()
		putPending()
		bankUpdate(12)
		A.Advance(SB.GroupView.LOADED_DELAY)
		assert.equal("- New (5)", labels()[7], "pending at the filled regroup")
		assert.same({ pending = 5, undecided = 0, arrived = 0 }, BW.view.NewReasons())
		for _, id in ipairs(PENDING) do
			load(id)
		end
		A.Advance(SB.GroupView.LOADED_DELAY)
		assert.equal("- New (0)", labels()[7])
		assert.equal("- BoE gear (6)", labels()[8])
		assert.same({ loads = 5, regroups = 6, stillPending = 0, filled = 1 }, BW.view.newStats)
		assert.same({ pending = 0, undecided = 0, arrived = 0 }, BW.view.NewReasons())
	end)

	-- P5: the late-data regroup waits while the mouse is over the bank's items.
	it("0.14.1: the late-data regroup waits while the mouse is over the bank's items, then lands", function()
		lateWarband()
		bankUpdate(12)
		BW.scroll.mouseOver = true
		A.Advance(SB.GroupView.LOADED_DELAY + SB.GroupView.RETRY * 3)
		assert.equal("- New (2)", labels()[7], "held")
		BW.scroll.mouseOver = false
		A.Advance(SB.GroupView.RETRY)
		assert.equal("- New (0)", labels()[7], "landed once the mouse left")
	end)

	-- A real deposit comes out of the bags in the same update: it stays in New, even into a tab that read empty.
	-- Mutation: in Inventory's markLate, drop the bags-total check (every fill of an empty tab is late).
	it("0.14.1: a deposit into a tab that read empty stays in New", function()
		lateWarband()
		local layouts, request = 0, BW.view.RequestLayout
		BW.view.RequestLayout = function(reason)
			layouts = layouts + 1
			return request(reason)
		end
		A.Clear(12, 2)
		A.Clear(0, 2) -- the flask leaves the bags ...
		A.Put(12, 1, Fixtures.FLASK, 2) -- ... and lands in the warband tab, in one update
		SB.eventFrame:Fire("BAG_UPDATE", 0)
		bankUpdate(12)
		A.Advance(SB.GroupView.LOADED_DELAY + SB.GroupView.RETRY)
		assert.equal(0, layouts)
		assert.equal("- New (1)", labels()[7])
	end)

	-- A tab that held items at the visit's start: what comes into it (here not from the bags) is a live change as
	-- before. Mutation: in Inventory's markLate, drop the visitEmpty check (every non-deposit fill is late).
	it("0.14.1: a stack coming into a tab that held items at the visit's start stays in New", function()
		SB.Config.Set("bank.show", "both")
		openBank()
		local layouts, request = 0, BW.view.RequestLayout
		BW.view.RequestLayout = function(reason)
			layouts = layouts + 1
			return request(reason)
		end
		A.Put(12, 3, Fixtures.HERB, 5)
		bankUpdate(12)
		A.Advance(SB.GroupView.LOADED_DELAY + SB.GroupView.RETRY)
		assert.equal(0, layouts)
		assert.equal("- New (1)", labels()[7])
	end)

	-- A tab that was only partly there at the visit's start: Inventory.FLOOD_MIN stacks or more in one update, none of
	-- them from the bags, are late data too. Mutation: in Inventory's markLate, drop `flood or`.
	it("0.14.1: a flood of stacks not from the bags into a tab that held items regroups the bank", function()
		SB.Config.Set("bank.show", "both")
		A.SetBagSize(12, 30)
		openBank()
		for slot = 3, 2 + SB.Inventory.FLOOD_MIN do
			A.Put(12, slot, Fixtures.HERB, slot)
		end
		bankUpdate(12)
		assert.equal("- New (" .. SB.Inventory.FLOOD_MIN .. ")", labels()[7])
		A.Advance(SB.GroupView.LOADED_DELAY)
		assert.equal("- New (0)", labels()[7])
		assert.equal("filled", BW.view.stats.lastLayoutReason)
	end)

	-- 0.14.1 (the report): a stack that overflowed a full New ("+N more below") still counts. Mutation: in
	-- GroupView's v.NewReasons, drop the overflowKeys loop.
	it("0.14.1: New's contents by reason count the stacks past a full New", function()
		SB.Config.Set("bank.columns", 1)
		SB.Config.Set("bags.newRows", 1)
		lateWarband()
		bankUpdate(12)
		assert.same({ pending = 0, undecided = 0, arrived = 2 }, BW.view.NewReasons())
	end)

	-- 0.14.1 (the report): an item whose data loaded but whose rule cannot decide yet waits in New as "undecided".
	it("0.14.1: New's contents are reported by reason: an undecided item", function()
		SB.Config.Set("bank.show", "both")
		local assign = SB.Categorizer.Assign
		SB.Categorizer.Assign = function(record)
			if record.itemID == Fixtures.ORE then
				return nil, "pending"
			end
			return assign(record)
		end
		openBank()
		assert.equal("- New (1)", labels()[7])
		assert.same({ pending = 0, undecided = 1, arrived = 0 }, BW.view.NewReasons())
		SB.Categorizer.Assign = assign
	end)

	-- Stack grouping (0.14.0): the character and warband banks show one icon per item (bags.stacks "one").
	describe("stack grouping (0.14.0)", function()
		local function total(bag, slot)
			local s = B.StackOf(B.Get(bag, slot))
			return s and s.total
		end

		-- Mutation: BankWindow's GroupView cfg drops `stacks`.
		it("the bank shows one icon with the total", function()
			A.Put(6, 4, Fixtures.HERB, 45)
			openBank()
			assert.same({ 1, 3, 4 }, shownSlots(6), "the potion, the free tile and the herbs' icon (the 20 hides under the 45)")
			assert.equal(65, total(6, 4))
			assert.equal(45, B.Get(6, 4).count, "Blizzard's count field keeps the real stack")
			assert.equal("- Herbs (1)", header("bank:c_herbs").text.text)
		end)

		-- P5. Mutation: the bank's SB_STACKS_CHANGED listener is deleted.
		it("stacks all shows every bank stack after a held layout", function()
			A.Put(6, 4, Fixtures.HERB, 45)
			openBank()
			local icon = B.Get(6, 4)
			local cell = at(6, 4)
			icon.mouseOver = true -- with every stack shown the 45 takes a cell of its own: it would move
			SB.Config.Set("bags.stacks", "all")
			SB.Emit("SB_STACKS_CHANGED")
			assert.same({ 1, 3, 4 }, shownSlots(6), "held under the mouse")
			assert.same(cell, at(6, 4))
			A.Advance(0.3)
			assert.same({ 1, 3, 4 }, shownSlots(6), "still under the mouse")
			icon.mouseOver = false
			A.Advance(0.3)
			assert.same({ 1, 2, 3, 4 }, shownSlots(6), "every stack shows")
			assert.same({ nil, nil }, { total(6, 2), total(6, 4) })
			assert.equal("- Herbs (2)", header("bank:c_herbs").text.text)
		end)

		-- Mutation: the bank's inventory handler drops v.PaintStacks().
		it("a deposit that tops up a hidden stack updates the total in place", function()
			A.Put(6, 4, Fixtures.HERB, 45)
			openBank()
			local cell = at(6, 4)
			A.Put(6, 2, Fixtures.HERB, 30) -- the hidden 20 becomes 30
			bankUpdate(6)
			assert.equal(75, total(6, 4))
			assert.same({ 45, 30 }, B.StackOf(B.Get(6, 4)).counts)
			assert.same({ 1, 3, 4 }, shownSlots(6), "nothing appears")
			assert.same(cell, at(6, 4), "nothing moves")
		end)

		-- Review Focus 5. Mutation: no `afterApply` on the bank's search box.
		it("a bank search counts and lights a hidden stack's match", function()
			A.Put(12, 3, Fixtures.HERB, 45)
			A.Put(12, 4, Fixtures.HERB, 7)
			openBank()
			assert.same({}, shownSlots(12), "the warband is folded")
			search("mycobloom")
			assert.equal(2, BW.found.warband, "both stacks count, the hidden 7 too")
			assert.same({ 1, 2, 3, 5 }, shownSlots(12), "the warband opens: the ore, the ring, the herbs' icon, the free tile")
			search("count<10 & mycobloom") -- only the hidden 7 matches
			assert.equal(1, BW.found.warband)
			assert.truthy(B.Get(12, 3).shown)
			assert.equal(1, B.Get(12, 3).alpha, "the shown 45's icon stays lit")
			assert.equal(B.DIM_ALPHA, B.Get(12, 1).alpha, "the ore is dimmed")
		end)
	end)
end)

describe("Bags and bank windows open together (Review Focus 1)", function()
	local SB, A, B, W, BW
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		SB.Config.Set("bags.newAlways", true) -- these tests were written with New always drawn (0.13.1: it hides while empty by default)
		Fixtures.SmallBags(A)
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		Fake.Install()
		Env.PaintGlobals()
		A.frames.BankFrame = blizzardBank()
		A.activeBankType = "bank"
		for _, path in ipairs({ "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/ListRows.lua",
			"SwagBag/UI/BagsWindow.lua",
			"SwagBag/UI/SearchBox.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua",
			"SwagBag/UI/BankMenu.lua" }) do
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

	-- 0.13.1. Mutation: in /swagbag new, drop the loop that asks the bank windows for a layout.
	it("/swagbag new always brings New into an open bank", function()
		SB.Config.Set("bags.newAlways", false)
		SB.Config.Set("bank.show", "both")
		W.Open()
		SB.eventFrame:Fire("BANKFRAME_OPENED")
		local function hasNew(id)
			for _, h in ipairs(SB.SectionHeaders.inUse) do
				if h.shown and h.sectionId == id then
					return true
				end
			end
			return false
		end
		assert.equal(false, hasNew("bank:new"))
		SB.Slash.Run("new always")
		A.Advance(SB.GroupView.RETRY + 0.01)
		assert.equal(true, hasNew("bank:new"))
		assert.equal(true, hasNew("warband:new"))
	end)

	it("a bags redraw (Reflow, a bag change) never takes the bank window's headers or placeholders", function()
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
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
			"SwagBag/UI/SearchBox.lua", "SwagBag/UI/TinyHost.lua", "SwagBag/UI/GroupView.lua", "SwagBag/UI/BankWindow.lua",
			"SwagBag/UI/BankMenu.lua" }) do
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

-- 0.13.1: New hides while empty in the bank (bags.newAlways, one setting for every window), and each bank
-- group has a faint colour band (bank.groupColors).
describe("BankWindow New and group colours (0.13.1)", function()
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
		SB.Emit("SB_LOGIN")
		Fixtures.Settle(SB)
		A.SetBagSize(6, 8)
		A.SetBagSize(12, 8)
		A.Put(6, 1, Fixtures.HEALING_POTION, 5)
		A.Put(6, 2, Fixtures.HERB, 20)
		A.Put(12, 1, Fixtures.ORE, 10)
		A.Put(12, 2, Fixtures.BOE_RING, 1)
		SB.Config.Set("bank.show", "both")
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
			if h.sectionId == id and h.shown then
				return h
			end
		end
	end
	local function at(bag, slot)
		local p = B.Get(bag, slot).points
		p = p[#p]
		return { p[4], p[5] }
	end

	-- Mutation: in BankWindow's GroupView cfg, delete `hideEmptyNew = function() ... end`.
	it("an empty bank shows no New header in either group by default", function()
		openBank()
		assert.falsy(header("bank:new"))
		assert.falsy(header("warband:new"))
		assert.truthy(header("bank:c_consumables"), "the rest is drawn")
	end)

	-- Mutation: in BankWindow's hideEmptyNew, return false always (New is drawn from the start), or
	-- return true always (an arrival never opens New).
	it("a deposit makes New appear in that group only, with the item in it", function()
		openBank()
		A.Put(6, 5, Fixtures.FLASK, 2)
		bankUpdate(6)
		local new = assert(header("bank:new"), "New opened in the character bank")
		assert.equal("- New (1)", new.text.text)
		assert.equal(new.points[1][5] - 20, at(6, 5)[2], "the item is the first cell of New")
		assert.falsy(header("warband:new"), "the warband bank has no New")
	end)

	-- Mutation: replace the cfg's hideEmptyNew with a function that ignores bags.newAlways (returns true).
	it("bags.newAlways = true shows New in both groups when empty", function()
		SB.Config.Set("bags.newAlways", true)
		openBank()
		assert.equal("- New (0)", header("bank:new").text.text)
		assert.equal("- New (0)", header("warband:new").text.text)
	end)

	-- P5 (the held redraw path, as the bags window). Mutation: in the bank, apply the deposit with a layout
	-- that ignores the mouse (BW.view.Layout instead of Changes' guarded redraw).
	it("a deposit while the mouse is over a button that would move: the redraw is held, then lands", function()
		openBank()
		local warbandAt = at(12, 1)
		B.Get(12, 1).mouseOver = true -- New opening in the character bank pushes the warband down
		A.Put(6, 5, Fixtures.FLASK, 2)
		bankUpdate(6)
		assert.same(warbandAt, at(12, 1), "the hovered button did not move")
		assert.falsy(header("bank:new"), "the redraw is held")
		B.Get(12, 1).mouseOver = false
		A.Advance(SB.GroupView.RETRY + 0.01)
		assert.truthy(header("bank:new"), "it landed once the mouse left")
		assert.truthy(at(12, 1)[2] < warbandAt[2], "the warband moved down")
	end)

	local function bands()
		return BW.view.bands
	end

	-- Mutation: swap the two colours in BankWindow's groupColor; or draw the bands at y 0.
	it("the bank shows two bands with the exact colours, each from its header's top", function()
		openBank()
		assert.equal(2, #bands())
		assert.same({ 0.85, 0.65, 0.25, 0.06 }, bands()[1].tex.calls.SetColorTexture)
		assert.same({ 0.25, 0.65, 1.0, 0.06 }, bands()[2].tex.calls.SetColorTexture)
		local top = function(h) local p = h.points[#h.points] return p[5] end
		assert.equal(top(header("#bank")), bands()[1].frame.points[1][5])
		assert.equal(top(header("#warband")), bands()[2].frame.points[1][5])
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#bank").bg.calls.SetColorTexture, "the deposit tint stays on top")
	end)

	-- Mutation: delete the folded branch in GroupView's drawBands.
	it("a folded group's band is header height only (one-bank mode folds the other bank)", function()
		SB.Config.Set("bank.show", "one")
		openBank()
		assert.equal(SB.GroupView.GROUP_HEADER, bands()[2].height, "the warband is folded")
		assert.truthy(bands()[1].height > SB.GroupView.GROUP_HEADER)
	end)

	-- Mutation: delete the `bank.groupColors` check in groupColor.
	it("bank.groupColors = false shows no bands; /swagbag bank colors redraws an open bank", function()
		SB.Config.Set("bank.groupColors", false)
		openBank()
		assert.equal(0, #bands())
		assert.equal(SB.L.BANK_COLORS_ON, (select(2, SB.Slash.Run("bank colors on"))))
		assert.equal(2, #bands())
		assert.equal(true, SB.Config.Get("bank.groupColors"))
		assert.equal(SB.L.BANK_COLORS_OFF, (select(2, SB.Slash.Run("bank colors off"))))
		assert.equal(0, #bands())
		assert.equal(false, SB.Config.Get("bank.groupColors"))
	end)

	it("closing the bank hides the bands", function()
		openBank()
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		assert.equal(0, #bands())
	end)
end)
