local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Checks.lua", "SwagBag/Core/Blocked.lua", "SwagBag/Core/Report.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
	"SwagBag/Engine/CategoryDefaults.lua", "SwagBag/Engine/Categories.lua",
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
		assert.falsy(C.Get("c_other").hasRule, "Other has no rule; it is the fallback")
		assert.truthy(C.Get("c_gear").hasRule)
	end)

	it("orders rules by priority, ties by id, never by table order", function()
		local p = ids(C.ByPriority())
		assert.same({ "c_reagents", "c_keystone", "c_junk", "c_quest", "c_tools", "c_boe", "c_gear", "c_consumables" },
			{ unpack(p, 1, 8) })
		assert.equal("c_other", p[#p])
		SB.Config.db.userEdits.c_ore = { priority = 55 } -- same as Herbs
		C.Load()
		p = ids(C.ByPriority())
		local herbs, ore
		for i, id in ipairs(p) do
			if id == "c_herbs" then
				herbs = i
			elseif id == "c_ore" then
				ore = i
			end
		end
		assert.equal(herbs + 1, ore, "tie: c_herbs before c_ore")
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
