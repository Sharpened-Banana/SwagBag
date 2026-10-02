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

	it("restyles in combat and creates no frame (a flat button gets one texture of SwagBag's own)", function()
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
