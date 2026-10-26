-- luacheck: globals C_Item C_TooltipInfo GetItemStats issecretvalue Enum LE_EXPANSION_MIDNIGHT LE_EXPANSION_CLASSIC
-- 0.16.0 search: the item facts behind the armor-type, stat, socket, set, expansion, bonus and tooltip keywords,
-- with the REAL Adapter and stubbed globals (plan docs/plans/2026-10-26-search-armor-types-and-item-facts.md).
local function load()
	local SB = {}
	assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
	return SB.Adapter
end

local function clear()
	C_Item, C_TooltipInfo, GetItemStats, issecretvalue, Enum = nil, nil, nil, nil, nil
	LE_EXPANSION_MIDNIGHT, LE_EXPANSION_CLASSIC = nil, nil
end

describe("Adapter armor subclasses and expansions", function()
	after_each(clear)

	-- Mutation: drop Mail from A.ARMOR_SUB.
	it("every armor subclass has its 12.1 number", function()
		local A = load()
		assert.same({ Generic = 0, Cloth = 1, Leather = 2, Mail = 3, Plate = 4, Cosmetic = 5, Shield = 6, Libram = 7,
			Idol = 8, Totem = 9, Sigil = 10, Relic = 11 }, A.ARMOR_SUB)
	end)

	it("Enum.ItemArmorSubclass renumbers them", function()
		Enum = { ItemArmorSubclass = { Plate = 40, Shield = 60 } }
		local A = load()
		assert.equal(40, A.ARMOR_SUB.Plate)
		assert.equal(60, A.ARMOR_SUB.Shield)
		assert.equal(3, A.ARMOR_SUB.Mail)
	end)

	-- Mutation: read LE_EXPANSION_* under other names.
	it("expansion numbers come from the LE_EXPANSION_* globals when the client has them", function()
		local A = load()
		assert.equal(11, A.EXPANSION.Midnight)
		assert.equal(0, A.EXPANSION.Classic)
		LE_EXPANSION_MIDNIGHT, LE_EXPANSION_CLASSIC = 21, 5
		A = load()
		assert.equal(21, A.EXPANSION.Midnight)
		assert.equal(5, A.EXPANSION.Classic)
	end)
end)

describe("Adapter.GetItemInfo set", function()
	after_each(clear)

	it("returns the item's set ID (the 16th value)", function()
		C_Item = { GetItemInfo = function()
			return "Helm", "link", 4, 600, 80, "Armor", "Plate", 1, "INVTYPE_HEAD", 1, 100, 4, 4, 1, 11, 1234, false
		end }
		local info = load().GetItemInfo(1)
		assert.equal(1234, info.setID)
		assert.equal(11, info.expansionID)
	end)
end)

describe("Adapter.ItemStats", function()
	after_each(clear)

	-- Mutation: map ITEM_MOD_CRIT_RATING_SHORT to "haste".
	it("normalises the client's stat names, sums empty sockets and keeps weapon dps", function()
		C_Item = { GetItemStats = function(link)
			assert.equal("item:1", link)
			return { ITEM_MOD_CRIT_RATING_SHORT = 120, ITEM_MOD_HASTE_RATING_SHORT = 80,
				ITEM_MOD_MASTERY_RATING_SHORT = 5, ITEM_MOD_VERSATILITY = 7, ITEM_MOD_CR_LIFESTEAL_SHORT = 1,
				ITEM_MOD_CR_AVOIDANCE_SHORT = 2, ITEM_MOD_CR_SPEED_SHORT = 3, ITEM_MOD_STAMINA_SHORT = 900,
				ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 512.5, EMPTY_SOCKET_PRISMATIC = 2, EMPTY_SOCKET_RED = 1 }
		end }
		local s = load().ItemStats("item:1")
		assert.same({ crit = 120, haste = 80, mastery = 5, vers = 7, leech = 1, avoidance = 2, speed = 3, stam = 900,
			dps = 512.5, emptySockets = 3 }, s)
	end)

	it("a combined primary stat counts for each of its parts", function()
		C_Item = { GetItemStats = function()
			return { ITEM_MOD_STRENGTH_AGILITY_INTELLECT_SHORT = 300, ITEM_MOD_AGILITY_SHORT = 10 }
		end }
		local s = load().ItemStats("item:1")
		assert.same({ str = 300, agi = 300, int = 300, emptySockets = 0 }, s)
	end)

	it("falls back to the global GetItemStats", function()
		GetItemStats = function()
			return { ITEM_MOD_INTELLECT_SHORT = 40 }
		end
		assert.same({ int = 40, emptySockets = 0 }, load().ItemStats("item:1"))
	end)

	it("false with no API, nil for no table, a broken call or a secret", function()
		local A = load()
		assert.equal(false, A.ItemStats("item:1"))
		C_Item = { GetItemStats = function() return nil end }
		assert.is_nil(A.ItemStats("item:1"))
		C_Item = { GetItemStats = function() error("broken") end }
		assert.is_nil(A.ItemStats("item:1"))
		C_Item = { GetItemStats = function() return { ITEM_MOD_CRIT_RATING_SHORT = "S" } end }
		issecretvalue = function(v) return v == "S" end
		assert.is_nil(A.ItemStats("item:1"))
		assert.equal(false, A.ItemStats(nil))
	end)
end)

describe("Adapter link fields", function()
	local A
	before_each(function()
		A = load()
	end)
	after_each(clear)

	-- Mutation: count the enchant field as a gem.
	it("LinkGemCount counts the filled gem fields", function()
		assert.equal(2, A.LinkGemCount("|cffa335ee|Hitem:212:7000:213746::213491::::80:::::|h[Ring]|h|r"))
		assert.equal(0, A.LinkGemCount("item:212:7000"))
		assert.equal(0, A.LinkGemCount("item:212"))
		assert.is_nil(A.LinkGemCount(nil))
		assert.is_nil(A.LinkGemCount("keystone:180653:503"))
	end)

	-- Mutation: read the bonus count from the item context field.
	it("LinkBonusIDs reads the bonus list after its count", function()
		assert.same({ 6652, 10356, 1540 },
			A.LinkBonusIDs("|cffa335ee|Hitem:212::::::::80:250::13:3:6652:10356:1540:2:9:80|h[Ring]|h|r"))
		assert.same({}, A.LinkBonusIDs("item:212::::::::80:250::13"))
		assert.same({}, A.LinkBonusIDs("item:212"))
		assert.is_nil(A.LinkBonusIDs(nil))
	end)
end)

describe("Adapter.TooltipLines", function()
	after_each(clear)

	local function data(lines)
		return { lines = lines }
	end

	-- Mutation: read only leftText.
	it("returns every left and right text, lower-cased, for a bag slot", function()
		C_TooltipInfo = { GetBagItem = function(bag, slot)
			assert.same({ 0, 3 }, { bag, slot })
			return data({ { leftText = "Blade of Fire" }, { leftText = "One-Hand", rightText = "Sword" },
				{ leftText = "+15 Fire Damage" }, { leftText = "" } })
		end }
		assert.same({ "blade of fire", "one-hand", "sword", "+15 fire damage" }, load().TooltipLines(0, 3, "item:1"))
	end)

	it("reads a link when there is no bag slot (guild and alt items)", function()
		C_TooltipInfo = { GetHyperlink = function(link)
			assert.equal("item:9", link)
			return data({ { leftText = "Saved Thing" } })
		end }
		assert.same({ "saved thing" }, load().TooltipLines(nil, nil, "item:9"))
	end)

	it("false with no API; nil for no data, no lines, a broken call or a secret line", function()
		local A = load()
		assert.equal(false, A.TooltipLines(0, 1, "item:1"))
		C_TooltipInfo = { GetBagItem = function() return nil end }
		assert.is_nil(A.TooltipLines(0, 1))
		C_TooltipInfo = { GetBagItem = function() return data({}) end }
		assert.is_nil(A.TooltipLines(0, 1))
		C_TooltipInfo = { GetBagItem = function() error("broken") end }
		assert.is_nil(A.TooltipLines(0, 1))
		C_TooltipInfo = { GetBagItem = function() return data({ { leftText = "Name" }, { leftText = "SECRET" } }) end }
		issecretvalue = function(v) return v == "SECRET" end
		assert.is_nil(A.TooltipLines(0, 1))
	end)
end)
