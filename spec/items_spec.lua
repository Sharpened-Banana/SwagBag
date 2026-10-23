local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Items.Describe", function()
	local SB, A, Items
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/Items.lua", "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua",
			"SwagBag/Engine/Query/Query.lua", "SwagBag/Engine/Keywords.lua" })
		A, Items = SB.Adapter, SB.Items
		Fixtures.SmallBags(A)
	end)

	it("returns nil, \"empty\" for an empty slot", function()
		assert.same({ nil, "empty" }, { Items.Describe(0, 16) })
	end)

	it("builds a full record for a loaded item", function()
		local r = Items.Describe(0, 1)
		assert.equal(Fixtures.HEALING_POTION, r.itemID)
		assert.equal("Algari Healing Potion", r.name)
		assert.equal(5, r.count)
		assert.equal(1, r.quality)
		assert.equal(A.ITEM_CLASS.Consumable, r.classID)
		assert.equal(A.CONSUMABLE_SUB.Potion, r.subclassID)
		assert.equal("", r.equipLoc)
		assert.equal(300, r.ilvl)
		assert.equal(71, r.reqLevel)
		assert.equal(20, r.maxStack)
		assert.equal("none", r.bind)
		assert.equal("backpack", r.location)
		assert.is_nil(r.tab)
		assert.equal(false, r.pending)
		assert.equal(true, r.isUsable)
	end)

	it("DescribeLink builds a guild bank record from the link: location guild, never bound, cooldown or new", function()
		local link = "|cffa335ee|Hitem:" .. Fixtures.BOE_RING .. "::::::::90:::::|h[Band of the Fallen]|h|r"
		A.tracks[link] = { "Hero", 2, 6 }
		local r = Items.DescribeLink({ itemID = Fixtures.BOE_RING, link = link, count = 1, icon = 7, quality = 4 }, 102, 5, 2)
		assert.same({ "Hero", 2, 6 }, r.track)
		assert.equal(true, r.hasUpgradeTrack)
		assert.equal(false, r.hasNoValue)
		assert.same({ 102, 5, 2, "guild", "Band of the Fallen", 285, "equip", "INVTYPE_FINGER" },
			{ r.bag, r.slot, r.tab, r.location, r.name, r.ilvl, r.bind, r.equipLoc })
		assert.same({ false, false, false, false, false }, { r.isBound, r.isWUE, r.onCooldown, r.isNew, r.pending })
		assert.equal(true, SB.Query.Eval(SB.Query.Compile("boe & ilvl>280"), r))
		local p = Items.DescribeLink({ itemID = Fixtures.UNLOADED, link = "item:" .. Fixtures.UNLOADED, count = 1 }, 101, 1, 1)
		assert.equal(true, p.pending)
		assert.is_nil(p.track)
		assert.equal(false, p.hasUpgradeTrack)
		assert.same({ Fixtures.UNLOADED }, A.loadRequests)
		local other = "item:" .. Fixtures.BOE_RING .. ":other"
		A.upgradeLinks[other] = true -- a track the client gives no details for
		local u = Items.DescribeLink({ itemID = Fixtures.BOE_RING, link = other, count = 1 }, 102, 6, 2)
		assert.is_nil(u.track)
		assert.equal(true, u.hasUpgradeTrack)
	end)

	it("marks an unloaded item pending, keeps instant facts, and asks the client to load it", function()
		A.Put(0, 7, Fixtures.UNLOADED, 1, { name = "Unloaded Helm" })
		local r = Items.Describe(0, 7)
		assert.equal(true, r.pending)
		assert.is_nil(r.name)
		assert.is_nil(r.ilvl)
		assert.is_nil(r.bind)
		assert.is_nil(r.reqLevel)
		assert.is_nil(r.maxStack)
		assert.is_nil(r.isCraftingReagent)
		assert.equal(A.ITEM_CLASS.Armor, r.classID)
		assert.equal("INVTYPE_CHEST", r.equipLoc)
		assert.same({ Fixtures.UNLOADED }, A.loadRequests)
	end)

	it("detects keystones and caged pets from the link", function()
		local key = Items.Describe(0, 5)
		assert.equal(true, key.isKeystone)
		assert.equal(true, key.isBound)
		A.Put(0, 8, Fixtures.PET_CAGE, 1, { link = "|cff0070dd|Hbattlepet:1387:25:3:1546:276:276:0|h[Hatespark]|h|r" })
		assert.equal(true, Items.Describe(0, 8).isCagedPet)
	end)

	it("knows the location kind and bank tab number", function()
		A.SetBagSize(5, 36)
		A.Put(5, 1, Fixtures.HERB, 40)
		A.SetBagSize(7, 98)
		A.Put(7, 3, Fixtures.ORE, 10)
		A.SetBagSize(13, 98)
		A.Put(13, 1, Fixtures.ORE, 10)
		assert.equal("reagentbag", Items.Describe(5, 1).location)
		assert.same({ "bank", 2 }, { Items.Describe(7, 3).location, Items.Describe(7, 3).tab })
		assert.same({ "warband", 2 }, { Items.Describe(13, 1).location, Items.Describe(13, 1).tab })
	end)

	it("fills the state flags", function()
		A.Put(0, 9, Fixtures.QUEST, 1)
		A.Put(0, 10, Fixtures.TOY, 1, { isLocked = true })
		A.Put(0, 4, Fixtures.SOULBOUND_HELM, 1, { isBound = true, inSet = true })
		assert.equal(true, Items.Describe(0, 2).onCooldown)
		assert.equal(true, Items.Describe(0, 3).hasUpgradeTrack)
		assert.equal(true, Items.Describe(0, 4).inEquipmentSet)
		assert.equal(true, Items.Describe(0, 9).isQuestItem)
		assert.equal(true, Items.Describe(0, 10).isToy)
		assert.equal(true, Items.Describe(0, 10).isLocked)
		assert.equal(false, Items.Describe(0, 1).isNew)
	end)

	it("asks Inventory whether the slot is new and reports pending items to it", function()
		local pending = {}
		SB.Inventory = { IsNew = function(bag, slot) return bag == 0 and slot == 1 end,
			MarkPending = function(id) pending[#pending + 1] = id end }
		A.Put(0, 7, Fixtures.UNLOADED, 1)
		assert.equal(true, Items.Describe(0, 1).isNew)
		Items.Describe(0, 7)
		assert.same({ Fixtures.UNLOADED }, pending)
	end)

	it("RefreshVolatile re-reads cooldown, usability and new without a full describe", function()
		local r = Items.Describe(0, 2)
		assert.equal(true, r.onCooldown)
		assert.equal(true, r.isUsable)
		A.slots[0][2].onCooldown = false
		A.items[Fixtures.FLASK].usable = false
		SB.Inventory = { IsNew = function() return true end }
		assert.equal(r, Items.RefreshVolatile(r))
		assert.equal(false, r.onCooldown)
		assert.equal(false, r.isUsable)
		assert.equal(true, r.isNew)
	end)

	it("Key gives itemID for static, link+bound for instance, nil for volatile", function()
		local r = Items.Describe(0, 4)
		assert.equal(Fixtures.SOULBOUND_HELM, Items.Key(r, "static"))
		assert.equal("item:" .. Fixtures.SOULBOUND_HELM .. "#b", Items.Key(r, "instance"))
		assert.is_nil(Items.Key(r, "volatile"))
		-- instance key for record with no link uses the fallback
		local noLink = { itemID = 12345, isBound = false }
		assert.equal("12345#u", Items.Key(noLink, "instance"))
		-- unbound record yields #u suffix
		local unbound = Items.Describe(0, 1)
		assert.equal("item:" .. Fixtures.HEALING_POTION .. "#u", Items.Key(unbound, "instance"))
		assert.equal("12345#uw", Items.Key({ itemID = 12345, isBound = false, isWUE = true }, "instance"))
		assert.equal("12345#b", Items.Key({ itemID = 12345, isBound = true, isWUE = true }, "instance"))
	end)
end)

-- Forever Stage A, Task 2: Forever's bank has 9 character tabs (6-14), so bag 13 is character bank tab 8.
describe("Items on WoW Forever", function()
	-- Mutation: restoring the literal ranges in Adapter.BagKind (13 would be warband tab 2).
	it("an item in bag 13 on Forever is in the bank, not the warband", function()
		local SB = Loader.New({ "SwagBag/Engine/Items.lua", "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua",
			"SwagBag/Engine/Query/Query.lua", "SwagBag/Engine/Keywords.lua" }, { flavor = "forever" })
		local A = SB.Adapter
		Fixtures.SmallBags(A)
		A.SetBagSize(13, 98)
		A.Put(13, 1, Fixtures.ORE, 10)
		local r = SB.Items.Describe(13, 1)
		assert.same({ "bank", 8 }, { r.location, r.tab })
		assert.equal(true, SB.Query.Eval(SB.Query.Compile("bank"), r))
		assert.equal(false, SB.Query.Eval(SB.Query.Compile("warband"), r))
	end)
end)
