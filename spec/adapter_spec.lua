-- luacheck: globals IsInGuild
-- luacheck: globals GetCursorInfo ClearCursor C_Container C_Item ItemLocation GetInventoryItemLink GetAverageItemLevel issecretvalue
-- luacheck: globals Auctionator ColorManager ITEM_QUALITY_COLORS
-- luacheck: globals PlayerHasToy C_MountJournal C_PetJournal C_HousingCatalog C_TransmogCollection
-- The REAL Adapter.lua (not the mock): cursor and sort helpers added in week 2; equipped items (week 3).
-- F1: spec/runner.lua installs format51 before any spec loads, so this first-sorting spec (no loader,
-- no single-file escape) is as strict as WoW too. Mutation: delete the require from spec/runner.lua.
describe("Test format reaches the Adapter specs", function()
	it("%s of a boolean or nil is an error here, with nothing but the real Adapter loaded", function()
		assert.has_error(function() return ("%s"):format(true) end, "string expected, got boolean")
		assert.has_error(function() return ("%s"):format(nil) end, "string expected, got nil")
	end)
end)

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
		GetInventoryItemLink, ItemLocation, C_Item, C_Container, issecretvalue = nil, nil, nil, nil, nil
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

	-- M3 (final review). Mutation: in A.IsWarboundUntilEquip, drop the isSecret(v) check.
	it("IsWarboundUntilEquip: true only for a plain true; a secret answer is false", function()
		assert.equal(false, A.IsWarboundUntilEquip(0, 1), "no API")
		ItemLocation.CreateFromBagAndSlot = function(_, bag, slot) return bag * 100 + slot end
		C_Item.IsBoundToAccountUntilEquip = function(loc) return loc == 1 end
		assert.equal(true, A.IsWarboundUntilEquip(0, 1))
		assert.equal(false, A.IsWarboundUntilEquip(0, 2))
		issecretvalue = function(v) return v == true end
		assert.equal(false, A.IsWarboundUntilEquip(0, 1), "a secret answer never decides")
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

-- F5: the row's name colour. Mutation: drop the pcall, or skip the ITEM_QUALITY_COLORS fallback.
describe("Adapter.QualityColor", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		ColorManager, ITEM_QUALITY_COLORS = nil, nil
	end)

	it("reads ColorManager's item quality colour when the client has it", function()
		ColorManager = { GetColorDataForItemQuality = function(q)
			assert.equal(4, q)
			return { color = { GetRGB = function() return 0.64, 0.21, 0.93 end } }
		end }
		assert.same({ 0.64, 0.21, 0.93 }, { A.QualityColor(4) })
	end)

	it("falls back to ITEM_QUALITY_COLORS, and answers nil with neither, for an unknown quality or an error", function()
		assert.is_nil(A.QualityColor(4))
		ITEM_QUALITY_COLORS = { [4] = { r = 0.6, g = 0.2, b = 0.9 } }
		assert.same({ 0.6, 0.2, 0.9 }, { A.QualityColor(4) })
		assert.is_nil(A.QualityColor(7))
		assert.is_nil(A.QualityColor(nil))
		ColorManager = { GetColorDataForItemQuality = function() error("boom") end }
		assert.same({ 0.6, 0.2, 0.9 }, { A.QualityColor(4) })
	end)
end)

describe("Adapter.IsInGuild (W5-6)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)
	after_each(function()
		IsInGuild = nil
	end)

	it("is true or false when the client answers a boolean, and nil when it cannot say", function()
		IsInGuild = nil
		assert.is_nil(A.IsInGuild(), "missing API")
		IsInGuild = function() error("boom") end
		assert.is_nil(A.IsInGuild(), "pcall failure")
		IsInGuild = function() return 1 end
		assert.is_nil(A.IsInGuild(), "non-boolean")
		IsInGuild = function() return true end
		assert.equal(true, A.IsInGuild())
		IsInGuild = function() return false end
		assert.equal(false, A.IsInGuild())
	end)
end)

-- Week 7 (user picks 3 and 9): the collection answers the "learn" glow and the uncollected marker use.
describe("Adapter collections (week 7)", function()
	local A
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		PlayerHasToy, C_MountJournal, C_PetJournal, C_HousingCatalog, issecretvalue = nil, nil, nil, nil, nil
		C_TransmogCollection = nil
	end)

	-- Mutation: in A.ToyKnown, return `ok and v` (a secret or a non-boolean passes through).
	it("toys and mounts: true, false, or nil without the API, for a non-mount item, or a secret", function()
		assert.is_nil(A.ToyKnown(1))
		PlayerHasToy = function(id) return id == 1 end
		assert.same({ true, false }, { A.ToyKnown(1), A.ToyKnown(2) })
		issecretvalue = function(v) return v == true end
		assert.is_nil(A.ToyKnown(1), "a secret answer is no answer")
		issecretvalue = nil
		assert.is_nil(A.MountKnown(5))
		C_MountJournal = { GetMountFromItem = function(id) return id == 5 and 77 or nil end,
			GetMountInfoByID = function() return "Horse", 1, 2, false, true, 0, false, false, 0, false, false end }
		assert.equal(false, A.MountKnown(5))
		assert.is_nil(A.MountKnown(6), "not a mount item")
	end)

	-- Mutation: in A.PetKnown, ignore the link (always ask GetPetInfoByItemID).
	it("pets: a caged pet's species comes from its link, a pet item's from the journal; decor from the catalog", function()
		local asked = {}
		C_PetJournal = { GetNumCollectedInfo = function(species)
			asked[#asked + 1] = species
			return species == 1387 and 1 or 0
		end, GetPetInfoByItemID = function() return "Pup", 1, 1, 1, "", "", false, true, true, false, true, 1, 42 end }
		assert.equal(true, A.PetKnown(82800, "|cff0070dd|Hbattlepet:1387:25:3:1546:276:276:0|h[Hatespark]|h|r"))
		assert.equal(false, A.PetKnown(12345, "item:12345"))
		assert.same({ 1387, 42 }, asked)
		assert.is_nil(A.DecorKnown(9))
		C_HousingCatalog = { GetCatalogEntryInfoByItem = function(id)
			if id == 9 then
				return { totalNumPlaced = 0, remainingRedeemable = 0, totalNumStored = 2 }
			elseif id == 10 then
				return { totalNumPlaced = 0, remainingRedeemable = 0, totalNumStored = 0 }
			end
			return id == 11 and {} or nil
		end }
		assert.same({ true, false }, { A.DecorKnown(9), A.DecorKnown(10) })
		assert.is_nil(A.DecorKnown(11), "no counts: the client cannot say")
		assert.is_nil(A.DecorKnown(12), "not decor")
	end)

	-- Week 7 (user pick 9). Mutation: in A.AppearanceKnown, drop the AccountCanCollectSource check.
	it("appearances: collected or not; nil with no source, one the account cannot collect, or a secret", function()
		assert.is_nil(A.AppearanceKnown("item:1"))
		C_TransmogCollection = {
			GetItemInfo = function(link) return 7, ({ ["item:1"] = 101, ["item:2"] = 102, ["item:3"] = 103, ["item:5"] = 104 })[link] end,
			AccountCanCollectSource = function(source) return source ~= 104, source ~= 103 end,
			PlayerHasTransmogItemModifiedAppearance = function(source) return source == 101 end,
		}
		assert.same({ true, false }, { A.AppearanceKnown("item:1"), A.AppearanceKnown("item:2") })
		assert.equal("cannot", A.AppearanceKnown("item:3"), "the account cannot collect it")
		assert.is_nil(A.AppearanceKnown("item:5"), "the client has no data for the source yet")
		assert.is_nil(A.AppearanceKnown("item:4"), "no appearance (a ring)")
		issecretvalue = function(v) return v == false end
		assert.is_nil(A.AppearanceKnown("item:2"), "a secret answer")
	end)
end)

-- Week 9 (user pick 8): the stacker's one game call. Mutation: in A.MoveStack, drop the put-back pickup.
describe("Adapter.MoveStack (real adapter, stubbed globals)", function()
	local A, calls, cursor
	before_each(function()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
		calls, cursor = {}, nil
		GetCursorInfo = function()
			if cursor then
				return "item", 211880, "item:211880"
			end
		end
	end)

	after_each(function()
		GetCursorInfo, ClearCursor, C_Container, issecretvalue = nil, nil, nil, nil
	end)

	-- keep: what the drop leaves on the cursor (true: the rest that did not fit).
	local function game(keep)
		C_Container = { PickupContainerItem = function(bag, slot)
			calls[#calls + 1] = { bag, slot }
			if #calls == 1 then
				cursor = true
			elseif #calls == 2 then
				cursor = keep or nil
			else
				cursor = nil
			end
		end }
	end

	it("picks up and drops with the game's own call, puts back what is left, never starts with an item held", function()
		assert.falsy(A.MoveStack(0, 2, 0, 1), "no API")
		game(false)
		assert.truthy(A.MoveStack(0, 2, 0, 1))
		assert.same({ { 0, 2 }, { 0, 1 } }, calls)
		calls = {}
		game(true)
		assert.truthy(A.MoveStack(0, 4, 0, 2))
		assert.same({ { 0, 4 }, { 0, 2 }, { 0, 4 } }, calls, "the rest goes back where it came from")
		assert.is_nil(cursor)
		calls, cursor = {}, true
		assert.falsy(A.MoveStack(0, 4, 0, 2), "the user holds an item")
		assert.same({}, calls)
	end)

	it("a throwing pickup is reported and the cursor is cleared", function()
		local cleared = 0
		ClearCursor = function() cleared = cleared + 1 cursor = nil end
		C_Container = { PickupContainerItem = function(bag)
			if bag == 9 then
				error("refused")
			end
			cursor = true
		end }
		local ok, err = A.MoveStack(0, 1, 9, 1)
		assert.equal(false, ok)
		assert.truthy(err)
		assert.equal(1, cleared, "nothing stays on the cursor")
	end)

	-- P5 (preflight S5): GetCursorInfo answers more than items. Mutation: in A.MoveStack, guard with
	-- `A.CursorItem() ~= nil` instead of `A.CursorBusy()`.
	it("CursorBusy sees anything on the cursor (money, a spell, a merchant's item, a secret item ID); no move starts", function()
		assert.falsy(A.CursorBusy(), "no API")
		game(false)
		issecretvalue = function(v) return v == 999 end
		for _, held in ipairs({ { "money", 500 }, { "spell", 1 }, { "merchant", 3 }, { "item", 999 } }) do
			GetCursorInfo = function() return held[1], held[2] end
			assert.is_nil(A.CursorItem(), held[1])
			assert.truthy(A.CursorBusy(), held[1])
			assert.falsy(A.MoveStack(0, 2, 0, 1), held[1])
		end
		assert.same({}, calls)
		GetCursorInfo = function() return nil end
		assert.falsy(A.CursorBusy(), "nothing held")
		GetCursorInfo = function() error("broken") end
		assert.falsy(A.CursorBusy(), "an error is no answer")
	end)
end)
