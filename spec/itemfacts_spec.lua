local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

-- 0.16.0 search: stats and tooltip lines are read only when a query asks, once per item instance.
describe("ItemFacts", function()
	local SB, A, F
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/Items.lua", "SwagBag/Engine/ItemFacts.lua" })
		A, F = SB.Adapter, SB.ItemFacts
		Fixtures.SmallBags(A)
		A.items[Fixtures.BOE_RING].stats = { crit = 120 }
		A.items[Fixtures.BOE_RING].tooltip = { "Band of the Fallen", "+5 Fire Damage" }
	end)

	-- Mutation: drop the cache (every call asks the client).
	it("reads a gear item's stats once per instance", function()
		local r = SB.Items.Describe(0, 3)
		assert.same({ crit = 120, emptySockets = 0 }, F.Stats(r))
		assert.same({ crit = 120, emptySockets = 0 }, F.Stats(SB.Items.Describe(0, 3)))
		assert.equal(1, A.statsCalls)
	end)

	it("stats: false for an item that is not gear, nil while loading (asked again later), false with no API", function()
		assert.equal(false, F.Stats(SB.Items.Describe(0, 1)))
		A.items[Fixtures.BOE_RING].stats = "secret"
		assert.is_nil(F.Stats(SB.Items.Describe(0, 3)))
		A.items[Fixtures.BOE_RING].stats = { haste = 9 }
		assert.same({ haste = 9, emptySockets = 0 }, F.Stats(SB.Items.Describe(0, 3)))
		A.Put(0, 12, Fixtures.UNLOADED, 1)
		assert.is_nil(F.Stats(SB.Items.Describe(0, 12)))
		F.Invalidate()
		A.noStatsAPI = true
		assert.equal(false, F.Stats(SB.Items.Describe(0, 3)))
	end)

	it("reads a bag item's tooltip by its slot, once per instance", function()
		local r = SB.Items.Describe(0, 3)
		assert.same({ "band of the fallen", "+5 fire damage" }, F.Tooltip(r))
		F.Tooltip(SB.Items.Describe(0, 3))
		assert.equal(1, A.tooltipCalls)
	end)

	-- Mutation: read a saved item's tooltip by bag and slot.
	it("reads a guild or alt item's tooltip by its link", function()
		local seen
		A.TooltipLines = function(bag, slot, link)
			seen = { bag, slot, link }
			return { "x" }
		end
		F.Tooltip(SB.Items.DescribeLink({ itemID = Fixtures.BOE_RING, link = "item:225001:1", count = 1 }, 102, 5, 2))
		assert.same({ nil, nil, "item:225001:1" }, seen)
	end)

	it("tooltip: nil while it loads or is secret (asked again), false with no API", function()
		A.items[Fixtures.BOE_RING].tooltip = "secret"
		assert.is_nil(F.Tooltip(SB.Items.Describe(0, 3)))
		A.items[Fixtures.BOE_RING].tooltip = { "Ring" }
		assert.same({ "ring" }, F.Tooltip(SB.Items.Describe(0, 3)))
		F.Invalidate()
		A.noTooltipAPI = true
		assert.equal(false, F.Tooltip(SB.Items.Describe(0, 3)))
	end)

	-- Mutation: Invalidate leaves the cache as it was.
	it("Invalidate forgets every answer", function()
		F.Tooltip(SB.Items.Describe(0, 3))
		F.Invalidate()
		F.Tooltip(SB.Items.Describe(0, 3))
		assert.equal(2, A.tooltipCalls)
	end)
end)
