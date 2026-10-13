-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 8: the bank window's list view (spec 2.2 v1.3, the bags window's since week 5) over the real
-- engine, button pool and GroupView: each group's sections, one row per slot, the slot's own secure
-- button scaled to the row (never made, reparented or re-ID'd), the shared column order, P5 and F6.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local function blizzardBank()
	local bf = Fake.New("Frame", UIParent)
	bf.TabSystem = Fake.New("Frame", bf)
	bf.TabSystem.tabs = { Fake.New("Button", bf.TabSystem), Fake.New("Button", bf.TabSystem) }
	return bf
end

describe("BankWindow list view (week 8)", function()
	local SB, A, BW, B, GV
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
		BW = Env.LoadBank(SB)
		B, GV = SB.Buttons, SB.GroupView
		SB.Emit("SB_LOGIN")
		A.SetBagSize(6, 8)
		A.SetBagSize(12, 8)
		A.items[Fixtures.HEALING_POTION].sellPrice = 100 -- the stack of 5: 500
		A.items[Fixtures.FLASK].sellPrice = 1000 -- one: 1000
		A.Put(6, 1, Fixtures.HEALING_POTION, 5)
		A.Put(6, 2, Fixtures.HERB, 20)
		A.Put(6, 3, Fixtures.FLASK, 1)
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

	local function labels()
		local out = {}
		for _, h in ipairs(SB.SectionHeaders.inUse) do
			if h.shown then
				out[#out + 1] = h.text.text
			end
		end
		return out
	end

	local function round(v)
		return math.floor(v * 1000 + 0.5) / 1000
	end

	-- Where a button sits in the scroll child: its point's offsets are in its own scale.
	local function on(bag, slot)
		local b = B.Get(bag, slot)
		local p = b.points[#b.points]
		return { round(p[4] * b.scale), round(p[5] * b.scale) }
	end

	local function row(bag, slot)
		return BW.rows.rows[B.Get(bag, slot)]
	end

	local function lastTopLeft(f)
		local found
		for _, p in ipairs(f.points) do
			if p[1] == "TOPLEFT" then
				found = p
			end
		end
		return found
	end

	-- Mutations: in GroupView's build(), drop the SB.Sort.DisplayOrder call; in its place(), offset by x, y
	-- (not x / scale, y / scale).
	it("each group's sections, one row per slot: the slot's own button at row size, its texts beside it", function()
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
		SB.Config.Set("bank.view", "list")
		openBank()
		assert.equal("list", BW.view.drawn)
		assert.same({ "- Character bank (3)  - right-clicked items land here", "- Warband bank (2)",
			"- New (0)", "- Consumables (2) - 15s vendor", "- Herbs (1)", "- Free (5)",
			"- New (0)", "- BoE gear (1)", "- Ore (1)", "- Free (6)" }, labels())
		assert.equal(GV.LIST_ROW / GV.SLOT, B.Get(6, 1).scale, "drawn at the row's height")
		local potion, flask = on(6, 1), on(6, 3)
		assert.equal(GV.PAD, potion[1], "every button sits at the row's left edge")
		assert.equal(GV.LIST_ROW + GV.LIST_GAP, flask[2] - potion[2], "flask (1000) one row above potion (500)")
		assert.equal(potion[2], row(6, 1).points[1][5], "the row's texts sit beside its button")
		assert.equal(GV.PAD + GV.LIST_ROW + GV.ROW_TEXT_GAP, row(6, 1).points[1][4])
		assert.same({ "Algari Healing Potion", "5", "285" }, { row(6, 1).name.text, row(6, 1).count.text,
			row(12, 2).ilvl.text })
		assert.equal(SB.L.LIST_FREE:format(5), row(6, 4).name.text, "the free tile's row says how many are free")
		assert.equal(GV.LIST_WIDTH, BW.child.w)
		assert.truthy(BW.columnsBar.frame.shown)
		assert.equal("Value v", BW.columnsBar.buttons.value.label.text)
		assert.equal(-(BW.HEADER + BW.COLUMNS_H), lastTopLeft(BW.scroll)[5], "the items start under the column bar")
	end)

	-- Mutation: in BW.SetView, save `view` as "sections" whatever was asked.
	it("SetView draws categories, list and grid, each answered in the title", function()
		openBank()
		BW.SetView("list")
		assert.same({ "list", "list", SB.L.BANK_VIEW_LIST },
			{ SB.Config.Get("bank.view"), BW.view.drawn, BW.frame.title.text })
		assert.truthy(row(6, 1).shown)
		BW.SetView("grid")
		assert.same({ "grid", "grid", SB.L.BANK_VIEW_GRID },
			{ SB.Config.Get("bank.view"), BW.view.drawn, BW.frame.title.text })
		assert.equal(1, B.Get(6, 1).scale, "full size again")
		assert.falsy(row(6, 1).shown)
		assert.falsy(BW.columnsBar.frame.shown)
		assert.equal(-BW.HEADER, lastTopLeft(BW.scroll)[5])
		BW.SetView("sections")
		assert.same({ "sections", "sections", SB.L.BANK_VIEW_SECTIONS },
			{ SB.Config.Get("bank.view"), BW.view.drawn, BW.frame.title.text })
	end)

	-- One order for every list (bags.list). Mutations: in GroupView's busyCheck, drop the rows.IsMouseOver
	-- check (the list re-sorts under the mouse); delete the bank window's SB_LIST_SORTED RequestLayout.
	it("a column click sorts every list by it (saved, answered); the bank's list regroups once the mouse leaves its row",
		function()
			SB.Config.Set("bank.view", "list")
			openBank()
			row(6, 1).mouseOver = true
			Fake.Fire(BW.columnsBar.buttons.name, "OnClick")
			assert.same({ "name", false }, { SB.Config.Get("bags.list.sort"), SB.Config.Get("bags.list.desc") })
			assert.equal("Sorted by Name, A to Z", BW.frame.title.text)
			assert.equal("Name ^", BW.columnsBar.buttons.name.label.text)
			assert.truthy(on(6, 3)[2] > on(6, 1)[2], "held: nothing moved under the row")
			row(6, 1).mouseOver = false
			A.Advance(GV.RETRY)
			assert.truthy(on(6, 1)[2] > on(6, 3)[2], "Algari Healing Potion above Flask of Alchemical Chaos")
			assert.equal("listsort", BW.view.stats.lastLayoutReason)
			SB.Sort.Save("value", true) -- a sort saved elsewhere (the bags' bar, /swagbag list)
			assert.truthy(on(6, 3)[2] > on(6, 1)[2], "the bank's list follows")
		end)

	-- Spec 4.3 in the list. Mutations: in GroupView's renderExtras, drop the rows.Ghosts call; in its showAt,
	-- drop the rows.Place call.
	it("a deposit lands in New as a row; a withdrawal leaves a row-size placeholder and a ghost row", function()
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
		SB.Config.Set("bank.view", "list")
		openBank()
		local herb, ore = on(6, 2), on(12, 1)
		A.Put(6, 5, Fixtures.JUNK, 3)
		bankUpdate(6)
		assert.equal(on(6, 5)[2], row(6, 5).points[1][5], "its row is beside it")
		assert.same({ "Broken Tooth", "3" }, { row(6, 5).name.text, row(6, 5).count.text })
		A.Clear(6, 2)
		bankUpdate(6)
		assert.equal(1, #B.placeholdersInUse)
		assert.equal(GV.LIST_ROW, B.placeholdersInUse[1].w)
		local ghost = BW.rows.ghosts[1]
		assert.same({ SB.L.LIST_BANK_GONE, herb[2], true }, { ghost.name.text, ghost.points[1][5], ghost.shown })
		assert.same(ore, on(12, 1), "nothing else moved")
	end)

	-- F6 (item safety). Mutation: in GroupView's commit, `if b.view == "list" and not scaleAll(b, listScale())`
	-- -> `if false` (a full-size secure button would be drawn in a 24 px row).
	it("F6: a bank button whose scale does not take: the bank shows categories, says so once, records it", function()
		openBank()
		B.Get(12, 2).SetScale = function() end
		BW.SetView("list")
		assert.equal("list", SB.Config.Get("bank.view"))
		assert.equal("sections", BW.view.drawn)
		assert.equal(1, B.Get(6, 1).scale, "every button back at full size")
		assert.falsy(BW.columnsBar.frame.shown)
		assert.same({ SB.L.LIST_SCALE_FALLBACK_BANK }, A.Lines())
		assert.equal("bank.listScale", SB.ErrorTrap.Recent()[1].label)
		assert.falsy(SB.SafeMode.IsOn("bank"))
		BW.Reflow("reflow")
		assert.equal(1, #A.Lines(), "said once per opening")
	end)

	-- Spec 4.1. Mutation: in ListRows' create(), make the row an "ItemButton" from ContainerFrameItemButtonTemplate.
	it("in combat too, the list only scales and places the secure bank buttons: never made, reparented or re-ID'd",
		function()
			openBank()
			local made = #Fake.created
			local strict = {}
			for _, bag in ipairs({ 6, 12 }) do
				for slot = 1, 8 do
					strict[#strict + 1] = Fake.Strict(B.Get(bag, slot))
				end
			end
			A.combat = true
			BW.SetView("list")
			assert.equal("list", BW.view.drawn)
			for i = made + 1, #Fake.created do
				local f = Fake.created[i]
				assert.truthy(f.kind == "Frame" or f.kind == "Button", f.kind)
				assert.falsy(f.template == "ContainerFrameItemButtonTemplate")
			end
			local scaled = 0
			for _, b in ipairs(strict) do
				for _, call in ipairs(b.log) do
					assert.falsy(call.name == "SetParent" or call.name == "SetID", call.name)
					scaled = scaled + (call.name == "SetScale" and 1 or 0)
				end
			end
			assert.equal(16, scaled)
		end)

	-- AC5.1. Mutation: the bank search box's setDimmed back to SB.Buttons.SetDimmed (rows stay bright).
	it("the bank's search dims a non-matching row with its button", function()
		SB.Config.Set("bank.show", "both") -- both groups open (week 13: the default opens one)
		SB.Config.Set("bank.view", "list")
		openBank()
		BW.searchBox.editBox:SetText("ore")
		Fake.Fire(BW.searchBox.editBox, "OnTextChanged")
		A.Advance(0.2)
		assert.same({ B.DIM_ALPHA, B.DIM_ALPHA }, { row(6, 1).alpha, B.Get(6, 1).alpha })
		assert.equal(1, row(12, 1).alpha)
	end)

	-- F8. Mutations: in GroupView's v.SetRecord, drop the rows.Paint call; in the bank window's SB_PRICES_CHANGED
	-- handler, drop BW.view.RefreshRows().
	it("a count change and new prices repaint the bank's rows in place; nothing moves", function()
		SB.Config.Set("bank.view", "list")
		openBank()
		local potion, reason = on(6, 1), BW.view.stats.lastLayoutReason
		A.Put(6, 1, Fixtures.HEALING_POTION, 3)
		bankUpdate(6)
		assert.equal("3", row(6, 1).count.text)
		A.auctionator = { prices = { [A.GetSlot(6, 2).link] = 90000 } }
		A.auctionatorCallback()
		A.Advance(0.5)
		assert.equal("180g", row(6, 2).value.text)
		assert.same({ potion, reason }, { on(6, 1), BW.view.stats.lastLayoutReason })
	end)

	-- Week 8 ruling Q4. Mutation: drop `BW.scaleWarned` from the reset in BW's close path (BW.sortPending, ... = false).
	it("F6: the fallback is said once per opening, so a second opening says it again", function()
		openBank()
		B.Get(12, 2).SetScale = function() end
		BW.SetView("list")
		assert.equal(1, #A.Lines())
		SB.eventFrame:Fire("BANKFRAME_CLOSED")
		assert.falsy(BW.scaleWarned)
		openBank()
		assert.equal("sections", BW.view.drawn)
		assert.equal(2, #A.Lines(), "a new opening says it again")
	end)

	-- Week 8 (final review F6 fallback, P5). The fallback to categories moves buttons, so it waits for the mouse
	-- like any layout. Mutation: in GroupView's RequestLayout, `commit(b, pos, reason, t0, true)` -> `commit(b, pos, reason, t0)`.
	it("F6: a list that falls back to categories waits while a row is under the mouse, then lands", function()
		SB.Config.Set("bank.view", "list")
		openBank()
		assert.equal("list", BW.view.drawn)
		local before = on(6, 1)
		B.Get(12, 2).scale = 1
		B.Get(12, 2).SetScale = function() end -- a scale that no longer takes
		row(6, 1).mouseOver = true
		BW.Reflow("reflow")
		assert.equal("list", BW.view.drawn, "held: nothing drawn under the mouse")
		assert.same(before, on(6, 1))
		row(6, 1).mouseOver = false
		A.Advance(GV.RETRY)
		assert.equal("sections", BW.view.drawn)
		assert.equal(1, B.Get(6, 1).scale)
		assert.equal(1, #SB.ErrorTrap.Recent(), "recorded once")
	end)

	-- Week 8 deferred (final re-review): a held fallback left the buttons it had already shrunk small until the
	-- retry landed, under categories still drawn at full size (smaller click targets meanwhile). Mutation: in
	-- GroupView's listFailed(), `if not held or v.drawn ~= "list" then` -> `if not held then`.
	it("F6: a fallback held under the mouse puts the drawn categories' buttons back at full size at once", function()
		openBank()
		A.Clear(6, 1) -- a withdrawal: the full layout that follows regroups the potion's neighbours
		bankUpdate(6)
		B.Get(12, 2).SetScale = function() end
		B.Get(6, 3).IsMouseOver = function(self) return self.scale ~= 1 end -- shrunk, the flask slides under the mouse
		BW.SetView("list")
		assert.equal("sections", BW.view.drawn, "held: the categories stay drawn")
		assert.equal(1, #B.placeholdersInUse, "nothing regrouped yet")
		for _, bag in ipairs({ 6, 12 }) do
			for slot = 1, 8 do
				assert.equal(1, B.Get(bag, slot).scale, bag .. ":" .. slot)
			end
		end
		A.Advance(GV.RETRY)
		assert.equal("sections", BW.view.drawn)
		assert.equal(0, #B.placeholdersInUse, "the retry landed the fallback")
	end)

	-- Week 8 (final review). The title says what is drawn. Mutation: in BW.SetView, flash
	-- VIEW_FLASH[view] (the list's title) whatever the layout drew.
	it("F6: the view's title says categories when the list could not be drawn", function()
		openBank()
		B.Get(12, 2).SetScale = function() end
		BW.SetView("list")
		assert.equal(SB.L.BANK_VIEW_SECTIONS, BW.frame.title.text)
	end)

	-- Week 8 ruling Q11. Mutation: in GroupView's listFailed(), drop `v.listFailed = true`.
	it("F6: after a fallback the visit stays on categories: no button is scaled again, no second error", function()
		openBank()
		B.Get(12, 2).SetScale = function() end
		BW.SetView("list")
		assert.equal("sections", BW.view.drawn)
		local errors, scales = #SB.ErrorTrap.Recent(), 0
		local button = B.Get(6, 1)
		local realSetScale = button.SetScale
		button.SetScale = function(self, scale)
			scales = scales + 1
			return realSetScale(self, scale)
		end
		BW.Reflow("reflow")
		bankUpdate(6)
		assert.same({ "sections", 0, errors }, { BW.view.drawn, scales, #SB.ErrorTrap.Recent() })
		assert.equal(1, #A.Lines())
	end)

	-- Week 8 ruling Q3 (W5-1). Mutation: in GroupView's showAt, drop the `if shown and isList() and not scaleIs(...)` branch.
	it("a button whose scale changed after the list was drawn stays hidden, row and all, until a layout follows", function()
		SB.Config.Set("bank.view", "list")
		openBank()
		B.Get(6, 5):SetScale(1)
		A.Put(6, 5, Fixtures.JUNK, 3)
		bankUpdate(6) -- showAt places the arrival, but it is not at row size
		assert.falsy(B.Get(6, 5).shown)
		assert.falsy(row(6, 5) and row(6, 5).shown, "no row for a button that is not drawn")
		A.Advance(GV.RETRY)
		assert.equal(GV.LIST_ROW / GV.SLOT, B.Get(6, 5).scale)
		assert.truthy(B.Get(6, 5).shown)
		assert.truthy(row(6, 5).shown)
	end)

	-- Week 8 ruling Q5. Mutation: in GroupView's showAt, drop the rows.Place call (a spare keeps its row).
	it("a button that leaves the layout takes its row with it", function()
		SB.Config.Set("bank.view", "list")
		openBank()
		assert.truthy(row(6, 3).shown)
		A.SetBagSize(6, 2) -- slot 3 is gone
		bankUpdate(6)
		assert.falsy(B.Get(6, 3).shown)
		assert.falsy(row(6, 3).shown)
	end)

	-- Week 8 ruling Q9. Mutation: drop `goneTip = L.LIST_BANK_GONE_TIP` from BankWindow's ListRows options.
	it("a ghost row in the bank says it regroups when the bank closes (tooltip and click answer)", function()
		SB.Config.Set("bank.view", "list")
		openBank()
		A.Clear(6, 2)
		bankUpdate(6)
		local ghost = BW.rows.ghosts[1]
		Fake.Fire(ghost, "OnEnter")
		assert.equal(SB.L.LIST_BANK_GONE_TIP, GameTooltip.text)
		Fake.Fire(ghost, "OnMouseUp", "LeftButton")
		assert.equal(SB.L.LIST_BANK_GONE_TIP, BW.frame.title.text)
	end)

	-- Week 8 ruling Q9 (placeholder icon). Mutation: drop `goneTip = L.LIST_BANK_GONE_TIP, -- a placeholder's` from BW.view's cfg.
	it("a placeholder icon's tooltip in the bank says the bank, not the bag", function()
		SB.Config.Set("bank.view", "list")
		openBank()
		A.Clear(6, 2)
		bankUpdate(6)
		Fake.Fire(B.placeholdersInUse[1], "OnEnter")
		assert.equal(SB.L.LIST_BANK_GONE_TIP, GameTooltip.text)
	end)

	-- Stack grouping (0.14.0). Mutations: in GroupView's build, no totalOf for DisplayOrder (the warband's
	-- order stays, the bank's 65 sorts as its 45); one totals index shared by both groups (the warband's 7
	-- sorts as 72); paintStacks without the row's total (Count says 45); v.RefreshRows without paintStacks.
	it("a bank list row shows the total", function()
		for id, name in pairs({ [777002] = "Arathor Sage", [777003] = "Arathor Thyme" }) do -- two more herbs
			A.AddItem(id, { name = name, classID = A.ITEM_CLASS.Tradegoods, subclassID = A.TRADEGOODS_SUB.Herb,
				quality = 1, ilvl = 1, maxStack = 1000, bind = "none", isCraftingReagent = true })
		end
		A.Put(6, 4, Fixtures.HERB, 45)
		A.Put(6, 5, 777003, 50)
		A.Put(12, 3, Fixtures.HERB, 7)
		A.Put(12, 4, 777002, 30)
		SB.Sort.Save("count", true)
		SB.Config.Set("bank.show", "both")
		SB.Config.Set("bank.view", "list")
		openBank()
		assert.equal("list", BW.view.drawn)
		assert.falsy(B.Get(6, 2).shown, "the 20 hides under the 45's row")
		assert.equal("65", row(6, 4).count.text)
		assert.equal("- Herbs (2)", labels()[5], "the bank's Herbs: the Mycobloom icon and the thyme")
		assert.truthy(on(6, 4)[2] > on(6, 5)[2], "the bank's Mycobloom (65) sorts above its thyme (50)")
		assert.equal("7", row(12, 3).count.text, "the warband's 7 is its own")
		assert.truthy(on(12, 4)[2] > on(12, 3)[2], "the warband's sage (30) sorts above its Mycobloom (7)")
		SB.Emit("SB_PRICES_CHANGED") -- every row's Value is painted again: a grouped row keeps its total
		assert.equal("65", row(6, 4).count.text)
	end)
end)
