-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Week 12 (spec AC8.7, AC15.1): Settings > Focus modes for modes of the user's own (UI/SettingsFocus.lua): New mode's
-- short form, a manual mode switched from the list, editing one (sections, name, trigger), Delete asking once more,
-- "This character only"; and share strings (Engine/Profiles.lua): the user's modes never travel, and say so.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Settings: focus modes of your own (week 12)", function()
	local SB, SW, F, L, events
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		SB.Config.Set("focus.auto", true) -- focus modes switch by themselves only when asked (0.14.3)
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

	-- The button with this text in the row with this label (a text box row has one button: Apply).
	local function rowButton(rowLabel, text)
		local index = 0
		for _, row in ipairs(SW.byId[SW.current].rows()) do
			local items = row.choices or row.actions or (row.kind == "input" and { { text = L.SET_APPLY } }) or {}
			for _, item in ipairs(items) do
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

	-- The text box of the row with this label: typed as the user does, then Enter.
	local function type(rowLabel, text)
		local index = 0
		for _, row in ipairs(SW.byId[SW.current].rows()) do
			if row.kind == "input" then
				index = index + 1
				if row.label == rowLabel then
					local box = SW.inputs[index]
					box:SetText(text)
					Fake.Fire(box, "OnTextChanged", true)
					Fake.Fire(box, "OnEnterPressed")
					return
				end
			end
		end
		error("no text box " .. rowLabel)
	end

	local function labels()
		local out = {}
		for _, row in ipairs(SW.byId.focus.rows()) do
			out[row.label] = true
		end
		return out
	end

	-- AC8.7. Mutation: in the Make mode run, `SF.creating, SF.editing, SF.renameText = nil, id, nil` ->
	-- `SF.creating, SF.renameText = nil, nil`.
	it("AC8.7: New mode is a short form: a name, when it switches on, Make mode; then its sections are shown", function()
		assert.falsy(labels()[L.SET_CUSTOM_NAME], "no form until New mode")
		click(L.SET_CUSTOM_LABEL, L.SET_CUSTOM_NEW)
		assert.equal(L.SET_CUSTOM_NEW_HINT, SW.lastStatus)
		type(L.SET_CUSTOM_NAME, "Vendor dump")
		assert.equal("Name: Vendor dump (click Make mode to keep it).", SW.lastStatus)
		assert.truthy(SW.selected[rowButton(L.SET_CUSTOM_TRIGGER, L.TRIGGER_MANUAL)], "manual by default")
		click(L.SET_CUSTOM_TRIGGER, L.TRIGGER_VENDOR)
		assert.equal("It switches on: At a vendor (click Make mode to keep it).", SW.lastStatus)
		assert.is_nil(SB.Config.db.modes, "nothing is made before Make mode")
		click(L.SET_CUSTOM_MAKE_LABEL, L.SET_CUSTOM_MAKE)
		assert.equal("Made the Vendor dump mode. Pick the sections it brings up below.", SW.lastStatus)
		assert.equal("vendor", F.Mode("m_vendor_dump").triggerId)
		assert.equal("m_vendor_dump", SB.SettingsFocus.editing)
		assert.truthy(labels()[L.SET_SECTIONS_OF:format("Vendor dump")])
		assert.falsy(labels()[L.SET_CUSTOM_NAME], "the form is gone")
		click("Junk", L.SET_SECTION_OPEN)
		assert.same({ "c_junk" }, F.Sections("m_vendor_dump"))
		click(L.SET_CUSTOM_LABEL, L.SET_CUSTOM_NEW)
		click(L.SET_CUSTOM_MAKE_LABEL, L.SET_CUSTOM_CANCEL)
		assert.equal(L.SET_CUSTOM_CANCELLED, SW.lastStatus)
		assert.equal(1, #F.custom)
	end)

	-- Mutation: in refusal(), drop the `elseif why and rawget(L, "SET_CUSTOM_WHY_" .. why:upper()) then` branch.
	it("a name that can't be used says why, at Enter and at Make mode; nothing is made", function()
		click(L.SET_CUSTOM_LABEL, L.SET_CUSTOM_NEW)
		type(L.SET_CUSTOM_NAME, "raid")
		assert.equal(L.SET_CUSTOM_WHY_BUILTIN, SW.lastStatus)
		click(L.SET_CUSTOM_MAKE_LABEL, L.SET_CUSTOM_MAKE)
		assert.equal(L.SET_CUSTOM_WHY_BUILTIN, SW.lastStatus)
		type(L.SET_CUSTOM_NAME, "")
		click(L.SET_CUSTOM_MAKE_LABEL, L.SET_CUSTOM_MAKE)
		assert.equal(L.SET_CUSTOM_WHY_EMPTY, SW.lastStatus)
		assert.same({}, F.custom)
		for _, why in ipairs({ "EMPTY", "LONG", "CODE", "BUILTIN", "TAKEN", "FULL", "TRIGGER", "NOTMANUAL" }) do
			assert.truthy(rawget(L, "SET_CUSTOM_WHY_" .. why), why)
		end
	end)

	-- Mutation: in the manual row's apply, `F.SetManual(m.id, v)` -> `F.SetManual(m.id, true)`.
	it("a manual mode's line in the list switches it on and off for this session, like /swagbag mode on", function()
		local id = F.CreateMode("Farming")
		F.SetSections(id, { "c_herbs" })
		SW.Render()
		local row = L.SET_MODE_LABEL:format("Farming (you switch it)")
		assert.truthy(SW.selected[rowButton(row, L.SET_OFF)])
		events = {}
		click(row, L.SET_MANUAL_ON)
		assert.equal(L.MODE_MANUAL_ON:format("Farming"), SW.lastStatus)
		assert.truthy(F.ManualOn(id))
		assert.truthy(SW.selected[rowButton(row, L.SET_MANUAL_ON)])
		assert.same({ "signal" }, events, "the open bags follow")
		click(row, L.SET_OFF)
		assert.equal(L.MODE_MANUAL_OFF:format("Farming"), SW.lastStatus)
		assert.falsy(F.ManualOn(id))
	end)

	-- Mutation: in sectionRows, drop `if F.IsCustom(id) then return end` (a Reset with no default to go back to).
	it("editing a mode of yours: its sections with no Reset, its name, when it switches on", function()
		local id = F.CreateMode("Farming")
		SW.Render()
		click(L.SET_EDIT_MODE, "Farming")
		assert.truthy(labels()[L.SET_SECTIONS_OF:format("Farming")])
		assert.falsy(labels()[L.SET_SECTIONS_DEFAULT_LABEL])
		click("Herbs", L.SET_SECTION_OPEN)
		assert.same({ "c_herbs" }, F.Sections(id))
		type(L.SET_CUSTOM_RENAME, "Herb run")
		assert.equal("Farming is now called Herb run.", SW.lastStatus)
		assert.equal("Herb run", F.NameOf(id))
		type(L.SET_CUSTOM_RENAME, "Fishing")
		assert.equal(L.SET_CUSTOM_WHY_BUILTIN, SW.lastStatus)
		assert.equal("Fishing", SW.inputs[1]:GetText(), "a refused name stays in the box to be fixed")
		assert.equal("Herb run", F.NameOf(id))
		click(L.SET_CUSTOM_TRIGGER, L.TRIGGER_BANK)
		assert.equal("Herb run now switches on: At the bank.", SW.lastStatus)
		assert.truthy(labels()[L.SET_MODE_LABEL:format("Herb run")], "now an On / Off line like SwagBag's own")
		F.SetSignal("bankOpen", true)
		assert.same({ "market", id }, F.Active())
	end)

	-- Mutation: in forgetting(), drop `row.apply = wrap(row.apply)` (a choice would keep Delete's question).
	it("Delete asks once more; any other click forgets the question; deleted, the page shows M+ again", function()
		local id = F.CreateMode("Farming")
		SW.Render()
		click(L.SET_EDIT_MODE, "Farming")
		click(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE)
		assert.equal("Click \"Delete: sure?\" to delete the Farming mode. Any other click keeps it.", SW.lastStatus)
		click("Herbs", L.SET_SECTION_OPEN)
		assert.truthy(rowButton(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE), "the question is forgotten")
		click(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE)
		click(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE_SURE)
		assert.equal("Deleted the Farming mode.", SW.lastStatus)
		assert.is_nil(F.Mode(id))
		assert.equal("mplus", SB.SettingsFocus.editing)
		assert.truthy(SW.selected[rowButton(L.SET_EDIT_MODE, "M+")])
	end)

	-- Final review, data safety. Mutation: in SettingsFocus, drop the page's leave hook (an armed Delete survives the
	-- window closing or the page changing, and one later click deletes the mode).
	it("an armed Delete is forgotten when the window closes or the page changes", function()
		local id = F.CreateMode("Farming")
		SW.Render()
		click(L.SET_EDIT_MODE, "Farming")
		click(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE)
		SW.Hide()
		SW.Show("focus")
		click(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE)
		assert.truthy(F.Mode(id), "closed and reopened: one click only asks")
		SW.AddPage({ id = "stub", title = "Stub", rows = function() return {} end })
		SW.Show("stub")
		SW.Show("focus")
		assert.truthy(rowButton(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE), "another page and back: asks again")
		click(L.SET_CUSTOM_DELETE_LABEL, L.SET_CUSTOM_DELETE)
		assert.truthy(F.Mode(id))
	end)

	-- Mutation: leave SF.creating / SF.renameText out of the leave hook.
	it("a half-made mode and a rename in the box are forgotten when the window closes", function()
		F.CreateMode("Farming")
		SW.Render()
		SB.SettingsFocus.creating = { name = "", trigger = "manual" }
		SB.SettingsFocus.renameText = "half"
		SW.Hide()
		assert.is_nil(SB.SettingsFocus.creating)
		assert.is_nil(SB.SettingsFocus.renameText)
	end)

	-- Final review. Mutation: wrap the manual row's label in layered() again.
	it("a manual mode's switch is session state: no (this character) label even with overrides", function()
		F.CreateMode("Farming")
		SB.Config.CharOverrideMany(SB.SettingsFocus.Paths(), true)
		local manual = L.SET_MODE_LABEL:format("Farming (you switch it)")
		local found
		for _, row in ipairs(SW.byId.focus.rows()) do
			if row.label == manual then
				found = true
			end
		end
		assert.truthy(found)
	end)

	-- Ruling: a manual mode ignores focus.on, so its line has no On button. Mutation: in the mode list, make the
	-- manual branch's choices `{ SET_ON, SET_OFF }` (an On switch that does nothing).
	it("a manual mode's line has no On / Off switch (it would do nothing): only Switched on / Off", function()
		F.CreateMode("Farming")
		SW.Render()
		local row = L.SET_MODE_LABEL:format("Farming (you switch it)")
		assert.truthy(rowButton(row, L.SET_MANUAL_ON))
		assert.has_error(function()
			rowButton(row, L.SET_ON)
		end)
	end)

	-- Ruling: the page names modes of yours (Edit, the editor's heading, the pick). Mutation: in modeName, return
	-- `L[SB.Focus.byId[id].name]` again.
	it("Edit(id) opens the page at a mode of yours, by its own name", function()
		local id = F.CreateMode("Farming")
		SB.SettingsFocus.Edit(id)
		assert.equal(L.SET_EDITING:format("Farming"), SW.lastStatus)
		assert.equal(id, SB.SettingsFocus.editing)
		assert.truthy(labels()[L.SET_SECTIONS_OF:format("Farming")])
		SB.SettingsFocus.Edit("m_nobody")
		assert.equal(id, SB.SettingsFocus.editing, "an unknown mode leaves the page where it was")
	end)

	-- AC15.1. Mutation: in SF.Paths, iterate `SB.Focus.MODES` instead of `SB.Focus.All()`.
	it("This character only makes your own modes' switches and sections this character's too", function()
		local id = F.CreateMode("Dump", "vendor")
		F.SetSections(id, { "c_junk" })
		SW.Render()
		click(L.SET_FOCUS_SCOPE, L.SET_FOCUS_CHARACTER)
		assert.truthy(SB.Config.IsCharOverride("focus.sections." .. id))
		assert.truthy(SB.Config.IsCharOverride("focus.on." .. id))
		click(L.SET_THIS_CHARACTER:format(L.SET_MODE_LABEL:format("Dump")), L.SET_OFF)
		assert.equal(true, SB.Config.db.settings.focus.on[id], "the account's switch is untouched")
		assert.falsy(F.IsEnabled(id))
		click(L.SET_CUSTOM_LABEL, L.SET_CUSTOM_NEW)
		type(L.SET_CUSTOM_NAME, "Later")
		click(L.SET_CUSTOM_MAKE_LABEL, L.SET_CUSTOM_MAKE)
		assert.truthy(SB.Config.IsCharOverride("focus.sections.m_later"), "a mode made meanwhile is this character's too")
	end)
end)

describe("Share strings and modes of your own (week 12)", function()
	local SB, Pr, F
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		files[#files + 1] = "SwagBag/Engine/Profiles.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		SB.Categories.Load()
		Pr, F = SB.Profiles, SB.Focus
	end)

	-- Mutation: in the profile command, drop the `if #modes > 0 then` block (the answer would not name them).
	it("an export leaves your own modes out and names them; an import never makes one (hostile entries skipped)", function()
		local id = F.CreateMode("Farming")
		F.SetSections(id, { "c_herbs" })
		F.SetEnabled(id, false)
		local ok, said = SB.Slash.Run("profile export")
		assert.truthy(ok)
		assert.same({ SB.L.PROFILE_EXPORTED, SB.L.PROFILE_EXPORT_MODES:format("Farming") }, said)
		local text = Pr.Export(false)
		assert.falsy(text:find("m_farming", 1, true))
		local data = assert(Pr.Parse("SWAGBAG:1:s.focus.on.m_evil=b1;s.focus.sections.m_evil=sc_junk;m.m_evil.name=sEvil;"
			.. "s.bags.columns=n14"))
		assert.same({ "focus.on.m_evil", "focus.sections.m_evil", "m.m_evil.name" }, data.skipped)
		assert.truthy(Pr.Import(data))
		assert.is_nil(F.Mode("m_evil"))
		assert.same({ id }, { F.custom[1].id })
		assert.equal(14, SB.Config.Get("bags.columns"))
		assert.equal("c_herbs", SB.Config.Get("focus.sections." .. id), "an import keeps your modes' sections")
	end)

	-- Week-11 deferred (Profiles preview). Mutation: in Pr.Preview's lowered names, drop `placedNames[id] or`.
	it("the preview's ranked-lower line names a category by the name it comes in under", function()
		SB.Config.db.categories = { u_mine = { name = "Mine", query = "herb", priority = 50 } }
		SB.Categories.Load()
		local data = assert(Pr.Parse("SWAGBAG:1:cu.u_mine.name=sMine;cu.u_mine.query=sore;cu.u_mine.priority=n95"))
		local lines = Pr.Preview(data)
		local found
		for _, line in ipairs(lines) do
			if line == SB.L.PROFILE_PREVIEW_LOWERED:format("Mine (2)") then
				found = true
			end
		end
		assert.truthy(found, table.concat(lines, " / "))
	end)

	-- Ruling Y5. Mutation: in Profiles' replace(), drop the loop that carries `SB.Focus.custom` modes' on / sections over.
	it("loading, resetting or undoing a profile keeps your own modes' sections and switches", function()
		assert.truthy(Pr.Save("older"))
		local id = F.CreateMode("Farming")
		F.SetSections(id, { "c_herbs", "c_ore" })
		F.SetEnabled(id, false)
		assert.truthy(Pr.Load("older"))
		assert.same({ "c_herbs", "c_ore" }, F.Sections(id))
		assert.falsy(F.IsEnabled(id))
		assert.equal("Farming", F.NameOf(id))
		assert.truthy(Pr.Reset())
		assert.same({ "c_herbs", "c_ore" }, F.Sections(id))
		assert.truthy(Pr.Undo())
		assert.same({ "c_herbs", "c_ore" }, F.Sections(id))
		assert.falsy(F.IsEnabled(id))
	end)
end)
