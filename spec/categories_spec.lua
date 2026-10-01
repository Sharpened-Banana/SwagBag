local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Checks.lua", "SwagBag/Core/Blocked.lua", "SwagBag/Core/Report.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
	"SwagBag/Engine/CategoryDefaults.lua", "SwagBag/Engine/Categories.lua",
}

-- A misspelled keyword silently becomes a name search, so check the keywords really used.
-- c_fish (name search by design), c_other (fallback) are exempt; c_tools also has an item list.
local EXPECTED = {
	c_keystone = { "keystone" }, c_consumables = { "consumable" }, c_gear = { "gear" },
	c_boe = { "boe", "gear" }, c_tradegoods = { "reagent", "tradegoods" }, c_herbs = { "herb" }, c_ore = { "ore" },
	c_leathercloth = { "cloth", "leather" }, c_enchanting = { "enchanting" }, c_cooking = { "cooking" },
	c_quest = { "questitem" }, c_housing = { "housing" }, c_collect = { "mount", "pet", "toy" },
	c_tools = { "profession gear", "profession tool" }, c_reagents = { "reagentbag" }, c_junk = { "junk" },
}

describe("Categories", function()
	local SB, C
	before_each(function()
		SB = Loader.New(FILES)
		SB.Config.Init(nil, nil)
		C = SB.Categories
		C.Load()
	end)

	local function ids(list)
		local out = {}
		for i, c in ipairs(list) do
			out[i] = c.id
		end
		return out
	end

	it("ships the spec 7.6 set in display order, with New first and Free last", function()
		assert.same({ "new", "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_herbs", "c_ore",
			"c_leathercloth", "c_enchanting", "c_cooking", "c_fish", "c_quest", "c_housing", "c_collect", "c_tools",
			"c_junk", "c_other", "free" }, C.SectionOrder())
		assert.equal("Keystone & Crests", C.Name("c_keystone"))
		assert.equal("New", C.Name("new"))
		assert.equal("Free", C.Name("free"))
	end)

	it("every built-in query compiles without errors or warnings", function()
		for _, c in ipairs(C.list) do
			assert.is_nil(c.error, c.id)
			assert.same({}, c.compiled.warnings, c.id)
		end
		for _, c in ipairs(C.list) do
			local want = EXPECTED[c.id]
			if want then
				local got = { unpack(c.compiled.keywords) }
				table.sort(got)
				assert.same(want, got, c.id .. " uses the intended keywords")
			end
		end
		assert.falsy(C.Get("c_other").hasRule, "Other has no rule; it is the fallback")
		assert.truthy(C.Get("c_gear").hasRule)
	end)

	it("orders rules by priority, ties by id, never by table order", function()
		local p = ids(C.ByPriority())
		assert.same({ "c_reagents", "c_keystone", "c_junk", "c_quest", "c_tools", "c_boe", "c_gear", "c_consumables" },
			{ unpack(p, 1, 8) })
		assert.equal("c_other", p[#p])
		-- Five rules tie at 55; their id order is the opposite of definition order for several.
		-- Shuffle the definition order too, so the result cannot depend on input order.
		local tied = { "c_ore", "c_herbs", "c_cooking", "c_enchanting", "c_leathercloth" }
		local want = { "c_cooking", "c_enchanting", "c_herbs", "c_leathercloth", "c_ore" }
		local orig = {}
		for i, d in ipairs(SB.CategoryDefaults) do
			orig[i] = d
		end
		local shuffles = {
			function(n, i) return n - i + 1 end,
			function(n, i) return (i * 7) % n + 1 end,
			function(n, i) return ((i + 5) % n) + 1 end,
		}
		for _, shuffle in ipairs(shuffles) do
			local n = #orig
			local seen, perm = {}, {}
			for i = 1, n do
				local j = shuffle(n, i)
				if not seen[j] then
					seen[j] = true
					perm[#perm + 1] = orig[j]
				end
			end
			for i = 1, n do
				if not seen[i] then
					perm[#perm + 1] = orig[i]
				end
			end
			assert.equal(n, #perm)
			for i = 1, n do
				SB.CategoryDefaults[i] = perm[i]
			end
			SB.Config.db.userEdits = {}
			for _, id in ipairs(tied) do
				SB.Config.db.userEdits[id] = { priority = 55 }
			end
			C.Load()
			local got = {}
			for _, id in ipairs(ids(C.ByPriority())) do
				for _, t in ipairs(tied) do
					if id == t then
						got[#got + 1] = id
					end
				end
			end
			assert.same(want, got, "ties by id under every input order")
		end
		for i = 1, #orig do
			SB.CategoryDefaults[i] = orig[i]
		end
	end)

	it("Reagents exists only while the reagent bag is shown separately (AC1.4)", function()
		assert.falsy(C.Get("c_reagents").enabled)
		SB.Config.Set("bags.reagentSeparate", true)
		C.Load()
		assert.truthy(C.Get("c_reagents").enabled)
		local order = C.SectionOrder()
		assert.equal("c_reagents", order[#order - 3])
	end)

	it("stores no built-in in SavedVariables until the user edits one (spec 8.5)", function()
		assert.same({}, SB.Config.db.userEdits)
		assert.same({}, SB.Config.db.categories)
	end)

	it("applies a stored diff over a built-in, and ResetBuiltin removes it", function()
		SB.Config.db.userEdits.c_gear = { name = "My Gear", priority = 99 }
		C.Load()
		assert.equal("My Gear", C.Get("c_gear").name)
		assert.equal(99, C.Get("c_gear").priority)
		assert.equal("gear", C.Get("c_gear").query, "fields not in the diff keep the default")
		C.ResetBuiltin("c_gear")
		assert.equal("Gear", C.Get("c_gear").name)
		assert.is_nil(SB.Config.db.userEdits.c_gear)
	end)

	it("AddToList stores a diff, moves the item off other lists, and bumps the version", function()
		local v = C.version
		assert.truthy(C.AddToList("c_consumables", 211880))
		assert.truthy(C.version > v)
		assert.truthy(C.Get("c_consumables").itemList.include[211880])
		assert.same({ itemList = { include = { [211880] = true } } }, SB.Config.db.userEdits.c_consumables)
		C.AddToList("c_fish", 211880)
		assert.falsy(C.Get("c_consumables").itemList.include[211880])
		assert.truthy(C.Get("c_fish").itemList.include[211880])
	end)

	it("moving a default-included item (Hearthstone) elsewhere excludes it from the built-in", function()
		assert.truthy(C.Get("c_tools").itemList.include[6948])
		C.AddToList("c_other", 6948)
		assert.truthy(C.Get("c_tools").itemList.exclude[6948])
		assert.truthy(C.Get("c_other").itemList.include[6948])
		C.AddToList("c_tools", 6948)
		assert.falsy(C.Get("c_tools").itemList.exclude[6948])
		assert.falsy(C.Get("c_other").itemList.include[6948])
	end)

	it("an item moved away and back leaves no diff behind (spec 8.5)", function()
		C.AddToList("c_fish", 211880)
		C.AddToList("c_consumables", 211880)
		assert.falsy(SB.Config.db.userEdits.c_fish, "emptied diff is pruned")
		C.ResetBuiltin("c_consumables")
		assert.same({}, SB.Config.db.userEdits)
		local _, edited = C.Counts()
		assert.equal(0, edited)
	end)

	it("Hearthstone round trip ends with no stored diffs", function()
		C.AddToList("c_other", 6948)
		C.AddToList("c_tools", 6948)
		assert.same({}, SB.Config.db.userEdits)
		assert.truthy(C.Get("c_tools").itemList.include[6948])
		local _, edited = C.Counts()
		assert.equal(0, edited)
	end)

	it("AddToList onto a damaged diff does not throw and rejects bad item ids", function()
		SB.Config.db.userEdits = { c_gear = "garbage" }
		SB.Config.db.categories = { u_x = "junk" }
		C.Load()
		assert.truthy(C.AddToList("c_gear", 123))
		assert.truthy(C.Get("c_gear").itemList.include[123])
		assert.falsy(C.AddToList("c_gear", 0 / 0))
		assert.falsy(C.AddToList("c_gear", 1.5))
		assert.falsy(C.AddToList("c_gear", -3))
	end)

	it("AddToList refuses unknown categories, New/Free and non-item values", function()
		assert.falsy(C.AddToList("nope", 1))
		assert.falsy(C.AddToList("new", 1))
		assert.falsy(C.AddToList("c_gear", "x"))
	end)

	it("a user category whose query does not compile is disabled with its error, others unaffected", function()
		SB.Config.db.categories.u_broken = { name = "Broken", query = "boe &", priority = 500, displayOrder = 5 }
		SB.Config.db.categories.u_ok = { name = "Mine", query = "potion", priority = 66, displayOrder = 25 }
		C.Load()
		local broken = C.Get("u_broken")
		assert.falsy(broken.enabled)
		assert.equal("Expected a value after \"&\" at character 6", broken.error)
		assert.truthy(C.Get("u_ok").enabled)
		local order = C.SectionOrder()
		for _, id in ipairs(order) do
			assert.truthy(id ~= "u_broken")
		end
		assert.equal("u_ok", order[4], "user category placed by its displayOrder (25: after Consumables)")
	end)

	it("a saved categoryOrder wins; unknown ids are skipped and the rest follow", function()
		SB.Config.db.categoryOrder = { "c_junk", "gone", "c_gear" }
		C.Load()
		assert.same({ "new", "c_junk", "c_gear", "c_keystone" }, { unpack(C.SectionOrder(), 1, 4) })
	end)

	it("damaged saved category data never breaks loading (Review Focus 4)", function()
		SB.Config.db.userEdits = { c_gear = "garbage", c_ore = { priority = "high", itemList = "x" }, nope = { name = "?" } }
		SB.Config.db.categories = { u_bad = "x", u_list = { name = "Only a list", itemList = { include = { [5] = true } } } }
		SB.Config.db.categoryOrder = { 42, "c_gear" }
		C.Load()
		assert.equal("Gear", C.Get("c_gear").name)
		assert.equal(0, C.Get("c_ore").priority)
		assert.same({}, C.Get("c_ore").itemList.include)
		assert.is_nil(C.Get("u_bad"))
		assert.falsy(C.Get("u_list").hasRule, "no query: only its manual list")
		assert.truthy(C.Get("u_list").enabled)
		assert.equal("c_gear", C.SectionOrder()[2])
	end)

	it("Counts reports totals, edited categories and broken ones", function()
		SB.Config.db.userEdits.c_gear = { name = "My Gear" }
		SB.Config.db.categories.u_broken = { name = "Broken", query = "(", priority = 1 }
		C.Load()
		assert.truthy(C.MarkFailed("c_fish", "boom"))
		assert.falsy(C.MarkFailed("c_fish", "boom again"), "only the first failure counts")
		local total, edited, broken = C.Counts()
		assert.equal(19, total)
		assert.equal(2, edited)
		assert.same({ "Fish & Lures", "Broken" }, broken)
	end)

	it("/swagbag report shows category counts and broken categories", function()
		SB.Checks.last = {}
		C.MarkFailed("c_fish", "boom")
		local text = SB.Report.Build()
		assert.truthy(text:find("\nCategories: 18 (0 edited)  Broken: Fish & Lures", 1, true))
	end)
end)
