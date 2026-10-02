-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The settings window (spec F15, 10.5): pages of choices, default first with its alternative
-- next to it (P1), feedback for every click (P2), read-only refusal, plain frames only.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Settings window", function()
	local SB, A, SW, bags, ran
	before_each(function()
		SB = Loader.New(Env.ENGINE)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		-- The bags window as the settings rows use it.
		bags = { calls = {} }
		function bags.View() return SB.Config.Get("bags.view") end
		function bags.SetView(v) bags.calls[#bags.calls + 1] = "view " .. v SB.Config.Set("bags.view", v) end
		function bags.SetScale(v) bags.calls[#bags.calls + 1] = "scale " .. v SB.Config.Set("bags.scale", v) end
		function bags.RequestLayout(r) bags.calls[#bags.calls + 1] = "layout " .. r end
		SB.BagsWindow = bags
		-- The chat commands the rows run (their real versions live in the windows' files).
		ran = {}
		for _, name in ipairs({ "free", "bank", "guild", "overlays" }) do
			SB.Slash.Register(name, "test", function(arg)
				ran[#ran + 1] = name .. " " .. arg
				return "ran " .. name .. " " .. arg
			end)
		end
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		SW = SB.SettingsWindow
		SB.Categories.Load()
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- The shown buttons of the page, in order: { text, selected }.
	local function buttons()
		local out = {}
		for i = 1, SW.used.buttons do
			local b = SW.buttons[i]
			out[#out + 1] = { b.text, SW.selected[b] == true }
		end
		return out
	end

	local function button(text)
		for i = 1, SW.used.buttons do
			local b = SW.buttons[i]
			if b.text == text then
				return b
			end
		end
		error("no button " .. text)
	end

	local function click(text)
		Fake.Fire(button(text), "OnClick")
	end

	it("a bare /swagbag opens the settings at the first page (spec 10.5)", function()
		SW.frame:Hide()
		SB.Slash.Dispatch("")
		assert.truthy(SW.IsOpen())
		assert.equal("bags", SW.current)
		assert.same({ "Settings opened." }, A.Lines())
	end)

	it("/swagbag settings <page> opens that page; an unknown page lists the pages", function()
		SB.Slash.Dispatch("settings bank")
		assert.equal("bank", SW.current)
		SB.Slash.Dispatch("settings nope")
		assert.equal("Use /swagbag settings, or /swagbag settings <page> (pages: bags, bank, overlays).", A.Lines()[2])
	end)

	it("P1: each row shows the default first, its alternative next to it, and the current one selected", function()
		SW.Show("bags")
		local b = buttons()
		assert.same({ "Categories", true }, b[1])
		assert.same({ "Grid", false }, b[2])
		assert.same({ "12", true }, b[3], "12 slots per row, the default, first")
	end)

	-- Mutation: in SettingsWindow's act(), drop SW.Say (the status line keeps the old text).
	it("P2: a choice with a chat command runs it and shows its answer", function()
		SW.Show("bags")
		click("Every free slot")
		assert.same({ "free all" }, ran)
		assert.equal("ran free all", SW.lastStatus)
	end)

	it("columns: saved, the bags regroup, the status says so, and the new one is selected", function()
		SW.Show("bags")
		click("14")
		assert.equal(14, SB.Config.Get("bags.columns"))
		assert.same({ "layout columns" }, bags.calls)
		assert.equal("Bags: 14 slots per row.", SW.lastStatus)
		assert.truthy(SW.selected[button("14")])
		assert.falsy(SW.selected[button("12")])
	end)

	-- Mutation: in the columns row's apply, ignore Config.Set's result.
	it("read-only settings: a click refuses with the reason and the selection stays", function()
		SB.Config.readOnly = true
		SW.Show("bags")
		click("14")
		assert.equal(12, SB.Config.Get("bags.columns"))
		assert.equal(SB.L.SETTINGS_READONLY, SW.lastStatus)
		assert.truthy(SW.selected[button("12")])
		click("Grid")
		assert.same({}, bags.calls)
		assert.equal(SB.L.SETTINGS_READONLY, SW.lastStatus)
	end)

	it("the view and size rows go through the bags window", function()
		SW.Show("bags")
		click("Grid")
		click("125%")
		assert.same({ "view grid", "scale 1.25" }, bags.calls)
		assert.equal("SwagBag 125%", SW.lastStatus)
	end)

	it("reagent bag own section: the categories are rebuilt, so Reagents exists at once", function()
		SW.Show("bags")
		assert.falsy(SB.Categories.Get("c_reagents").enabled)
		click("Own section")
		assert.truthy(SB.Categories.Get("c_reagents").enabled)
		assert.equal(SB.L.SET_REAGENTS_OWN_DONE, SW.lastStatus)
	end)

	it("bank page rows run the bank and guild commands; totals off refreshes the open headers", function()
		local refreshed = 0
		SB.On("SB_PRICES_CHANGED", function() refreshed = refreshed + 1 end)
		SW.Show("bank")
		click("Shown beside")
		click("View only")
		click("Any tab")
		click("Hide")
		assert.same({ "bank beside", "guild view", "guild anytab on" }, ran)
		assert.equal(false, SB.Config.Get("prices.headerTotals"))
		assert.equal(1, refreshed)
	end)

	it("overlays page: each overlay switches through /swagbag overlays", function()
		SW.Show("overlays")
		click("Off") -- the first row: item level on gear
		click("Pawn")
		assert.same({ "overlays ilvl off", "overlays pawn on" }, ran)
	end)

	-- Mutation: run row.apply directly instead of through ErrorTrap.Run in act().
	it("an error in a change is recorded without Safe Mode, and the status line says so", function()
		SW.Show("bags")
		bags.RequestLayout = function() error("layout broke") end
		click("14")
		assert.equal(SB.L.SETTINGS_FAILED, SW.lastStatus)
		assert.equal("none", SB.ErrorTrap.Recent()[1].window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	-- Mutation: in SettingsPages' run(), return the command's feedback even when ok is false.
	it("a command that errors shows SETTINGS_FAILED, recorded under the command's own window", function()
		SB.Slash.Register("bank", "test", function() error("bank broke") end, "bank")
		SW.Show("bank")
		click("Shown beside")
		assert.equal(SB.L.SETTINGS_FAILED, SW.lastStatus)
		assert.equal("bank", SB.ErrorTrap.Recent()[1].window)
		assert.truthy(SB.SafeMode.IsOn("bank"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("an unknown command shows the unknown-command text, not 'recorded'", function()
		SB.Slash.commands.free = nil
		SW.Show("bags")
		click("Every free slot")
		assert.equal(SB.L.UNKNOWN_COMMAND:format("free"), SW.lastStatus)
	end)

	it("read-only: a command row shows what the command answered", function()
		SB.Slash.Register("free", "test", function()
			if SB.Config.readOnly then return SB.L.SETTINGS_READONLY end
			return "ok"
		end)
		SB.Config.readOnly = true
		SW.Show("bags")
		click("Every free slot")
		assert.equal(SB.L.SETTINGS_READONLY, SW.lastStatus)
	end)

	-- Mutation: remove the SB_CONFIG_CHANGED listener in SettingsWindow.
	it("rows follow changes made outside the window (Config.Set, a typed command)", function()
		SW.Show("bags")
		assert.truthy(SW.selected[button("12")])
		SB.Config.Set("bags.columns", 16)
		assert.truthy(SW.selected[button("16")])
		assert.falsy(SW.selected[button("12")])
		SB.Slash.Register("free", "test", function(arg)
			SB.Config.Set("bags.freeTile", arg == "tile")
			return "x"
		end)
		SB.Slash.Dispatch("free all")
		assert.truthy(SW.selected[button("Every free slot")])
		SW.frame:Hide()
		SB.Config.Set("bags.columns", 10) -- closed: no redraw work
	end)

	it("re-showing the open page keeps its scroll; another page starts at the top", function()
		SW.Show("bags")
		SW.scroll:SetVerticalScroll(50)
		SW.Show("bags")
		assert.equal(50, SW.scroll:GetVerticalScroll())
		SW.Show("bank")
		assert.equal(0, SW.scroll:GetVerticalScroll())
	end)

	it("opens in combat, and creates only plain frames (never an item or secure button)", function()
		A.combat = true
		SW.Show("bank")
		SW.Show("overlays")
		SW.Show("bags")
		for _, f in ipairs(Fake.created) do
			assert.truthy(f.kind == "Frame" or f.kind == "Button" or f.kind == "ScrollFrame", f.kind)
			assert.falsy(tostring(f.template):find("Secure"), tostring(f.template))
		end
	end)

	it("rebuilding a page reuses its buttons (no new frames per click)", function()
		SW.Show("bags")
		local n = #Fake.created
		click("14")
		click("12")
		SW.Show("bank")
		SW.Show("bags")
		assert.equal(n, #Fake.created)
	end)
end)

describe("Settings window load order", function()
	it("loads before Config.Init without touching Config", function()
		local SB = Loader.New(Env.ENGINE)
		SB.Config.Get = function() error("Config.Get called while loading") end
		Fake.Install()
		local ok, err = pcall(function()
			Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
			Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		end)
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)
