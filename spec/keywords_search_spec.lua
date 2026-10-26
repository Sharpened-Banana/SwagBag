local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

-- 0.16.0 search (plan docs/plans/2026-10-26-search-armor-types-and-item-facts.md, user answers Q1-Q14):
-- armor types, the cloth/leather change, the stat, socket, expansion, set, transmog and bonus keywords, the
-- damage-type phrases and text: tooltip search.
local FILES = {
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/ItemFacts.lua", "SwagBag/Engine/Keywords.lua",
}

-- Bag 1:
--  1 cloth robe (crit 120, haste 80, one empty socket, one gem; tooltip +5 Fire Damage; bonus 6652, 1540)
--  2 leather legs   3 mail chest (two gems, no empty socket)   4 plate helm (set 1500, Midnight)
--  5 shield         6 cloth (the material)   7 leather (the material)
--  8 sword (dps 500.5; tooltip +20 Frost Damage; The War Within)   9 potion (tooltip says fire damage)
-- 10 cosmetic hat   11 a robe still loading
local function setup(A)
	Fixtures.Install(A)
	local C, AS, TS = A.ITEM_CLASS, A.ARMOR_SUB, A.TRADEGOODS_SUB
	local function armor(id, name, sub, loc, extra)
		local def = { name = name, classID = C.Armor, subclassID = sub, equipLoc = loc, quality = 3, ilvl = 600,
			maxStack = 1, bind = "equip" }
		for k, v in pairs(extra or {}) do
			def[k] = v
		end
		A.AddItem(id, def)
	end
	armor(600001, "Robe of Embers", AS.Cloth, "INVTYPE_ROBE", { stats = { crit = 120, haste = 80, emptySockets = 1 },
		tooltip = { "Robe of Embers", "+5 Fire Damage" } })
	armor(600002, "Hide Leggings", AS.Leather, "INVTYPE_LEGS")
	armor(600003, "Chain Hauberk", AS.Mail, "INVTYPE_CHEST")
	armor(600004, "Plate Visage", AS.Plate, "INVTYPE_HEAD", { setID = 1500, expansionID = 11 })
	armor(600005, "Tower Shield", AS.Shield, "INVTYPE_SHIELD")
	A.AddItem(600006, { name = "Weavercloth", classID = C.Tradegoods, subclassID = TS.Cloth, quality = 1,
		maxStack = 1000, bind = "none" })
	A.AddItem(600007, { name = "Sunless Carapace", classID = C.Tradegoods, subclassID = TS.Leather, quality = 1,
		maxStack = 1000, bind = "none" })
	A.AddItem(600008, { name = "Frostbrand", classID = C.Weapon, subclassID = 7, equipLoc = "INVTYPE_WEAPON",
		quality = 4, ilvl = 610, maxStack = 1, bind = "equip", stats = { dps = 500.5, str = 40 }, expansionID = 10,
		tooltip = { "Frostbrand", "+20 Frost Damage" } })
	A.AddItem(600009, { name = "Volatile Draught", classID = C.Consumable, subclassID = A.CONSUMABLE_SUB.Potion,
		quality = 1, maxStack = 20, bind = "none", tooltip = { "Volatile Draught", "Use: Deals 50 Fire Damage." } })
	armor(600010, "Party Hat", AS.Cosmetic, "INVTYPE_HEAD")
	A.AddItem(600011, { classID = C.Armor, subclassID = AS.Cloth, equipLoc = "INVTYPE_ROBE", pending = true })
	A.SetBagSize(1, 12)
	A.Put(1, 1, 600001, 1, { link = "item:600001::213746:::::::::13:2:6652:1540" })
	A.Put(1, 3, 600003, 1, { link = "item:600003::213746:213491::::::::" })
	for i = 1, 11 do
		if i ~= 1 and i ~= 3 then
			A.Put(1, i, 600000 + i, 1)
		end
	end
end

describe("Search keywords (0.16.0)", function()
	local SB, Q, A
	before_each(function()
		SB = Loader.New(FILES)
		Q, A = SB.Query, SB.Adapter
		setup(A)
	end)

	local ALL = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
	local function matching(query, opts)
		local compiled = Q.Compile(query, opts)
		assert.same({}, compiled.errors, query)
		local out = {}
		for _, slot in ipairs(ALL) do
			if Q.Eval(compiled, SB.Items.Describe(1, slot)) == true then
				out[#out + 1] = slot
			end
		end
		return out
	end
	local function at(query, slot)
		return Q.Eval(Q.Compile(query), SB.Items.Describe(1, slot))
	end

	-- Q1. Mutation: cloth matches only the material again.
	it("bare cloth and leather find the material and the armor; the phrases narrow them", function()
		assert.same({ 1, 6, 11 }, matching("cloth"))
		assert.same({ 2, 7 }, matching("leather"))
		assert.same({ 1, 11 }, matching("cloth armor"))
		assert.same({ 2 }, matching("leather armor"))
		assert.same({ 6 }, matching("cloth material"))
		assert.same({ 7 }, matching("leather material"))
	end)

	it("mail, plate, shield and the relic types are armor subclasses", function()
		assert.same({ 3 }, matching("mail"))
		assert.same({ 3 }, matching("mail armor"))
		assert.same({ 4 }, matching("plate"))
		assert.same({ 4 }, matching("plate armor"))
		assert.same({ 5 }, matching("shield"))
		for _, w in ipairs({ "libram", "idol", "totem", "sigil", "relic" }) do
			assert.same({}, matching(w), w)
		end
	end)

	-- Q2.
	it("armor and gear keep their meaning", function()
		assert.same({ 1, 2, 3, 4, 5, 10, 11 }, matching("armor"))
		assert.same({ 1, 2, 3, 4, 5, 8, 10, 11 }, matching("gear"))
	end)

	-- Q9. Mutation: crit reads the haste stat.
	it("stats: bare means the gear has it, a number compares it", function()
		assert.same({ 1 }, matching("crit"))
		assert.same({ 1 }, matching("haste & crit>100"))
		assert.same({}, matching("crit>200"))
		assert.same({ 8 }, matching("str"))
		assert.same({ 8 }, matching("strength"))
		assert.equal(false, at("crit", 6), "not gear")
		assert.is_nil(at("crit", 11), "still loading")
		assert.equal(true, at("crit<1", 2), "gear without crit has 0")
		assert.equal(false, at("crit<1", 6), "not gear has no crit")
	end)

	it("dps and damage>N compare a weapon's damage per second", function()
		assert.same({ 8 }, matching("dps>500"))
		assert.same({ 8 }, matching("damage>500"))
		assert.same({}, matching("dps>501"))
	end)

	-- Mutation: count only empty sockets.
	it("sockets counts empty and filled sockets; socketed means all are filled", function()
		assert.same({ 1, 3 }, matching("sockets"))
		assert.same({ 1, 3 }, matching("sockets>1"))
		assert.same({ 3 }, matching("socketed"))
		assert.same({}, matching("sockets>2"))
	end)

	it("expansion names and expansion=N", function()
		assert.same({ 4 }, matching("midnight"))
		assert.same({ 8 }, matching("tww"))
		assert.same({ 8 }, matching("war within"))
		assert.same({ 4 }, matching("expansion=" .. A.EXPANSION.Midnight))
		assert.same({}, matching("classic"))
	end)

	-- Q6.
	it("expansion keywords never match on WoW Forever", function()
		SB = Loader.New(FILES, { flavor = "forever" })
		Q, A = SB.Query, SB.Adapter
		setup(A)
		assert.same({}, matching("midnight"))
		assert.same({}, matching("expansion>0"))
	end)

	it("set, bonus=N and transmog", function()
		assert.same({ 4 }, matching("set"))
		assert.same({ 1 }, matching("bonus=1540"))
		assert.same({ 1 }, matching("bonus=6652"))
		assert.same({}, matching("bonus=1"))
		-- Collections.Uncollected says what the account lacks; transmog keeps gear with an appearance only
		local LACKS = { [600002] = "appearance", [600003] = "toy", [600009] = "appearance" }
		SB.Collections = { Uncollected = function(r) return LACKS[r.itemID] end }
		assert.same({ 2 }, matching("transmog"))
	end)

	-- Q11. Mutation: damage phrases match items that are not gear.
	it("damage phrases read the tooltip of gear, in either word order", function()
		assert.same({ 1 }, matching("fire damage"))
		assert.same({ 1 }, matching("damage fire"))
		assert.same({ 8 }, matching("frost damage"))
		assert.same({}, matching("shadow damage"))
		assert.same({ 1, 8 }, matching("damage"))
		assert.equal(false, at("fire damage", 9), "a potion is not gear")
	end)

	it("a damage phrase is unknown while the tooltip loads, false with no tooltip API", function()
		A.items[600001].tooltip = "secret"
		assert.is_nil(at("fire damage", 1))
		SB.ItemFacts.Invalidate()
		A.noTooltipAPI = true
		assert.equal(false, at("fire damage", 1))
	end)

	-- Q4, applied: a typed word never turns into a tooltip read. Mutation: drop the tooltip check in prefix expansion.
	it("the search box's word expansion never reaches a tooltip keyword", function()
		assert.same({}, matching("fire", { prefix = true }))
		assert.equal(0, A.tooltipCalls)
		assert.same({ 1, 8 }, matching("fire damage | frost damage", { prefix = true }))
	end)

	-- Q7, Q8.
	it("text: searches the whole tooltip of any item, case-insensitive", function()
		assert.same({ 1, 9 }, matching("text:fire"))
		assert.same({ 1, 9 }, matching("tip:FIRE"))
		assert.same({ 9 }, matching("text:\"deals 50\""))
		assert.same({ 9 }, matching("text:deals 50"))
		assert.same({ 1 }, matching("text:fire & gear"))
		assert.same({ 2, 3, 4, 5, 6, 7, 8, 10 }, matching("!text:fire & !text:volatile"))
	end)

	it("text: is unknown while a tooltip loads and false with no tooltip API", function()
		A.items[600009].tooltip = "secret"
		assert.is_nil(at("text:fire", 9))
		SB.ItemFacts.Invalidate()
		A.noTooltipAPI = true
		assert.equal(false, at("text:fire", 9))
	end)

	it("plain words still only match names (Q4)", function()
		assert.same({}, matching("embers fire"))
		assert.same({ 1 }, matching("embers"))
		assert.equal(0, A.tooltipCalls)
	end)
end)
