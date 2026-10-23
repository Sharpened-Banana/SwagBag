-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The setup wizard (spec F7: AC7.1, AC7.2, AC7.4; week 12, from the quick setup screen): when it shows, its four
-- steps, Finish / Skip / later, read-only, combat. What each style sets is spec/setup_spec.lua.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Quick setup", function()
	local SB, A, QS, bags
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		files[#files + 1] = "SwagBag/Engine/Setup.lua"
		SB = Loader.New(files)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
		Fake.Install()
		bags = { layouts = 0, open = false }
		function bags.IsOpen() return bags.open end
		function bags.RequestLayout() bags.layouts = bags.layouts + 1 end
		function bags.RefreshTitle() end
		SB.BagsWindow = bags
		Loader.LoadFile(SB, "SwagBag/UI/QuickSetup.lua")
		QS = SB.QuickSetup
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	local function login()
		SB.Emit("SB_LOGIN")
		A.Advance(3)
	end

	local function pick(id)
		Fake.Fire(QS.styleButtons[id], "OnClick")
	end

	-- Next until the wizard is at step n (week 12).
	local function step(n)
		while QS.step < n do
			Fake.Fire(QS.nextButton, "OnClick")
		end
	end

	local function finishWizard()
		step(4)
		Fake.Fire(QS.finishButton, "OnClick")
	end

	-- The shown step-2 button with this text.
	local function switch(text)
		for _, b in ipairs(QS.switchButtons) do
			if b.shown and b.text == text then
				return b
			end
		end
		error("no switch " .. text)
	end

	it("shows a few seconds after the first login; not again once applied or skipped", function()
		SB.Emit("SB_LOGIN")
		assert.falsy(QS.IsOpen(), "not during the loading screen")
		A.Advance(3)
		assert.truthy(QS.IsOpen())
		Fake.Fire(QS.skipButton, "OnClick")
		login()
		assert.falsy(QS.IsOpen())
	end)

	it("does not show with read-only settings or while the bags are in Safe Mode", function()
		SB.Config.readOnly = true
		login()
		assert.falsy(QS.IsOpen())
		SB.Config.readOnly = false
		SB.SafeMode.Enable("bags", "manual")
		login()
		assert.falsy(QS.IsOpen())
	end)

	-- AC7.1 (week 12). Mutation: in QS.Paint, `QS.finishButton:SetShown(QS.step == QS.STEPS)` ->
	-- `QS.finishButton:SetShown(true)`.
	it("AC7.1: four steps, one screen each: Back, Next and Skip on the way, Finish on the last; nothing saved before", function()
		login()
		local seen = {}
		for n = 1, 4 do
			step(n)
			seen[n] = QS.frame.stepLabel.text
			assert.truthy(QS.frame.steps[n].shown, "step " .. n)
			for m = 1, 4 do
				assert.equal(m == n, QS.frame.steps[m].shown == true, "only step " .. n .. " is shown")
			end
			assert.equal(n > 1, QS.backButton.shown, "Back on step " .. n)
			assert.equal(n < 4, QS.nextButton.shown, "Next on step " .. n)
			assert.equal(n == 4, QS.finishButton.shown, "Finish on step " .. n)
			assert.truthy(QS.skipButton.shown, "Skip on step " .. n)
		end
		assert.same({ "Step 1 of 4: What do you play?", "Step 2 of 4: What that turns on",
			"Step 3 of 4: How your bags look", "Step 4 of 4: Gold" }, seen)
		Fake.Fire(QS.backButton, "OnClick")
		assert.equal(3, QS.step)
		assert.same({}, SB.Config.db.settings, "nothing is written before Finish")
		assert.same({}, A.Lines())
	end)

	-- Mutation: remove `C.Set("setup.done", true)` from Setup.Finish.
	it("Finish sets each picked style's preset and the slots per row, says what it did, and closes", function()
		login()
		pick("mplus")
		pick("gold")
		step(3)
		Fake.Fire(QS.columnButtons[14], "OnClick")
		bags.open = true
		finishWizard()
		assert.falsy(QS.IsOpen())
		assert.equal(true, SB.Config.Get("setup.done"))
		assert.equal(14, SB.Config.Get("bags.columns"))
		assert.equal(true, SB.Config.Get("prices.headerTotals"))
		assert.same({ "c_keystone", "c_tradegoods", "c_boe" },
			{ SB.Config.db.categoryOrder[1], SB.Config.db.categoryOrder[2], SB.Config.db.categoryOrder[3] })
		assert.equal("c_tradegoods", SB.Categories.SectionOrder()[3], "the categories follow at once")
		assert.equal(1, bags.layouts, "the open bags regroup")
		assert.same({ "Set up for M+, Gold-making. Change anything later: type /swagbag."
			.. " Settings are saved when you log out or /reload." }, A.Lines()) -- Y14
	end)

	-- Week 11 final fix 1. Mutation: in Setup.Finish, drop the Profiles.CategoriesChanged call (a profile Undo would then
	-- put an imported string's category order back over the order quick setup wrote).
	it("Finish's new category order drops the categories from the profiles' one step of undo", function()
		local told = 0
		SB.Profiles = { CategoriesChanged = function()
			told = told + 1
		end }
		login()
		pick("mplus")
		pick("gold")
		finishWizard()
		assert.equal("table", type(SB.Config.db.categoryOrder))
		assert.equal(1, told)
	end)

	it("AC7.2: Skip keeps the defaults, says so, and closes", function()
		login()
		Fake.Fire(QS.skipButton, "OnClick")
		assert.falsy(QS.IsOpen())
		assert.equal(true, SB.Config.Get("setup.done"))
		assert.same({ SB.L.QS_SKIPPED }, A.Lines())
		assert.equal(12, SB.Config.Get("bags.columns"))
	end)

	-- Mutation: set setup.done in the OnHide handler.
	it("Esc or the X is \"later\": nothing is saved, it says so, and it shows at the next login", function()
		login()
		QS.frame:Hide()
		assert.same({ SB.L.QS_LATER }, A.Lines())
		assert.equal(false, SB.Config.Get("setup.done"))
		login()
		assert.truthy(QS.IsOpen())
	end)

	-- Mutation: write categoryOrder before the readOnly check.
	it("read-only settings: Finish and Skip refuse with the reason and change nothing", function()
		QS.Show()
		pick("raid")
		pick("gold")
		pick("collector")
		SB.Config.readOnly = true
		finishWizard()
		Fake.Fire(QS.skipButton, "OnClick")
		assert.same({ SB.L.SETTINGS_READONLY, SB.L.SETTINGS_READONLY }, A.Lines())
		assert.truthy(QS.IsOpen())
		assert.is_nil(SB.Config.db.settings.focus)
		assert.is_nil(SB.Config.db.categoryOrder, "the category order is not written")
		assert.equal(false, SB.Config.Get("setup.done"))
		assert.equal(12, SB.Config.Get("bags.columns"))
	end)

	-- Mutation: make follow() not run under its own ErrorTrap.Run.
	it("a refresh error after a successful Finish still reports success, with a note", function()
		QS.Show()
		pick("mplus")
		bags.open = true
		function bags.RequestLayout() error("layout boom") end
		finishWizard()
		assert.equal(true, SB.Config.Get("setup.done"))
		assert.falsy(QS.IsOpen())
		assert.same({ SB.L.QS_APPLIED:format("M+") .. " " .. SB.L.QS_REFRESH_NOTE }, A.Lines())
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	-- Mutation: always print L.QS_LATER from OnHide.
	it("Esc after setup is done does not promise it comes back at the next login", function()
		SB.Config.Set("setup.done", true)
		SB.Slash.Dispatch("setup")
		QS.frame:Hide()
		local lines = A.Lines()
		assert.equal(SB.L.QS_LATER_KEPT, lines[#lines])
		assert.falsy(SB.L.QS_LATER_KEPT:find("next login", 1, true))
	end)

	-- Mutation: drop the combat / instance check in QS.TryShow, or the retry handlers.
	it("W4-21: login in combat waits for combat to end", function()
		A.combat = true
		login()
		assert.falsy(QS.IsOpen())
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.truthy(QS.IsOpen())
	end)

	it("W4-21: login in an instance waits until the player leaves it", function()
		A.instance = { instanceType = "party", difficultyID = 8 }
		login()
		assert.falsy(QS.IsOpen())
		A.instance = {}
		SB.eventFrame:Fire("PLAYER_ENTERING_WORLD")
		assert.truthy(QS.IsOpen())
	end)

	it("W4-21: /swagbag setup opens at once in combat", function()
		A.combat = true
		SB.Slash.Dispatch("setup")
		assert.truthy(QS.IsOpen())
	end)

	it("AC7.4: /swagbag setup shows it again (P2)", function()
		SB.Slash.Dispatch("setup")
		assert.truthy(QS.IsOpen())
		assert.same({ SB.L.QS_OPENED }, A.Lines())
	end)

	-- Week 6, D18. Mutation: delete the pauseNote SetText.
	it("explains the bags' Pause button in one line", function()
		SB.Slash.Dispatch("setup")
		assert.equal(SB.L.QS_PAUSE_NOTE, QS.frame.pauseNote.text)
		assert.truthy(QS.frame.pauseNote.shown)
	end)

	it("a picked style shows as picked; a second click unpicks it", function()
		QS.Show()
		pick("raid")
		assert.equal("|cff44ff44Raid|r", QS.styleButtons.raid.text)
		pick("raid")
		assert.equal("Raid", QS.styleButtons.raid.text)
	end)

	-- Mutation: make Skip always answer with L.QS_SKIPPED.
	it("Skip on a re-run (setup already done) says it keeps the current settings", function()
		SB.Config.Set("setup.done", true)
		SB.Slash.Dispatch("setup")
		Fake.Fire(QS.skipButton, "OnClick")
		assert.same({ SB.L.QS_OPENED, SB.L.QS_SKIPPED_KEPT }, A.Lines())
		assert.truthy(SB.L.QS_SKIPPED_KEPT:find("current settings", 1, true))
		assert.falsy(QS.IsOpen())
	end)

	-- Mutation: call fn bare in finish() (no ErrorTrap.Run), or give it window "bags".
	it("W4-6: an error in Finish says SETTINGS_FAILED on the status line and in chat, and never trips Safe Mode", function()
		QS.Show()
		pick("mplus")
		SB.Config.Set = function() error("boom") end
		finishWizard()
		assert.equal(SB.L.SETTINGS_FAILED, QS.frame.status.text)
		assert.same({ SB.L.SETTINGS_FAILED }, A.Lines())
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.truthy(QS.IsOpen(), "the screen stays so the user can retry or Skip")
	end)

	-- AC9.2 on screen (week 12). Mutation: in paintStep2, `local on = value(key) == true` -> `local on = true`.
	it("step 2 lists every focus mode and what the picks switch, each with its state; a click switches it", function()
		SB.Config.Set("overlays.upgrade", false)
		QS.Show()
		pick("mplus")
		step(2)
		assert.truthy(switch("M+ mode: On"))
		assert.truthy(switch("AH/Vendor/Bank mode: On"))
		assert.truthy(switch("Upgrade arrow on gear: On"), "M+ switches the arrow on")
		local shown = 0
		for _, b in ipairs(QS.switchButtons) do
			if b.shown then
				shown = shown + 1
			end
		end
		assert.equal(12, shown, "Switch by themselves, six modes and M+'s five switches")
		Fake.Fire(switch("Upgrade arrow on gear: On"), "OnClick")
		assert.truthy(switch("Upgrade arrow on gear: Off"))
		Fake.Fire(switch("Fishing mode: On"), "OnClick")
		assert.falsy(QS.lit[switch("Fishing mode: Off")])
		assert.truthy(QS.lit[switch("Keystone level and dungeon: On")])
		assert.is_nil(SB.Config.db.settings.focus, "still nothing written")
		finishWizard()
		assert.equal(false, SB.Config.Get("overlays.upgrade"))
		assert.equal(false, SB.Config.Get("focus.on.fishing"))
		assert.equal(true, SB.Config.db.settings.overlays.keystone, "written, though it is the default (AC9.2)")
	end)

	-- 0.14.3. Mutation: Setup.Preset sets "focus.auto" for a picked style (Finish would write it), or paintStep2 shows it On.
	it("step 2 shows Switch by themselves Off even with M+ picked; Finish leaves it unwritten unless clicked", function()
		QS.Show()
		pick("mplus")
		step(2)
		assert.truthy(switch("Focus modes switch by themselves: Off"))
		assert.truthy(switch("M+ mode: On"))
		finishWizard()
		assert.equal(false, SB.Config.Get("focus.auto"))
		assert.is_nil(SB.Config.db.settings.focus.auto, "not written: the user did not switch it")
		QS.Show()
		step(2)
		Fake.Fire(switch("Focus modes switch by themselves: Off"), "OnClick")
		assert.truthy(switch("Focus modes switch by themselves: On"))
		finishWizard()
		assert.equal(true, SB.Config.Get("focus.auto"))
	end)

	-- AC7.4 (week 12). Mutation: in QS.Show, `QS.draft, QS.step, QS.combatHidden = Setup.New(), 1, false` ->
	-- `QS.draft, QS.step, QS.combatHidden = QS.draft or Setup.New(), 1, false`.
	it("AC7.4: /swagbag setup starts from the settings as they are: last time's styles, the layout, the gold", function()
		SB.Config.Set("setup.done", true)
		SB.Config.Set("setup.styles", "gold")
		SB.Config.Set("bags.columns", 16)
		SB.Config.Set("bags.scale", 0.9)
		SB.Config.Set("prices.worthGold", 500)
		SB.Config.Set("vendor.autoSell", false)
		QS.Show()
		pick("raid")
		QS.frame:Hide()
		SB.Slash.Dispatch("setup")
		assert.truthy(QS.lit[QS.styleButtons.gold])
		assert.falsy(QS.lit[QS.styleButtons.raid], "what was picked but not finished is gone")
		step(3)
		assert.truthy(QS.lit[QS.columnButtons[16]])
		assert.falsy(QS.lit[QS.columnButtons[12]])
		assert.truthy(QS.lit[QS.scaleButtons[0.9]])
		step(4)
		assert.truthy(QS.lit[QS.worthButtons[500]])
		assert.falsy(QS.lit[QS.worthButtons[100]])
		assert.truthy(QS.lit[QS.sellButtons[false]])
		assert.falsy(QS.worthButtons.top.shown)
	end)

	-- Mutation: in pricesLine, `if source and source ~= "Vendor" then` -> `if source then`.
	it("step 4 says where prices come from (an auction addon found, or a vendor's price); its choices are saved", function()
		QS.Show()
		step(4)
		assert.equal(SB.L.WIZ_PRICES_VENDOR, QS.frame.prices.text)
		A.auctionator = { prices = {} }
		SB.Prices.Invalidate()
		QS.Show()
		step(4)
		assert.equal("SwagBag found Auctionator: your items' prices come from it.", QS.frame.prices.text)
		Fake.Fire(QS.worthButtons.off, "OnClick")
		Fake.Fire(QS.sellButtons[false], "OnClick")
		assert.truthy(QS.lit[QS.worthButtons.off])
		Fake.Fire(QS.finishButton, "OnClick")
		assert.equal("off", SB.Config.Get("prices.worth"))
		assert.equal(false, SB.Config.Get("vendor.autoSell"))
	end)

	-- Mutation: in paintStep3, `if T.Available(id) or id == value("theme.name") then` -> `if true then`.
	it("step 3 offers the looks whose addon is loaded; Finish switches the look and the open bags' size", function()
		local applied = {}
		SB.Theme = { order = { "blizzard", "flat", "elvui" }, Button = function() end,
			Name = function(id) return ({ blizzard = "Blizzard", flat = "Flat", elvui = "ElvUI" })[id] end,
			Available = function(id) return id ~= "elvui" end,
			Apply = function(id, save) applied[#applied + 1] = { id, save } return true end }
		local scaled = {}
		function bags.SetScale(v, quiet) scaled[#scaled + 1] = { v, quiet } end
		QS.Show()
		step(3)
		assert.truthy(QS.lookButtons.blizzard.shown)
		assert.truthy(QS.lit[QS.lookButtons.blizzard])
		assert.is_nil(QS.lookButtons.elvui, "a look whose addon is not loaded is not offered")
		Fake.Fire(QS.lookButtons.flat, "OnClick")
		Fake.Fire(QS.scaleButtons[1.1], "OnClick")
		bags.open = true
		finishWizard()
		assert.equal("flat", SB.Config.Get("theme.name"))
		assert.same({ { "flat", false } }, applied)
		assert.same({ { 1.1, true } }, scaled)
	end)

	-- A user of the quick setup (week 11 and before) is never shown the wizard by itself. Mutation: in QS.TryShow,
	-- `if SB.SafeMode.IsOn("bags") or SB.Config.readOnly or SB.Config.Get("setup.done") then` ->
	-- `if SB.SafeMode.IsOn("bags") or SB.Config.readOnly then`.
	it("setup done (a week-11 save, or done while it waited in an instance): never shown by itself again", function()
		SB.Config.Init({ schemaVersion = 2, settings = { setup = { done = true }, bags = { columns = 14 } } }, nil)
		login()
		assert.falsy(QS.IsOpen())
		SB.Config.Init(nil, nil)
		A.instance = { instanceType = "party", difficultyID = 8 }
		login()
		SB.Slash.Dispatch("setup")
		Fake.Fire(QS.skipButton, "OnClick")
		A.instance = {}
		SB.eventFrame:Fire("PLAYER_ENTERING_WORLD")
		assert.falsy(QS.IsOpen(), "the wait for leaving the instance does not bring it back")
		assert.same({ SB.L.QS_OPENED, SB.L.QS_SKIPPED }, A.Lines())
	end)

	-- Mutation: in the PLAYER_REGEN_DISABLED handler, drop `QS.Close("combat")`.
	it("combat starts while it is open: it steps aside, says so once, and comes back as it was when combat ends", function()
		QS.Show()
		pick("gold")
		step(3)
		Fake.Fire(QS.columnButtons[10], "OnClick")
		A.combat = true
		SB.eventFrame:Fire("PLAYER_REGEN_DISABLED")
		assert.falsy(QS.IsOpen())
		assert.same({ SB.L.WIZ_COMBAT_HIDDEN }, A.Lines())
		assert.equal("Setup steps aside during the fight; it comes back where you were when combat ends.",
			SB.L.WIZ_COMBAT_HIDDEN)
		assert.same({}, SB.Config.db.settings, "nothing is saved")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.truthy(QS.IsOpen())
		assert.equal(3, QS.step)
		assert.truthy(QS.lit[QS.columnButtons[10]])
		assert.truthy(QS.draft.styles.gold)
		A.combat = true -- Finish in combat (opened or kept open by the user): plain frames, the settings are saved
		finishWizard()
		assert.equal(10, SB.Config.Get("bags.columns"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.falsy(QS.IsOpen())
	end)

	-- Y4. Mutations: in the PLAYER_REGEN_ENABLED handler, drop the `if not inInstance() then` guard; in the
	-- PLAYER_ENTERING_WORLD handler, drop its `not inInstance()` check; in the "setup" slash handler, always QS.Show().
	it("combat inside an instance: it stays away when combat ends, and comes back as it was when you leave", function()
		A.instance = { instanceType = "party", difficultyID = 8 }
		QS.Show()
		pick("gold")
		step(3)
		Fake.Fire(QS.columnButtons[16], "OnClick")
		A.combat = true
		SB.eventFrame:Fire("PLAYER_REGEN_DISABLED")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.falsy(QS.IsOpen(), "not over the run")
		SB.eventFrame:Fire("PLAYER_ENTERING_WORLD")
		assert.falsy(QS.IsOpen(), "still inside")
		A.instance = {}
		SB.eventFrame:Fire("PLAYER_ENTERING_WORLD")
		assert.truthy(QS.IsOpen())
		assert.equal(3, QS.step)
		assert.truthy(QS.lit[QS.columnButtons[16]])
		assert.truthy(QS.draft.styles.gold)
		assert.same({ SB.L.WIZ_COMBAT_HIDDEN_RUN }, A.Lines(), "one line, once")
		assert.equal("Setup steps aside during the fight; it comes back where you were when you leave the instance."
			.. " Type /swagbag setup to bring it back sooner.", SB.L.WIZ_COMBAT_HIDDEN_RUN)
	end)

	it("combat inside an instance: /swagbag setup resumes the kept draft; outside, combat ending brings it back", function()
		A.instance = { instanceType = "raid", difficultyID = 16 }
		QS.Show()
		pick("raid")
		step(2)
		A.combat = true
		SB.eventFrame:Fire("PLAYER_REGEN_DISABLED")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.falsy(QS.IsOpen())
		SB.Slash.Dispatch("setup")
		assert.truthy(QS.IsOpen())
		assert.equal(2, QS.step, "the kept draft, not a fresh one")
		assert.truthy(QS.draft.styles.raid)
		A.instance = {}
		A.combat = true
		SB.eventFrame:Fire("PLAYER_REGEN_DISABLED")
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.truthy(QS.IsOpen(), "outside an instance: back when combat ends")
	end)

	-- Gold glow visibility. Mutation: in paintStep4, `value("prices.worth")` -> `SB.Config.Get("prices.worth")`.
	it("step 4: Gold would switch the gold glow on, and shows it; choosing Off there writes Off, with no amount", function()
		SB.Config.Set("prices.worth", "off")
		SB.Config.Set("prices.worthGold", 250)
		QS.Show()
		pick("gold")
		step(4)
		assert.falsy(QS.lit[QS.worthButtons.off], "Off is not the draft's choice any more")
		assert.equal("fixed", SB.Setup.Value(QS.draft, "prices.worth"))
		Fake.Fire(QS.worthButtons[500], "OnClick")
		assert.truthy(QS.lit[QS.worthButtons[500]])
		Fake.Fire(QS.worthButtons.off, "OnClick")
		assert.truthy(QS.lit[QS.worthButtons.off])
		assert.falsy(QS.lit[QS.worthButtons[500]])
		Fake.Fire(QS.finishButton, "OnClick")
		assert.equal("off", SB.Config.Get("prices.worth"))
		assert.equal(250, SB.Config.Get("prices.worthGold"), "Y6: the amount picked and then dropped is not written")
	end)

	it("step 4: Gold alone lights the glow's amount, and Finish writes the glow as fixed", function()
		SB.Config.Set("prices.worth", "off")
		QS.Show()
		pick("gold")
		step(4)
		assert.truthy(QS.lit[QS.worthButtons[100]], "the amount is pre-selected")
		assert.falsy(QS.lit[QS.worthButtons.off])
		Fake.Fire(QS.finishButton, "OnClick")
		assert.equal("fixed", SB.Config.Get("prices.worth"))
	end)

	-- Review fix 2. Mutation: QS frame `frame:SetSize(580, 400)` -> `frame:SetSize(580, 360)`.
	it("step 2 with every style picked: the lowest row ends above the status line", function()
		QS.Show()
		for _, s in ipairs(QS.STYLES) do
			pick(s.id)
		end
		step(2)
		local lowest, rows = 0, 0
		for _, b in ipairs(QS.switchButtons) do
			if b.shown then
				rows = rows + 1
				local y = -b.points[1][5] -- below the step panel's top
				lowest = math.max(lowest, 60 + y + b.h) -- the panel starts 60 below the frame's top
			end
		end
		assert.truthy(rows >= 17, "six modes and the picks' switches")
		local statusBottom = 44 -- status: anchored 44 above the frame's bottom, up to two lines (24) tall
		assert.truthy(lowest <= QS.frame.h - statusBottom - 24, lowest .. " vs " .. QS.frame.h)
	end)

	-- Review fix 3. Mutation: in QS.Paint, drop the skipButton:SetText line.
	it("Skip says what it keeps: the defaults on a first run, your settings on a re-run", function()
		QS.Show()
		assert.equal("Skip (use defaults)", QS.skipButton.text)
		assert.equal("Nothing is saved until Finish. Skip keeps SwagBag's defaults.", QS.frame.status.text)
		SB.Config.Set("setup.done", true)
		QS.Show()
		assert.equal("Skip (keep my settings)", QS.skipButton.text)
		assert.equal("Nothing is saved until Finish. Skip keeps your current settings.", QS.frame.status.text)
		step(2)
		assert.equal("Nothing is saved until Finish. Skip keeps your current settings.", QS.frame.status.text)
	end)

	-- Review fix 4. Mutation: in Setup.Switches, drop the `not m.custom and not m.id:match("^m_")` test.
	it("step 2 lists the built-in modes only, not the user's own", function()
		table.insert(SB.Focus.MODES, { id = "m_farming", class = "activity", name = "MODE_MPLUS", custom = true })
		QS.Show()
		step(2)
		for _, b in ipairs(QS.switchButtons) do
			assert.falsy(b.shown and b.key == "focus.on.m_farming")
		end
		local shown = 0
		for _, b in ipairs(QS.switchButtons) do
			shown = shown + (b.shown and 1 or 0)
		end
		assert.equal(7, shown, "Switch by themselves and the six built-in modes")
		table.remove(SB.Focus.MODES)
	end)

	-- AC7.3 (week 12). Mutation: in finish(), drop `QS.offer:Show()`.
	it("after Finish the tour is offered once: Show me around starts it, No thanks or Esc say how to get it later", function()
		local started = 0
		SB.Tour = { Start = function()
			started = started + 1
			return "TOUR STARTED"
		end }
		QS.Show()
		finishWizard()
		assert.falsy(QS.IsOpen())
		assert.truthy(QS.offer.shown)
		Fake.Fire(QS.tourButton, "OnClick")
		assert.falsy(QS.offer.shown)
		assert.equal(1, started)
		assert.same({ SB.L.WIZ_DONE_NONE, "TOUR STARTED" }, A.Lines())
		QS.Show()
		finishWizard()
		Fake.Fire(QS.noTourButton, "OnClick")
		QS.Show()
		finishWizard()
		QS.offer:Hide() -- Esc
		QS.Show()
		Fake.Fire(QS.skipButton, "OnClick")
		assert.falsy(QS.offer.shown, "Skip offers nothing")
		local lines = A.Lines()
		assert.same({ SB.L.WIZ_DONE_NONE, SB.L.WIZ_TOUR_LATER, SB.L.WIZ_DONE_NONE, SB.L.WIZ_TOUR_LATER,
			SB.L.QS_SKIPPED_KEPT }, { lines[3], lines[4], lines[5], lines[6], lines[7] })
		assert.equal(1, started)
	end)

	-- Mutation: in finish(), drop `and not SB.Adapter.InCombat()`.
	it("no tour offer in combat; combat starting while it is offered takes it away, with how to get it later", function()
		SB.Tour = { Start = function() return "TOUR STARTED" end }
		A.combat = true
		SB.Slash.Dispatch("setup")
		finishWizard()
		assert.falsy(QS.offer.shown)
		A.combat = false
		QS.Show()
		finishWizard()
		assert.truthy(QS.offer.shown)
		A.combat = true
		SB.eventFrame:Fire("PLAYER_REGEN_DISABLED")
		assert.falsy(QS.offer.shown)
		local lines = A.Lines()
		assert.equal(SB.L.WIZ_TOUR_LATER, lines[#lines])
	end)

	-- Final review. Mutation: in finish(), drop `and not inInstance()`.
	it("no tour offer when Finish runs inside an instance", function()
		SB.Tour = { Start = function() return "TOUR STARTED" end }
		A.instance = { instanceType = "party", difficultyID = 8 }
		QS.Show()
		finishWizard()
		assert.falsy(QS.IsOpen())
		assert.falsy(QS.offer.shown)
		A.instance = {}
		QS.Show()
		finishWizard()
		assert.truthy(QS.offer.shown)
	end)

	-- Final review. Mutation: in QS.Show, drop `QS.AnswerOffer()` (the offer's Hide says "later" on top of the wizard).
	it("/swagbag setup while the tour is offered answers the offer: it goes, with no 'later' line", function()
		SB.Tour = { Start = function() return "TOUR STARTED" end }
		QS.Show()
		finishWizard()
		assert.truthy(QS.offer.shown)
		local before = #A.Lines()
		SB.Slash.Dispatch("setup")
		assert.falsy(QS.offer.shown)
		assert.truthy(QS.IsOpen())
		for i = before + 1, #A.Lines() do
			assert.falsy(A.Lines()[i] == SB.L.WIZ_TOUR_LATER)
		end
		assert.is_nil(QS.offerAnswered, "the flag is spent by the hide")
	end)

	-- Final review. Mutation: in AnswerOffer, drop `QS.offerAnswered = true`.
	it("AnswerOffer (the tour started by its command) hides the offer without the 'later' line; nothing offered, nothing done", function()
		SB.Tour = { Start = function() return "TOUR STARTED" end }
		QS.AnswerOffer()
		assert.same({}, A.Lines())
		QS.Show()
		finishWizard()
		local before = #A.Lines()
		QS.AnswerOffer()
		assert.falsy(QS.offer.shown)
		assert.equal(before, #A.Lines())
	end)

	-- Final review. Mutation: in QS.TryShow, drop the `frame:IsShown() or QS.combatHidden` early return.
	it("first run waiting, then the user opened /swagbag setup: a later zone change leaves the open draft alone", function()
		A.instance = { instanceType = "party", difficultyID = 8 }
		login()
		assert.truthy(QS.waiting)
		SB.Slash.Dispatch("setup")
		assert.falsy(QS.waiting, "opening it clears the wait")
		pick("gold")
		step(2)
		A.instance = {}
		SB.eventFrame:Fire("PLAYER_ENTERING_WORLD")
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.equal(2, QS.step)
		assert.truthy(QS.draft.styles.gold)
		QS.waiting = true -- even a wait left behind
		QS.TryShow()
		assert.equal(2, QS.step)
		assert.truthy(QS.draft.styles.gold)
	end)

	-- Controller ruling Y7. Mutation: in finish(), drop `and not SB.SafeMode.IsOn("bags")`.
	it("no tour offer while the bags are in Safe Mode (the tour would only refuse)", function()
		SB.Tour = { Start = function() return "TOUR STARTED" end }
		SB.SafeMode.Enable("bags", "manual")
		QS.Show()
		finishWizard()
		assert.falsy(QS.IsOpen())
		assert.falsy(QS.offer.shown)
		SB.SafeMode.Disable("bags")
		QS.Show()
		finishWizard()
		assert.truthy(QS.offer.shown)
	end)

	it("only plain frames", function()
		for _, f in ipairs(Fake.created) do
			assert.truthy(f.kind == "Frame" or f.kind == "Button", f.kind)
		end
	end)
end)

describe("Quick setup load order", function()
	-- Mutation: call SB.Config.Get at the top level of UI/QuickSetup.lua.
	it("loads before Config.Init without touching Config", function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		files[#files + 1] = "SwagBag/Engine/Setup.lua"
		local SB = Loader.New(files)
		Fake.Install()
		SB.Config.Get = function() error("Config.Get called at load time") end
		local ok, err = pcall(Loader.LoadFile, SB, "SwagBag/UI/QuickSetup.lua")
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)

-- Forever Stage A, Task 3: the wizard offers no M+ style on WoW Forever.
describe("Quick setup on WoW Forever", function()
	local SB
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		files[#files + 1] = "SwagBag/Engine/Setup.lua"
		SB = Loader.New(files, { flavor = "forever" })
		SB.Config.Init(nil, nil)
		Fake.Install()
		SB.BagsWindow = { IsOpen = function() return false end, RequestLayout = function() end,
			RefreshTitle = function() end }
		Loader.LoadFile(SB, "SwagBag/UI/QuickSetup.lua")
	end)

	after_each(function()
		Fake.Uninstall()
	end)

	-- Mutation: QS.STYLES = Setup.STYLES.
	it("on Forever the wizard shows four style buttons", function()
		local QS, ids = SB.QuickSetup, {}
		for _, s in ipairs(QS.STYLES) do
			ids[#ids + 1] = s.id
		end
		assert.same({ "raid", "gold", "casual", "collector" }, ids)
		local buttons = 0
		for _ in pairs(QS.styleButtons) do
			buttons = buttons + 1
		end
		assert.equal(4, buttons)
		assert.is_nil(QS.styleButtons.mplus)
	end)
end)
