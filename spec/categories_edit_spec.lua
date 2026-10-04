-- Week 11 (spec F6, AC6.2): the category editor's writers in Engine/Categories.lua. A user category is made, saved,
-- moved and deleted here; a built-in keeps only the user's difference (spec 8.5); a broken rule is never dropped: a
-- category with a rule that works keeps it in use and the broken text waits as its draft (spec 7.5 #3), one with no
-- rule that works is saved switched off with its error; every writer refuses while the settings are read-only.
local Loader = dofile("spec/helpers/loader.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Category editing (week 11)", function()
	local SB, C, L, changed, lastPath, focusChanged
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		files[#files + 1] = "SwagBag/Engine/Profiles.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		C, L = SB.Categories, SB.L
		C.Load()
		changed, focusChanged = 0, 0
		SB.On("SB_CONFIG_CHANGED", function(_, path)
			changed, lastPath = changed + 1, path
		end)
		SB.On("SB_FOCUS_CHANGED", function()
			focusChanged = focusChanged + 1
		end)
	end)

	-- Mutations: in Categories.CheckName, drop the `for _, c in ipairs(C.list) do ... end` loop (a taken name is
	-- accepted); or in Categories.Create, `table.insert(db.categoryOrder, 1, id)` -> `table.insert(db.categoryOrder, id)`.
	it("Create: a user category with a checked name, shown first, at priority 88", function()
		local id = C.Create("  My potions ", "potion")
		assert.equal("u_my_potions", id)
		local c = C.Get(id)
		assert.same({ "My potions", "potion", 88, true, false, "user" }, { c.name, c.query, c.priority, c.enabled, c.builtin,
			c.source })
		assert.same({ "new", id, "c_keystone" }, { unpack(C.SectionOrder(), 1, 3) })
		assert.equal("u_my_potions_2", C.Create("My potions!", "potion"), "another name, the same id stem")
		assert.same({ nil, "TAKEN" }, { C.Create("my POTIONS", "flask") })
		assert.same({ nil, "TAKEN" }, { C.Create("Gear", "flask") })
		assert.same({ nil, "TAKEN" }, { C.Create("new", "flask") })
		assert.same({ nil, "EMPTY" }, { C.Create("   ", "flask") })
		assert.same({ nil, "LONG" }, { C.Create(string.rep("x", C.MAX_NAME + 1), "flask") })
		assert.same({ nil, "CHARS" }, { C.Create("|cffff0000Red", "flask") })
		assert.same({ nil, "long" }, { C.Create("Long", string.rep("a", C.MAX_QUERY + 1)) })
		SB.Config.db.categoryOrder = { "c_gear", "c_keystone" }
		local third = C.Create("Third", "toy")
		assert.same({ third, "c_gear", "c_keystone" }, SB.Config.db.categoryOrder, "a saved order gets it first")
		assert.equal(third, C.SectionOrder()[2])
	end)

	-- Mutations: in Categories.Save, drop `out.enabled = false -- AC6.2: no rule that works ...` (a rule broken again
	-- is stored switched on); or drop `out.enabled = true -- fixed: on again, ...` (a fixed rule stays off).
	it("AC6.2: a new category whose rule doesn't compile is made switched off with its error; fixed, it is on again", function()
		local id, why, err = C.Create("Broken one", "boe &")
		assert.equal("u_broken_one", id)
		assert.equal("broken", why)
		assert.equal("Expected a value after \"&\" at character 6", err)
		local c = C.Get(id)
		assert.same({ "boe &", false, err }, { c.query, c.enabled, c.error })
		assert.same({ "boe &", false }, { SB.Config.db.categories[id].query, SB.Config.db.categories[id].enabled })
		local _, _, broken = C.Counts()
		assert.same({ "Broken one" }, broken, "the report names it")
		assert.same({ true, "broken", "Expected a closing ) after \"boe\" at character 5" },
			{ C.Save(id, { query = "(boe", enabled = true }) }, "no rule that works to keep")
		assert.same({ false, "(boe" }, { C.Get(id).enabled, C.Get(id).query })
		assert.equal(false, SB.Config.db.categories[id].enabled, "saved switched off (spec 7.10)")
		assert.same({ true }, { C.Save(id, { query = "boe" }) }, "no On/Off sent")
		assert.same({ true, nil }, { C.Get(id).enabled, C.Get(id).error })
		assert.equal(true, SB.Config.db.categories[id].enabled)
	end)

	-- Mutation: in Categories.Save, `if err and out.query ~= nil and not c.error then` -> `if false then` (the
	-- broken text replaces the rule that works, and switches the category off).
	it("a broken change of a rule that works keeps that rule in use, and on; the change waits as a draft until fixed", function()
		local id = C.Create("Pots", "potion")
		local err = "Expected a value after \"&\" at character 9"
		assert.same({ true, "draft", err }, { C.Save(id, { query = "potion &", enabled = true }) })
		local c = C.Get(id)
		assert.same({ "potion", true, nil, "potion &", err }, { c.query, c.enabled, c.error, c.draft, c.draftError })
		assert.same({ "potion", true, "potion &" }, { SB.Config.db.categories[id].query, SB.Config.db.categories[id].enabled,
			SB.Config.db.categories[id].draft })
		local _, _, broken = C.Counts()
		assert.same({}, broken, "it works: nothing is broken")
		assert.truthy(C.Save(id, { name = "Pots 2" }))
		assert.equal("potion &", C.Get(id).draft, "a save without a rule keeps the draft")
		assert.truthy(C.Save(id, { query = "potion | flask" }))
		assert.same({ "potion | flask", nil }, { C.Get(id).query, C.Get(id).draft })
		assert.is_nil(SB.Config.db.categories[id].draft)
		assert.same({ true, "draft", "Expected a value after \"&\" at character 13" },
			{ C.Save("c_consumables", { query = "consumable &" }) })
		assert.same({ draft = "consumable &" }, SB.Config.db.userEdits.c_consumables, "a built-in's draft is its diff")
		assert.same({ "consumable", true }, { C.Get("c_consumables").query, C.Get("c_consumables").enabled })
		assert.truthy(C.Save("c_consumables", { query = "consumable" }))
		assert.is_nil(SB.Config.db.userEdits.c_consumables, "fixed back to its own rule: nothing stored")
	end)

	-- Mutation: in Categories.Save, drop `out.enabled = true -- fixed: on again, ...` (Reagents stays off).
	it("Reagents (On/Off is a setting's) with a broken rule saved off is on again once fixed; the editor sends no On/Off", function()
		SB.Config.Set("bags.reagentSeparate", true)
		SB.Config.db.userEdits.c_reagents = { query = "reagentbag &", enabled = false }
		C.Load()
		assert.same({ false, "Expected a value after \"&\" at character 13" },
			{ C.Get("c_reagents").enabled, C.Get("c_reagents").error })
		assert.truthy(C.Save("c_reagents", { name = "Reagents", query = "reagentbag" }))
		assert.is_nil(SB.Config.db.userEdits.c_reagents, "its own rule, on: nothing stored")
		assert.equal(true, C.Get("c_reagents").enabled)
	end)

	-- Mutation: in Categories.Save, `if def and (v == def[f] or ...) then` -> `if false then` (an unchanged field of a
	-- built-in is stored).
	it("a built-in keeps only the user's difference; Reset to default removes it; its rank rules hold", function()
		assert.truthy(C.Save("c_gear", { name = "Gear", query = "gear & !junk", priority = 70, enabled = true }))
		assert.same({ query = "gear & !junk" }, SB.Config.db.userEdits.c_gear)
		assert.equal("gear & !junk", C.Get("c_gear").query)
		assert.truthy(C.Save("c_gear", { query = "gear", name = "My gear", enabled = false }))
		assert.same({ name = "My gear", enabled = false }, SB.Config.db.userEdits.c_gear)
		assert.truthy(C.Save("c_gear", { name = "Gear", enabled = true }))
		assert.is_nil(SB.Config.db.userEdits.c_gear, "nothing left: nothing stored")
		assert.truthy(C.Save("c_gear", { priority = 89 }))
		assert.truthy(C.ResetBuiltin("c_gear"))
		assert.is_nil(SB.Config.db.userEdits.c_gear)
		assert.equal(70, C.Get("c_gear").priority)
		assert.same({ false, "pinned" }, { C.Save("c_junk", { priority = 50 }) })
		assert.truthy(C.Save("c_junk", { priority = 90, name = "Trash" }), "its own rank is no change")
		assert.same({ name = "Trash" }, SB.Config.db.userEdits.c_junk)
		for _, bad in ipairs({ 90, 0, 2.5, "50" }) do
			assert.same({ false, "priority" }, { C.Save("c_gear", { priority = bad }) }, tostring(bad))
		end
		assert.same({ false, "TAKEN" }, { C.Save("c_gear", { name = "ore" }) })
		assert.truthy(C.Save("c_gear", { name = "GEAR" }), "its own name, another case")
		assert.same({ false, "unknown" }, { C.Save("c_nope", { name = "x" }) })
	end)

	-- Mutations: in Categories.Delete, drop the `left = without(Cfg.charDB.overrides[path], id)` block (this
	-- character's own focus sections keep the id); or `SB.Emit("SB_CONFIG_CHANGED", "focus.sections")` ->
	-- `SB.Emit("SB_CONFIG_CHANGED", nil)`; or in Focus.lua's listener, `if path == "focus.sections" then` ->
	-- `if false then` (Focus refreshes and the open bags re-stack).
	it("deleting a user category takes it out of the order, every focus mode and the collapsed sections", function()
		local id = C.Create("Pots", "potion")
		local keep = C.Create("Keep", "flask")
		SB.Config.Set("focus.sections.mplus", "c_consumables," .. id .. ",c_gear")
		SB.Config.CharOverride("focus.sections.market", true)
		SB.Config.Set("focus.sections.market", id .. ",c_junk")
		SB.Config.db.categoryOrder = { id, keep, "c_gear" }
		SB.Config.UI().collapsed.bags = { [id] = true, c_gear = true }
		SB.Config.Set("focus.style", "collapse")
		SB.Focus.SetSignal("challengeMode", true)
		assert.truthy(SB.Focus.Expanded()[id], "M+ opens it")
		changed, focusChanged = 0, 0
		assert.truthy(C.Delete(id))
		assert.is_nil(C.Get(id))
		assert.equal(false, SB.Config.db.categories[id], "deleted, and its id is never given again")
		assert.same({ keep, "c_gear" }, SB.Config.db.categoryOrder)
		assert.equal("c_consumables,c_gear", SB.Config.Get("focus.sections.mplus"))
		assert.equal("c_junk", SB.Config.Get("focus.sections.market"))
		assert.same({ c_gear = true }, SB.Config.UI().collapsed.bags)
		assert.equal(1, changed, "Focus is told once")
		assert.equal("focus.sections", lastPath, "not nil: prices, tooltips and the rest keep what they know")
		assert.is_nil(SB.Focus.Expanded()[id], "Focus read its sections again")
		assert.equal(0, focusChanged, "nothing open moves: the bags are not re-stacked (P5)")
		assert.same({ false, "builtin" }, { C.Delete("c_gear") })
		assert.same({ false, "unknown" }, { C.Delete(id) })
		assert.truthy(C.Delete(keep))
		assert.equal(1, changed, "nothing opened it: no event")
	end)

	-- Mutation: in Focus.lua's sectionNames, `if not SB.Categories or sid == SB.Categories.FREE or
	-- SB.Categories.Get(sid) then` -> `if true then` (a deleted id is named in /swagbag mode list).
	it("an id that is no category any more (another character's own sections can keep one) is not named in /swagbag mode list", function()
		SB.Config.Set("focus.sections.fishing", "c_fish,u_gone,free")
		local line = SB.Focus.ListLines()[5]
		assert.equal(L.MODE_LIST_LINE:format(L.MODE_FISHING, L.OVERLAY_ON, "", "Fish & Lures, Free"), line)
	end)

	-- Mutation: in Categories.Move, `if to < 1 or to > #order then` -> `if to < 1 then`.
	it("Move: one place up or down in the display order, saved; past either end refused", function()
		assert.truthy(C.Move("c_consumables", -1))
		assert.same({ "new", "c_consumables", "c_keystone", "c_gear" }, { unpack(C.SectionOrder(), 1, 4) })
		assert.equal("c_consumables", SB.Config.db.categoryOrder[1])
		assert.same({ false, "edge" }, { C.Move("c_consumables", -1) })
		assert.same({ false, "edge" }, { C.Move("c_other", 1) })
		assert.truthy(C.Move("c_keystone", 1))
		assert.same({ "c_consumables", "c_gear", "c_keystone" }, { unpack(SB.Config.db.categoryOrder, 1, 3) })
		assert.same({ false, "unknown" }, { C.Move("u_none", 1) })
	end)

	-- Mutation: in Categories.ResetBuiltin, drop the read-only refusal (the diff is removed while read-only).
	it("read-only: every writer refuses and changes nothing", function()
		local id = C.Create("Mine", "toy")
		assert.truthy(C.Save("c_gear", { name = "Kit" }))
		SB.Config.readOnly = true
		assert.same({ nil, "readonly" }, { C.Create("Other", "pet") })
		assert.same({ false, "readonly" }, { C.Save(id, { name = "Ours" }) })
		assert.same({ false, "readonly" }, { C.Delete(id) })
		assert.same({ false, "readonly" }, { C.Move(id, 1) })
		assert.same({ false, "readonly" }, { C.ResetBuiltin("c_gear") })
		assert.same({ name = "Kit" }, SB.Config.db.userEdits.c_gear)
		assert.equal("Mine", C.Get(id).name)
	end)

	-- Mutation: in Categories.Preview, `if SB.Query.Eval(compiled, record) == true then` -> `if SB.Query.Eval(compiled,
	-- record) ~= false then` (an item still loading counts as a match).
	it("Preview counts the bags' items a rule matches now; an error or a failing keyword says why", function()
		Fixtures.SmallBags(SB.Adapter)
		SB.Adapter.Put(0, 7, Fixtures.UNLOADED, 1)
		SB.Inventory.ScanAll()
		assert.same({ 2, 7 }, { C.Preview("potion | flask") })
		assert.same({ 7, 7 }, { C.Preview("") }, "no rule: every item")
		assert.same({ 0, 7 }, { C.Preview("boe & !gear") })
		assert.same({ 1, 7 }, { C.Preview("gear & ilvl>=280 | epic & !keystone & !gear") })
		assert.same({ nil, "Expected a value after \"|\" at character 9" }, { C.Preview("potion |") })
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function() error("boom") end })
		assert.same({ nil, L.SEARCH_EVAL_FAILED }, { C.Preview("boom") })
	end)

	-- Mutations: in Categories.CheckName, drop the `for _, def in ipairs(SB.CategoryDefaults) do` loop (a renamed
	-- built-in's own name is given away); or in Categories.Delete, `Cfg.db.categories[id] = false` ->
	-- `Cfg.db.categories[id] = nil` (the id is given again).
	it("a renamed built-in keeps its own name reserved; a deleted category's id is never given again", function()
		assert.truthy(C.Save("c_gear", { name = "Kit" }))
		assert.same({ nil, "TAKEN" }, { C.Create("gear", "toy") }, "Reset to default would make two named Gear")
		assert.same({ false, "TAKEN" }, { C.Save("c_boe", { name = "Gear" }) })
		assert.truthy(C.Save("c_gear", { name = "Gear" }), "its own name, back")
		local id = C.Create("Pots", "potion")
		assert.equal("u_pots", id)
		assert.truthy(C.Delete(id))
		assert.equal("u_pots_2", C.Create("Pots", "potion"), "a stale u_pots elsewhere never finds a new category")
		C.Load()
		assert.is_nil(C.Get("u_pots"))
	end)

	-- Mutations: in Categories' queryWhy, drop `elseif SB.Query.EscapeCode(query) then ⏎ return "code"`; or in
	-- Profiles.Export, `if type(def) == "table" and importable(def.query) then` -> `if type(def) == "table" then` (the
	-- whole string is refused at import).
	it("a rule with a chat code is refused; an export leaves out a rule an import would refuse, and names it", function()
		assert.same({ nil, "code" }, { C.Create("Linky", "boe | |Hitem:19019|h") })
		local id = C.Create("Pots", "potion")
		assert.same({ false, "code" }, { C.Save(id, { query = "|cffff0000red" }) })
		assert.equal("potion", C.Get(id).query)
		local bad = C.Create("Broken", "boe &")
		SB.Config.db.userEdits.c_ore = { name = "Rocks", query = "ore &" } -- a rule that broke in an older build
		local text, left = SB.Profiles.Export(true)
		assert.same({ "Broken", "Rocks" }, left)
		local data = assert(SB.Profiles.Parse(text), "never refused at import")
		assert.same({ "Pots", "potion" }, { data.users[id].name, data.users[id].query })
		assert.is_nil(data.users[bad])
		assert.same({ name = "Rocks" }, data.edits.c_ore)
		assert.equal(C.PINNED, SB.Profiles.PINNED, "one list of the four that keep their priority")
		assert.same({ 500, 500, 500 }, { SB.Query.MAX_QUERY, C.MAX_QUERY, SB.Profiles.MAX_STRING })
	end)

	-- Mutations: in Categories.Save, `elseif #warnings > 0 and out.query ~= nil and out.query ~= c.query then` ->
	-- `elseif false then` (Save says nothing of a word that matches item names only); or -> `elseif #warnings > 0 then`
	-- (a built-in's own words are warned about at every save of its name or priority).
	it("Save and Create run Validate (spec 7.9): a rule with a warning is saved, and the answer carries it", function()
		local id, why, warnings = C.Create("Pots", "potin")
		assert.same({ "u_pots", "warned" }, { id, why })
		assert.same({ kind = "text", value = "potin", position = 1 }, warnings[1])
		local ok, why2, more = C.Save(id, { query = "#potin | flask" })
		assert.same({ true, "warned", "unknown_keyword", "potin" }, { ok, why2, more[1].kind, more[1].value })
		assert.same({ true }, { C.Save(id, { name = "Pots 2", query = "#potin | flask" }) }, "its rule unchanged: said already")
		assert.same({ true }, { C.Save("c_fish", { priority = 61, query = "fish | lure | bait" }) }, "its own words")
		assert.same({ true }, { C.Save(id, { query = "potion" }) })
		assert.equal("potion", C.Get(id).query)
	end)

	-- Mutation: in Categories.lua's build, `if type(draft) == "string" then` -> `if draft then` (a draft that is not
	-- text breaks the load).
	it("a save from before week 11 loads as it did; a draft and a deleted id are read defensively", function()
		SB.Config.db.categories = { u_mats = { name = "Mats", query = "herb | ore", priority = 58, displayOrder = 55,
			enabled = true, source = "user" } }
		SB.Config.db.userEdits = { c_junk = { name = "Trash" } }
		local before = SB.Config.Copy({ SB.Config.db.categories, SB.Config.db.userEdits })
		C.Load()
		local c = C.Get("u_mats")
		assert.same({ "Mats", "herb | ore", 58, true, "user", nil, nil, nil },
			{ c.name, c.query, c.priority, c.enabled, c.source, c.error, c.draft, c.draftError })
		assert.equal("Trash", C.Name("c_junk"))
		assert.same(before, { SB.Config.db.categories, SB.Config.db.userEdits }, "loading changes nothing saved")
		SB.Config.db.categories.u_gone = false
		SB.Config.db.categories.u_odd = { name = "Odd", query = "toy", draft = 5 }
		SB.Config.db.categories.u_new = { name = "New one", query = "toy", draft = "toy &" }
		C.Load()
		assert.is_nil(C.Get("u_gone"))
		assert.same({ "toy", true, nil }, { C.Get("u_odd").query, C.Get("u_odd").enabled, C.Get("u_odd").draft })
		assert.same({ "toy &", "Expected a value after \"&\" at character 6" }, { C.Get("u_new").draft,
			C.Get("u_new").draftError })
	end)
end)
