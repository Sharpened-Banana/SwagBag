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
		assert.same({ "List", false }, b[2])
		assert.same({ "Grid", false }, b[3])
		assert.same({ "12", true }, b[4], "12 slots per row, the default, first")
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

	-- Ruling W4-15. Mutation: delete the New row from bagsRows in SettingsPages.lua.
	it("the New row runs /swagbag new, hidden first (the default), always shown next to it", function()
		SB.Slash.Register("new", "test", function(arg)
			ran[#ran + 1] = "new " .. arg
			return "ran new " .. arg
		end)
		SW.Show("bags")
		assert.truthy(SW.selected[button("Hidden")])
		click("Always shown")
		assert.same({ "new always" }, ran)
		assert.equal("ran new always", SW.lastStatus)
	end)

	-- Week 5: the list view's order runs /swagbag list. Mutation: in the order row's apply, drop
	-- the saved column (run "list desc").
	it("the list rows run /swagbag list: a column in its natural direction; the order keeps the column", function()
		SB.Slash.Register("list", "test", function(arg)
			ran[#ran + 1] = "list " .. arg
			return "ran list " .. arg
		end)
		SW.Show("bags")
		assert.truthy(SW.selected[button("Value")], "value, the default, first")
		assert.truthy(SW.selected[button("Highest first")])
		click("Name")
		click("Lowest first")
		assert.same({ "list name", "list value asc" }, ran)
		assert.equal("ran list value asc", SW.lastStatus)
	end)

	it("overlays page: each overlay switches through /swagbag overlays", function()
		SW.Show("overlays")
		click("Off") -- the first row: item level on gear
		click("Pawn")
		assert.same({ "overlays ilvl off", "overlays pawn on" }, ran)
	end)

	-- P1: the default is the first choice. Mutation: build the bind row with onOff (On first) again.
	it("overlays page: Show BoE/WuE is Off first (its default); the others stay On first", function()
		SW.Show("overlays")
		local list = buttons()
		assert.equal("On", list[1][1])
		assert.same({ "Off", true }, list[11], "default Off: listed first and selected")
		assert.same({ "On", false }, list[12])
		click("Pawn")
	end)

	-- Week 7 (user pick 7), P1. Mutation: in the worth row's apply, run "worth top 10" whatever the setting.
	it("bank page: the gold glow row, 100g first and selected; each choice runs /swagbag worth", function()
		SB.Slash.Register("worth", "test", function(arg)
			ran[#ran + 1] = "worth " .. arg
			return "ran worth " .. arg
		end)
		SB.Config.Set("prices.worthTop", 15)
		SW.Show("bank")
		assert.truthy(SW.selected[button("100g or more")])
		click("500g or more")
		click("Your top 15%")
		assert.same({ "worth 500", "worth top 15" }, ran)
	end)

	-- Week 9 (user pick 8), P1. Mutation: in the sort row's apply, run "sort stacks" whatever the choice.
	it("bags page: the Sort button row, Blizzard's sort first and selected; each choice runs /swagbag sort", function()
		SB.Slash.Register("sort", "test", function(arg)
			ran[#ran + 1] = "sort " .. arg
			return "ran sort " .. arg
		end)
		SW.Show("bags")
		assert.truthy(SW.selected[button(SB.L.SET_SORT_BLIZZARD)])
		click(SB.L.SET_SORT_STACKS)
		click(SB.L.SET_SORT_BLIZZARD)
		assert.same({ "sort stacks", "sort blizzard" }, ran)
		assert.equal("ran sort blizzard", SW.lastStatus)
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

	-- A test page shaped like Settings > Alt data (O2 step 19: "Shown (not twice with Syndicator)"
	-- spilled out of its button and the next button was cut). Text is 6 px per character.
	local function wideRows()
		local create = CreateFrame
		CreateFrame = function(kind, name, parent, template)
			local f = create(kind, name, parent, template)
			if kind == "Button" then
				function f.GetTextWidth(self)
					return 6 * #(self.text or "")
				end
			end
			return f
		end
		SW.AddPage({ id = "wide", title = "Wide", rows = function()
			return {
				{ kind = "choice", label = "Counts", width = 190, tip = "What the row does.", get = function() return "auto" end,
					choices = { { value = "auto", text = "Shown (not twice with Syndicator)", tip = "The default." },
						{ value = "on", text = "Always shown" }, { value = "off", text = "Hidden" } },
					apply = function() return "done" end },
				{ kind = "note", label = "Below" },
			}
		end })
		SW.Show("wide")
	end

	local function topLeft(region)
		local p = region.points[#region.points]
		return { p[4], p[5] }
	end

	-- Week 6, D19. Mutations: size every button to the row's width only (no text width); drop the
	-- out-of-room line break.
	it("a button is as wide as its text plus padding; one that does not fit starts the next line", function()
		wideRows()
		local b1, b2, b3 = button("Shown (not twice with Syndicator)"), button("Always shown"), button("Hidden")
		assert.equal(6 * 33 + SW.TEXT_PAD, b1.w, "the long text fits its button")
		assert.equal(190, b2.w, "never narrower than the row's width")
		assert.same({ 12, -22 }, topLeft(b1))
		assert.same({ 12 + b1.w + 4, -22 }, topLeft(b2))
		assert.same({ 12, -22 - SW.ROW - SW.LINE_GAP }, topLeft(b3), "out of room: the next line")
		assert.same({ 4, -22 - SW.ROW - SW.LINE_GAP - SW.ROW - SW.GAP }, topLeft(SW.labels[2]),
			"the row grew: the note below moved down")
		assert.truthy(b2.w + topLeft(b2)[1] <= SW.child:GetWidth(), "nothing runs past the page")
	end)

	-- Week 6, D18. Mutations: in ShowTip, skip the item's own tip; in OnLeave, always Hide.
	it("a row's tip shows on its buttons with the button's own tip after it; leaving hides it", function()
		wideRows()
		local lines = {}
		GameTooltip = Fake.New("GameTooltip")
		function GameTooltip.SetText(_, t) lines[#lines + 1] = t end
		function GameTooltip.AddLine(_, t) lines[#lines + 1] = t end
		function GameTooltip.IsOwned(t, owner) return t.calls.SetOwner ~= nil and t.calls.SetOwner[1] == owner end
		Fake.Fire(button("Shown (not twice with Syndicator)"), "OnEnter")
		assert.same({ "Counts", "What the row does.", "The default." }, lines)
		GameTooltip:Show()
		Fake.Fire(button("Hidden"), "OnLeave")
		assert.truthy(GameTooltip.shown, "another button's leave leaves the tooltip alone")
		Fake.Fire(button("Shown (not twice with Syndicator)"), "OnLeave")
		assert.falsy(GameTooltip.shown)
		SW.Show("bags")
		lines = {}
		Fake.Fire(button("Categories"), "OnEnter")
		assert.same({}, lines, "a row without a tip shows none")
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
