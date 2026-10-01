local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
}

-- Backpack after setup:
--  1 healing potion x5   2 flask x2 (cooldown)   3 BoE ring 285 (upgrade)   4 soulbound helm 270 (in set)
--  5 keystone            6 junk x3               7 herb x40                 8 ore x10
--  9 caged pet          10 toy (locked)         11 quest item              12 unloaded chest
-- 13 bag item           14 warbound-until-equip ring
-- Reagent bag (5) slot 1 herb; character bank tab 2 (bag 7) slot 3 ore; warband tab 2 (bag 13) slot 1 ore.
local function setup(A)
	Fixtures.SmallBags(A)
	A.Put(0, 7, Fixtures.HERB, 40)
	A.Put(0, 8, Fixtures.ORE, 10)
	A.Put(0, 9, Fixtures.PET_CAGE, 1, { link = "|cff0070dd|Hbattlepet:1387:25:3:1546:276:276:0|h[Hatespark]|h|r" })
	A.Put(0, 10, Fixtures.TOY, 1, { isLocked = true })
	A.Put(0, 11, Fixtures.QUEST, 1, { quest = true })
	A.Put(0, 12, Fixtures.UNLOADED, 1)
	A.Put(0, 13, Fixtures.BAG, 1)
	A.Put(0, 14, Fixtures.BOE_RING, 1, { isWUE = true })
	A.SetBagSize(5, 36)
	A.Put(5, 1, Fixtures.HERB, 12)
	A.SetBagSize(7, 98)
	A.Put(7, 3, Fixtures.ORE, 10)
	A.SetBagSize(13, 98)
	A.Put(13, 1, Fixtures.ORE, 10)
end

describe("Keywords (v1.0, week-1 families)", function()
	local SB, Q
	before_each(function()
		SB = Loader.New(FILES)
		Q = SB.Query
		setup(SB.Adapter)
	end)

	-- Which of the given backpack slots match the query.
	local function matching(query, slots, bag)
		local compiled = Q.Compile(query)
		assert.same({}, compiled.errors, query)
		local out = {}
		for _, slot in ipairs(slots) do
			if Q.Eval(compiled, SB.Items.Describe(bag or 0, slot)) == true then
				out[#out + 1] = slot
			end
		end
		return out
	end
	local ALL = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 }

	it("type: consumables", function()
		assert.same({ 1 }, matching("potion", ALL))
		assert.same({ 2 }, matching("flask", ALL))
		assert.same({ 1, 2 }, matching("consumable", ALL))
	end)

	it("type: gear, armor, weapon", function()
		assert.same({ 3, 4, 12, 14 }, matching("gear", ALL))
		assert.same({ 3, 4, 12, 14 }, matching("armor", ALL))
		assert.same({}, matching("weapon", ALL))
	end)

	it("type: trade goods, herb, ore, reagent", function()
		assert.same({ 7, 8 }, matching("trade goods", ALL))
		assert.same({ 7, 8 }, matching("tradegoods", ALL))
		assert.same({ 7 }, matching("herb", ALL))
		assert.same({ 8 }, matching("ore", ALL))
		assert.same({ 5, 7, 8 }, matching("reagent", ALL))
	end)

	it("type: keystone, pet, toy, quest, container, junk", function()
		assert.same({ 5 }, matching("keystone", ALL))
		assert.same({ 9 }, matching("pet", ALL))
		assert.same({ 10 }, matching("toy", ALL))
		assert.same({ 11 }, matching("quest", ALL))
		assert.same({ 13 }, matching("container", ALL))
		assert.same({ 6 }, matching("junk", ALL))
	end)

	it("slot keywords use the equip location", function()
		assert.same({ 3, 14 }, matching("finger", ALL))
		assert.same({ 4 }, matching("head", ALL))
		assert.same({ 12 }, matching("chest", ALL))
		assert.same({ 13 }, matching("bag", ALL))
	end)

	it("quality keywords and colour aliases", function()
		assert.same({ 3, 5, 14 }, matching("epic", ALL))
		assert.same({ 6 }, matching("gray", ALL))
		assert.same({ 6 }, matching("poor", ALL))
		assert.same({ 2, 4, 9, 10 }, matching("rare", ALL))
	end)

	it("binding keywords", function()
		assert.same({ 3, 13 }, matching("boe", ALL))
		assert.same({ 4, 5, 10 }, matching("bop", ALL))
		assert.same({ 4, 5 }, matching("bound", ALL))
		assert.same({ 4, 5 }, matching("soulbound", ALL))
		assert.same({ 14 }, matching("warbound", ALL))
		assert.same({ 14 }, matching("wue", ALL))
		assert.same({ 1, 2, 3, 6, 7, 8, 9, 10, 11, 12, 13, 14 }, matching("tradeable", ALL))
	end)

	it("numeric keywords", function()
		assert.same({ 3, 14 }, matching("ilvl>280", ALL))
		assert.same({ 4 }, matching("gear<280", ALL))
		assert.same({ 3, 4, 14 }, matching("lvl>=80", ALL))
		assert.same({ 1, 2 }, matching("level=71", ALL))
		assert.same({ 1, 7, 8 }, matching("count>=5", ALL))
		assert.same({ 7, 8 }, matching("stack>=1000", ALL))
	end)

	it("state keywords", function()
		assert.same({ 2 }, matching("cooldown", ALL))
		assert.same({ 3 }, matching("upgrade", ALL))
		assert.same({ 4 }, matching("equipped", ALL))
		assert.same({ 1, 2 }, matching("usable", ALL))
		assert.same({ 10 }, matching("locked", ALL))
		assert.same({ 1, 2, 6, 7, 8 }, matching("partial", ALL))
		assert.same({}, matching("new", ALL))
	end)

	it("location keywords and tab=N", function()
		assert.same({ 1 }, matching("backpack & potion", { 1 }))
		assert.same({ 1 }, matching("reagentbag", { 1 }, 5))
		assert.same({ 1 }, matching("bags", { 1 }, 5))
		assert.same({ 3 }, matching("bank & tab=2", { 3 }, 7))
		assert.same({ 1 }, matching("warband & tab=2", { 1 }, 13))
		assert.same({}, matching("bank", { 1 }, 13))
	end)

	it("an unloaded item gives nil for loaded-only facts, but instant facts still work", function()
		local r = SB.Items.Describe(0, 12)
		assert.equal(true, Q.Eval(Q.Compile("armor"), r))
		assert.equal(true, Q.Eval(Q.Compile("chest"), r))
		assert.is_nil(Q.Eval(Q.Compile("boe"), r))
		assert.is_nil(Q.Eval(Q.Compile("epic"), r))
		assert.is_nil(Q.Eval(Q.Compile("ilvl>1"), r))
		assert.is_nil(Q.Eval(Q.Compile("level>1"), r))
		assert.is_nil(Q.Eval(Q.Compile("partial"), r))
		assert.is_nil(Q.Eval(Q.Compile("stack>1"), r))
		assert.is_nil(Q.Eval(Q.Compile("gear<280"), r))
		assert.is_nil(Q.Eval(Q.Compile("junk"), r))
	end)

	it("evaluates composed queries across keyword families", function()
		assert.same({ 3 }, matching("gear & ilvl>280 & !bound & !wue", ALL))
		assert.same({ 5 }, matching("keystone | crest", ALL))
		assert.same({ 6 }, matching("junk | (gray & !quest)", ALL))
		assert.same({ 1 }, matching("\"Healing Potion\"", ALL))
	end)

	it("every keyword returns only true/false/nil (eval) or number/false/nil (value) on every record", function()
		local records = {}
		for _, slot in ipairs(ALL) do
			records[#records + 1] = SB.Items.Describe(0, slot)
		end
		records[#records + 1] = SB.Items.Describe(5, 1)
		records[#records + 1] = SB.Items.Describe(7, 3)
		for name, kw in pairs(Q.keywords) do
			for _, r in ipairs(records) do
				if kw.eval then
					local v = kw.eval(r)
					assert.truthy(v == true or v == false or v == nil, name .. " eval returned " .. tostring(v))
				end
				if kw.value then
					local v = kw.value(r)
					assert.truthy(type(v) == "number" or v == false or v == nil, name .. " value returned " .. tostring(v))
				end
			end
		end
	end)
end)
