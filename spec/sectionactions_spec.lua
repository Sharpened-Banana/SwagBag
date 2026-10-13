-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip StaticPopupDialogs StaticPopup_Show StaticPopup_Hide YES NO
-- Week 7 (user pick 6): Shift+right-click a section header for Sell all (at a vendor, asks first) or
-- Send all to the bank / warband bank (at a bank). Moves go through the mover: out of combat, one at a
-- time, never under the mouse; one chat line when an action ends.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local GRAY = 400200

describe("Section actions (week 7)", function()
	local SB, A, SA, Mover, sections, shown, shownData
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		for _, f in ipairs({ "SwagBag/Engine/Locks.lua", "SwagBag/Engine/Mover.lua", "SwagBag/Engine/Vendor.lua" }) do
			files[#files + 1] = f
		end
		SB = Loader.New(files)
		A, Mover = SB.Adapter, SB.Mover
		SB.Config.Init(nil, nil)
		SB.Config.Set("vendor.autoSell", false)
		Fixtures.SmallBags(A)
		A.AddItem(GRAY, { name = "Frayed Robe", classID = A.ITEM_CLASS.Armor, subclassID = 1, equipLoc = "INVTYPE_CHEST",
			quality = 0, ilvl = 5, maxStack = 1, bind = "none", sellPrice = 50 })
		A.items[Fixtures.HERB].sellPrice = 10
		A.SetBagSize(1, 10)
		for slot = 1, 5 do
			A.Put(1, slot, Fixtures.HERB, 20)
		end
		SB.Inventory.ScanAll()
		Fake.Install()
		shown, shownData = nil, nil
		StaticPopupDialogs, YES, NO = {}, "Yes", "No"
		-- As Blizzard does: a dialog already up is cancelled (OnCancel) when the same one is shown again,
		-- unless noCancelOnReuse; the data given to Show reaches OnAccept as its second argument.
		StaticPopup_Show = function(which, _, _, data)
			local d = StaticPopupDialogs[which]
			if shown == which and d.OnCancel and not d.noCancelOnReuse then
				d.OnCancel(nil, shownData, "override")
			end
			shown, shownData = which, data
		end
		StaticPopup_Hide = function(which)
			if shown == which then
				shown, shownData = nil, nil
			end
		end
		-- The bags window as the actions read it: the Trade Goods section holds bag 1's herbs.
		sections = { c_tradegoods = { 1, 2, 3, 4, 5 } }
		SB.BagsWindow = { SectionSlots = function(id)
			local out = {}
			for _, slot in ipairs(sections[id] or {}) do
				if A.GetSlot(1, slot) then
					out[#out + 1] = { bag = 1, slot = slot, record = SB.Items.Describe(1, slot) }
				end
			end
			return out
		end }
		SB.BankWindow = { interaction = false }
		Loader.LoadFile(SB, "SwagBag/UI/SectionActions.lua")
		SA = SB.SectionActions
	end)

	after_each(function()
		Fake.Uninstall()
		StaticPopupDialogs, StaticPopup_Show, StaticPopup_Hide, YES, NO = nil, nil, nil, nil, nil
	end)

	-- Yes, as Blizzard presses it: the dialog's OnAccept with the data the question was shown with.
	local function accept()
		StaticPopupDialogs.SWAGBAG_SELL_ALL.OnAccept(nil, shownData)
	end

	local function used(kind)
		local out = {}
		for _, u in ipairs(A.used) do
			if u.kind == kind then
				out[#out + 1] = u.slot
			end
		end
		return out
	end

	local function texts()
		local out = {}
		for i, e in ipairs(SA.Entries("c_tradegoods")) do
			out[i] = e.text
		end
		return out
	end

	-- Mutation: in SA.Sellable, drop `not SB.Vendor.Protected(r)` (locked and set items would be sold).
	it("at a vendor Sell all asks first, then sells what a vendor pays for, never locked or set items", function()
		A.Put(1, 2, GRAY, 1, { inSet = true })
		A.Put(1, 3, Fixtures.HERB, 20, { hasNoValue = true })
		SB.Locks.Toggle(GRAY) -- also locks nothing else: the herbs stay sellable
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		assert.same({ "Sell all (3)" }, texts())
		SA.Entries("c_tradegoods")[1].run()
		assert.equal("SWAGBAG_SELL_ALL", shown)
		assert.equal("Sell 3 items from Trade Goods for about 6s 0c? " .. SB.L.SECTION_SELL_KEEPS,
			StaticPopupDialogs.SWAGBAG_SELL_ALL.text)
		assert.same({}, used("sell"), "nothing before the answer")
		accept()
		A.Advance(Mover.DELAY * 5)
		assert.same({ 1, 4, 5 }, used("sell"))
		assert.same({ "Sold 3 items for 6s 0c." }, A.Lines())
	end)

	-- Ruling R1: Sell all shares the visit's 12 with the auto-sell and /swagbag sell junk. Mutations: in
	-- SA.ConfirmSell, `math.min(#list, past and V.BUYBACK or V.Room())` -> `math.min(#list, V.BUYBACK)`; or
	-- `if past then` -> `if false then` (no word about the Buyback tab); or SA.SellConfirmed drops `p.past`.
	it("Sell all sells what still fits in the Buyback tab this visit; past that its question says so", function()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SB.Vendor.soldThisVisit = 10 -- the auto-sell sold 10 at this vendor
		SA.Entries("c_tradegoods")[1].run()
		assert.equal("Sell 2 items from Trade Goods for about 4s 0c? " .. SB.L.SECTION_SELL_KEEPS,
			StaticPopupDialogs.SWAGBAG_SELL_ALL.text)
		accept()
		A.Advance(Mover.DELAY * 5)
		assert.same({ 1, 2 }, used("sell"))
		SA.Entries("c_tradegoods")[1].run()
		assert.equal("Sell 3 items from Trade Goods for about 6s 0c? " .. SB.L.SECTION_SELL_PAST .. " "
			.. SB.L.SECTION_SELL_KEEPS, StaticPopupDialogs.SWAGBAG_SELL_ALL.text)
		accept()
		A.Advance(Mover.DELAY * 5)
		assert.same({ 1, 2, 3, 4, 5 }, used("sell"))
		assert.same({ "Sold 2 items for 4s 0c. " .. SB.L.VENDOR_MORE:format(3), "Sold 3 items for 6s 0c." }, A.Lines())
	end)

	-- Ruling R19: a gold-maker sees what the stack would fetch at auction before saying yes. Mutation: in
	-- SA.ConfirmSell, `if worth > copper then` -> `if false then`.
	it("Sell all's question names the Auction House value when it is higher than the vendor's", function()
		A.auctionator = { prices = { ["item:" .. Fixtures.HERB] = 1000 } } -- 10s each at auction, 10c at a vendor
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SA.Entries("c_tradegoods")[1].run()
		assert.equal("Sell 5 items from Trade Goods for about 10s 0c? At the Auction House they are worth about 10g 0s"
			.. " 0c. " .. SB.L.SECTION_SELL_KEEPS, StaticPopupDialogs.SWAGBAG_SELL_ALL.text)
	end)

	-- Week 9 ruling R0: the Auction House sentence does not follow the price source. Mutation: in SA.Sellable,
	-- `local ah = P and not P.Bound(r) and P.AuctionValue(r.link, r.itemID)` -> `local ah = P and P.Value(r.link,
	-- r.itemID, P.Bound(r))`.
	it("with Vendor chosen as the price source, Sell all's question still names the Auction House value", function()
		SB.Config.Set("prices.source", "vendor")
		A.auctionator = { prices = { ["item:" .. Fixtures.HERB] = 1000 } }
		assert.same({ 10, "Vendor" }, { SB.Prices.Value("item:" .. Fixtures.HERB, Fixtures.HERB) },
			"the windows show the vendor's")
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SA.Entries("c_tradegoods")[1].run()
		assert.equal("Sell 5 items from Trade Goods for about 10s 0c? At the Auction House they are worth about 10g 0s"
			.. " 0c. " .. SB.L.SECTION_SELL_KEEPS, StaticPopupDialogs.SWAGBAG_SELL_ALL.text)
	end)

	-- Mutations: SA.SellConfirmed skips the atVendor() check; MERCHANT_CLOSED stops hiding the question.
	it("a vendor that closes takes the question down; a Yes that still arrives sells nothing and says so", function()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SA.Entries("c_tradegoods")[1].run()
		local data = shownData
		SB.eventFrame:Fire("MERCHANT_CLOSED")
		assert.is_nil(shown, "the question is gone with the vendor")
		StaticPopupDialogs.SWAGBAG_SELL_ALL.OnAccept(nil, data)
		A.Advance(Mover.DELAY * 5)
		assert.same({}, used("sell"))
		assert.same({ SB.L.VENDOR_NOT_OPEN }, A.Lines())
	end)

	-- Mutation: ConfirmSell drops the data argument of StaticPopup_Show (and OnAccept reads SA.pending again).
	it("a second question while the first is up (Blizzard cancels the first on reuse): Yes sells the second", function()
		sections.c_other = { 6, 7 }
		A.Put(1, 6, Fixtures.HERB, 20)
		A.Put(1, 7, Fixtures.HERB, 20)
		SB.Inventory.ScanAll()
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SA.Entries("c_tradegoods")[1].run()
		SA.Entries("c_other")[1].run()
		accept()
		A.Advance(Mover.DELAY * 5)
		assert.same({ 6, 7 }, used("sell"))
		assert.equal(1, #A.Lines(), "answers once")
	end)

	-- Mutation: ConfirmSell does not escape %.
	it("the question survives a % in a category name and says '1 item' for one", function()
		SB.Categories.Name = function() return "100% Herbs" end
		SB.eventFrame:Fire("MERCHANT_SHOW")
		sections.c_tradegoods = { 1 }
		SA.Entries("c_tradegoods")[1].run()
		local text = StaticPopupDialogs.SWAGBAG_SELL_ALL.text
		assert.truthy(text:find("Sell 1 item from 100%% Herbs for about", 1, true))
		assert.truthy(pcall(string.format, text), "Blizzard formats the text again: a bare % would error")
	end)

	-- Mutations: SA.Bankable ignores AllowedInBank; or send() passes "bank" whatever the kind.
	it("at a bank: Send all to the bank or the warband bank, leaving out what the warband bank refuses", function()
		A.notAllowed.warband[Fixtures.HERB] = true
		A.Put(1, 2, Fixtures.ORE, 10)
		SB.Inventory.ScanAll()
		SB.BankWindow.interaction = true
		assert.same({ "Send all to bank (5)", "Send all to warband bank (1)" }, texts())
		SA.Entries("c_tradegoods")[2].run()
		A.Advance(Mover.DELAY * 3)
		assert.same({ 2 }, used("warband"))
		assert.same({}, used("bank"))
		assert.same({ "Sent 1 item from Trade Goods to the warband bank." }, A.Lines())
	end)

	-- Mutation: in send()'s done, drop the `result.why == "stuck"` branch.
	it("a bank that stops taking items (full) ends the run and says how many stayed", function()
		SB.BankWindow.interaction = true
		local n = 0
		A.onUse = function(bag, slot)
			n = n + 1
			if n <= 2 then
				A.Clear(bag, slot)
			end -- the third stays: the tab is full
		end
		SA.Entries("c_tradegoods")[1].run()
		A.Advance(Mover.DELAY * 10)
		assert.same({ 1, 2, 3 }, used("bank"))
		assert.same({ "Sent 2 items from Trade Goods to the bank. The bank did not take the next one (full, or a tab"
			.. " that does not take it), so 3 stayed." }, A.Lines())
	end)

	-- P2. Mutations: in SA.Open, return false without a chat line when there are no entries; or drop the
	-- combat check in SA.ConfirmSell (a question would come first, and nothing could sell).
	it("nowhere to act: one line says where actions work; Free has none; in combat nothing moves", function()
		SA.Open("c_tradegoods")
		SB.BankWindow.interaction = true
		SA.Open("free")
		A.combat = true
		SA.Entries("c_tradegoods")[1].run()
		SB.eventFrame:Fire("MERCHANT_SHOW") -- in combat, with nothing for the auto-sell or the repair to do
		SA.Entries("c_tradegoods")[1].run() -- Sell all
		assert.is_nil(shown, "no question in combat")
		assert.same({}, used("bank"))
		local L = SB.L
		assert.same({ L.SECTION_WHERE, L.SECTION_NOTHING:format("Free"), L.SECTION_COMBAT, L.SECTION_COMBAT }, A.Lines(),
			"auto-sell off and nothing to repair: the vendor itself says nothing (ruling R9)")
	end)

	-- Mutations: the menu button's OnClick runs without hiding the menu first; or the menu frame is never themed
	-- (ruling R14: drop `SB.Theme.Window(f, "dialog")`).
	it("the menu: a button per action and Cancel, beside the header; a click runs it and closes the menu", function()
		SB.BankWindow.interaction = true
		local themed
		SB.Theme = { Window = function(f, kind) themed = { f, kind } end, Button = function() end }
		local header = Fake.New("Button", UIParent)
		assert.truthy(SA.Open("c_tradegoods", header))
		local m = SA.menu
		assert.same({ m, "dialog" }, themed, "themes restyle the menu like every SwagBag window")
		assert.same({ "Send all to bank (5)", "Send all to warband bank (5)", "Cancel" },
			{ m.buttons[1].text, m.buttons[2].text, m.buttons[3].text })
		assert.same({ "TOPLEFT", header, "BOTTOMLEFT", 24, 0 }, m.points[1])
		Fake.Fire(m.buttons[3], "OnClick")
		assert.falsy(m.shown, "Cancel closes")
		SA.Open("c_tradegoods", header)
		Fake.Fire(m.buttons[1], "OnClick")
		assert.falsy(m.shown)
		assert.same({ 1 }, used("bank"), "the first move at once")
		SA.Open("c_tradegoods", header)
		SB.Emit("SB_BAGS_CLOSED")
		assert.falsy(m.shown, "closing the bags closes the menu")
	end)

	-- Mutation: SA.Hint skips the SA.Available() check (every header gets a tooltip).
	it("a header's tooltip names Shift+right-click only while a vendor or bank is open", function()
		local header = Fake.New("Button", UIParent)
		SA.Hint("c_tradegoods", header)
		assert.is_nil(GameTooltip.calls.SetOwner, "no vendor, no bank: no tooltip")
		SB.eventFrame:Fire("MERCHANT_SHOW")
		SA.Hint("c_tradegoods", header)
		assert.equal("Trade Goods", GameTooltip.text)
		assert.equal(SB.L.SECTION_HINT_VENDOR, GameTooltip.calls.AddLine[1])
	end)
end)

-- Stack grouping (0.14.0), Review Focus 4: Sell all acts on every real stack, also the ones hidden under a
-- grouped icon. The real bags window here (its SectionSlots), not a stand-in.
describe("Sell all with grouped stacks (0.14.0)", function()
	local SB, A, SA, W
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		for _, f in ipairs({ "SwagBag/Engine/Locks.lua", "SwagBag/Engine/Mover.lua", "SwagBag/Engine/Vendor.lua" }) do
			files[#files + 1] = f
		end
		SB = Loader.New(files)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		SB.Config.Set("vendor.autoSell", false)
		Fixtures.SmallBags(A)
		A.items[Fixtures.HERB].sellPrice = 10
		A.Put(0, 7, Fixtures.HERB, 45)
		A.Put(0, 8, Fixtures.HERB, 7)
		Fake.Install()
		Env.PaintGlobals()
		StaticPopupDialogs = {}
		for _, path in ipairs({ "SwagBag/UI/Buttons.lua", "SwagBag/UI/SectionHeaders.lua", "SwagBag/UI/ListRows.lua",
			"SwagBag/UI/BagsWindow.lua", "SwagBag/UI/SectionActions.lua" }) do
			Loader.LoadFile(SB, path)
		end
		W, SA = SB.BagsWindow, SB.SectionActions
		SB.Emit("SB_LOGIN") -- the herbs are in the bags at login: seen
		Fixtures.Settle(SB)
	end)

	after_each(function()
		Env.ClearPaintGlobals()
		Fake.Uninstall()
		StaticPopupDialogs = nil
	end)

	-- Mutation: in W.SectionSlots, iterate the cells only (drop the members loop).
	it("Sell all includes the hidden stack", function()
		assert.truthy(W.Open())
		assert.falsy(SB.Buttons.Get(0, 8):IsShown(), "the 7 hides under the 45's icon")
		local shown = SB.Buttons.Get(0, 7)
		assert.same({ 52, 45 }, { SB.Buttons.StackOf(shown).total, shown.count }, "the real pool: count stays the stack's")
		local out = {}
		for _, it in ipairs(SA.Sellable("c_herbs")) do
			out[#out + 1] = it.slot .. "x" .. it.count
		end
		assert.same({ "7x45", "8x7" }, out)
	end)
end)
