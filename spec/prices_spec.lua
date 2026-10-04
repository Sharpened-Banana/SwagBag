local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua",
	"SwagBag/Engine/Query/Query.lua", "SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Layout.lua",
	"SwagBag/Engine/Prices.lua", "SwagBag/Providers/Auctionator.lua",
}

local HERB_LINK = "|cffffffff|Hitem:210796::::::::80:::::|h[Mycobloom]|h|r"
local RING_LINK = "|cffa335ee|Hitem:225001::::::::80:::::|h[Band of the Fallen]|h|r"

describe("Prices (spec F10, 3.3)", function()
	local SB, A, P
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.Install(A)
		A.items[Fixtures.HERB].sellPrice = 1500
		A.items[Fixtures.BOE_RING].sellPrice = 250000
		P = SB.Prices
		SB.Emit("SB_LOGIN")
	end)

	-- Week 8 (final review). A secret link must never be a table key (indexing with one errors in WoW):
	-- it prices by itemID. Mutation: delete the `if SB.Adapter.IsSecret(link) then link = nil end` guard in P.Value.
	it("a secret link prices by itemID: never a cache key, never an error", function()
		local secretLink = "item:secret"
		A.IsSecret = function(v) return v == secretLink end
		assert.same({ 1500, "Vendor" }, { P.Value(secretLink, Fixtures.HERB) })
		assert.truthy(P.cache[Fixtures.HERB])
		assert.is_nil(P.cache[secretLink])
		assert.same({ 1500, "Vendor" }, { P.Value(secretLink, Fixtures.HERB, true) })
		assert.is_nil(P.boundCache[secretLink])
	end)

	it("money: gold with thousands separators, else silver, else copper", function()
		assert.same({ "12c", "35s", "1,240g", "123,456g", "1g", "0c" },
			{ P.Money(12), P.Money(3550), P.Money(12400000), P.Money(1234567890), P.Money(10000), P.Money(0) })
	end)

	-- Week 7 (user pick 7). Mutation: in WorthThreshold, math.ceil -> math.floor (top 10% of 5 values: none).
	it("worth-money line: a fixed gold amount, or the top percent of the valued stacks; off or nothing valued: none", function()
		assert.equal(1000000, P.WorthThreshold({}, "fixed", 100, 10))
		assert.equal(60, P.WorthThreshold({ 10, 20, 30, 40, 50, 60, 70, 0 }, "top", 100, 20), "20% of 7 rounds up to 2")
		assert.equal(500, P.WorthThreshold({ 5, 500, 50, 0, 1 }, "top", 100, 10), "at least one item")
		assert.is_nil(P.WorthThreshold({ 0, 0 }, "top", 100, 10))
		assert.is_nil(P.WorthThreshold({ 10 }, "off", 100, 10))
	end)

	it("without Auctionator the vendor price answers and the source is Vendor", function()
		assert.same({ 1500, "Vendor" }, { P.Value(HERB_LINK, Fixtures.HERB) })
		assert.equal("Vendor", P.Source())
	end)

	it("with Auctionator its price wins; an item it has no price for falls back to the vendor", function()
		A.auctionator = { prices = { [HERB_LINK] = 42000 } }
		P.Invalidate()
		assert.equal("Auctionator", P.Source())
		assert.same({ 42000, "Auctionator" }, { P.Value(HERB_LINK, Fixtures.HERB) })
		assert.same({ 250000, "Vendor" }, { P.Value(RING_LINK, Fixtures.BOE_RING) })
	end)

	-- Week 9 (user pick 10). Mutations: give TSM a priority above Auctionator's; or in active() drop the choice
	-- check (every available provider answers, whatever the setting).
	it("by default Auctionator answers, else TSM, else the vendor; prices.source picks one, the vendor fills in", function()
		Loader.LoadFile(SB, "SwagBag/Providers/TSM.lua")
		A.tsm = { prices = { DBMarket = { [HERB_LINK] = 30000 } } }
		P.Invalidate()
		assert.same({ "TSM", 30000 }, { P.Source(), (P.Value(HERB_LINK, Fixtures.HERB)) }, "no Auctionator: TSM")
		A.auctionator = { prices = { [HERB_LINK] = 42000 } }
		P.Invalidate()
		assert.same({ "Auctionator", 42000 }, { P.Source(), (P.Value(HERB_LINK, Fixtures.HERB)) }, "both: Auctionator")
		SB.Config.Set("prices.source", "tsm")
		assert.same({ "TSM", 30000 }, { P.Source(), (P.Value(HERB_LINK, Fixtures.HERB)) })
		assert.same({ 250000, "Vendor" }, { P.Value(RING_LINK, Fixtures.BOE_RING) }, "what TSM has no price for")
		SB.Config.Set("prices.source", "vendor")
		assert.same({ "Vendor", 1500 }, { P.Source(), (P.Value(HERB_LINK, Fixtures.HERB)) })
		SB.Config.Set("prices.source", "auctionator")
		A.auctionator = nil
		P.Invalidate()
		assert.same({ "Vendor", 1500 }, { P.Source(), (P.Value(HERB_LINK, Fixtures.HERB)) }, "the chosen one is not loaded")
	end)

	-- Mutations: the TSM provider asks for "DBMarket" whatever the setting; or the SB_CONFIG_CHANGED listener
	-- does not drop the cache.
	it("TSM's price string follows the setting; a new source or string drops the cache and refreshes the totals", function()
		Loader.LoadFile(SB, "SwagBag/Providers/TSM.lua")
		local refreshed = 0
		SB.On("SB_PRICES_CHANGED", function() refreshed = refreshed + 1 end)
		A.tsm = { prices = { DBMarket = { [HERB_LINK] = 30000 }, DBMinBuyout = { [HERB_LINK] = 25000 } } }
		SB.Config.Set("prices.source", "tsm")
		assert.equal(30000, P.Value(HERB_LINK, Fixtures.HERB))
		SB.Config.Set("prices.tsm", "DBMinBuyout")
		assert.equal(25000, P.Value(HERB_LINK, Fixtures.HERB))
		assert.same({ HERB_LINK, "DBMinBuyout" }, A.tsmCalls[#A.tsmCalls])
		A.Advance(P.REFRESH_DELAY)
		assert.equal(1, refreshed, "one refresh after the burst")
		assert.equal("TSM (DBMinBuyout)", P.SourceText())
		SB.Config.Set("prices.source", "auto")
		assert.equal("TSM (DBMinBuyout)", P.SourceText(), "auto, no Auctionator: TSM")
		A.tsm = nil
		P.Invalidate()
		assert.equal("Vendor", P.SourceText())
	end)

	-- Preflight S2: TSM's data may load after the first lookup. Mutation: in P.Value, `if hit and (hit[3] == nil
	-- or now <= hit[3]) then` -> `if hit then` (a TSM "no price" kept for the cache's 10 minutes).
	it("a TSM 'no price' is kept 30 seconds only, so TSM data that arrives after login is used", function()
		Loader.LoadFile(SB, "SwagBag/Providers/TSM.lua")
		A.tsm = { prices = { DBMarket = {} } }
		P.Invalidate()
		assert.same({ 1500, "Vendor" }, { P.Value(HERB_LINK, Fixtures.HERB) })
		A.tsm.prices.DBMarket[HERB_LINK] = 30000
		assert.same({ 1500, "Vendor" }, { P.Value(HERB_LINK, Fixtures.HERB) }, "kept a moment")
		A.Advance(P.MISS_AGE + 1)
		assert.same({ 30000, "TSM" }, { P.Value(HERB_LINK, Fixtures.HERB) })
	end)

	-- Ruling R0. Mutations: in P.AuctionValue, `best = math.max(best or v, v)` -> `best = best or v` (the first
	-- source's answer); or in P.Invalidate, `P.ahCache, P.auction = {}, nil` -> `P.auction = nil`.
	it("AuctionValue asks every loaded auction source whatever prices.source says; the highest answers", function()
		Loader.LoadFile(SB, "SwagBag/Providers/TSM.lua")
		SB.Config.Set("prices.source", "vendor")
		A.auctionator = { prices = { [HERB_LINK] = 42000 } }
		A.tsm = { prices = { DBMarket = { [HERB_LINK] = 30000 } } }
		P.Invalidate()
		assert.same({ 1500, "Vendor" }, { P.Value(HERB_LINK, Fixtures.HERB) }, "what the windows show")
		assert.equal(42000, P.AuctionValue(HERB_LINK, Fixtures.HERB))
		A.auctionator.prices[HERB_LINK] = 20000
		P.Invalidate()
		assert.equal(30000, P.AuctionValue(HERB_LINK, Fixtures.HERB), "TSM's is the higher one now")
		A.auctionator, A.tsm = nil, nil
		P.Invalidate()
		assert.is_nil(P.AuctionValue(HERB_LINK, Fixtures.HERB), "no auction addon: no auction price, never the vendor's")
	end)

	-- Mutation: in the price command, set prices.source without checking Config.Set's answer.
	it("/swagbag price says where prices come from, picks a source and TSM's price, and refuses the rest", function()
		Loader.LoadFile(SB, "SwagBag/Providers/TSM.lua")
		local L = SB.L
		local function run(line)
			local _, feedback = SB.Slash.Run(line)
			return feedback
		end
		assert.equal(L.PRICE_STATE:format(L.PRICE_CHOICE_AUTO, "Vendor"), run("price"))
		A.tsm = { prices = {} }
		assert.equal(L.PRICE_SET:format(L.PRICE_CHOICE_TSM:format("DBMarket")), run("price tsm"))
		assert.equal("tsm", SB.Config.Get("prices.source"))
		assert.equal(L.PRICE_SET:format(L.PRICE_CHOICE_TSM:format("DBRegionMarketAvg")), run("price TSM dbregionmarketavg"))
		assert.equal("DBRegionMarketAvg", SB.Config.Get("prices.tsm"))
		assert.equal(L.PRICE_SET:format(L.PRICE_CHOICE_AUCTIONATOR) .. " " .. L.PRICE_NOT_LOADED:format("Auctionator"),
			run("price auctionator"))
		assert.equal(L.PRICE_SET:format(L.PRICE_CHOICE_VENDOR), run("price vendor"))
		assert.equal(L.PRICE_SET:format(L.PRICE_CHOICE_AUTO), run("price auto"))
		assert.equal(L.PRICE_TSM_SET:format("DBMinBuyout"), run("price string dbminbuyout"))
		assert.same({ "auto", "DBMinBuyout" }, { SB.Config.Get("prices.source"), SB.Config.Get("prices.tsm") },
			"price string: TSM's price only, never the source")
		assert.equal(L.PRICE_USAGE, run("price string"))
		assert.equal(L.PRICE_USAGE, run("price tsm dbanything"))
		assert.equal(L.PRICE_USAGE, run("price auctionhouse"))
		SB.Config.readOnly = true
		assert.equal(L.SETTINGS_READONLY, run("price tsm"))
		assert.equal("auto", SB.Config.Get("prices.source"))
	end)

	-- Mutation: register the bare function instead of the Guard-wrapped one in the SB_LOGIN handler.
	it("Auctionator's update callback runs trapped: an error is recorded, never raised (P6)", function()
		P.Invalidate = function() error("boom") end
		A.auctionatorCallback()
		assert.equal(1, #SB.ErrorTrap.Recent())
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("a bound item is worth its vendor price only", function()
		A.auctionator = { prices = { [RING_LINK] = 9990000 } }
		P.Invalidate()
		assert.same({ 250000, "Vendor" }, { P.Value(RING_LINK, Fixtures.BOE_RING, true) })
		assert.same({ 9990000, "Auctionator" }, { P.Value(RING_LINK, Fixtures.BOE_RING, false) })
	end)

	it("caches per link for the session; Auctionator's update callback and 10 minutes drop the cache", function()
		A.auctionator = { prices = { [HERB_LINK] = 42000 } }
		SB.Emit("SB_LOGIN")
		P.Invalidate()
		P.Value(HERB_LINK, Fixtures.HERB)
		P.Value(HERB_LINK, Fixtures.HERB)
		assert.equal(1, A.auctionatorCalls)
		A.auctionator.prices[HERB_LINK] = 50000
		A.auctionatorCallback()
		assert.equal(50000, P.Value(HERB_LINK, Fixtures.HERB))
		A.auctionator.prices[HERB_LINK] = 60000
		A.Advance(599)
		assert.equal(50000, P.Value(HERB_LINK, Fixtures.HERB), "still cached")
		A.Advance(2)
		assert.equal(60000, P.Value(HERB_LINK, Fixtures.HERB))
		assert.equal(3, A.auctionatorCalls)
	end)

	it("a provider that throws three times is switched off with one line; the vendor price carries on", function()
		A.auctionator = { prices = {}, fail = true }
		P.Invalidate()
		for i = 1, 4 do
			assert.equal(1500, P.Value(HERB_LINK .. i, Fixtures.HERB))
		end
		assert.equal("Vendor", P.Source())
		assert.same({ "Price source Auctionator stopped working and was switched off until /reload." }, A.Lines())
		assert.equal(1, #SB.ErrorTrap.Recent())
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.equal(3, A.auctionatorCalls, "never asked again")
	end)

	it("providers with the same priority are asked in name order, whatever order they registered in", function()
		local asked = {}
		local function provider(name, v)
			return { name = name, priority = 5, available = function() return true end,
				value = function() asked[#asked + 1] = name return v end }
		end
		P.RegisterProvider(provider("Zeta", 1))
		P.RegisterProvider(provider("Alpha", nil))
		assert.same({ 1, "Zeta" }, { P.Value("item:1", 1) })
		assert.same({ "Alpha", "Zeta" }, asked)
	end)

	it("section totals: value x count per section; placeholders and holes are skipped", function()
		A.items[Fixtures.HEALING_POTION].sellPrice = 100
		local records = {
			[1] = { itemID = Fixtures.HERB, link = HERB_LINK, count = 20 },
			[2] = { itemID = Fixtures.HERB, link = HERB_LINK, count = 3 },
			[3] = { itemID = Fixtures.HEALING_POTION, link = "item:" .. Fixtures.HEALING_POTION, count = 5 },
			[4] = { itemID = Fixtures.UNLOADED, pending = true, count = 1 },
		}
		local st = { sections = {
			c_herbs = { size = 3, cells = { { bag = 0, slot = 1 }, nil, { bag = 0, slot = 2 } } },
			-- a placeholder stands where a button was; its slot's item is counted where the button is now
			c_consumables = { size = 2, cells = { { bag = 0, slot = 3 }, { bag = 0, slot = 3, placeholder = true } } },
			new = { size = 1, cells = { { bag = 0, slot = 4 } } },
		} }
		st.sections.free = { size = 2, cells = { { bag = 0, slot = 9 }, { shown = false, spare = "bags" } } } -- tile + spare entry
		local totals = P.SectionTotals(st, function(_, slot) return records[slot] end)
		assert.same({ c_herbs = 23 * 1500, c_consumables = 500, new = 0, free = 0 }, totals)
	end)

	it("a warbound-until-equipped item is worth its vendor price only (W3-35)", function()
		A.auctionator = { prices = { [RING_LINK] = 9990000 } }
		P.Invalidate()
		local st = { sections = { c = { size = 1, cells = { { bag = 0, slot = 1 } } } } }
		local rec = { itemID = Fixtures.BOE_RING, link = RING_LINK, count = 1, isWUE = true }
		assert.same({ c = 250000 }, P.SectionTotals(st, function() return rec end))
		A.SetBagSize(0, 1)
		A.Put(0, 1, Fixtures.BOE_RING, 1, { link = RING_LINK, isWUE = true })
		local q = SB.Query.Compile("value>100")
		assert.equal(false, SB.Query.Eval(q, SB.Items.Describe(0, 1)), "25g, not the 999g auction price")
	end)

	it("the value keyword compares the price per unit in gold (spec 7.4: value>100 & tradegoods)", function()
		A.auctionator = { prices = { [HERB_LINK] = 1500000 } }
		P.Invalidate()
		A.SetBagSize(0, 2)
		A.Put(0, 1, Fixtures.HERB, 20, { link = HERB_LINK })
		A.Put(0, 2, Fixtures.ORE, 5)
		local q = SB.Query.Compile("value>100 & tradegoods")
		assert.equal(true, SB.Query.Eval(q, SB.Items.Describe(0, 1)))
		assert.equal(false, SB.Query.Eval(q, SB.Items.Describe(0, 2)))
	end)
end)
