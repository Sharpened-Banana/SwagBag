-- The list view's display order (Engine/Sort.lua): pure sorting by name, count, item level or
-- value, items without the value last, ties by name then physical order, empty slots after.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Prices.lua",
	"SwagBag/Providers/Auctionator.lua", "SwagBag/Engine/OverlayData.lua", "SwagBag/Engine/Sort.lua",
}

-- The guard the user asked for in week 5: WoW's Lua 5.1 refuses a boolean or nil for %s, so every
-- spec does too (spec/helpers/format51.lua, installed by spec/runner.lua). Mutation: in format51,
-- drop the "%%" skip or the "+ #" flag class from the pattern (the F2 tests below fail).
describe("Test format (spec/helpers/format51.lua)", function()
	it("formats %s as strictly as WoW's Lua 5.1: a boolean or nil is an error, strings and numbers are fine", function()
		Loader.New()
		assert.has_error(function() return ("%s"):format(true) end, "string expected, got boolean")
		assert.has_error(function() return ("%d %s"):format(1, nil) end, "string expected, got nil")
		assert.equal("a 1 2.5", ("%s %s %.1f"):format("a", 1, 2.5))
		assert.equal("100%", ("%d%%"):format(100))
	end)

	-- F2: a flag the pattern does not know would shift the argument index and check the wrong argument.
	it("counts the arguments right past the + space and # flags, and past a literal %%", function()
		assert.has_error(function() return ("%+d %s"):format(1, true) end, "bad argument #3")
		assert.equal("+1 a", ("%+d %s"):format(1, "a"))
		assert.has_error(function() return ("% d %s"):format(1, true) end, "bad argument #3")
		assert.has_error(function() return ("%#x %s"):format(255, nil) end, "bad argument #3")
		assert.equal("0xff a", ("%#x %s"):format(255, "a"))
		assert.has_error(function() return ("%%s %s"):format(true) end, "bad argument #2")
		assert.equal("%s a", ("%%s %s"):format("a"))
		assert.equal("%s", ("%%s"):format(true))
		assert.equal("50% x", ("%d%% %s"):format(50, "x"))
	end)
end)

describe("Sort", function()
	local SB, A, S
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		S = SB.Sort
	end)

	local function slot(n, record)
		return { bag = 0, slot = n, record = record }
	end

	local function rec(name, count, extra)
		local r = extra or {}
		r.name, r.count = name, count
		return r
	end

	local function names(list)
		local out = {}
		for i, s in ipairs(list) do
			out[i] = s.record and s.record.name or ("empty " .. s.slot)
		end
		return out
	end

	local function value(r)
		return r.v
	end

	-- Mutation: compare a.key < b.key for both directions.
	it("by name, A to Z or Z to A; empty slots after, in physical order", function()
		local slots = { slot(1, rec("Bismuth", 5)), slot(2, nil), slot(3, rec("Algari Healing Potion", 2)),
			slot(4, nil), slot(5, rec("Mycobloom", 20)) }
		assert.same({ "Algari Healing Potion", "Bismuth", "Mycobloom", "empty 2", "empty 4" },
			names(S.DisplayOrder(slots, { by = "name", desc = false }, value)))
		assert.same({ "Mycobloom", "Bismuth", "Algari Healing Potion", "empty 2", "empty 4" },
			names(S.DisplayOrder(slots, { by = "name", desc = true }, value)))
	end)

	it("by count, highest first", function()
		local slots = { slot(1, rec("A", 5)), slot(2, rec("B", 20)), slot(3, rec("C", 1)) }
		assert.same({ "B", "A", "C" }, names(S.DisplayOrder(slots, { by = "count", desc = true }, value)))
	end)

	-- Mutation: in the comparator, drop the "a.key == nil -> false" branch.
	it("an item without the value goes last in both directions (a potion's item level, an unpriced item)", function()
		local helm = rec("Helm", 1, { equipLoc = "INVTYPE_HEAD", ilvl = 270 })
		local ring = rec("Ring", 1, { equipLoc = "INVTYPE_FINGER", ilvl = 285 })
		local potion = rec("Potion", 5, { ilvl = 300 })
		local slots = { slot(1, potion), slot(2, helm), slot(3, ring) }
		assert.same({ "Ring", "Helm", "Potion" }, names(S.DisplayOrder(slots, { by = "ilvl", desc = true }, value)))
		assert.same({ "Helm", "Ring", "Potion" }, names(S.DisplayOrder(slots, { by = "ilvl", desc = false }, value)))
		local priced = { slot(1, rec("Unpriced", 1)), slot(2, rec("Cheap", 1, { v = 10 })), slot(3, rec("Dear", 1, { v = 90 })) }
		assert.same({ "Cheap", "Dear", "Unpriced" }, names(S.DisplayOrder(priced, { by = "value", desc = false }, value)))
	end)

	-- Mutation: drop the name tie-break (equal keys keep their input order).
	it("ties are broken by name, then by physical order, so the order never depends on the input table", function()
		local a1, a2 = rec("Same", 1, { v = 5 }), rec("Same", 1, { v = 5 })
		local slots = { slot(1, rec("Zed", 1, { v = 5 })), slot(2, a1), slot(3, a2) }
		local out = S.DisplayOrder(slots, { by = "value", desc = true }, value)
		assert.same({ "Same", "Same", "Zed" }, names(out))
		assert.equal(2, out[1].slot)
		assert.equal(3, out[2].slot)
	end)

	it("an item still loading sorts by the name in its link, else last", function()
		local loading = { link = "|cff0070dd|Hitem:1|h[Aaa Loading]|h|r", count = 1, pending = true }
		local slots = { slot(1, rec("Bbb", 1)), slot(2, loading), slot(3, { count = 1, pending = true }) }
		local out = S.DisplayOrder(slots, { by = "name", desc = false }, value)
		assert.equal(2, out[1].slot)
		assert.equal(1, out[2].slot)
		assert.equal(3, out[3].slot)
	end)

	it("Sort.Next: the same column flips; another column starts at its natural direction", function()
		assert.same({ by = "value", desc = false }, S.Next({ by = "value", desc = true }, "value"))
		assert.same({ by = "name", desc = false }, S.Next({ by = "value", desc = true }, "name"))
		assert.same({ by = "count", desc = true }, S.Next({ by = "name", desc = false }, "count"))
		assert.same({ by = "ilvl", desc = true }, S.Next(nil, "ilvl"))
	end)

	it("Sort.Spec: value, highest first, by default; a damaged saved column falls back to value", function()
		assert.same({ by = "value", desc = true }, S.Spec())
		SB.Config.Set("bags.list.sort", "weight")
		assert.same({ by = "value", desc = true }, S.Spec())
		assert.truthy(S.Save("name", false))
		assert.same({ by = "name", desc = false }, S.Spec())
	end)

	-- Mutation: in Sort.Save, return true whatever Config.Set answered.
	it("Sort.Save refuses an unknown column and read-only settings, and writes nothing", function()
		assert.falsy(S.Save("weight", true))
		SB.Config.readOnly = true
		assert.falsy(S.Save("name", false))
		SB.Config.readOnly = false
		assert.same({ by = "value", desc = true }, S.Spec())
	end)

	it("Sort.Ilvl: equippable gear only", function()
		assert.equal(285, S.Ilvl({ equipLoc = "INVTYPE_FINGER", ilvl = 285 }))
		assert.is_nil(S.Ilvl({ equipLoc = "", ilvl = 300 }))
		assert.is_nil(S.Ilvl(nil))
	end)

	-- D11 / W3-35. Mutation: in Sort.Value, pass false instead of isBound or isWUE.
	it("Sort.Value: the stack's value; a bound or warbound-until-equipped item at its vendor price", function()
		A.items[Fixtures.BOE_RING].sellPrice = 1000
		A.auctionator = { prices = { ["item:225001"] = 500000 } }
		local ring = { itemID = Fixtures.BOE_RING, link = "item:225001", count = 2 }
		assert.equal(1000000, S.Value(ring))
		SB.Prices.Invalidate()
		ring.isBound = true
		assert.equal(2000, S.Value(ring))
		ring.isBound, ring.isWUE = false, true
		assert.equal(2000, S.Value(ring))
		assert.is_nil(S.Value({ itemID = Fixtures.BOE_RING, link = "item:225001", count = 1, pending = true }))
		assert.is_nil(S.Value(nil))
	end)
end)
