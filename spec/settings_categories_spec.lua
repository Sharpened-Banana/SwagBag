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
		assert.same({ L.CAT_NEW_BUTTON, L.CAT_EDIT, L.CAT_UP, L.CAT_DOWN, L.CAT_EDIT }, { unpack(texts(), 1, 5) })
		assert.equal(L.CAT_MAKE, labels()[2])
		assert.same({ P:format("Keystone & Crests", 95), P:format("Consumables", 65), P:format("Gear", 70) },
			{ unpack(labels(), 3, 5) })
		assert.equal("Other", labels()[#labels()], "Other takes what no rule takes: no priority")
		assert.equal(1 + #C.display * 3, #texts())
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

	-- Mutations: in SettingsCategories' previewRows, `return run("search " .. d.text)` -> `return run("search")`; or
	-- `for _, w in ipairs(SB.Query.Validate(SB.Query.Compile(d.text)).warnings) do` ->
	-- `for _, w in ipairs({ SB.Query.Validate(SB.Query.Compile(d.text)).warnings[1] }) do` (the first warning only).
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
end)
