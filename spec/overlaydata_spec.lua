local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("OverlayData (spec F9)", function()
	local SB, A, O
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/Items.lua", "SwagBag/Engine/OverlayData.lua" })
		A, O = SB.Adapter, SB.OverlayData
		Fixtures.SmallBags(A)
	end)

	local function gear(equipLoc, ilvl, extra)
		local r = { itemID = 400000, classID = A.ITEM_CLASS.Armor, equipLoc = equipLoc, ilvl = ilvl, pending = false }
		for k, v in pairs(extra or {}) do
			r[k] = v
		end
		return r
	end

	local function weapon(equipLoc, ilvl)
		return { itemID = 400001, classID = A.ITEM_CLASS.Weapon, equipLoc = equipLoc, ilvl = ilvl, pending = false }
	end

	local function worn(list)
		local out = {}
		for slot, e in pairs(list) do
			out[slot] = { ilvl = e[1], equipLoc = e[2] }
		end
		return out
	end

	it("item level only on equippable gear", function()
		assert.equal(285, O.For(SB.Items.Describe(0, 3)).ilvl, "the ring")
		assert.is_nil(O.For(SB.Items.Describe(0, 1)).ilvl, "a potion")
		assert.is_nil(O.For({ classID = A.ITEM_CLASS.Armor, equipLoc = "INVTYPE_BAG", ilvl = 1 }).ilvl, "a bag")
		assert.is_nil(O.For(gear("INVTYPE_FINGER", nil, { pending = true })).ilvl, "still loading")
	end)

	it("the upgrade track as initial, level and maximum", function()
		assert.equal("H3/6", O.For(gear("INVTYPE_HEAD", 280, { track = { track = "Hero", level = 3, max = 6 } })).track)
		assert.is_nil(O.For(gear("INVTYPE_HEAD", 280)).track)
	end)

	-- Week 7 (user pick 2, horizon research): an Ascendant Venomstone raises a fully upgraded item's level
	-- past its track. The overlay keeps reading the client's track (never a table of item levels), so a
	-- boosted item reads M6/6 with its new item level, and a level past the maximum still draws.
	it("a Venomstone-boosted item keeps its track text; a level past the maximum draws as it is", function()
		A.tracks["item:225001::boosted"] = { track = "Myth", level = 6, max = 6 }
		A.Put(0, 7, Fixtures.BOE_RING, 1, { link = "item:225001::boosted", ilvl = 344 })
		local d = O.For(SB.Items.Describe(0, 7))
		assert.same({ "M6/6", 344 }, { d.track, d.ilvl })
		A.tracks["item:225001::boosted"] = { track = "Myth", level = 7, max = 6 }
		assert.equal("M7/6", O.For(SB.Items.Describe(0, 7)).track)
	end)

	it("the keystone's level and a short dungeon name from its link", function()
		local r = SB.Items.Describe(0, 5)
		assert.same({ level = 12, dungeon = "AKCE" },
			O.For(r, { dungeonName = function(id) return id == 503 and "Ara-Kara, City of Echoes" or nil end }).keystone)
		assert.same({ level = 12 }, O.For(r, {}).keystone, "no name known: the level alone")
	end)

	it("short dungeon names: initials of the words that matter, or three letters of a one-word name", function()
		assert.same({ "DC", "AKCE", "PSF", "Roo", "OF", "TP" }, { O.Short("Darkflame Cleft"),
			O.Short("Ara-Kara, City of Echoes"), O.Short("Priory of the Sacred Flame"), O.Short("The Rookery"),
			O.Short("Operation: Floodgate"), O.Short("Theater of Pain") })
		assert.same({ "EDA", "TSG" }, { O.Short("Eco-Dome Al'dani"), O.Short("Tazavesh: So'leah's Gambit") })
		assert.is_nil(O.Short(nil))
	end)

	it("a junk coin on gray items a vendor pays for", function()
		assert.equal(true, O.For(SB.Items.Describe(0, 6)).junk)
		A.Put(0, 6, Fixtures.JUNK, 3, { hasNoValue = true })
		assert.equal(false, O.For(SB.Items.Describe(0, 6)).junk)
		assert.equal(false, O.For(SB.Items.Describe(0, 1)).junk)
	end)

	-- Week 7: a gray piece kept in an equipment set is not junk. Mutation: drop `and not record.inEquipmentSet`.
	it("no junk coin on a gray item in an equipment set", function()
		A.AddItem(400100, { name = "Frayed Robe", classID = A.ITEM_CLASS.Armor, subclassID = 1, equipLoc = "INVTYPE_CHEST",
			quality = 0, ilvl = 5, maxStack = 1, bind = "none", sellPrice = 12 })
		A.Put(0, 7, 400100, 1)
		A.Put(0, 8, 400100, 1, { inSet = true })
		assert.equal(true, O.For(SB.Items.Describe(0, 7)).junk)
		assert.equal(false, O.For(SB.Items.Describe(0, 8)).junk)
	end)

	-- Week 7 (ruling R11): a locked gray item is never sold, so it gets no "sell me" coin. Mutation: in
	-- OverlayData.For, drop `out.junk = out.junk and not out.locked`.
	it("no junk coin on a gray item the user locked", function()
		A.AddItem(400100, { name = "Frayed Robe", classID = A.ITEM_CLASS.Armor, subclassID = 1, equipLoc = "INVTYPE_CHEST",
			quality = 0, ilvl = 5, maxStack = 1, bind = "none", sellPrice = 12 })
		A.Put(0, 7, 400100, 1)
		local robe = SB.Items.Describe(0, 7)
		assert.same({ true, false }, { O.For(robe, { locked = function() return false end }).junk,
			O.For(robe, { locked = function() return true end }).junk })
	end)

	it("BoE and WuE badges until the item is bound", function()
		assert.equal("BoE", O.For(SB.Items.Describe(0, 3)).bind)
		assert.equal("WuE", O.For(gear("INVTYPE_HEAD", 1, { bind = "equip", isWUE = true })).bind)
		assert.is_nil(O.For(gear("INVTYPE_HEAD", 1, { bind = "equip", isBound = true })).bind)
		assert.is_nil(O.For(SB.Items.Describe(0, 4)).bind, "soulbound helm")
	end)

	it("upgrade arrow, one slot: beats the item worn there; an empty slot is always beaten (AC9.3)", function()
		local up = O.IsUpgrade
		assert.equal(true, up(gear("INVTYPE_HEAD", 280), worn({ [1] = { 270, "INVTYPE_HEAD" } })))
		assert.equal(false, up(gear("INVTYPE_HEAD", 280), worn({ [1] = { 285, "INVTYPE_HEAD" } })))
		assert.equal(false, up(gear("INVTYPE_HEAD", 280), worn({ [1] = { 280, "INVTYPE_HEAD" } })), "equal is not up")
		assert.equal(true, up(gear("INVTYPE_HEAD", 280), worn({})))
		assert.equal(true, up(gear("INVTYPE_ROBE", 281), worn({ [5] = { 280, "INVTYPE_CHEST" } })))
	end)

	it("rings and trinkets compare with the lower of both slots", function()
		local up = O.IsUpgrade
		assert.equal(true, up(gear("INVTYPE_FINGER", 285), worn({ [11] = { 290, "INVTYPE_FINGER" },
			[12] = { 280, "INVTYPE_FINGER" } })))
		assert.equal(false, up(gear("INVTYPE_FINGER", 285), worn({ [11] = { 290, "INVTYPE_FINGER" },
			[12] = { 286, "INVTYPE_FINGER" } })))
		assert.equal(true, up(gear("INVTYPE_TRINKET", 270), worn({ [13] = { 300, "INVTYPE_TRINKET" } })),
			"the second trinket slot is empty")
		assert.equal(false, up(gear("INVTYPE_TRINKET", 270), worn({ [13] = { 300, "INVTYPE_TRINKET" },
			[14] = { 270, "INVTYPE_TRINKET" } })))
	end)

	it("a two-hander compares by summed item level against main and off hand", function()
		local up = O.IsUpgrade
		local dual = worn({ [16] = { 290, "INVTYPE_WEAPON" }, [17] = { 280, "INVTYPE_SHIELD" } })
		assert.equal(true, up(weapon("INVTYPE_2HWEAPON", 286), dual), "572 > 570")
		assert.equal(false, up(weapon("INVTYPE_2HWEAPON", 285), dual), "570 = 570")
		assert.equal(false, up(weapon("INVTYPE_2HWEAPON", 289), worn({ [16] = { 290, "INVTYPE_2HWEAPON" } })))
		assert.equal(true, up(weapon("INVTYPE_2HWEAPON", 291), worn({ [16] = { 290, "INVTYPE_2HWEAPON" } })))
		assert.equal(true, up(weapon("INVTYPE_RANGEDRIGHT", 200), worn({})))
		assert.equal(true, up(weapon("INVTYPE_2HWEAPON", 200), worn({ [16] = { 290, "INVTYPE_WEAPON" } })),
			"a 1H main hand with an empty off hand: 400 > 290 (empty counts as 0)")
	end)

	it("one-handers: the main hand, plus the off hand when it holds a one-hand weapon; off-hands never beat a two-hander",
		function()
			local up = O.IsUpgrade
			local shield = worn({ [16] = { 280, "INVTYPE_WEAPON" }, [17] = { 260, "INVTYPE_SHIELD" } })
			assert.equal(false, up(weapon("INVTYPE_WEAPON", 275), shield), "the shield slot is not a weapon slot")
			local dual = worn({ [16] = { 290, "INVTYPE_WEAPON" }, [17] = { 280, "INVTYPE_WEAPON" } })
			assert.equal(true, up(weapon("INVTYPE_WEAPON", 285), dual))
			assert.equal(true, up(gear("INVTYPE_SHIELD", 270), shield))
			assert.equal(false, up(gear("INVTYPE_HOLDABLE", 400), worn({ [16] = { 290, "INVTYPE_2HWEAPON" } })))
			assert.equal(true, up(weapon("INVTYPE_WEAPONMAINHAND", 300), worn({ [16] = { 290, "INVTYPE_2HWEAPON" } })))
		end)

	it("no arrow on gear the character cannot use, on items still loading, or on things that are not worn gear", function()
		local up = O.IsUpgrade
		assert.equal(false, up(gear("INVTYPE_HEAD", 400), worn({}), function() return false end))
		assert.equal(false, up(gear("INVTYPE_HEAD", 400, { pending = true }), worn({})))
		assert.equal(false, up(gear("INVTYPE_BODY", 400), worn({})), "a shirt")
		assert.equal(false, up({ classID = A.ITEM_CLASS.Consumable, equipLoc = "", ilvl = 400 }, worn({})))
	end)

	it("a worn slot whose item level cannot be read gives no arrow; an empty slot still counts as 0", function()
		local up = O.IsUpgrade
		assert.equal(false, up(gear("INVTYPE_HEAD", 280), { [1] = { unknown = true, equipLoc = "INVTYPE_HEAD" } }))
		assert.equal(false, up(gear("INVTYPE_FINGER", 280), { [11] = { unknown = true, equipLoc = "INVTYPE_FINGER" } }))
		assert.equal(false, up(weapon("INVTYPE_2HWEAPON", 280), { [17] = { unknown = true, equipLoc = "INVTYPE_SHIELD" } }))
		assert.equal(true, up(gear("INVTYPE_HEAD", 280), {}))
	end)

	it("with Pawn the verdict is Pawn's; without an answer from Pawn the item-level rule decides", function()
		local helm = gear("INVTYPE_HEAD", 200)
		local worse = worn({ [1] = { 300, "INVTYPE_HEAD" } })
		assert.equal(true, O.For(helm, { equipped = worse, pawn = function() return true end }).upgrade)
		assert.equal(false, O.For(gear("INVTYPE_HEAD", 400), { equipped = worse, pawn = function() return false end }).upgrade)
		assert.equal(false, O.For(helm, { equipped = worse, pawn = function() return nil end }).upgrade)
		assert.equal(false, O.For(helm, { equipped = worse, canUse = function() return false end,
			pawn = function() return true end }).upgrade, "Pawn does not override 'cannot use'")
		assert.equal(false, O.For(gear("INVTYPE_HEAD", 200, { pending = true }), { equipped = worse,
			pawn = function() return true end }).upgrade, "Pawn does not override 'still loading'")
		assert.equal(true, O.For(gear("INVTYPE_HEAD", 301), { equipped = worse, pawn = function() return nil end }).upgrade)
	end)
end)
