-- Week 7 (user pick 3): which bag items to open or learn (Engine/Collections.lua). Real APIs only,
-- through the Adapter; cached per item, asked again only after something is learned or an item leaves.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Crests.lua",
	"SwagBag/Engine/Collections.lua",
}

describe("Collections (week 7)", function()
	local SB, A, Coll
	before_each(function()
		SB = Loader.New(FILES)
		A, Coll = SB.Adapter, SB.Collections
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		local C, MS = A.ITEM_CLASS, A.MISC_SUB
		A.AddItem(500001, { name = "Cache of Riches", classID = C.Miscellaneous, subclassID = 0, quality = 3, bind = "pickup" })
		A.AddItem(500002, { name = "Reins of the Test Drake", classID = C.Miscellaneous, subclassID = MS.Mount, quality = 4,
			bind = "pickup" })
		A.AddItem(500003, { name = "Lost Kitten", classID = C.Miscellaneous, subclassID = MS.CompanionPet, quality = 3,
			bind = "none" })
		A.AddItem(500004, { name = "Silvermoon Lamp", classID = C.Housing, subclassID = 0, quality = 2, bind = "none" })
		A.AddItem(500005, { name = "Thalassian Treatise on Alchemy", classID = C.Consumable, subclassID = 8, quality = 3,
			bind = "pickup" })
		A.Put(0, 7, 500001, 1, { hasLoot = true })
		A.Put(0, 8, 500002, 1)
		A.Put(0, 9, 500003, 1)
		A.Put(0, 10, 500004, 1)
		A.Put(0, 11, 500005, 1)
		A.Put(0, 12, Fixtures.TOY, 1)
		A.Put(0, 13, Fixtures.PET_CAGE, 1, { link = "|cff0070dd|Hbattlepet:1387:25:3:1546:276:276:0|h[Hatespark]|h|r" })
	end)

	local function learn(slot)
		return Coll.Learn(SB.Items.Describe(0, slot))
	end

	-- Mutations: in Collections.Learn, the mount answer's `== false` -> `~= true` (a silent client would
	-- make it glow); or drop the `if r.hasLoot` branch.
	it("open: a container with loot; learn: a toy, mount, pet or decor not collected yet; else nothing", function()
		A.collected.toys[Fixtures.TOY] = false
		A.collected.mounts[500002] = false
		A.collected.pets[500003] = false
		A.collected.decor[500004] = false
		A.collected.pets[1387] = true -- the caged pet's species is already collected
		assert.same({ "open", "learn", "learn", "learn", "learn", "learn" },
			{ learn(7), learn(8), learn(9), learn(10), learn(11), learn(12) })
		assert.is_nil(learn(13), "a caged pet whose species is collected")
		assert.is_nil(learn(1), "a potion")
		assert.is_nil(learn(4), "gear")
		Coll.Invalidate()
		A.collected.toys[Fixtures.TOY] = true
		A.collected.mounts[500002] = nil -- the client gives no answer: no glow, never a wrong one
		assert.same({ nil, nil }, { learn(12), learn(8) })
	end)

	-- Mutation: in knowledge(), drop the isGear check (a cloak named "Treatise..." would glow).
	it("knowledge items: by confirmed ID or the name word, never gear; an alt's saved item never glows", function()
		A.AddItem(500006, { name = "Treatise Cloak", classID = A.ITEM_CLASS.Armor, subclassID = 1, equipLoc = "INVTYPE_CLOAK",
			quality = 3, ilvl = 280, bind = "equip" })
		A.Put(0, 14, 500006, 1)
		assert.is_nil(learn(14))
		SB.Crests.knowledge.ids[Fixtures.QUEST] = true
		A.Put(0, 15, Fixtures.QUEST, 1)
		assert.equal("learn", learn(15))
		local saved = SB.Items.Describe(0, 11)
		saved.offline = true
		assert.is_nil(Coll.Learn(saved))
	end)

	-- Week 7 (user pick 9). Mutations: in Coll.Uncollected, `== false` -> `~= true` for looks (a silent
	-- client would star every piece); or drop TRANSMOG_COLLECTION_UPDATED from the events.
	it("Uncollected: gear whose look is missing, toys, mounts and pets not yet collected; cached per link", function()
		local link = "item:225001::upgradable" -- the fixture's BoE ring, slot 3
		A.collected.looks[link] = false
		A.collected.toys[Fixtures.TOY] = false
		A.collected.mounts[500002] = true
		local function kind(slot)
			return Coll.Uncollected(SB.Items.Describe(0, slot))
		end
		assert.same({ "appearance", "toy" }, { kind(3), kind(12) })
		assert.is_nil(kind(8), "a mount already collected")
		assert.is_nil(kind(4), "the client gives no answer for the helm's look: no star")
		assert.is_nil(kind(10), "decor: the learn glow only")
		A.collected.looks[link] = "cannot"
		Coll.Invalidate()
		assert.is_nil(kind(3), "an account that cannot collect the look: no star")
		A.collected.looks[link] = false
		Coll.Invalidate()
		kind(3)
		local calls = A.collectionCalls
		kind(3)
		assert.equal(calls, A.collectionCalls, "cached")
		A.collected.looks[link] = true
		SB.Overlays = { RefreshAll = function() end }
		SB.eventFrame:Fire("TRANSMOG_COLLECTION_UPDATED")
		assert.is_nil(kind(3), "collected now")
	end)

	-- Week 7: the `uncollected` keyword (spec 7.3). Mutation: register it as always false.
	it("the search keyword `uncollected` finds the same items", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Query/Lexer.lua")
		Loader.LoadFile(SB, "SwagBag/Engine/Query/Parser.lua")
		Loader.LoadFile(SB, "SwagBag/Engine/Query/Query.lua")
		Loader.LoadFile(SB, "SwagBag/Engine/Keywords.lua")
		A.collected.toys[Fixtures.TOY] = false
		local q = SB.Query.Compile("uncollected")
		assert.same({ true, false }, { SB.Query.Eval(q, SB.Items.Describe(0, 12)), SB.Query.Eval(q, SB.Items.Describe(0, 1)) })
	end)

	-- Mutations: drop the Inventory listener's Invalidate; or register no NEW_TOY_ADDED handler.
	it("answers are cached per item; a toy learned or an item leaving asks again, and the windows re-draw", function()
		A.collected.toys[Fixtures.TOY] = false
		learn(12)
		learn(12)
		assert.equal(1, A.collectionCalls, "the second draw is a table lookup")
		A.collected.toys[Fixtures.TOY] = true
		local drawn = 0
		SB.Overlays = { RefreshAll = function() drawn = drawn + 1 end }
		SB.eventFrame:Fire("NEW_TOY_ADDED", Fixtures.TOY)
		A.Advance(Coll.REFRESH)
		assert.is_nil(learn(12), "learned: no glow on another copy")
		assert.same({ 2, 1 }, { A.collectionCalls, drawn })
		SB.Inventory.Notify(SB.Inventory.R.ITEM, { { bag = 0, slot = 12, reasons = SB.Inventory.R.ITEM } })
		learn(12)
		assert.equal(3, A.collectionCalls)
	end)

	-- P6 (ruling R15): the bag listener runs inside Inventory.Notify's "bags" trap; its own "none" trap keeps a
	-- failure in it from switching the bags to Safe Mode. Mutation: the listener's trap window "none" -> "bags".
	it("a failure in the collections' bag listener is recorded under none, never Safe Mode", function()
		local real = Coll.Invalidate
		Coll.Invalidate = function()
			error("boom")
		end
		SB.Inventory.Notify(SB.Inventory.R.ITEM, { { bag = 0, slot = 12, reasons = SB.Inventory.R.ITEM } })
		Coll.Invalidate = real
		local e = SB.ErrorTrap.Recent()[1]
		assert.same({ "collections.inventory", "none" }, { e.label, e.window })
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)
end)
