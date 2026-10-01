local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua",
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

	it("money: gold with thousands separators, else silver, else copper", function()
		assert.same({ "12c", "35s", "1,240g", "123,456g", "1g", "0c" },
			{ P.Money(12), P.Money(3550), P.Money(12400000), P.Money(1234567890), P.Money(10000), P.Money(0) })
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
