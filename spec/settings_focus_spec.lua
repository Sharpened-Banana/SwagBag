-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The Focus modes settings page (spec 6, AC8.1-8.5, AC15.1): every focus setting with its
-- alternative, per-mode on/off, each mode's sections with Reset to default, and "This character".
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Settings: focus modes page", function()
	local SB, SW, F, events, L
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsFocus.lua")
		SW, F, L = SB.SettingsWindow, SB.Focus, SB.L
		SB.Categories.Load()
		events = {}
		SB.On("SB_FOCUS_CHANGED", function(_, reason) events[#events + 1] = reason end)
		SW.Show("focus")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- The button with this text in the row with this label (rows are label, then its buttons).
	local function rowButton(rowLabel, text)
		local index = 0
		for _, row in ipairs(SW.byId[SW.current].rows()) do
			for _, item in ipairs(row.choices or row.actions or {}) do
				index = index + 1
				if row.label == rowLabel and item.text == text then
					return SW.buttons[index]
				end
			end
		end
		error("no button " .. text .. " in row " .. rowLabel)
	end

	local function click(rowLabel, text)
		Fake.Fire(rowButton(rowLabel, text), "OnClick")
	end

	local function selected(rowLabel, text)
		return SW.selected[rowButton(rowLabel, text)] == true
	end

	-- Week 6, D18 (S1: the page was not understood). Mutations: drop the intro row; drop the tip of
	-- the style row (or of any other row with buttons).
	it("starts with a plain-words intro, and every row with buttons explains itself on hover", function()
		local all = SW.byId.focus.rows()
		assert.same({ kind = "note", label = L.SET_FOCUS_INTRO }, all[1])
		assert.equal(L.SET_FOCUS_INTRO, SW.labels[1].text)
		for _, row in ipairs(all) do
			if row.choices or row.actions then
				assert.truthy(type(row.tip) == "string" and row.tip ~= "", "no tip on " .. row.label)
			end
		end
		local lines = {}
		GameTooltip = { SetOwner = function() end, SetText = function(_, t) lines[#lines + 1] = t end,
			AddLine = function(_, t) lines[#lines + 1] = t end, Show = function() end }
		Fake.Fire(rowButton(L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_COLLAPSE), "OnEnter")
		Fake.Fire(rowButton(L.SET_MODE_LABEL:format("Fishing"), L.SET_ON), "OnEnter")
		Fake.Fire(rowButton("Junk", L.SET_SECTION_OPEN), "OnEnter")
		assert.same({ L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_TIP,
			L.SET_MODE_LABEL:format("Fishing"), L.SET_MODE_TIP:format(L.SET_MODE_WHEN_FISHING),
			"Junk", L.SET_SECTION_TIP:format("M+") }, lines)
	end)

	it("AC8.1 and P1: the defaults are selected, each with its alternative next to it", function()
		assert.truthy(selected(L.SET_FOCUS_AUTO, L.SET_FOCUS_AUTO_ON))
		assert.truthy(selected(L.SET_FOCUS_RESOLVE, L.SET_FOCUS_MERGE))
		assert.truthy(selected(L.SET_FOCUS_PEEK, L.SET_FOCUS_PEEK_PEEK))
		assert.truthy(selected(L.SET_FOCUS_ANNOUNCE, L.SET_FOCUS_QUIET))
		assert.truthy(selected(L.SET_FOCUS_SCOPE, L.SET_FOCUS_ACCOUNT))
		for _, name in ipairs({ "M+", "Raid", "Delves", "Gathering", "Fishing", "AH/Vendor/Bank" }) do
			assert.truthy(selected(L.SET_MODE_LABEL:format(name), L.SET_ON), name)
		end
		assert.truthy(selected(L.SET_EDIT_MODE, "M+"))
		assert.truthy(selected("Consumables", L.SET_SECTION_OPEN))
		assert.truthy(selected("Junk", L.SET_SECTION_CLOSED))
	end)

	-- Week 6, user request 1 (P1, P2). Mutations: the row's apply always answers MODE_STYLE_FRONT; drop
	-- "focus.style" from SF.Paths (This character would leave the style account-wide).
	it("the style row: Move to the top by default; Collapse the rest is saved, answers and re-stacks", function()
		assert.truthy(selected(L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_FRONT))
		click(L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_COLLAPSE)
		assert.equal("collapse", SB.Config.Get("focus.style"))
		assert.same({ "settings" }, events)
		assert.equal(L.MODE_STYLE_COLLAPSE, SW.lastStatus)
		assert.truthy(selected(L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_COLLAPSE))
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		assert.truthy(SB.Config.IsCharOverride("focus.style"), "This character covers the style too")
		SB.Config.readOnly = true
		click(L.SET_FOCUS_STYLE, L.SET_FOCUS_STYLE_FRONT)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		assert.equal("collapse", SB.Config.Get("focus.style"))
	end)

	-- Mutation: write the setting straight into SB.Config.db (bypassing Config.Set), so nothing
	-- is emitted and Focus never refreshes.
	it("strict priority is saved and the open bag re-stacks (SB_FOCUS_CHANGED settings)", function()
		click(L.SET_FOCUS_RESOLVE, L.SET_FOCUS_PRIORITY)
		assert.equal("priority", SB.Config.Get("focus.resolve"))
		assert.same({ "settings" }, events)
		assert.equal(L.SET_FOCUS_PRIORITY_DONE, SW.lastStatus)
		assert.truthy(selected(L.SET_FOCUS_RESOLVE, L.SET_FOCUS_PRIORITY))
	end)

	it("a mode switched off never triggers", function()
		click(L.SET_MODE_LABEL:format("Fishing"), L.SET_OFF)
		assert.falsy(F.IsEnabled("fishing"))
		assert.equal("Fishing mode is off: it no longer collapses anything.", SW.lastStatus)
		F.SetSignal("fishing", true)
		assert.same({}, F.Active())
	end)

	-- Mutation: in the section row's apply, keep `sid` out of the list when v is true.
	it("a section opened for M+ joins its set; the M+ mode then opens it", function()
		click("Junk", L.SET_SECTION_OPEN)
		assert.same({ "c_consumables", "c_keystone", "c_gear", "c_junk" }, F.Sections("mplus"))
		assert.equal("Junk now opens in the M+ mode.", SW.lastStatus)
		click("Gear", L.SET_SECTION_CLOSED)
		assert.same({ "c_consumables", "c_keystone", "c_junk" }, F.Sections("mplus"))
	end)

	-- W4-4. Mutation: skip Free in the section rows (`sid ~= SB.Categories.FREE`).
	it("the editor has a Free row; toggling it changes the mode's sections", function()
		click(L.CAT_FREE, L.SET_SECTION_OPEN)
		assert.same({ "c_consumables", "c_keystone", "c_gear", "free" }, F.Sections("mplus"))
		assert.truthy(selected(L.CAT_FREE, L.SET_SECTION_OPEN))
		assert.has_error(function() rowButton(L.CAT_NEW, L.SET_SECTION_OPEN) end, nil)
	end)

	-- W4-2. Mutation: the editor reads Focus.Sections(id) (filtered) instead of (id, true).
	it("with only Mining, editing Gathering keeps the herb and skinning sections stored", function()
		F.SetSignal("professions", { ore = true })
		click(L.SET_EDIT_MODE, "Gathering")
		click("Junk", L.SET_SECTION_OPEN)
		assert.same({ "c_herbs", "c_ore", "c_leathercloth", "c_tools", "c_junk" }, F.Sections("gathering", true))
		assert.truthy(selected("Herbs", L.SET_SECTION_OPEN), "the raw list is shown, not the filtered one")
	end)

	it("Reset to default brings the built-in set back", function()
		click("Junk", L.SET_SECTION_OPEN)
		click(L.SET_SECTIONS_DEFAULT_LABEL, L.SET_RESET_DEFAULT)
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"))
		assert.equal("The M+ mode opens its default sections again.", SW.lastStatus)
	end)

	it("picking another mode shows its sections", function()
		click(L.SET_EDIT_MODE, "Fishing")
		assert.truthy(selected("Fish & Lures", L.SET_SECTION_OPEN))
		assert.truthy(selected("Consumables", L.SET_SECTION_CLOSED))
		click("Consumables", L.SET_SECTION_OPEN)
		assert.same({ "c_fish", "c_cooking", "c_consumables" }, F.Sections("fishing"))
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"), "M+ untouched")
	end)

	-- Mutation: CharOverride only "focus.auto" in the scope row's apply.
	it("AC15.1: \"This character\" makes every focus setting this character's own; back again clears them", function()
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		for _, path in ipairs(SB.SettingsFocus.Paths()) do
			assert.truthy(SB.Config.IsCharOverride(path), path)
		end
		click("Junk", L.SET_SECTION_OPEN)
		click(L.SET_THIS_CHARACTER:format(L.SET_MODE_LABEL:format("Raid")), L.SET_OFF)
		assert.is_nil(SB.Config.db.settings.focus, "the account-wide settings are untouched")
		assert.equal("c_consumables,c_keystone,c_gear,c_junk", SB.Config.charDB.overrides["focus.sections.mplus"])
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_ACCOUNT)
		assert.falsy(SB.Config.IsCharOverride("focus.sections.mplus"))
		assert.truthy(F.IsEnabled("raid"), "the account setting applies again")
	end)

	-- Mutation: layered() returns the plain text.
	it("the layer is named while \"This character\" is on: the sections note and the mode labels", function()
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		local labels = {}
		for _, row in ipairs(SW.byId.focus.rows()) do
			labels[row.label] = true
		end
		assert.truthy(labels[L.SET_THIS_CHARACTER:format(L.SET_SECTIONS_OF:format("M+"))])
		assert.truthy(labels[L.SET_THIS_CHARACTER:format(L.SET_MODE_LABEL:format("Raid"))])
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_ACCOUNT)
		assert.truthy(SW.byId.focus.rows()[2].label == L.SET_FOCUS_AUTO, "row 1 is the intro (week 6)")
		assert.falsy(SW.byId.focus.rows()[8].label:find("this character", 1, true), "row 8: the first mode")
	end)

	it("the scope row shows This character when only one focus path is overridden", function()
		SB.Config.CharOverride("focus.sections.raid", true)
		SW.Render()
		assert.truthy(selected(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER))
	end)

	-- Mutation: SettingsFocus applies the scope with one CharOverride per path.
	it("the scope toggle is one change: exactly one SB_CONFIG_CHANGED, with no path", function()
		local seen = {}
		SB.On("SB_CONFIG_CHANGED", function(_, path) seen[#seen + 1] = path == nil and "nil" or path end)
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		assert.same({ "nil" }, seen)
		seen = {}
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_ACCOUNT)
		assert.same({ "nil" }, seen)
	end)

	-- W4-2. Mutation: in the scope row's apply, also SetSections("gathering", F.Sections("gathering")).
	it("with only Mining, the override on then off keeps every stored Gathering section", function()
		F.SetSignal("professions", { ore = true })
		local all = { "c_herbs", "c_ore", "c_leathercloth", "c_tools" }
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		assert.same(all, F.Sections("gathering", true))
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_ACCOUNT)
		assert.same(all, F.Sections("gathering", true))
	end)

	-- W4-2. Mutation: ResetSections writes F.Sections(id) (filtered) instead of the default.
	it("with only Mining, Reset on Gathering restores every section", function()
		F.SetSignal("professions", { ore = true })
		click(L.SET_EDIT_MODE, "Gathering")
		click("Junk", L.SET_SECTION_OPEN)
		click(L.SET_SECTIONS_DEFAULT_LABEL, L.SET_RESET_DEFAULT)
		assert.same({ "c_herbs", "c_ore", "c_leathercloth", "c_tools" }, F.Sections("gathering", true))
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		click(L.SET_SECTIONS_DEFAULT_LABEL, L.SET_RESET_DEFAULT)
		assert.same({ "c_herbs", "c_ore", "c_leathercloth", "c_tools" }, F.Sections("gathering", true))
	end)

	it("read-only settings: every focus change refuses with the reason", function()
		SB.Config.readOnly = true
		click("Junk", L.SET_SECTION_OPEN)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		click(L.SET_FOCUS_RESOLVE, L.SET_FOCUS_PRIORITY)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		click(L.SET_MODE_LABEL:format("Raid"), L.SET_OFF)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		assert.falsy(SB.Config.CharOverrideMany({ "focus.auto" }, true))
		click(L.SET_SECTIONS_DEFAULT_LABEL, L.SET_RESET_DEFAULT)
		assert.equal(L.SETTINGS_READONLY, SW.lastStatus)
		assert.same({ "c_consumables", "c_keystone", "c_gear" }, F.Sections("mplus"))
	end)

	it("Edit(mode) opens the page at that mode and says so (AC8.5)", function()
		SW.Hide()
		SB.SettingsFocus.Edit("gathering")
		assert.truthy(SW.IsOpen())
		assert.equal("focus", SW.current)
		assert.truthy(selected(L.SET_EDIT_MODE, "Gathering"))
		assert.equal("Editing the sections the Gathering mode opens (below).", SW.lastStatus)
	end)
end)
