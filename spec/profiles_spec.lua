-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip ChatFontNormal loadstring load
-- Week 7 (user pick 12): named profiles (account-wide copies of the settings the user set) and a
-- versioned share string that is read with patterns only, previewed before it changes anything, and
-- refused whole when it is damaged, too long, from a newer SwagBag, or has a wrong value.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

-- Named loadSB, never `load`: a local `load` would hide the global one the "never runs" test intercepts
-- (ruling R4).
local function loadSB(withUI)
	local files = { unpack(Env.ENGINE) }
	files[#files + 1] = "SwagBag/Engine/Profiles.lua"
	local SB = Loader.New(files)
	SB.Config.Init(nil, nil)
	SB.Categories.Load()
	if withUI then
		Fake.Install()
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsProfiles.lua")
		Loader.LoadFile(SB, "SwagBag/UI/ShareBox.lua")
	end
	return SB
end

describe("Profiles (week 7)", function()
	local SB, A, Pr, C, changed
	before_each(function()
		SB = loadSB(false)
		A, Pr, C = SB.Adapter, SB.Profiles, SB.Config
		changed = 0
		SB.On("SB_CONFIG_CHANGED", function(_, path)
			if path == nil then
				changed = changed + 1
			end
		end)
	end)

	-- Mutation: in replace(), drop the loop that keeps KEEP's keys (Safe Mode would travel with a profile).
	it("save, change, load: the profile's settings come back; Safe Mode and quick setup stay this machine's", function()
		C.Set("bags.columns", 14)
		C.Set("safeMode.bags", true)
		assert.same({ true, "M+" }, { Pr.Save(" M+ ") })
		assert.is_nil(SB.Config.db.profiles["M+"].settings.safeMode, "never saved")
		C.Set("bags.columns", 10)
		C.Set("setup.done", true)
		assert.truthy(Pr.Load("M+"))
		assert.same({ 14, true, true }, { C.Get("bags.columns"), C.Get("safeMode.bags"), C.Get("setup.done") })
		assert.same({ "M+" }, Pr.List())
		assert.equal("M+", SB.Config.db.profile)
		assert.equal(1, changed, "one SB_CONFIG_CHANGED(nil): every engine follows")
	end)

	-- Mutation: Pr.Undo returns true without restoring d.backups.profile.
	it("undo brings back the settings before a load or a reset, once", function()
		C.Set("bags.columns", 16)
		Pr.Save("A")
		C.Set("bags.columns", 10)
		Pr.Load("A")
		assert.truthy(Pr.Undo())
		assert.equal(10, C.Get("bags.columns"))
		assert.same({ false, "none" }, { Pr.Undo() })
		assert.truthy(Pr.Reset())
		assert.equal(12, C.Get("bags.columns"), "the default")
		Pr.Undo()
		assert.equal(10, C.Get("bags.columns"))
	end)

	-- Mutation: cleanName accepts any length.
	it("bad names, unknown profiles and read-only settings change nothing and say why", function()
		assert.same({ false, "name" }, { Pr.Save("") })
		assert.same({ false, "name" }, { Pr.Save(("x"):rep(25)) })
		assert.same({ false, "unknown" }, { Pr.Load("nope") })
		assert.same({ false, "unknown" }, { Pr.Delete("nope") })
		Pr.Save("A")
		SB.Config.readOnly = true
		assert.same({ false, "readonly" }, { Pr.Load("A") })
		assert.same({ false, "readonly" }, { Pr.Delete("A") })
		SB.Config.readOnly = false
		assert.truthy(Pr.Delete("A"))
		assert.same({}, Pr.List())
		SB.Config.db.profiles = "broken"
		assert.same({}, Pr.List(), "damaged saved data reads as none")
	end)

	-- Mutation: in esc(), let "%" through unescaped (a value with % would come back wrong).
	it("a share string round-trips the settings you set: text with ; = % |, booleans, numbers, the watch list", function()
		C.Set("bags.footer.entries", "gold,-free")
		C.Set("overlays.junk", false)
		C.Set("bags.scale", 1.25)
		C.Set("consumables.watch", { { query = "flask & lvl>=80;=%|", threshold = 2, name = "WATCH_FLASK" },
			{ itemID = 211880, threshold = 5 } })
		C.Set("safeMode.bank", true)
		local text = Pr.Export(false)
		assert.equal("SWAGBAG:1:", text:sub(1, 10))
		assert.falsy(text:find("safeMode", 1, true))
		assert.falsy(text:find("|", 1, true), "no pipe: chat and edit boxes would read it as a code")
		local data = assert(Pr.Parse(text))
		assert.same({ ["bags.footer.entries"] = "gold,-free", ["overlays.junk"] = false, ["bags.scale"] = 1.25 },
			data.settings)
		assert.same({ { query = "flask & lvl>=80;=%|", threshold = 2, name = "WATCH_FLASK" },
			{ itemID = 211880, threshold = 5 } }, data.watch)
	end)

	-- Mutation: in Pr.Parse, `elseif tonumber(version) > Pr.VERSION` -> `elseif false` (a newer string read anyway).
	it("refuses a string that is not ours, from a newer SwagBag, damaged, too long or with a wrong value", function()
		assert.same({ nil, "notours" }, { Pr.Parse("hello") })
		assert.same({ nil, "newer" }, { Pr.Parse("SWAGBAG:2:s.bags.columns=n14") })
		assert.same({ nil, "damaged", "s.bags.columns=x14" }, { Pr.Parse("SWAGBAG:1:s.bags.columns=x14") })
		assert.same({ nil, "damaged", "s.bags.view=s%ZZ" }, { Pr.Parse("SWAGBAG:1:s.bags.view=s%ZZ") })
		assert.same({ nil, "type", "bags.columns" }, { Pr.Parse("SWAGBAG:1:s.bags.columns=strue") })
		assert.same({ nil, "toolong" }, { Pr.Parse("SWAGBAG:1:" .. ("s.bags.view=ssections;"):rep(2000)) })
		assert.same({ nil, "damaged", "w" }, { Pr.Parse("SWAGBAG:1:w=sq%252A0") })
		assert.same({ nil, "empty" }, { Pr.Parse("  ") })
	end)

	-- Ruling R3 (and R13: MAX_LIST is enforced). Mutations: in Pr.Parse, `elseif not valid(path, value) then` ->
	-- `elseif false then`; or `if NEVER[path] then` -> `if false then` (the guild bank's safety switch would
	-- travel); or in numbers(), drop `count > Pr.MAX_LIST or `.
	it("refuses a value outside its range or words, whole; never carries withdrawAnyTab; caps item lists", function()
		assert.same({ nil, "type", "bags.columns" }, { Pr.Parse("SWAGBAG:1:s.bags.columns=n0") })
		assert.same({ nil, "type", "bags.columns" }, { Pr.Parse("SWAGBAG:1:s.bags.columns=n12.5") })
		assert.same({ nil, "type", "bags.scale" }, { Pr.Parse("SWAGBAG:1:s.overlays.junk=b0;s.bags.scale=n-3") })
		assert.same({ nil, "type", "prices.worthTop" }, { Pr.Parse("SWAGBAG:1:s.prices.worthTop=n0") })
		assert.same({ nil, "type", "theme.name" }, { Pr.Parse("SWAGBAG:1:s.theme.name=sbogus") })
		assert.same({ nil, "type", "focus.sections.raid" }, { Pr.Parse("SWAGBAG:1:s.focus.sections.raid=sc_gear%3Bx") })
		local data = assert(Pr.Parse("SWAGBAG:1:s.bags.columns=n14;s.guildBank.withdrawAnyTab=b1"))
		assert.same({ { ["bags.columns"] = 14 }, { "guildBank.withdrawAnyTab" } }, { data.settings, data.ignored })
		C.Set("guildBank.withdrawAnyTab", true)
		assert.falsy(Pr.Export(false):find("withdrawAnyTab", 1, true), "never exported either")
		assert.same({ nil, "type", "cu.u_x.inc" },
			{ Pr.Parse("SWAGBAG:1:cu.u_x.inc=s" .. ("1%2C"):rep(Pr.MAX_LIST) .. "1") })
	end)

	-- Mutations: in Pr.Parse, an unknown setting path is stored in data.settings (then imported as junk); or
	-- (ruling R4: the global `load` is the one intercepted) `local known = knownPaths()` -> `local known =
	-- load("return 1") and knownPaths()`.
	it("never runs what it reads; settings this version does not know are skipped and named", function()
		local loads = 0
		local realLoad, realLoadstring = _G.load, _G.loadstring
		_G.load = function(...) loads = loads + 1 return realLoad(...) end
		_G.loadstring = function(...) loads = loads + 1 return realLoadstring(...) end
		local data = Pr.Parse("SWAGBAG:1:s.bags.columns=n14;s.bags.sparkles=b1;s.os.execute=sx;zz=b1")
		_G.load, _G.loadstring = realLoad, realLoadstring
		assert.equal(0, loads)
		assert.same({ ["bags.columns"] = 14 }, data.settings)
		assert.same({ "bags.sparkles", "os.execute", "zz" }, data.skipped)
	end)

	-- Mutation: Pr.Preview lists every setting in the string, changed or not.
	it("the preview names each change (old -> new), the watch list, categories and skipped settings", function()
		C.Set("bags.columns", 14)
		local data = Pr.Parse("SWAGBAG:1:s.bags.columns=n14;s.bags.view=slist;s.bags.sparkles=b1;w=s")
		assert.same({ "Bag view: sections -> list", "Consumables watch list: 0 entries",
			"Not known by this version (skipped): bags.sparkles" }, Pr.Preview(data))
		assert.same({ SB.L.PROFILE_PREVIEW_NOTHING }, Pr.Preview(Pr.Parse("SWAGBAG:1:s.bags.columns=n14")))
	end)

	-- Ruling R18. Mutation: in Pr.Label, `local key = LABELS[path]` -> `local key = nil` (dotted paths).
	it("the preview names every setting as the settings window does, and a mode's sections by their names", function()
		for path in pairs(Pr.KnownPaths()) do
			local label = Pr.Label(path)
			assert.truthy(label ~= path and not label:match("^[%u_]+$"), path)
		end
		C.Set("focus.sections.raid", "c_gear")
		assert.same({ "Focus mode Raid opens: Gear -> Consumables, Gear",
			"Never imported (a safety setting stays as you set it here): " .. SB.L.PROFILE_LABEL_ANYTAB },
			Pr.Preview(assert(Pr.Parse("SWAGBAG:1:s.focus.sections.raid=sc_consumables%2Cc_gear;"
				.. "s.guildBank.withdrawAnyTab=b1"))))
	end)

	-- Ruling R7. Mutations: in Pr.Preview, `if watchChanged(data) then` -> `if data.watch then` (your own list
	-- would show as a change); or `#data.watch == 1 and L.PROFILE_PREVIEW_WATCH_ONE or` -> `` (1 entries).
	it("a watch list equal to yours is no change; one entry says entry", function()
		C.Set("consumables.watch", { { itemID = 211880, threshold = 5 } })
		local own = assert(Pr.Parse(Pr.Export(false)))
		assert.same({ SB.L.PROFILE_PREVIEW_NOTHING }, Pr.Preview(own))
		assert.same({ true, 0 }, { Pr.Import(own) })
		assert.same({ "Consumables watch list: 1 entry" }, Pr.Preview(assert(Pr.Parse("SWAGBAG:1:w=si211880%252A3"))))
	end)

	-- Mutations: Pr.Import skips data.edits; or (ruling R22) drops `def.source = "import"`.
	it("with categories: your categories, built-in edits and the order travel; import loads them, undo keeps settings", function()
		SB.Config.db.categories.u_mats = { name = "Mats", query = "herb | ore", priority = 58, displayOrder = 55,
			itemList = { include = { [211880] = true } } }
		SB.Config.db.userEdits.c_junk = { name = "Trash" }
		SB.Config.db.categoryOrder = { "c_junk", "u_mats" }
		local text = Pr.Export(true)
		SB.Config.db.categories, SB.Config.db.userEdits, SB.Config.db.categoryOrder = {}, {}, nil
		SB.Categories.Load()
		local data = assert(Pr.Parse(text))
		assert.same({ true, 3 }, { Pr.Import(data) })
		assert.same({ "Mats", "Trash" }, { SB.Categories.Name("u_mats"), SB.Categories.Name("c_junk") })
		assert.same({ "new", "c_junk", "u_mats" }, { unpack(SB.Categories.SectionOrder(), 1, 3) })
		assert.truthy(SB.Categories.Get("u_mats").itemList.include[211880])
		assert.equal("import", SB.Categories.Get("u_mats").source, "spec 7.7: it came from a share string")
	end)

	-- Ruling R6. Mutation: in Pr.Undo, `if back.withCategories then` -> `if false then` (the import's categories
	-- would stay after undo).
	it("undo after an import with categories brings back your categories, built-in edits and order too", function()
		SB.Config.db.categories.u_old = { name = "Old", query = "herb", priority = 58, displayOrder = 55 }
		SB.Config.db.userEdits.c_junk = { name = "Trash" }
		SB.Categories.Load()
		local data = assert(Pr.Parse("SWAGBAG:1:cu.u_new.name=sNew;cu.u_new.query=sore;cu.u_new.priority=n57;"
			.. "cu.u_new.displayOrder=n56;ce.c_junk.name=sJunk2;co=sc_junk%2Cu_new"))
		assert.truthy(Pr.Import(data))
		assert.same({ "New", "Junk2" }, { SB.Categories.Name("u_new"), SB.Categories.Name("c_junk") })
		assert.truthy(Pr.Undo())
		assert.same({ "Old", "Trash" }, { SB.Categories.Name("u_old"), SB.Categories.Name("c_junk") })
		assert.same({ true, true }, { SB.Config.db.categories.u_new == nil, SB.Config.db.categoryOrder == nil })
	end)

	-- P2. Mutation: /swagbag profile load ignores Load's answer (always says loaded).
	it("/swagbag profile answers every form", function()
		SB.Slash.Dispatch("profile save Raid")
		SB.Slash.Dispatch("profile")
		SB.Slash.Dispatch("profile load Nope")
		SB.Slash.Dispatch("profile load Raid")
		SB.Slash.Dispatch("profile undo")
		SB.Slash.Dispatch("profile delete Raid")
		SB.Slash.Dispatch("profile dance")
		local L = SB.L
		assert.same({ L.PROFILE_SAVED:format("Raid"), L.PROFILE_STATE:format("Raid", "Raid"), L.PROFILE_UNKNOWN:format("Nope"),
			L.PROFILE_LOADED:format("Raid"), L.PROFILE_UNDONE, L.PROFILE_DELETED:format("Raid"), L.PROFILE_USAGE }, A.Lines())
	end)
end)

describe("Share box and Profiles page (week 7)", function()
	local SB, A, SX, SW
	before_each(function()
		SB = loadSB(true)
		A, SX, SW = SB.Adapter, SB.ShareBox, SB.SettingsWindow
		ChatFontNormal = {}
	end)

	after_each(function()
		Fake.Uninstall()
		ChatFontNormal = nil
	end)

	-- Mutation: SX.Import imports without a preview (SX.data nil -> Parse inline).
	it("import: Preview first; a typed change needs a new preview; Import applies and answers in chat", function()
		SB.Slash.Dispatch("profile import")
		local f = SX.frame
		f.edit:SetText("SWAGBAG:1:s.bags.columns=n16")
		assert.falsy(SX.Import())
		assert.equal(SB.L.SHARE_PREVIEW_FIRST, f.status.text)
		assert.truthy(SX.Preview())
		assert.equal("Import would change:\nSlots per row: 12 -> 16", f.status.text)
		Fake.Fire(f.edit, "OnTextChanged", true)
		assert.falsy(SX.Import(), "changed since the preview")
		SX.Preview()
		assert.truthy(SX.Import())
		assert.equal(16, SB.Config.Get("bags.columns"))
		assert.falsy(f.shown)
		assert.same({ SB.L.PROFILE_IMPORT_OPENED, SB.L.PROFILE_IMPORTED:format(1) }, A.Lines())
	end)

	-- Mutations: SX.Preview keeps SX.data from an earlier good string when the new one is refused; or (ruling
	-- R18) drop `detail = SB.Profiles.Label(detail)` (the reason would name a dotted path).
	it("a refused string says why in the box and can never be imported", function()
		SX.ShowImport()
		SX.frame.edit:SetText("SWAGBAG:1:s.bags.columns=n16")
		SX.Preview()
		SX.frame.edit:SetText("SWAGBAG:9:s.bags.columns=n10")
		assert.falsy(SX.Preview())
		assert.equal(SB.L.SHARE_ERR_NEWER, SX.frame.status.text)
		assert.falsy(SX.Import())
		assert.equal(12, SB.Config.Get("bags.columns"))
		SX.frame.edit:SetText("SWAGBAG:1:s.bags.columns=n0")
		assert.falsy(SX.Preview())
		assert.equal("That string has a wrong value for Slots per row; nothing was read.", SX.frame.status.text)
	end)

	-- Mutation: ShowExport skips HighlightText.
	it("export shows the string selected, read-only, without import buttons", function()
		SB.Config.Set("bags.columns", 14)
		SB.Slash.Dispatch("profile export")
		local f = SX.frame
		assert.equal(SB.Profiles.Export(false), f.edit.text)
		assert.truthy(f.edit.calls.HighlightText)
		assert.same({ false, false }, { f.preview.shown, f.import.shown })
		f.edit.text = "typed"
		Fake.Fire(f.edit, "OnTextChanged", true)
		assert.equal(SB.Profiles.Export(false), f.edit.text, "typing puts the string back")
	end)

	-- Mutation: the page's Save button runs "profile save Profile 1" every time (the second would overwrite).
	it("the Profiles page saves under a free name, loads and deletes through /swagbag profile", function()
		SW.Show("profiles")
		local function click(text, nth)
			local seen = 0
			for i = 1, SW.used.buttons do
				if SW.buttons[i].text == text then
					seen = seen + 1
					if seen == (nth or 1) then
						Fake.Fire(SW.buttons[i], "OnClick")
						return
					end
				end
			end
			error("no button " .. text)
		end
		click(SB.L.SET_PROFILES_SAVE_BUTTON)
		click(SB.L.SET_PROFILES_SAVE_BUTTON)
		assert.same({ "Profile 1", "Profile 2" }, SB.Profiles.List())
		click(SB.L.SET_PROFILE_DELETE, 1)
		assert.same({ "Profile 2" }, SB.Profiles.List())
		assert.equal(SB.L.PROFILE_DELETED:format("Profile 1"), SW.lastStatus)
	end)
end)
