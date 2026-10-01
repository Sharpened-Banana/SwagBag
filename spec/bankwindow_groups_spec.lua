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
		assert.same({ "- Character bank (2)  - deposits go here", "- Warband bank (2)",
			"- New (0)", "- Consumables (1)", "- Herbs (1)", "- Free (6)",
			"- New (0)", "- BoE gear (1)", "- Ore (1)", "- Free (6)" }, labels())
		assert.truthy(B.Get(6, 1).shown)
		assert.equal(BW.child, B.frames[6].parent, "the bank tab's bag frame lives in the bank window")
		assert.equal(16, #BW.view.cells)
		assert.equal("open", BW.view.stats.lastLayoutReason)
	end)

	it("the group that receives deposits is tinted; a tab click moves the highlight to the other group", function()
		openBank()
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#bank").bg.calls.SetColorTexture)
		A.activeBankType = "warband"
		Fake.Fire(bf.TabSystem.tabs[2], "OnClick")
		A.Advance(0)
		assert.equal("- Warband bank (2)  - deposits go here", header("#warband").text.text)
		assert.equal("- Character bank (2)", header("#bank").text.text)
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, header("#warband").bg.calls.SetColorTexture)
	end)

	it("a deposit shows in that group's New; nothing else moves", function()
		openBank()
		local before = { at(6, 1), at(6, 2), at(12, 1), at(12, 2) }
		A.Put(6, 5, Fixtures.FLASK, 2) -- a bag item right-clicked into the character bank
		bankUpdate(6)
		assert.equal(header("bank:new").points[1][5] - 20, at(6, 5)[2], "first cell of New")
		assert.same(before, { at(6, 1), at(6, 2), at(12, 1), at(12, 2) })
		assert.equal("- Character bank (3)  - deposits go here", header("#bank").text.text)
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

	it("Reflow regroups, but waits while the mouse is over the items", function()
		openBank()
		A.Clear(6, 2)
		bankUpdate(6)
		BW.scroll.mouseOver = true
		Fake.Fire(BW.reflowButton, "OnClick")
		assert.equal(SB.L.REFLOW_WAITING, BW.frame.title.text)
		assert.equal(1, #B.placeholdersInUse)
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
		assert.same({ "- Character bank (2)  - deposits go here", "- Warband bank (2)" }, labels())
		assert.equal(SB.L.VIEW_TO_SECTIONS, BW.viewButton.text)
		Fake.Fire(BW.viewButton, "OnClick")
		assert.equal("sections", SB.Config.Get("bank.view"))
		assert.equal(10, #labels())
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

	it("an item dropped on a bank section header goes to the bags window's drag-to-assign", function()
		openBank()
		A.cursor = { itemID = Fixtures.JUNK }
		header("bank:c_herbs").scripts.OnReceiveDrag(header("bank:c_herbs"))
		assert.same({ "c_herbs" }, SB.BagsWindow.dropped)
	end)

	it("the first visit to a full bank (1,078 slots) is laid out within 80 ms (spec 9)", function()
		Big.Install(A)
		local t0 = os.clock()
		openBank()
		local ms = (os.clock() - t0) * 1000
		assert.equal(1078, #BW.view.cells)
		assert.truthy(ms <= 80, ("first bank open took %.1f ms"):format(ms))
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
		for _, path in ipairs({ "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/BagsWindow.lua",
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
		W.Reflow("reflow")
		assert.equal(headers, bankHeaders(), "the bank's headers survived the bags regroup")
		assert.truthy(bankPlaceholder.shown, "and so did its placeholder")
		BW.Reflow("reflow")
		assert.truthy(#SB.SectionHeaders.inUse > headers, "the bags window kept its headers too")
	end)
end)
