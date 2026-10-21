-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Themes (UI/Theme.lua, UI/Themes.lua): the Blizzard look is exactly the old one (AC14.1); a theme
-- restyles only SwagBag's own frames, live, in or out of combat; refusals answer (P2).
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Theme", function()
	local SB, A, T
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		Fake.Install()
		A.FontObject = function(name) return { fontObject = name } end
		Loader.LoadFile(SB, "SwagBag/UI/Theme.lua")
		T = SB.Theme
		SB.Config.Init(nil, nil)
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- A font string made with a font object, as the windows make theirs.
	local function fontString(objectName)
		local fs = Fake.New("FontString")
		fs.GetFontObject = function() return objectName end
		return fs
	end

	local function templateButton()
		local b = Fake.New("Button")
		b.Left, b.Middle, b.Right = Fake.New("Texture"), Fake.New("Texture"), Fake.New("Texture")
		return b
	end

	-- AC14.1. Mutation: change any number of the Blizzard palette (e.g. window alpha 0.95 -> 0.9).
	it("the Blizzard look is the old one: backdrops, header colour, slot atlas, fonts untouched", function()
		local main, dialog = Fake.New("Frame"), Fake.New("Frame")
		T.Window(main, "main")
		T.Window(dialog, "dialog")
		assert.same({ { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 } },
			main.calls.SetBackdrop)
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, main.calls.SetBackdropColor)
		assert.same({ 0.35, 0.35, 0.4, 1 }, main.calls.SetBackdropBorderColor)
		assert.same({ 0.06, 0.06, 0.08, 0.97 }, dialog.calls.SetBackdropColor)
		assert.same({ 1, 1, 1, 0.06 }, { T.HeaderColor() })
		local slot = Fake.New("Texture")
		T.Slot(slot)
		assert.same({ "bags-item-slot64" }, slot.calls.SetAtlas)
		local fs = fontString("GameFontNormal")
		T.Text(fs, "title")
		assert.same({ "GameFontNormal" }, fs.calls.SetFontObject, "the font it was made with")
		local b = templateButton()
		T.Button(b)
		assert.truthy(b.Left.shown)
		assert.is_nil(b.calls.CreateTexture, "no texture added to a button in the Blizzard look")
	end)

	-- Mutation: in Theme.Apply, drop restyleAll().
	it("Modern flat restyles every registered object at once, and Blizzard puts every one back", function()
		local main, fs, b, slot = Fake.New("Frame"), fontString("GameFontNormal"), templateButton(), Fake.New("Texture")
		local row = Fake.New("Frame")
		row.bg = Fake.New("Texture")
		T.Window(main, "main")
		T.Text(fs, "title")
		T.Button(b)
		T.Slot(slot)
		T.Row(row)
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		assert.truthy(T.Apply("flat", true))
		assert.equal("flat", SB.Config.Get("theme.name"))
		assert.same({ 0.09, 0.09, 0.1, 0.92 }, main.calls.SetBackdropColor)
		assert.same({ 0, 0, 0, 1 }, main.calls.SetBackdropBorderColor)
		assert.same({ { fontObject = "GameFontHighlight" } }, fs.calls.SetFontObject)
		assert.falsy(b.Left.shown, "the template's own textures are hidden")
		assert.same({ 0.14, 0.14, 0.15, 1 }, slot.calls.SetColorTexture)
		assert.truthy(row.bg.shown)
		assert.truthy(T.Apply("blizzard", true))
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, main.calls.SetBackdropColor)
		assert.same({ "GameFontNormal" }, fs.calls.SetFontObject)
		assert.truthy(b.Left.shown)
		assert.same({ "bags-item-slot64" }, slot.calls.SetAtlas)
		assert.falsy(row.bg.shown)
	end)

	it("an object registered while a theme is on gets that theme at once", function()
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		T.Apply("flat", false)
		local w = Fake.New("Frame")
		T.Window(w, "dialog")
		assert.same({ 0.09, 0.09, 0.1, 0.96 }, w.calls.SetBackdropColor)
	end)

	-- Mutation: in Theme.Apply, write theme.name before the availability check.
	it("Apply refuses an unknown look, a look not available now and read-only settings, and changes nothing", function()
		T.Register({ id = "gone", name = "Gone", available = function() return false end, palette = function() return {} end })
		local main = Fake.New("Frame")
		T.Window(main, "main")
		assert.same({ false, "unknown" }, { T.Apply("nope", true) })
		assert.same({ false, "unavailable" }, { T.Apply("gone", true) })
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		SB.Config.readOnly = true
		assert.same({ false, "readonly" }, { T.Apply("flat", true) })
		assert.equal("blizzard", T.Current())
		assert.equal("blizzard", SB.Config.Get("theme.name"))
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, main.calls.SetBackdropColor)
	end)

	it("SB_THEME_CHANGED fires with the new look", function()
		local seen
		SB.On("SB_THEME_CHANGED", function(_, id) seen = id end)
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		T.Apply("flat", false)
		assert.equal("flat", seen)
	end)

	it("at login the saved look applies; one not available now shows Blizzard's, says so once and stays saved", function()
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		SB.Config.Set("theme.name", "flat")
		SB.Emit("SB_LOGIN")
		assert.equal("flat", T.Current())
		T.Apply("blizzard", false)
		T.Register({ id = "gone", name = "Gone", available = function() return false end, palette = function() return {} end })
		SB.Config.Set("theme.name", "gone")
		SB.Emit("SB_LOGIN")
		assert.equal("blizzard", T.Current())
		assert.same({ SB.L.THEME_FALLBACK:format("Gone") }, A.Lines())
		assert.equal("gone", SB.Config.Get("theme.name"))
	end)

	-- 0.14.5 (user request). Mutation: in styleWindow, ignore palette.edge (or in styleSlot, palette.slotTexture).
	it("the Classic look: dialog border, tiled stone, the old slot squares, gold text; Blizzard comes back exactly", function()
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		local main, slot, fs = Fake.New("Frame"), Fake.New("Texture"), fontString("GameFontHighlight")
		T.Window(main, "main")
		T.Slot(slot)
		T.Text(fs, "title")
		local b = templateButton()
		T.Button(b)
		assert.truthy(T.Apply("classic", true))
		assert.equal("classic", SB.Config.Get("theme.name"))
		assert.same({ { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16, tile = true, tileSize = 32,
			insets = { left = 4, right = 4, top = 4, bottom = 4 } } }, main.calls.SetBackdrop)
		assert.same({ 1, 1, 1, 1 }, main.calls.SetBackdropColor)
		assert.same({ "Interface\\PaperDoll\\UI-Backpack-EmptySlot" }, slot.calls.SetTexture)
		assert.same({ { fontObject = "GameFontNormal" } }, fs.calls.SetFontObject)
		assert.truthy(b.Left.shown, "Blizzard's own red buttons stay")
		assert.same({ 1, 0.82, 0, 0.1 }, { T.HeaderColor() })
		assert.truthy(T.Apply("blizzard", false))
		assert.same({ { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 } },
			main.calls.SetBackdrop)
		assert.same({ "bags-item-slot64" }, slot.calls.SetAtlas)
		assert.same({ "GameFontHighlight" }, fs.calls.SetFontObject)
	end)

	it("a live switch creates no frame (it works on plain frames and SwagBag's own textures, so combat is no obstacle)", function()
		local b = templateButton()
		T.Button(b)
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		A.combat = true
		local n = #Fake.created
		assert.truthy(T.Apply("flat", false))
		assert.equal(n, #Fake.created)
		assert.falsy(b.Left.shown)
	end)

	it("loads before Config.Init without touching Config", function()
		local SB2 = Loader.New(Env.ENGINE)
		SB2.Config.Get = function() error("Config.Get called while loading") end
		local ok, err = pcall(Loader.LoadFile, SB2, "SwagBag/UI/Theme.lua")
		assert.truthy(ok, tostring(err))
	end)
end)

describe("Theme hardening (W5-5)", function()
	local SB, A, T
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		Fake.Install()
		A.FontObject = function(name) return { fontObject = name } end
		Loader.LoadFile(SB, "SwagBag/UI/Theme.lua")
		T = SB.Theme
		SB.Config.Init(nil, nil)
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function unchanged(main)
		assert.equal("blizzard", T.Current())
		assert.equal("blizzard", SB.Config.Get("theme.name"))
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, main.calls.SetBackdropColor)
	end

	-- Mutations: move Config.Set above the palette check; drop validPalette.
	it("a palette() that errors is refused: nothing changes, nothing is saved, the error is recorded", function()
		T.Register({ id = "bad", name = "Bad", available = function() return true end, palette = function() error("boom") end })
		local main = Fake.New("Frame")
		T.Window(main, "main")
		assert.same({ false, "unavailable" }, { T.Apply("bad", true) })
		unchanged(main)
		assert.truthy(#SB.ErrorTrap.Recent() > 0)
		assert.falsy(SB.SafeMode.IsOn("bags"), "a theme glitch never takes the bags away")
	end)

	it("a palette without its required fields is refused the same way", function()
		T.Register({ id = "empty", name = "Empty", available = function() return true end, palette = function() return {} end })
		T.Register({ id = "badcol", name = "BadCol", available = function() return true end, palette = function()
			return { window = { 1, 1, 1 }, dialog = { 1, 1, 1, 1 }, border = { 1, 1, 1, 1 }, header = { 1, 1, 1, 1 }, backdrop = "x" }
		end })
		local main = Fake.New("Frame")
		T.Window(main, "main")
		assert.same({ false, "unavailable" }, { T.Apply("empty", true) })
		assert.same({ false, "unavailable" }, { T.Apply("badcol", true) })
		unchanged(main)
	end)

	it("an available() that errors counts as not available", function()
		T.Register({ id = "bad", name = "Bad", available = function() error("boom") end, palette = function() return {} end })
		assert.same({ false, "unavailable" }, { T.Apply("bad", true) })
		assert.equal("blizzard", T.Current())
	end)

	-- Mutation: drop the ErrorTrap.Run around restyleAll, or the restore.
	it("a restyle that fails part-way puts the previous look back and saves nothing", function()
		local main = Fake.New("Frame")
		T.Window(main, "main")
		local fs = Fake.New("FontString")
		fs.GetFontObject = function() return "GameFontNormal" end
		T.Text(fs, "title")
		fs.SetFontObject = function(self, obj)
			if type(obj) == "table" then
				error("font failed")
			end
			self.calls.SetFontObject = { obj }
		end
		assert.same({ false, "unavailable" }, { T.Apply("flat", true) })
		unchanged(main)
		assert.same({ "GameFontNormal" }, fs.calls.SetFontObject)
	end)

	it("a header colour is never an error", function()
		assert.same({ 1, 1, 1, 0.06 }, { T.HeaderColor() })
	end)

	it("Blizzard-themed font strings get no SetFont and no SetTextColor", function()
		local fs = Fake.New("FontString")
		fs.GetFontObject = function() return "GameFontNormal" end
		T.Text(fs, "title")
		T.Apply("flat", false)
		T.Apply("blizzard", false)
		assert.is_nil(fs.calls.SetFont)
		assert.is_nil(fs.calls.SetTextColor)
	end)

	it("Modern flat twice leaves one texture on a button, and a large title stays large", function()
		local b = Fake.New("Button")
		T.Button(b)
		local made = 0
		b.CreateTexture = function(self) made = made + 1; return Fake.New("Texture", self) end
		T.Apply("flat", false)
		T.Apply("flat", false)
		assert.equal(1, made)
		local fs = Fake.New("FontString")
		fs.GetFontObject = function() return "GameFontNormalLarge" end
		T.Text(fs, "titleLarge")
		assert.same({ { fontObject = "GameFontHighlightLarge" } }, fs.calls.SetFontObject)
	end)
end)

describe("Blizzard values on the guild window and quick setup (AC14.1)", function()
	local SB
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		SB.Config.Init(nil, nil)
		Fake.Install()
		Env.PaintGlobals()
		SB.Adapter.FontObject = function(name) return { fontObject = name } end
		Loader.LoadFile(SB, "SwagBag/UI/Theme.lua")
	end)

	after_each(function()
		Env.ClearPaintGlobals()
		Fake.Uninstall()
	end)

	it("the guild bank window is registered with the main look", function()
		Env.FakeBags(SB)
		local GW = Env.LoadGuild(SB)
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, GW.frame.calls.SetBackdropColor)
		assert.same({ 0.35, 0.35, 0.4, 1 }, GW.frame.calls.SetBackdropBorderColor)
		SB.Theme.Register({ id = "flat", name = "x", available = function() return true end, palette = function()
			return { window = { 0.1, 0.1, 0.1, 0.5 }, dialog = { 0, 0, 0, 1 }, border = { 0, 0, 0, 1 }, header = { 1, 1, 1, 1 },
				backdrop = "b" }
		end })
		SB.Theme.Apply("flat", false)
		assert.same({ 0.1, 0.1, 0.1, 0.5 }, GW.frame.calls.SetBackdropColor)
	end)

	it("the quick setup window is a dialog with the old numbers", function()
		SB.BagsWindow = { RequestLayout = function() end, RefreshTitle = function() end, IsOpen = function() return false end }
		Loader.LoadFile(SB, "SwagBag/Engine/Setup.lua") -- week 12: the wizard's draft
		Loader.LoadFile(SB, "SwagBag/UI/QuickSetup.lua")
		local f = SB.QuickSetup.frame
		assert.same({ 0.06, 0.06, 0.08, 0.97 }, f.calls.SetBackdropColor)
		assert.same({ 0.35, 0.35, 0.4, 1 }, f.calls.SetBackdropBorderColor)
		assert.is_nil(f.title.calls.SetFont)
	end)
end)

describe("Themes: /swagbag theme, Settings > Look, the windows", function()
	local SB, A, T, SW
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		Env.PaintGlobals()
		A.FontObject = function(name) return { fontObject = name } end
		Loader.LoadFile(SB, "SwagBag/UI/Theme.lua")
		T = SB.Theme
		SB.BagsWindow = { View = function() return "sections" end }
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		SW = SB.SettingsWindow
	end)

	after_each(function()
		Env.ClearPaintGlobals()
		Fake.Uninstall()
	end)

	-- P2. Mutation: in the theme command, return THEME_SET even when Apply fails.
	it("/swagbag theme answers every form", function()
		T.Register({ id = "gone", name = "Gone", available = function() return false end, palette = function() return {} end })
		SB.Slash.Dispatch("theme")
		SB.Slash.Dispatch("theme flat")
		SB.Slash.Dispatch("theme gone")
		SB.Slash.Dispatch("theme nope")
		local lines = A.Lines()
		assert.truthy(lines[1]:find("Look: Blizzard. Looks: blizzard (Blizzard), flat (Modern flat), ", 1, true), lines[1])
		assert.truthy(lines[1]:find("gone (Gone, not available now)", 1, true), lines[1])
		assert.equal("Look: Modern flat. Only SwagBag's own windows change.", lines[2])
		assert.equal(SB.L.THEME_UNAVAILABLE:format("Modern flat"), lines[3])
		assert.truthy(lines[4]:find("Use /swagbag theme", 1, true))
		SB.Config.readOnly = true
		SB.Slash.Dispatch("theme blizzard")
		assert.equal(SB.L.SETTINGS_READONLY, A.Lines()[5])
		assert.equal("flat", T.Current())
	end)

	it("Settings > Look: Blizzard first and selected; a click switches live and the status line answers", function()
		SW.Show("look")
		assert.equal("Blizzard", SW.buttons[1].text)
		assert.truthy(SW.selected[SW.buttons[1]])
		Fake.Fire(SW.buttons[2], "OnClick")
		assert.equal("flat", T.Current())
		assert.equal("Look: Modern flat. Only SwagBag's own windows change.", SW.lastStatus)
		assert.same({ 0.09, 0.09, 0.1, 0.96 }, SW.frame.calls.SetBackdropColor, "the settings window itself changed")
		assert.truthy(SW.selected[SW.buttons[2]])
	end)

	it("the bank window and its title buttons follow the look", function()
		Env.FakeBags(SB)
		Env.LoadBank(SB)
		local BW = SB.BankWindow
		assert.same({ 0.06, 0.06, 0.08, 0.95 }, BW.frame.calls.SetBackdropColor)
		T.Apply("flat", false)
		assert.same({ 0.09, 0.09, 0.1, 0.92 }, BW.frame.calls.SetBackdropColor)
		assert.same({ { fontObject = "GameFontHighlight" } }, BW.frame.title.calls.SetFontObject)
	end)

	-- The deposit group keeps its tint through a theme change. Mutation: drop the tinted check in
	-- SectionHeaders' SB_THEME_CHANGED handler.
	it("section headers take the new background, except one tinted for deposits", function()
		Loader.LoadFile(SB, "SwagBag/UI/SectionHeaders.lua")
		local H = SB.SectionHeaders
		local parent = Fake.New("Frame")
		local plain = H.Acquire(parent, "c_junk", "Junk", 0, 0, 100)
		local tinted = H.Acquire(parent, "#bank", "Bank", 0, -20, 100)
		H.Tint(tinted, 0.25, 0.85, 0.35, 0.3)
		T.Apply("flat", false)
		assert.same({ 1, 1, 1, 0.03 }, plain.bg.calls.SetColorTexture)
		assert.same({ 0.25, 0.85, 0.35, 0.3 }, tinted.bg.calls.SetColorTexture)
		H.ReleaseAll(parent)
		local again = H.Acquire(parent, "#bank", "Bank", 0, 0, 100)
		assert.same({ 1, 1, 1, 0.03 }, again.bg.calls.SetColorTexture, "a reacquired header loses the tint")
	end)
end)

describe("Themes: Matches ElvUI", function()
	local SB, A, T, SW, media
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		Env.PaintGlobals()
		A.FontObject = function(name) return { fontObject = name } end
		media = { font = "Fonts\\Elv.ttf", size = 12, blank = "Interface\\ElvBlank", border = { 0, 0, 0, 1 },
			backdrop = { 0.1, 0.1, 0.1, 1 }, fade = { 0.05, 0.05, 0.05, 0.8 } }
		A.ElvUIMedia = function() return media end
		Loader.LoadFile(SB, "SwagBag/UI/Theme.lua")
		T = SB.Theme
		SB.BagsWindow = { View = function() return "sections" end }
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		Loader.LoadFile(SB, "SwagBag/UI/Themes.lua")
		SW = SB.SettingsWindow
	end)

	after_each(function()
		Env.ClearPaintGlobals()
		Fake.Uninstall()
	end)

	-- Mutation: in the elvui palette, use m.border for the window background.
	it("uses ElvUI's texture, colours and font, sized by role, outlined", function()
		local w, fs, slot = Fake.New("Frame"), Fake.New("FontString"), Fake.New("Texture")
		T.Window(w, "main")
		T.Text(fs, "title")
		T.Slot(slot)
		assert.truthy(T.Apply("elvui", true))
		assert.same({ { bgFile = "Interface\\ElvBlank", edgeFile = "Interface\\ElvBlank", edgeSize = 1 } }, w.calls.SetBackdrop)
		assert.same({ 0.05, 0.05, 0.05, 0.8 }, w.calls.SetBackdropColor)
		assert.same({ 0, 0, 0, 1 }, w.calls.SetBackdropBorderColor)
		assert.same({ "Fonts\\Elv.ttf", 13, "OUTLINE" }, fs.calls.SetFont, "title: one point larger")
		assert.same({ 0.1, 0.1, 0.1, 1 }, slot.calls.SetColorTexture)
		assert.same({ 0.1, 0.1, 0.1, 0.6 }, { T.HeaderColor() })
	end)

	it("reads ElvUI's media again on every switch (a profile change shows after the next /swagbag theme elvui)", function()
		local w = Fake.New("Frame")
		T.Window(w, "main")
		T.Apply("elvui", false)
		media.fade = { 0.2, 0.2, 0.3, 0.7 }
		SB.Slash.Dispatch("theme elvui")
		assert.same({ 0.2, 0.2, 0.3, 0.7 }, w.calls.SetBackdropColor)
	end)

	-- Mutation: make the elvui theme's available() return true.
	it("without ElvUI the choice is refused with the reason; nothing changes", function()
		media = nil
		SB.Slash.Dispatch("theme elvui")
		assert.equal("The ElvUI look needs ElvUI, which is not loaded. The look stays Blizzard.", A.Lines()[1])
		assert.equal("blizzard", T.Current())
		assert.equal("blizzard", SB.Config.Get("theme.name"))
		SW.Show("look")
		Fake.Fire(SW.buttons[4], "OnClick") -- Blizzard, Modern flat, Classic (0.14.5), Matches ElvUI
		assert.equal("The ElvUI look needs ElvUI, which is not loaded. The look stays Blizzard.", SW.lastStatus)
		assert.truthy(SW.selected[SW.buttons[1]], "Blizzard stays selected")
		assert.equal(0, #SB.ErrorTrap.Recent(), "refused by available(), not by a palette that blew up")
	end)

	it("read-only settings refuse the ElvUI look and say so", function()
		SB.Config.readOnly = true
		SB.Slash.Dispatch("theme elvui")
		assert.equal(SB.L.SETTINGS_READONLY, A.Lines()[1])
		assert.equal("blizzard", T.Current())
	end)

	it("a saved ElvUI look while ElvUI is not loaded shows Blizzard's at login, says so, and stays saved", function()
		SB.Config.Set("theme.name", "elvui")
		media = nil
		SB.Emit("SB_LOGIN")
		assert.equal("blizzard", T.Current())
		assert.same({ SB.L.THEME_FALLBACK:format("Matches ElvUI") }, A.Lines())
		assert.equal("elvui", SB.Config.Get("theme.name"))
	end)

	-- F13. Mutation: in styleText (UI/Theme.lua), skip SetFontObject(original) when the palette has no fonts.
	it("ElvUI straight back to Blizzard puts back every font object it was made with", function()
		local fs = Fake.New("FontString")
		fs.GetFontObject = function() return "GameFontNormal" end
		local small = Fake.New("FontString")
		small.GetFontObject = function() return "GameFontHighlightSmall" end
		T.Text(fs, "title")
		T.Text(small, "small")
		assert.truthy(T.Apply("elvui", true))
		assert.same({ "Fonts\\Elv.ttf", 13, "OUTLINE" }, fs.calls.SetFont)
		assert.truthy(T.Apply("blizzard", true))
		assert.same({ "GameFontNormal" }, fs.calls.SetFontObject)
		assert.same({ "GameFontHighlightSmall" }, small.calls.SetFontObject)
		assert.equal("blizzard", T.Current())
	end)

	it("the elvui palette() returns nil (no error logged) when ElvUI's media is gone", function()
		media = nil
		assert.is_nil(T.themes.elvui.palette())
		assert.same({ false, "unavailable" }, { T.Apply("elvui", false) })
		assert.equal(0, #SB.ErrorTrap.Recent())
	end)

	it("a palette ElvUI cannot fill is refused by validation, not applied (W5-5)", function()
		media.fade = { 0.2, "x", 0.3, 0.7 }
		assert.same({ false, "unavailable" }, { T.Apply("elvui", true) })
		assert.equal("blizzard", T.Current())
		assert.equal("blizzard", SB.Config.Get("theme.name"))
	end)

	it("the report names the look and the saved setting", function()
		Loader.LoadFile(SB, "SwagBag/Core/Checks.lua")
		Loader.LoadFile(SB, "SwagBag/Core/Report.lua")
		T.Apply("elvui", true)
		assert.truthy(SB.Report.Build():find("Look: elvui (setting elvui)", 1, true))
	end)
end)

describe("Adapter.ElvUIMedia (ElvUI's public globals, read only)", function()
	-- luacheck: globals ElvUI issecretvalue
	local SB
	before_each(function()
		SB = Loader.New()
	end)

	after_each(function()
		ElvUI = nil
		issecretvalue = nil
	end)

	it("reads the font, texture, colours (r/g/b/a or [1]..[4]) and font size", function()
		ElvUI = { { media = { normFont = "F.ttf", blankTex = "Blank", bordercolor = { r = 0, g = 0, b = 0 },
			backdropcolor = { 0.1, 0.2, 0.3, 1 }, backdropfadecolor = { r = 0.05, g = 0.05, b = 0.05, a = 0.7 } },
			db = { general = { fontSize = 11 } } } }
		assert.same({ font = "F.ttf", size = 11, blank = "Blank", border = { 0, 0, 0, 1 }, backdrop = { 0.1, 0.2, 0.3, 1 },
			fade = { 0.05, 0.05, 0.05, 0.7 } }, SB.Adapter.ElvUIMedia())
	end)

	it("is nil without ElvUI, with odd media, and never errors", function()
		assert.is_nil(SB.Adapter.ElvUIMedia())
		ElvUI = { { media = { normFont = 3 } } }
		assert.is_nil(SB.Adapter.ElvUIMedia())
		ElvUI = setmetatable({}, { __index = function() error("boom") end })
		assert.is_nil(SB.Adapter.ElvUIMedia())
	end)

	it("clamps the font size to 6-32, falling back to 12 when missing or out of range", function()
		local function sizeOf(v)
			ElvUI = { { media = { normFont = "F.ttf", blankTex = "Blank", bordercolor = { 0, 0, 0, 1 },
				backdropcolor = { 0.1, 0.1, 0.1, 1 }, backdropfadecolor = { 0.1, 0.1, 0.1, 0.8 } },
				db = { general = { fontSize = v } } } }
			return SB.Adapter.ElvUIMedia().size
		end
		assert.equal(6, sizeOf(6))
		assert.equal(32, sizeOf(32))
		assert.equal(12, sizeOf(5))
		assert.equal(12, sizeOf(33))
		assert.equal(12, sizeOf(nil))
		assert.equal(12, sizeOf("big"))
	end)

	it("is nil when a required value is missing or secret", function()
		local function make(over)
			local m = { normFont = "F.ttf", blankTex = "Blank", bordercolor = { 0, 0, 0, 1 }, backdropcolor = { 0.1, 0.1, 0.1, 1 },
				backdropfadecolor = { 0.1, 0.1, 0.1, 0.8 } }
			for k, v in pairs(over) do m[k] = v end
			ElvUI = { { media = m, db = { general = { fontSize = 12 } } } }
		end
		make({})
		assert.truthy(SB.Adapter.ElvUIMedia())
		make({ bordercolor = false })
		assert.is_nil(SB.Adapter.ElvUIMedia())
		make({ blankTex = false })
		assert.is_nil(SB.Adapter.ElvUIMedia())
		make({})
		issecretvalue = function(v) return v == "F.ttf" end
		assert.is_nil(SB.Adapter.ElvUIMedia())
	end)
end)
