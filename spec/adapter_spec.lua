-- luacheck: globals GetCursorInfo ClearCursor C_Container C_Item ItemLocation GetInventoryItemLink GetAverageItemLevel issecretvalue
-- luacheck: globals Auctionator
-- The REAL Adapter.lua (not the mock): cursor and sort helpers added in week 2; equipped items (week 3).
describe("Adapter cursor and sort helpers", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		GetCursorInfo, ClearCursor, C_Container, GetAverageItemLevel = nil, nil, nil, nil
	end)

	it("CursorItem returns the item on the cursor, and nothing for spells, errors or a missing API", function()
		assert.is_nil(A.CursorItem())
		GetCursorInfo = function() return "item", 211880, "|Hitem:211880|h[Potion]|h" end
		assert.same({ 211880, "|Hitem:211880|h[Potion]|h" }, { A.CursorItem() })
		GetCursorInfo = function() return "spell", 1, nil end
		assert.is_nil(A.CursorItem())
		GetCursorInfo = function() error("broken") end
		assert.is_nil(A.CursorItem())
	end)

	it("ClearCursor and SortBags call the game only when it has them", function()
		A.ClearCursor()
		assert.falsy(A.SortBags())
		local cleared, sorted = 0, 0
		ClearCursor = function() cleared = cleared + 1 end
		C_Container = { SortBags = function() sorted = sorted + 1 end }
		A.ClearCursor()
		assert.truthy(A.SortBags())
		assert.same({ 1, 1 }, { cleared, sorted })
	end)

	it("SortBags returns false and the error when the game call throws", function()
		C_Container = { SortBags = function() error("boom") end }
		local ok, err = A.SortBags()
		assert.equal(false, ok)
		assert.truthy(err)
	end)
end)

describe("Adapter.EquippedItems (real adapter, stubbed globals)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
		GetInventoryItemLink = function(_, slot)
			return (slot == 1 or slot == 2) and ("item:" .. slot) or nil
		end
		ItemLocation = { CreateFromEquipmentSlot = function(_, slot) return slot end }
		C_Item = {
			GetItemInfoInstant = function(link) return 1, nil, nil, "INVTYPE_HEAD", 0, 4, 0, link end,
			GetCurrentItemLevel = function(slot)
				if slot == 2 then
					error("cannot read")
				end
				return 285
			end,
		}
	end)

	after_each(function()
		GetInventoryItemLink, ItemLocation, C_Item, C_Container = nil, nil, nil, nil
	end)

	it("a readable item level is a number; an unreadable one is unknown, not 0; empty slots are absent", function()
		local out = A.EquippedItems()
		assert.equal(285, out[1].ilvl)
		assert.is_nil(out[1].unknown)
		assert.is_nil(out[2].ilvl)
		assert.equal(true, out[2].unknown)
		assert.is_nil(out[3])
		C_Item.GetCurrentItemLevel = function() return "x" end
		assert.equal(true, A.EquippedItems()[1].unknown, "not a number")
	end)

	it("EquippedItemLevel is GetAverageItemLevel's equipped value, and nil without the API or on an error", function()
		assert.is_nil(A.EquippedItemLevel())
		GetAverageItemLevel = function() return 285.5, 279.44, 270 end
		assert.equal(279.44, A.EquippedItemLevel())
		GetAverageItemLevel = function() return 285.5 end
		assert.is_nil(A.EquippedItemLevel())
		GetAverageItemLevel = function() error("boom") end
		assert.is_nil(A.EquippedItemLevel())
		GetAverageItemLevel = function() return 1, "x" end
		assert.is_nil(A.EquippedItemLevel(), "not a number")
		GetAverageItemLevel = function() return 1, 279.4 end
		issecretvalue = function(v) return v == 279.4 end
		assert.is_nil(A.EquippedItemLevel(), "a secret value")
		issecretvalue = nil
	end)

	-- The free tile (plan D19). Mutation: delete the BagKind "reagentbag" test in A.BagFamily.
	it("BagFamily: the reagent bag is its own family, a bag with a free-slot family is too, else 'any'", function()
		assert.same({ "any", "reagent", "any" }, { A.BagFamily(0), A.BagFamily(5), A.BagFamily(6) })
		C_Container = { GetContainerNumFreeSlots = function(bag) return 3, bag == 2 and 8 or 0 end }
		assert.same({ "any", "family8", "reagent" }, { A.BagFamily(1), A.BagFamily(2), A.BagFamily(5) })
		C_Container = { GetContainerNumFreeSlots = function() error("boom") end }
		assert.equal("any", A.BagFamily(2))
	end)
end)

describe("Adapter Auctionator (real adapter, stubbed global)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		Auctionator = nil
	end)

	local function price(v)
		Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return v end } } }
		assert.truthy(A.AuctionatorAvailable())
		return A.AuctionatorPrice("item:1")
	end

	it("accepts finite prices of 0 or more; infinity, NaN, negatives and non-numbers are no price", function()
		assert.equal(1500, price(1500))
		assert.equal(0, price(0))
		assert.is_nil(price(math.huge))
		assert.is_nil(price(-math.huge))
		assert.is_nil(price(0 / 0))
		assert.is_nil(price(-5))
		assert.is_nil(price("12"))
	end)

	it("resolves the API when availability is asked, not on every price call", function()
		local calls = 0
		Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() calls = calls + 1 return 7 end } } }
		assert.is_nil(A.AuctionatorPrice("item:1"), "not asked yet")
		A.AuctionatorAvailable()
		assert.equal(7, A.AuctionatorPrice("item:1"))
		Auctionator = nil
		assert.equal(7, A.AuctionatorPrice("item:1"), "the resolved API is kept until the next availability check")
		assert.equal(2, calls)
	end)
end)
