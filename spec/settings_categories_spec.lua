-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 11 (spec F6, AC6.1, AC6.2): Settings > Categories, the visual rule builder. The page is driven the way the
-- user drives it: buttons by their text, text boxes by typing and Enter.
local P = "%s, priority %d" -- a category's line in the list (L.CAT_LIST_PRIORITY)
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Settings > Categories (week 11)", function()
	local SB, SW, C, L, searched
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		table.insert(files, 12, "SwagBag/Engine/Query/Rows.lua") -- right after Query.lua, as in the TOC
		table.insert(files, 13, "SwagBag/Engine/Query/Paste.lua")
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		Fake.Install()
		searched = {}
		SB.Slash.Register("search", "test", function(arg)
			searched[#searched + 1] = arg
			SB.Search.SetText(arg) -- the bags' search now holds it, as /swagbag search does
			return "searched " .. arg
		end)
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsCategories.lua")
		SW, C, L = SB.SettingsWindow, SB.Categories, SB.L
		C.Load()
		Fixtures.SmallBags(SB.Adapter)
		SB.Inventory.ScanAll()
		SW.Show("categories")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function texts()
		local out = {}
		for i = 1, SW.used.buttons do
			out[i] = SW.buttons[i].text
		end
		return out
	end

	local function labels()
		local out = {}
		for i = 1, SW.used.labels do
			out[i] = SW.labels[i].text
		end
		return out
	end

	local function has(list, want)
		for _, v in ipairs(list) do
			if v == want then
				return true
			end
		end
		return false
	end

	-- The n-th shown button with this text (default the first).
	local function nth(text, n)
		n = n or 1
		for i = 1, SW.used.buttons do
			local b = SW.buttons[i]
			if b.text == text then
				n = n - 1
				if n == 0 then
					return b
				end
			end
		end
		error("no button " .. text)
	end

	local function click(text, n)
		Fake.Fire(nth(text, n), "OnClick")
		return SW.lastStatus
	end

	-- Type into the n-th text box shown (as the user does: each keystroke, then Enter).
	local function type(n, text)
		local e = SW.inputs[n]
		assert.truthy(e and n <= SW.used.inputs, "no text box " .. n)
		e:SetText(text)
		Fake.Fire(e, "OnTextChanged", true)
		return e
	end

	local function enter(n, text)
		Fake.Fire(type(n, text), "OnEnterPressed")
		return SW.lastStatus
	end

	-- Mutations: in SettingsCategories' state(), `if c.error then` -> `if false then` (a broken one reads "off"); or
	-- `return L.CAT_LIST_PRIORITY:format(s, c.priority)` -> `return s` (no priority in the list).
	it("the page lists every category in display order with its priority, Edit, Up and Down, and the state it is in", function()
		assert.equal(L.CAT_INTRO, labels()[1])
		assert.same({ L.CAT_NEW_BUTTON, L.PASTE_BUTTON, L.CAT_EDIT, L.CAT_UP, L.CAT_DOWN }, { unpack(texts(), 1, 5) })
		assert.equal(L.CAT_MAKE, labels()[2])
		assert.same({ P:format("Keystone & Crests", 95), P:format("Consumables", 65), P:format("Gear", 70) },
			{ unpack(labels(), 3, 5) })
		assert.equal("Other", labels()[#labels()], "Other takes what no rule takes: no priority")
		assert.equal(2 + #C.display * 3, #texts())
		C.Create("Mine", "toy")
		C.Create("Bad", "boe &")
		C.Save("c_gear", { name = "Kit" })
		C.Save("c_boe", { query = "gear & boe &" })
		SW.Render()
		local l = labels()
		assert.equal(P:format("Bad (off: its rule has an error)", 88), l[3])
		assert.equal(P:format("Mine (yours)", 88), l[4])
		assert.equal(P:format("Kit (changed)", 70), l[7])
		assert.truthy(has(l, P:format("BoE gear (your change has an error: the rule before it is used)", 75)))
		assert.truthy(has(l, P:format("Reagents (off)", 100)), "off while the reagent bag shares the bags")
	end)

	-- Mutation: in SettingsCategories' move(), `return (step < 0 and L.CAT_MOVED_UP or L.CAT_MOVED_DOWN):format(name)` ->
	-- `return L.CAT_UNKNOWN`.
	it("Up and Down move a category one place and answer once; the first can't go up", function()
		assert.equal("Keystone & Crests is already first.", click(L.CAT_UP, 1))
		assert.equal("Consumables moved up one place.", click(L.CAT_UP, 2))
		assert.same({ P:format("Consumables", 65), P:format("Keystone & Crests", 95) }, { unpack(labels(), 3, 4) })
		assert.equal("Other is already last.", click(L.CAT_DOWN, #C.display))
		assert.equal("Consumables moved down one place.", click(L.CAT_DOWN, 1))
		assert.equal(0, #SB.Adapter.Lines(), "the status line answers, not chat")
	end)

	-- Mutations: in SettingsCategories' pick(), drop `rulesChanged(d)` (the picked keyword never reaches the text); or in
	-- SettingsWindow's Render, drop `e.onChange = row.set` (typing is lost).
	it("New category: a name, a rule from the lists, a number, Save: it shows first, at priority 88", function()
		assert.equal(L.CAT_NEW_HINT, click(L.CAT_NEW_BUTTON))
		assert.equal(L.CAT_EDITING_NEW, labels()[1])
		type(1, "Big gear")
		assert.equal(L.CAT_PICK_HINT, click(L.CAT_ADD_RULE))
		assert.truthy(has(labels(), L.KW_FAMILY_NUMBER))
		assert.equal(L.CAT_RULE_NOW:format("gear"), click("gear", 1))
		click(L.CAT_ADD_RULE)
		assert.equal(L.CAT_TYPE_VALUE, click("ilvl"))
		assert.truthy(has(labels(), "Rule 2: ilvl >= ?"))
		assert.equal(L.CAT_RULE_NOW:format("gear & ilvl>=280"), enter(2, "280"))
		assert.equal(L.CAT_RULE_NOW:format("gear & ilvl>280"), click(">"))
		assert.equal("Matches 1 of the 6 items in your bags right now.", labels()[#labels() - 2])
		assert.equal(L.CAT_SAVED:format("Big gear"), click(L.CAT_SAVE))
		local c = C.Get("u_big_gear")
		assert.same({ "Big gear", "gear & ilvl>280", 88, true }, { c.name, c.query, c.priority, c.enabled })
		assert.equal("u_big_gear", C.SectionOrder()[2])
		assert.equal(P:format("Big gear (yours)", 88), labels()[3], "back at the list")
	end)

	-- Mutation: in SettingsCategories' readText(), `d.rules, d.why, d.err, d.textTyped = rules, why, err, false` ->
	-- `d.why, d.err, d.textTyped = why, err, false` (the text never changes the rows).
	it("rows and text change each other, losslessly; a rule nobody touched keeps its own spelling", function()
		click(L.CAT_EDIT, 5) -- BoE gear: gear & boe
		assert.equal("Editing: BoE gear", labels()[1])
		assert.truthy(has(labels(), "Rule 1: gear"))
		assert.truthy(has(labels(), "Rule 2: boe"))
		assert.equal(L.CAT_RULE_NOW:format("gear & !boe"), click(L.CAT_NOT, 3))
		assert.truthy(has(labels(), "Rule 2: not boe"))
		assert.equal(L.CAT_TEXT_SHOWN, click(L.CAT_SHOW_TEXT))
		assert.equal("gear & !boe", SW.inputs[2]:GetText())
		assert.equal(L.CAT_TEXT_READ:format(L.CAT_RULE_NOW:format("gear & (boe | wue)")), enter(2, "gear & (boe | wue)"))
		assert.truthy(has(labels(), "Group 2"))
		assert.equal(L.CAT_RULE_NOW:format("gear | (boe | wue)"), click(L.CAT_ANY_GROUP))
		click(L.CAT_CANCEL)
		C.Create("Mine", "~boe||bop")
		SW.Render()
		click(L.CAT_EDIT, 1)
		enter(1, "Mine too")
		assert.equal(L.CAT_SAVED:format("Mine too"), click(L.CAT_SAVE))
		assert.equal("~boe||bop", C.Get("u_mine").query, "untouched: saved as typed")
	end)

	-- Mutation: in SettingsCategories' editorRows, `if d.showText or not d.rules then` -> `if d.showText then` (a rule
	-- too nested for rows has no way to be edited).
	it("a rule too nested for rows opens as text only, and is saved as it is", function()
		C.Create("Deep", "gear & (boe | (epic & !bound))")
		SW.Render()
		click(L.CAT_EDIT, 1)
		assert.truthy(has(labels(), L.CAT_TEXT_ONLY:format(L.CAT_WHY_DEEP)))
		assert.equal("gear & (boe | (epic & !bound))", SW.inputs[2]:GetText())
		type(2, "gear & (boe | (rare & !bound))")
		assert.equal(L.CAT_SAVED:format("Deep"), click(L.CAT_SAVE))
		assert.equal("gear & (boe | (rare & !bound))", C.Get("u_deep").query)
		-- the text takes the whole query language: ~, ||, #, quoted names, numbers, any nesting (P3: the power is here)
		local full = "~(#boe || \"x y\") & (ilvl>=5 | !(epic | (rare & ~bound))) & 400-450"
		click(L.CAT_EDIT, 1)
		enter(2, full)
		assert.equal(L.CAT_SAVED:format("Deep"), click(L.CAT_SAVE))
		assert.equal(full, C.Get("u_deep").query, "saved as typed")
	end)

	-- Mutations: in SettingsCategories' SC.Save, `return L.CAT_SAVED_DRAFT:format(name, detail)` ->
	-- `return L.CAT_SAVED:format(name)` (it says "Saved" only); or in SC.Edit, `text = c.draft or` -> `text =` (the
	-- change with the error is not what opens).
	it("AC6.2: Save keeps a broken change as a draft while the rule before it stays in use; the list and the editor show it", function()
		click(L.CAT_EDIT, 2) -- Consumables
		click(L.CAT_SHOW_TEXT)
		local err = "Expected a value after \"&\" at character 13"
		assert.equal(L.CAT_TEXT_ERROR_KEEP:format(err), enter(2, "consumable &"))
		assert.equal(L.CAT_SAVED_DRAFT:format("Consumables", err), click(L.CAT_SAVE))
		assert.same({ draft = "consumable &" }, SB.Config.db.userEdits.c_consumables)
		assert.same({ "consumable", true }, { C.Get("c_consumables").query, C.Get("c_consumables").enabled })
		assert.equal(P:format("Consumables (your change has an error: the rule before it is used)", 65), labels()[4])
		click(L.CAT_EDIT, 2)
		assert.truthy(has(labels(), L.CAT_DRAFT_NOTE:format(err)), "the editor says why")
		assert.truthy(has(labels(), L.CAT_TEXT_ONLY:format(L.CAT_WHY_ERROR)), "the change opens, as text")
		assert.equal("consumable &", SW.inputs[2]:GetText())
		assert.equal(L.CAT_DRAFT_DROPPED, click(L.CAT_DRAFT_DROP))
		assert.truthy(has(labels(), "Rule 1: consumable"), "the rule in use is back, as rows")
		assert.equal(L.CAT_SAVED:format("Consumables"), click(L.CAT_SAVE))
		assert.is_nil(SB.Config.db.userEdits.c_consumables, "the draft is gone: nothing stored")
		click(L.CAT_NEW_BUTTON)
		enter(1, "Bad")
		click(L.CAT_ADD_RULE)
		click("potion")
		click(L.CAT_SHOW_TEXT)
		enter(2, "potion &")
		assert.equal(L.CAT_SAVED_BROKEN:format("Bad", "Expected a value after \"&\" at character 9"), click(L.CAT_SAVE),
			"a new category has no rule before it: saved switched off")
		assert.equal(P:format("Bad (off: its rule has an error)", 88), labels()[3])
	end)

	-- Mutations: in SettingsCategories' editorRows, `if d.builtin and edited(d.id) then` -> `if d.builtin then`; or in
	-- reset(), `if SC.confirmReset ~= d.id then` -> `if false then` (one click resets at once).
	it("a built-in: Save stores only the difference; Reset to default asks once more, then brings it back; Junk has no priority", function()
		click(L.CAT_EDIT, 3) -- Gear
		assert.falsy(has(texts(), L.SET_RESET_DEFAULT), "nothing to reset")
		assert.equal(L.CAT_PRIORITY_NOW:format(80), click("+10"))
		assert.equal(L.CAT_PRIORITY_NOW:format(89), click("+10"))
		assert.equal(L.CAT_SAVED:format("Gear"), click(L.CAT_SAVE))
		assert.same({ priority = 89 }, SB.Config.db.userEdits.c_gear)
		click(L.CAT_EDIT, 3)
		assert.equal(L.CAT_RESET_ASK:format("Gear"), click(L.SET_RESET_DEFAULT))
		click("+1")
		assert.equal(L.CAT_PRIORITY_NOW:format(89), SW.lastStatus, "the most it may have")
		assert.truthy(has(texts(), L.SET_RESET_DEFAULT), "any other click forgets the question")
		click(L.SET_RESET_DEFAULT)
		assert.same({ priority = 89 }, SB.Config.db.userEdits.c_gear, "asked, not done")
		assert.equal(L.CAT_RESET_DONE:format("Gear"), click(L.CAT_RESET_SURE))
		assert.is_nil(SB.Config.db.userEdits.c_gear)
		assert.equal(L.CAT_INTRO, labels()[1], "back at the list: no editor holds what the reset forgot")
		assert.equal(P:format("Gear", 70), labels()[5])
		click(L.CAT_EDIT, #C.display - 1) -- Junk
		assert.equal("Editing: Junk", labels()[1])
		assert.truthy(has(labels(), L.CAT_PINNED_NOTE))
		assert.falsy(has(texts(), "+10"))
		assert.falsy(has(texts(), L.CAT_DELETE), "a built-in is never deleted")
	end)

	-- Mutation: in SettingsCategories' forget(), drop `SC.confirmDelete = nil` (an old question still deletes).
	it("Delete asks once more; any other click forgets the question", function()
		C.Create("Mine", "toy")
		SW.Render()
		click(L.CAT_EDIT, 1)
		assert.equal(L.CAT_DELETE_ASK:format("Mine"), click(L.CAT_DELETE))
		click(L.CAT_NOT)
		assert.truthy(has(texts(), L.CAT_DELETE), "the question is forgotten")
		click(L.CAT_DELETE)
		assert.equal(L.CAT_DELETED:format("Mine"), click(L.CAT_DELETE_SURE))
		assert.is_nil(C.Get("u_mine"))
		assert.equal(P:format("Keystone & Crests", 95), labels()[3])
	end)

	-- Final review, data safety. Mutation: in SettingsCategories, drop `SC.confirmDelete, SC.confirmReset = nil, nil` from
	-- the page's leave hook (a "sure?" armed before the window closed or the page changed deletes on one later click).
	it("an armed Delete is forgotten when the window closes or the page changes", function()
		C.Create("Mine", "toy")
		SW.Render()
		click(L.CAT_EDIT, 1)
		click(L.CAT_DELETE)
		SW.Hide()
		SW.Show("categories")
		click(L.CAT_DELETE)
		assert.truthy(C.Get("u_mine"), "closed and reopened: one click only asks")
		SW.AddPage({ id = "stub", title = "Stub", rows = function() return {} end })
		SW.Show("stub")
		SW.Show("categories")
		click(L.CAT_DELETE)
		assert.truthy(C.Get("u_mine"), "another page and back: one click only asks")
	end)

	-- Mutation: as above, for Reset to default.
	it("an armed Reset to default is forgotten when the window closes", function()
		click(L.CAT_EDIT, 3) -- Gear
		click("+10")
		click(L.CAT_SAVE)
		click(L.CAT_EDIT, 3)
		click(L.SET_RESET_DEFAULT)
		SW.Hide()
		SW.Show("categories")
		click(L.SET_RESET_DEFAULT)
		assert.truthy(SB.Config.db.userEdits.c_gear, "one click after reopening only asks")
	end)

	-- Mutation: previewRows drops `SB.Search.PreviewExact(SC.shown)` (Show matches widens the rule by keyword prefixes).
	it("Show matches lights exactly what the rule matches: no keyword prefixes, until the user types", function()
		click(L.CAT_NEW_BUTTON)
		click(L.CAT_ADD_RULE)
		click(L.CAT_PICK_NAME)
		enter(2, "trink")
		click(L.CAT_SHOW_TEXT)
		enter(3, "trink")
		click(L.CAT_SHOW_MATCHES)
		assert.same({}, SB.Search.active.keywords, "the rule trink is a name, not the trinket keyword")
		SB.Search.SetText("trin")
		SB.Search.SetText("trink")
		assert.same({ "trinket" }, SB.Search.active.keywords, "typed by hand afterwards: prefix matching")
	end)

	-- Mutation: previewRows keeps exactText when the bags refuse the search (bags closed).
	it("a Show matches the bags refuse leaves no exact flag behind", function()
		SB.Slash.Register("search", "test", function() return SB.L.SEARCH_OPEN_FIRST end)
		click(L.CAT_NEW_BUTTON)
		click(L.CAT_ADD_RULE)
		click(L.CAT_PICK_NAME)
		enter(2, "trink")
		click(L.CAT_SHOW_TEXT)
		enter(3, "trink")
		assert.equal(L.SEARCH_OPEN_FIRST, click(L.CAT_SHOW_MATCHES))
		assert.is_nil(SB.Search.exactText)
		SB.Search.SetText("trink")
		assert.same({ "trinket" }, SB.Search.active.keywords, "typed later: prefix matching")
	end)

	-- Mutations: in SettingsCategories' previewRows, `return run("search " .. text)` -> `return run("search")`; or
	-- `for _, w in ipairs(SB.Query.Validate(SB.Query.Compile(text)).warnings) do` ->
	-- `for _, w in ipairs({ SB.Query.Validate(SB.Query.Compile(text)).warnings[1] }) do` (the first warning only).
	it("the preview counts the bags' matches, names every word that is no keyword, and Show matches searches the bags", function()
		click(L.CAT_NEW_BUTTON)
		click(L.CAT_ADD_RULE)
		click(L.CAT_PICK_NAME)
		enter(2, "potin")
		assert.truthy(has(labels(), "Matches 0 of the 6 items in your bags right now."))
		assert.falsy(has(labels(), L.CAT_WARN_WORD:format("potin") .. L.CAT_DID_YOU_MEAN:format("potion")),
			"a quoted name is never a keyword: no hint")
		click(L.CAT_SHOW_TEXT)
		enter(3, "potin | flask")
		assert.truthy(has(labels(), "Matches 1 of the 6 items in your bags right now."))
		assert.truthy(has(labels(), L.CAT_WARN_WORD:format("potin") .. L.CAT_DID_YOU_MEAN:format("potion")))
		assert.equal("searched potin | flask", click(L.CAT_SHOW_MATCHES))
		assert.equal("searched ", click(L.CAT_CLEAR_MATCHES))
		assert.same({ "potin | flask", "" }, searched)
		enter(3, "potion |")
		assert.truthy(has(labels(), L.CAT_PREVIEW_ERROR:format("Expected a value after \"|\" at character 9")))
		enter(2, "potin | flsk | #fish")
		local l = labels()
		assert.truthy(has(l, L.CAT_WARN_WORD:format("potin") .. L.CAT_DID_YOU_MEAN:format("potion")))
		assert.truthy(has(l, L.CAT_WARN_WORD:format("flsk") .. L.CAT_DID_YOU_MEAN:format("flask")), "every warning")
		assert.truthy(has(l, SB.Query.FormatWarning({ value = "fish", position = 16 })))
		enter(1, "Typos")
		assert.equal(L.CAT_SAVED_WARNED:format("Typos", SB.Query.FormatWarning({ value = "fish", position = 16 }) .. " "
			.. L.CAT_WARN_WORD:format("potin") .. L.CAT_DID_YOU_MEAN:format("potion") .. " "
			.. L.CAT_WARN_WORD:format("flsk") .. L.CAT_DID_YOU_MEAN:format("flask")), click(L.CAT_SAVE),
			"Save runs Validate (spec 7.9)")
	end)

	-- Mutation: in SettingsCategories' SC.Save, `return refusal(why, d.name)` -> `return L.CAT_SAVED:format(d.name)`.
	it("read-only: Save, Delete and Up refuse with the reason, and nothing changes", function()
		C.Create("Mine", "toy")
		SW.Render()
		SB.Config.readOnly = true
		assert.equal(L.SETTINGS_READONLY, click(L.CAT_UP, 2))
		click(L.CAT_EDIT, 1)
		enter(1, "Ours")
		assert.equal(L.SETTINGS_READONLY, click(L.CAT_SAVE))
		click(L.CAT_DELETE)
		assert.equal(L.SETTINGS_READONLY, click(L.CAT_DELETE_SURE))
		assert.equal("Mine", C.Get("u_mine").name)
		assert.is_nil(SB.Config.db.categoryOrder)
	end)

	-- Mutation: in SettingsWindow's Render, `items = { { text = row.button or L.SET_APPLY, commit = commit } }` ->
	-- `items = {}` (no Apply button: Enter is the only way, which a mouse user doesn't know).
	it("a text box: typing is kept across a redraw; Enter and Apply each answer once", function()
		click(L.CAT_NEW_BUTTON)
		type(1, "Half typed")
		SW.Render() -- a setting changed elsewhere redraws the page
		assert.equal("Half typed", SW.inputs[1]:GetText())
		assert.equal(L.CAT_NAME_OK:format("Half typed"), click(L.SET_APPLY, 1))
		assert.equal(L.CAT_NAME_TAKEN:format("gear"), enter(1, "gear"))
		assert.equal(L.CAT_NAME_LONG:format(C.MAX_NAME), enter(1, string.rep("n", 31)))
		assert.equal(0, #SB.Adapter.Lines())
	end)

	-- Mutation: in SettingsCategories' SC.Save, `if d.rowsEdited and d.rules then` -> `if false then` (an empty name
	-- row is saved as "", which takes every item in the bags).
	it("Save refuses a rule row that isn't finished, naming the row; nothing is saved", function()
		click(L.CAT_NEW_BUTTON)
		enter(1, "Empty")
		click(L.CAT_ADD_RULE)
		click(L.CAT_PICK_NAME)
		assert.equal(L.CAT_SAVE_ROW:format(1, L.CAT_PROBLEM_EMPTY), click(L.CAT_SAVE))
		assert.is_nil(C.Get("u_empty"))
		assert.equal(L.CAT_EDITING_NEW, labels()[1], "still editing")
		enter(2, "Healing")
		click(L.CAT_ADD_RULE)
		click("ilvl")
		assert.equal(L.CAT_SAVE_ROW:format(2, L.CAT_PROBLEM_NUMBER), click(L.CAT_SAVE))
		click(L.CAT_REMOVE, 2)
		assert.equal(L.CAT_SAVED:format("Empty"), click(L.CAT_SAVE))
		assert.equal("\"Healing\"", C.Get("u_empty").query)
	end)

	-- Mutations: in SettingsCategories' ruleRows, `{ text = L.CAT_ADD_RULE, run = rowsClick(function()` ->
	-- `{ text = L.CAT_ADD_RULE, run = forget(function()`; or `local ra = { { text = L.CAT_CHANGE, run = rowsClick(function()`
	-- -> `local ra = { { text = L.CAT_CHANGE, run = forget(function()` (the pick lands on the old rows; the typed text is lost).
	it("Add a rule and Change after text typed but not read: the text is read first, so nothing typed is lost", function()
		click(L.CAT_EDIT, 5) -- BoE gear: gear & boe
		click(L.CAT_SHOW_TEXT)
		type(2, "gear & epic & bound")
		assert.equal(L.CAT_TEXT_FIRST, click(L.CAT_ADD_RULE))
		assert.truthy(has(labels(), "Rule 3: bound"), "the typed text is the rows now")
		assert.falsy(has(labels(), L.KW_FAMILY_TYPE), "no list opened on the old rows")
		click(L.CAT_ADD_RULE)
		assert.equal(L.CAT_RULE_NOW:format("gear & epic & bound & toy"), click("toy"))
		type(2, "gear | toy")
		assert.equal(L.CAT_TEXT_FIRST, click(L.CAT_CHANGE, 4))
		assert.truthy(has(labels(), "Rule 2: toy"))
		assert.falsy(has(labels(), L.KW_FAMILY_TYPE))
		assert.equal(L.CAT_SAVED:format("BoE gear"), click(L.CAT_SAVE))
		assert.equal("gear | toy", C.Get("c_boe").query)
	end)

	-- Mutation: in SettingsCategories' valueRow, `if not SC.draft.textTyped then` -> `if true then` (a keystroke in a
	-- value box writes the rows over the text typed in the rule's box).
	it("typing in a value box after text typed but not read: the text is kept, and Enter there reads it first", function()
		C.Create("Big", "ilvl>=500")
		SW.Render()
		click(L.CAT_EDIT, 1)
		click(L.CAT_SHOW_TEXT)
		type(3, "potion | flask") -- the boxes: the name, the item level, the rule as text
		type(2, "600")
		assert.equal("potion | flask", SB.SettingsCategories.draft.text)
		assert.equal(L.CAT_TEXT_FIRST, enter(2, "600"))
		assert.truthy(has(labels(), "Rule 2: flask"))
		assert.equal(L.CAT_SAVED:format("Big"), click(L.CAT_SAVE))
		assert.equal("potion | flask", C.Get("u_big").query)
	end)

	-- Mutations: in SettingsWindow's input(), `e = SB.TextBox(CreateFrame("EditBox", nil, child, "InputBoxTemplate"))` ->
	-- `e = CreateFrame("EditBox", nil, child, "InputBoxTemplate")` (the settings boxes keep the keyboard in a pull); or
	-- in Core/Events.lua, drop `textBoxes[i]:ClearFocus()` (no box lets go).
	it("combat start: every SwagBag text box lets the keyboard go, so ability keys work in a pull", function()
		click(L.CAT_NEW_BUTTON)
		type(1, "Half typed")
		Loader.LoadFile(SB, "SwagBag/UI/ShareBox.lua")
		Loader.LoadFile(SB, "SwagBag/UI/ReportBox.lua")
		SB.ShareBox.ShowImport()
		SB.ReportBox.Show("report")
		local boxes = { SW.inputs[1], SB.ShareBox.frame.edit, SB.ReportBox.frame.edit }
		for _, e in ipairs(boxes) do
			e.calls.ClearFocus = nil
		end
		SB.Emit("PLAYER_REGEN_DISABLED")
		for i, e in ipairs(boxes) do
			assert.truthy(e.calls.ClearFocus, "box " .. i)
		end
		assert.equal("Half typed", SW.inputs[1]:GetText(), "nothing typed is lost")
		assert.equal(0, #SB.Adapter.Lines())
	end)

	-- Mutation: in SettingsCategories' editorRows, `maxLetters = 2 * C.MAX_QUERY` -> `maxLetters = C.MAX_QUERY` (a
	-- longer pasted rule is cut silently into another rule).
	it("the rule's text box takes more than a rule may hold, so a longer rule is refused with its length; a chat code too", function()
		click(L.CAT_EDIT, 2) -- Consumables
		click(L.CAT_SHOW_TEXT)
		assert.equal(2 * C.MAX_QUERY, SW.inputs[2].calls.SetMaxLetters[1])
		local long = "consumable | " .. string.rep("x", 600)
		assert.equal(L.CAT_TEXT_TOOLONG:format(#long, 500), enter(2, long))
		assert.equal(L.CAT_TOO_LONG:format(500), click(L.CAT_SAVE))
		assert.is_nil(SB.Config.db.userEdits.c_consumables, "nothing saved")
		enter(2, "consumable | |T123:0|t")
		assert.equal(L.CAT_CODE, click(L.CAT_SAVE))
		assert.is_nil(SB.Config.db.userEdits.c_consumables)
	end)

	-- Mutations: in SettingsCategories' OnHide hook, `local shown = SC.shown` -> `local shown = nil` (the bags stay
	-- dimmed); or `if shown and SB.Search and SB.Search.IsActive() and SB.Search.text == shown then` -> `if shown then`
	-- (the user's own search is cleared too).
	it("closing the settings window clears the bags' search Show matches put there, and only that one", function()
		click(L.CAT_EDIT, 2) -- Consumables
		click(L.CAT_SHOW_MATCHES)
		SW.Hide()
		assert.same({ "consumable", "" }, searched, "the bags are not left dimmed")
		SW.Show("categories")
		click(L.CAT_SHOW_MATCHES)
		SB.Search.SetText("boe") -- the user typed a search of their own in the bags since
		SW.Hide()
		assert.same({ "consumable", "", "consumable" }, searched, "theirs stays")
		SW.Show("categories")
		SW.Hide()
		assert.equal(3, #searched, "nothing shown, nothing cleared")
	end)

	-- Mutations: in SettingsCategories' make(), `local id, why = C.Create(p.name, p.result.query, "import")` ->
	-- `local id, why = C.Create(p.name, p.text, "import")` (the pasted text, not what SwagBag read it as); or in
	-- pasteRows, drop `previewRows(out, p.result.query, true)` (no count before saving: AC6.3).
	it("Paste: the search is read, its differences named, its matches counted; Make category saves it as yours", function()
		assert.equal(L.PASTE_HINT, click(L.PASTE_BUTTON))
		assert.equal(L.PASTE_INTRO, labels()[1])
		assert.falsy(has(texts(), L.PASTE_MAKE), "nothing read yet")
		assert.equal(L.PASTE_READ:format("#gear & value>=1000 | pot | key"), enter(1, "#gear & >1000g | pot | key"))
		local l = labels()
		assert.truthy(has(l, L.PASTE_READS_AS:format("#gear & value>=1000 | pot | key")))
		assert.truthy(has(l, L.PASTE_NOTE_GOLD))
		assert.truthy(has(l, L.PASTE_NOTE_NAME:format("pot", "pot") .. L.PASTE_NOTE_PREFIX:format("potion")))
		assert.truthy(has(l, L.PASTE_NOTE_ALSO:format("key", "keystone")))
		assert.truthy(has(l, "Matches 1 of the 6 items in your bags right now."), "the potion's name holds pot")
		assert.falsy(has(l, L.CAT_WARN_WORD:format("pot") .. L.CAT_DID_YOU_MEAN:format("pet")), "Paste's own note says it")
		assert.equal("From Baganator", SW.inputs[2]:GetText())
		assert.equal("searched #gear & value>=1000 | pot | key", click(L.CAT_SHOW_MATCHES))
		assert.equal(L.PASTE_MADE:format("From Baganator"), click(L.PASTE_MAKE))
		local c = C.Get("u_from_baganator")
		assert.same({ "#gear & value>=1000 | pot | key", "import", 88, true }, { c.query, c.source, c.priority, c.enabled })
		assert.equal(P:format("From Baganator (yours)", 88), labels()[3], "back at the list, first")
		click(L.PASTE_BUTTON)
		enter(1, "#toy")
		assert.equal("From Baganator 2", SW.inputs[2]:GetText(), "a free name")
	end)

	-- Mutation: in SettingsCategories' readPaste(), `if not result then` -> `if false then` (a refused string offers
	-- Make category).
	it("Paste: a string SwagBag can't read is refused whole, with the reason; nothing is made", function()
		click(L.PASTE_BUTTON)
		local said = enter(1, "boe | (epic")
		assert.equal(L.PASTE_READ:format("boe | (epic)"), said, "an open ( is closed, as in Baganator")
		said = enter(1, "boe)")
		assert.equal(L.PASTE_ERR_ERROR:format("Expected & or | but found \")\" at character 4"), said)
		assert.truthy(has(labels(), said))
		assert.falsy(has(texts(), L.PASTE_MAKE))
		assert.equal(L.PASTE_ERR_QUOTE:format(4), enter(1, "pot\"s"))
		assert.equal(L.PASTE_ERR_CODE, enter(1, "|cffff0000x"))
		assert.equal(L.PASTE_ERR_LONG:format(600), enter(1, string.rep("b", 600)))
		assert.equal(L.PASTE_ERR_GROWN:format(799), enter(1, string.rep("5g|", 99) .. "5g"), "299 pasted, 799 read")
		assert.equal(L.PASTE_CANCELLED, click(L.CAT_CANCEL))
		local n = 0
		for _ in pairs(SB.Config.db.categories) do
			n = n + 1
		end
		assert.equal(0, n)
	end)

	-- Mutation: in SettingsCategories' pasteRows, the box's set: `p.text, p.result, p.why = text, nil, nil` ->
	-- `p.text = text` (a string changed after it was read is made without being read again).
	it("Paste: a string changed after it was read must be read again; a taken name is refused", function()
		click(L.PASTE_BUTTON)
		enter(1, "#toy")
		type(1, "#toy | #pet")
		assert.equal(L.PASTE_READ_FIRST, click(L.PASTE_MAKE), "changed: read it again first")
		assert.falsy(has(texts(), L.PASTE_MAKE))
		enter(1, "#toy | #pet")
		type(2, "Gear")
		assert.equal(L.CAT_NAME_TAKEN:format("Gear"), click(L.PASTE_MAKE))
		type(2, "Fun")
		assert.equal(L.PASTE_MADE:format("Fun"), click(L.PASTE_MAKE))
		assert.equal("#toy | #pet", C.Get("u_fun").query)
	end)

	-- Mutation: in SwagBag/Locale/enUS.lua, drop `L.PASTE_NOTE_PARENS = "A ( left open at the end is closed, as
	-- Baganator does."` (L falls back to the key's name, so the page would show "PASTE_NOTE_PARENS").
	it("every reason and note the page builds a key for at run time has its words in enUS.lua", function()
		local Rows, Paste, seen = SB.QueryRows, SB.QueryPaste, {}
		local function words(prefix, why)
			seen[prefix] = seen[prefix] or {}
			table.insert(seen[prefix], why)
			assert.truthy(rawget(L, prefix .. why), prefix .. why)
		end
		for _, fam in ipairs(Rows.FAMILIES) do
			words("", fam.label)
		end
		local rows41 = {}
		for i = 1, 41 do
			rows41[i] = "w" .. i
		end
		for _, text in ipairs({ "boe &", "a & (b | (c & d))", table.concat(rows41, " | "), string.rep("a", 501) }) do
			local _, why = Rows.FromText(text)
			words("CAT_WHY_", why:upper())
		end
		for _, row in ipairs({ Rows.NewRow(nil), { kind = "text", value = "a\"b" }, Rows.NewRow("ilvl", true),
			{ kind = "word", value = "536" } }) do
			words("CAT_PROBLEM_", Rows.Problem(row))
		end
		for _, name in ipairs({ " ", string.rep("n", 31), "a|b", "gear" }) do
			local _, why = C.CheckName(name)
			words("CAT_NAME_", why)
		end
		for _, text in ipairs({ " ", string.rep("a", 501), "|T1:0|t", "a\"b", "boe)", string.rep("5g|", 99) .. "5g" }) do
			local _, why = Paste.Translate(text)
			words("PASTE_ERR_", why)
		end
		for _, n in ipairs(Paste.Translate("!!boe | (#elemental | pot | upgrade | key | >5g | <600").notes) do
			words("PASTE_NOTE_", n.kind)
		end
		assert.same({ "ERROR", "DEEP", "LONG", "TOOLONG" }, seen.CAT_WHY_)
		assert.same({ "EMPTY", "QUOTE", "NUMBER", "WORD" }, seen.CAT_PROBLEM_)
		assert.same({ "EMPTY", "LONG", "CHARS", "TAKEN" }, seen.CAT_NAME_)
		assert.same({ "EMPTY", "LONG", "CODE", "QUOTE", "ERROR", "GROWN" }, seen.PASTE_ERR_)
		assert.same({ "NOTS", "GOLD", "PARENS", "UNKNOWN", "NAME", "DIFFERENT", "ALSO", "ILVL" }, seen.PASTE_NOTE_)
	end)

	-- Fix round 1. Mutation: in SettingsCategories' Show matches, `SC.shown = d.text:match("^%s*(.-)%s*$")` -> `SC.shown = d.text`.
	it("closing the settings window clears Show matches' search for a rule typed with spaces around it (the command trims it)", function()
		click(L.CAT_EDIT, 2) -- Consumables
		click(L.CAT_SHOW_TEXT)
		enter(2, "toy ")
		click(L.CAT_SHOW_MATCHES)
		assert.equal("toy", SB.Search.text)
		SW.Hide()
		assert.same({ "toy", "" }, searched, "the bags are not left dimmed")
	end)

	-- Mutation: in SettingsWindow's Render, drop `SW.inputs[i]:ClearFocus()`; or drop the frame's OnHide ClearFocus hook.
	it("a settings text box that is hidden or re-used, or whose window closes, lets the keyboard go", function()
		click(L.CAT_NEW_BUTTON)
		local e = SW.inputs[1]
		e.calls.ClearFocus = nil
		SW.Render()
		assert.truthy(e.calls.ClearFocus, "redraw")
		e.calls.ClearFocus = nil
		SW.Hide()
		assert.truthy(e.calls.ClearFocus, "window closed")
	end)

	-- Mutation: in SettingsCategories, `maxLetters = C.MAX_NAME + 20` -> `maxLetters = C.MAX_NAME`; or the value box's
	-- `maxLetters = C.MAX_QUERY + 20` -> `maxLetters = 100`.
	it("the name box and a value box take more than their limit, so a longer paste is refused with the reason, not cut", function()
		click(L.CAT_NEW_BUTTON)
		assert.truthy(SW.inputs[1].calls.SetMaxLetters[1] > C.MAX_NAME)
		click(L.CAT_ADD_RULE)
		click(L.CAT_PICK_NAME)
		assert.truthy(SW.inputs[2].calls.SetMaxLetters[1] > 100)
		assert.equal(L.CAT_NAME_LONG:format(C.MAX_NAME), enter(1, string.rep("n", 35)))
	end)

	-- Mutation: in SC.Save, `if not ok2 then return refusal(why2, d.name) end` -> removed.
	it("a new category whose follow-up save is refused answers that refusal, not Saved", function()
		click(L.CAT_NEW_BUTTON)
		enter(1, "Fresh")
		click(L.CAT_ADD_RULE)
		click("toy")
		local real = C.Save
		C.Save = function()
			return false, "readonly"
		end
		local said = click(L.CAT_SAVE)
		C.Save = real
		assert.equal(L.SETTINGS_READONLY, said)
	end)

	-- Week 11 final fix 3. Mutation: in SC.Save, drop `d.id = id` after Create (the draft stays unbound: the next Save
	-- makes the category again and is refused, "name taken").
	it("a new category whose follow-up save was refused is saved by the next Save, not made twice", function()
		click(L.CAT_NEW_BUTTON)
		enter(1, "Fresh")
		click(L.CAT_ADD_RULE)
		click("toy")
		local real = C.Save
		C.Save = function()
			return false, "readonly"
		end
		click(L.CAT_SAVE)
		C.Save = real
		assert.equal(L.CAT_SAVED:format("Fresh"), click(L.CAT_SAVE))
		local n = 0
		for _, def in pairs(SB.Config.db.categories) do
			n = n + ((def and def.name == "Fresh") and 1 or 0)
		end
		assert.equal(1, n)
	end)

	-- Week 11 final fix 4. Mutation: in SC.Edit (or SC.New), drop `SC.paste = nil` (the page keeps showing the paste view).
	it("Edit and New leave the paste view, so the page shows the editor they opened", function()
		click(L.PASTE_BUTTON)
		SB.SettingsCategories.Edit("c_gear")
		assert.is_nil(SB.SettingsCategories.paste)
		SW.Render()
		assert.truthy(has(texts(), L.CAT_SAVE), "the editor, not the paste view")
		click(L.CAT_CANCEL)
		click(L.PASTE_BUTTON)
		SB.SettingsCategories.New()
		assert.is_nil(SB.SettingsCategories.paste)
		SW.Render()
		assert.falsy(has(texts(), L.PASTE_MAKE))
		assert.truthy(has(texts(), L.CAT_SAVE))
	end)

	-- Week 11 final fix 5. Mutation: in pasteRows, `maxLetters = C.MAX_NAME + 20` -> `maxLetters = C.MAX_NAME`.
	it("the paste view's name box takes more than a name may hold, so a longer name is refused with the reason", function()
		click(L.PASTE_BUTTON)
		enter(1, "#toy")
		assert.truthy(SW.inputs[2].calls.SetMaxLetters[1] > C.MAX_NAME)
		assert.equal(L.CAT_NAME_LONG:format(C.MAX_NAME), enter(2, string.rep("n", 35)))
	end)

	-- Week 11 final fix 6. Mutation: put back "the next time you open them (or press Reflow)" in L.CAT_SAVED.
	it("the Save answers say the bags use the change at their next full layout, never moving an item under the mouse", function()
		for _, key in ipairs({ "CAT_SAVED", "CAT_SAVED_WARNED", "PASTE_MADE" }) do
			assert.truthy(L[key]:find("next full layout", 1, true), key)
			assert.truthy(L[key]:find("under your mouse", 1, true), key)
		end
	end)

	-- 0.16.0 (Q7, Q13). Mutation: in SettingsCategories' valueRow, turn a tooltip row into a name row when typed in.
	it("a tooltip-text rule: picked from the lists, typed in, saved as text:", function()
		click(L.CAT_NEW_BUTTON)
		type(1, "Fiery")
		click(L.CAT_ADD_RULE)
		assert.truthy(has(labels(), L.CAT_PICK_TIP_LABEL))
		assert.equal(L.CAT_TYPE_VALUE, click(L.CAT_PICK_TIP))
		assert.truthy(has(labels(), "Rule 1: " .. L.CAT_SUM_TIP:format("")))
		assert.truthy(has(labels(), L.CAT_VALUE_TIP))
		assert.equal(L.CAT_RULE_NOW:format("text:\"fire damage\""), enter(2, "fire damage"))
		assert.truthy(has(labels(), "Rule 1: " .. L.CAT_SUM_TIP:format("fire damage")))
		click(L.CAT_SAVE)
		assert.equal("text:\"fire damage\"", C.Get("u_fiery").query)
	end)

	it("a keyword that reads tooltips says so on its rule", function()
		click(L.CAT_NEW_BUTTON)
		click(L.CAT_ADD_RULE)
		click("fire damage")
		assert.truthy(has(labels(), "Rule 1: " .. L.CAT_SUM_READS_TIPS:format("fire damage")))
		click(L.CAT_ADD_RULE)
		click("mail")
		assert.truthy(has(labels(), "Rule 2: mail"))
	end)

	it("the lists offer the expansion keywords on Retail", function()
		click(L.CAT_NEW_BUTTON)
		click(L.CAT_ADD_RULE)
		assert.truthy(has(texts(), "midnight"))
		assert.truthy(has(labels(), L.KW_FAMILY_EXPANSION))
	end)

	-- Mutation: in Core/Events.lua, call `textBoxes[i]:ClearFocus()` directly, without the per-box trap.
	it("one text box that errors in ClearFocus does not stop the others letting go", function()
		local later = false
		SB.TextBox({ ClearFocus = function()
			error("boom")
		end })
		SB.TextBox({ ClearFocus = function()
			later = true
		end })
		SB.Emit("PLAYER_REGEN_DISABLED")
		assert.truthy(later)
	end)
end)

-- 0.16.0 (Q6): keywords for facts WoW Forever lacks are not offered there.
describe("Settings > Categories on WoW Forever (0.16.0)", function()
	local SB, SW, L
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		table.insert(files, 12, "SwagBag/Engine/Query/Rows.lua")
		table.insert(files, 13, "SwagBag/Engine/Query/Paste.lua")
		SB = Loader.New(files, { flavor = "forever" })
		SB.Config.Init(nil, nil)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsCategories.lua")
		SW, L = SB.SettingsWindow, SB.L
		SB.Categories.Load()
		SW.Show("categories")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- Mutation: drop the Allows("keyword", word) check in SettingsCategories' pickerRows.
	it("the expansion family and the expansion number are hidden; every other keyword stays", function()
		SB.SettingsCategories.New()
		SB.SettingsCategories.picking = { block = 1 }
		SW.Render()
		local texts, labels = {}, {}
		for i = 1, SW.used.buttons do
			texts[SW.buttons[i].text] = true
		end
		for i = 1, SW.used.labels do
			labels[SW.labels[i].text] = true
		end
		assert.falsy(texts["midnight"])
		assert.falsy(texts["expansion"])
		assert.falsy(labels[L.KW_FAMILY_EXPANSION], "an empty family is not shown")
		assert.truthy(texts["mail"])
		assert.truthy(texts["crit"])
	end)
end)
