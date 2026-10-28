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
		for _, name in ipairs({ "free", "stacks", "bank", "guild", "overlays", "ilvlcolors" }) do
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

	-- The button with this text in the row labelled rowLabel (several rows offer Show and Hide): the label sits on its
	-- row's line or the line above, so it is the nearest such button at or below the label.
	local function inRow(rowLabel, text)
		local function y(region)
			return region.points[#region.points][5]
		end
		local labelY
		for i = 1, SW.used.labels do
			if SW.labels[i].text == rowLabel then
				labelY = y(SW.labels[i])
			end
		end
		assert(labelY, "no row " .. rowLabel)
		local best
		for i = 1, SW.used.buttons do
			local b = SW.buttons[i]
			if b.text == text and y(b) <= labelY and (best == nil or y(b) > y(best)) then
				best = b
			end
		end
		return assert(best, "no button " .. text .. " in " .. rowLabel)
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
		assert.same({ "Bags", false }, b[4], "0.17: the per-bag view")
		assert.same({ "12", true }, b[5], "12 slots per row, the default, first")
	end)

	-- Mutation: in SettingsWindow's act(), drop SW.Say (the status line keeps the old text).
	it("P2: a choice with a chat command runs it and shows its answer", function()
		SW.Show("bags")
		click("Every free slot")
		assert.same({ "free all" }, ran)
		assert.equal("ran free all", SW.lastStatus)
	end)

	-- Stack grouping. Mutation: in the stacks row, apply = function(v) return run("stacks one") end.
	it("the stacks row runs /swagbag stacks", function()
		SW.Show("bags")
		click("Every stack")
		assert.same({ "stacks all" }, ran)
		assert.equal("ran stacks all", SW.lastStatus)
		SB.Slash.Register("stacks", "test", function(arg)
			return arg == "all" and SB.L.STACKS_MODE_ALL or SB.L.STACKS_MODE_ONE
		end)
		click("Every stack")
		assert.equal(SB.L.STACKS_MODE_ALL, SW.lastStatus)
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
		Fake.Fire(inRow(SB.L.SET_TOTALS, "Hide"), "OnClick")
		assert.same({ "bank beside", "guild view", "guild anytab on" }, ran)
		assert.equal(false, SB.Config.Get("prices.headerTotals"))
		assert.equal(1, refreshed)
	end)

	-- Week 13 Task 4. Mutation: delete the bank.show row from bankRows in SettingsPages.lua.
	it("Settings > Bank & guild has the choice", function()
		local L = SB.L
		SW.Show("bank")
		local found = false
		for i = 1, SW.used.labels do
			found = found or SW.labels[i].text == L.SET_BANK_SHOW
		end
		assert.truthy(found, "the row is labelled")
		assert.same({ L.SET_BANK_SHOW_ONE, true }, { button(L.SET_BANK_SHOW_ONE).text, SW.selected[button(L.SET_BANK_SHOW_ONE)] == true })
		click(L.SET_BANK_SHOW_BOTH)
		click(L.SET_BANK_SHOW_ONE)
		assert.same({ "bank both", "bank one" }, ran)
		assert.equal("ran bank one", SW.lastStatus)
	end)

	-- 0.14.2. Mutation: delete the Warband gold row from bankRows, or run "bank gold" with the wrong word.
	it("Settings > Bank & guild has Warband gold, Show first", function()
		local L = SB.L
		SW.Show("bank")
		local found = false
		for i = 1, SW.used.labels do
			found = found or SW.labels[i].text == L.SET_BANK_GOLD
		end
		assert.truthy(found, "the row is labelled")
		assert.equal("Warband gold in SwagBag's bank", L.SET_BANK_GOLD)
		assert.truthy(SW.selected[inRow(L.SET_BANK_GOLD, L.SET_SHOW)] == true, "Show is the default")
		Fake.Fire(inRow(L.SET_BANK_GOLD, L.SET_HIDE), "OnClick")
		Fake.Fire(inRow(L.SET_BANK_GOLD, L.SET_SHOW), "OnClick")
		assert.same({ "bank gold off", "bank gold on" }, ran)
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

	local function labelsOf(format)
		local n = 0
		for _, row in ipairs(SW.byId.overlays.rows()) do
			for i = 1, SB.IlvlColors.MAX do
				if row.label == format:format(i) then
					n = n + 1
				end
			end
		end
		return n
	end

	it("the overlays page shows level and color rows only while colors are on", function()
		local L = SB.L
		local lvl, col = L.SET_ILVL_LEVEL, L.SET_ILVL_COLOR
		assert.equal(0, labelsOf(lvl))
		assert.equal(0, labelsOf(col))
		SB.Config.Set("overlays.ilvlColors", true)
		SB.Config.Set("overlays.ilvlSteps", "680:green,690:blue,700:purple")
		assert.equal(4, labelsOf(lvl))
		assert.equal(3, labelsOf(col))
		SB.Config.Set("overlays.ilvlSteps", "")
		assert.equal(0, labelsOf(col))
		local notes = 0
		for _, row in ipairs(SW.byId.overlays.rows()) do
			if row.kind == "note" and row.label == L.ILVLCOLORS_SET_BY_HAND then
				notes = notes + 1
			end
		end
		assert.equal(1, notes, "empty steps while on: the note")
		SW.Show("overlays")
		Fake.Fire(inRow(L.SET_OV_ILVLCOLORS, "On"), "OnClick")
		assert.equal("ilvlcolors on", ran[#ran])
	end)

	it("a level row writes its step, empty removes it, a word is refused", function()
		local L = SB.L
		SB.Config.Set("overlays.ilvlColors", true)
		SB.Config.Set("overlays.ilvlSteps", "680:green,690:blue")
		local function row(i)
			for _, r in ipairs(SW.byId.overlays.rows()) do
				if r.label == L.SET_ILVL_LEVEL:format(i) then
					return r
				end
			end
		end
		local function colorRow(i)
			for _, r in ipairs(SW.byId.overlays.rows()) do
				if r.label == L.SET_ILVL_COLOR:format(i) then
					return r
				end
			end
		end
		assert.equal("680", row(1).get())
		assert.equal("", row(3).get())
		row(1).commit("685")
		assert.equal("685:green,690:blue", SB.Config.Get("overlays.ilvlSteps"))
		assert.equal(L.SET_ILVL_BAD, row(2).commit("high"))
		assert.equal(L.SET_ILVL_BAD, row(2).commit("0"))
		assert.equal(L.SET_ILVL_BAD, row(2).commit("100000"))
		assert.equal("685:green,690:blue", SB.Config.Get("overlays.ilvlSteps"))
		row(3).commit("700")
		assert.equal("685:green,690:blue,700:white", SB.Config.Get("overlays.ilvlSteps"))
		colorRow(3).apply("orange")
		assert.equal("685:green,690:blue,700:orange", SB.Config.Get("overlays.ilvlSteps"))
		assert.equal("orange", colorRow(3).get())
		row(1).commit("")
		assert.equal("690:blue,700:orange", SB.Config.Get("overlays.ilvlSteps"))
		SB.Config.readOnly = true
		assert.equal(L.SETTINGS_READONLY, row(1).commit("1"))
		assert.equal(L.SETTINGS_READONLY, colorRow(1).apply("gray"))
		assert.equal("690:blue,700:orange", SB.Config.Get("overlays.ilvlSteps"))
	end)

	-- P1: the default is the first choice. Mutation: build the bind row with onOff (On first) again.
	it("overlays page: Show BoE/WuE is Off first (its default); the others stay On first", function()
		SW.Show("overlays")
		local list = buttons()
		assert.equal("On", list[1][1])
		assert.same({ "Off", true }, list[13], "default Off: listed first and selected")
		assert.same({ "On", false }, list[14])
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

	-- Week 9 (user pick 10), P1. The TSM price row changes TSM's price only, never the source (preflight S7).
	-- Mutations: in the TSM price row's apply, run "price string" without the name; or run "price tsm " .. v.
	it("bank page: the price source rows, Auto and DBMarket first and selected; each choice runs /swagbag price", function()
		SB.Slash.Register("price", "test", function(arg)
			ran[#ran + 1] = "price " .. arg
			return "ran price " .. arg
		end)
		SW.Show("bank")
		assert.truthy(SW.selected[button(SB.L.SET_PRICE_AUTO)])
		assert.truthy(SW.selected[button("DBMarket")])
		click("TSM")
		click("DBMinBuyout")
		click(SB.L.SET_PRICE_VENDOR)
		assert.same({ "price tsm", "price string DBMinBuyout", "price vendor" }, ran)
	end)

	-- Week 9 (preflight S16), P1. Mutation: in the other bag addons row's apply, run "otherbags off" whatever the
	-- choice.
	it("bags page: the other bag addons row, Warn at login first and selected; each choice runs /swagbag otherbags", function()
		SB.Slash.Register("otherbags", "test", function(arg)
			ran[#ran + 1] = "otherbags " .. arg
			return "ran otherbags " .. arg
		end)
		SW.Show("bags")
		assert.truthy(SW.selected[button(SB.L.SET_OTHER_BAGS_WARN)])
		click(SB.L.SET_OTHER_BAGS_QUIET)
		click(SB.L.SET_OTHER_BAGS_WARN)
		assert.same({ "otherbags off", "otherbags on" }, ran)
		assert.equal("ran otherbags on", SW.lastStatus)
	end)

	-- Week 7 deferred: an amount typed in chat had no button. Mutation: drop the custom-amount choice from the
	-- worth row.
	it("bank page: a gold amount set with /swagbag worth shows as its own selected choice", function()
		SB.Config.Set("prices.worthGold", 250)
		SW.Show("bank")
		assert.truthy(SW.selected[button("250g or more")])
		assert.falsy(SW.selected[button("100g or more")])
	end)

	-- Final review (item 5; Task 6 minor): the typed amount's button follows the stored amount each time the page
	-- is drawn, and shows only while the glow is in that fixed mode (no unselected 250g next to "top" or "Off").
	-- Mutation: in worthChoices, drop `SB.Config.Get("prices.worth") == "fixed" and`.
	it("bank page: the typed amount's button shows the stored amount, only in the fixed mode", function()
		SB.Config.Set("prices.worthGold", 250)
		SB.Config.Set("prices.worth", "top")
		SW.Show("bank")
		assert.has_error(function() button("250g or more") end)
		SB.Config.Set("prices.worth", "off")
		SW.Show("bank")
		assert.has_error(function() button("250g or more") end)
		SB.Config.Set("prices.worth", "fixed")
		SB.Config.Set("prices.worthGold", 300)
		SW.Hide()
		SW.Show("bank")
		assert.truthy(SW.selected[button("300g or more")], "the stored amount, drawn again on show")
		assert.has_error(function() button("250g or more") end)
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

-- Forever Stage A, Task 3: no Settings row for an overlay WoW Forever leaves out.
describe("Settings window on WoW Forever", function()
	local SB, SW
	before_each(function()
		SB = Loader.New(Env.ENGINE, { flavor = "forever" })
		SB.Config.Init(nil, nil)
		Fake.Install()
		SB.BagsWindow = { View = function() return "category" end, SetView = function() end, SetScale = function() end,
			RequestLayout = function() end }
		Loader.LoadFile(SB, "SwagBag/UI/SettingsWindow.lua")
		Loader.LoadFile(SB, "SwagBag/UI/SettingsPages.lua")
		SW = SB.SettingsWindow
		SB.Categories.Load()
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- Mutation: overlayRows without the Allows filter.
	it("on Forever the Overlays page has no Upgrade track or Keystone row", function()
		local L, labels = SB.L, {}
		for _, row in ipairs(SW.byId.overlays.rows()) do
			labels[#labels + 1] = row.label
		end
		assert.same({ L.SET_OV_ILVL, L.SET_OV_ILVLCOLORS, L.SET_OV_UPGRADE, L.SET_OV_JUNK, L.SET_OV_BIND, L.SET_OV_LEARN, L.SET_OV_LOCK,
			L.SET_OV_UNCOLLECTED, L.SET_OV_PAWN }, labels)
	end)

	-- Forever Stage A, Task 4. Mutation: bankRows without the reason check.
	-- Review fix: the price rows drive the bags window too, so they stay. Mutation: the Forever list without them.
	it("on Forever Settings > Bank & guild shows the note and the price rows only", function()
		local L, labels = SB.L, {}
		SB.SafeMode.Enable("bank", "forever")
		for _, row in ipairs(SW.byId.bank.rows()) do
			labels[#labels + 1] = row.label
		end
		assert.same({ L.SET_BANK_FOREVER_NOTE, L.SET_TOTALS, L.SET_PRICE_SOURCE, L.SET_PRICE_TSM }, labels,
			"no bank, guild or gold-glow (SET_WORTH) rows")
		SB.SafeMode.Disable("bank") -- the opt-in (/swagbag safe bank): the rows come back
		assert.truthy(#SW.byId.bank.rows() > 1)
	end)
end)
