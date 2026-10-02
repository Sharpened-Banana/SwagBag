-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- The quick setup screen (spec 12.1 "one-screen quick setup (playstyle -> preset)"; AC7.2,
-- AC7.4): when it shows, what each style sets, Apply / Skip / later, read-only.
local Loader = dofile("spec/helpers/loader.lua")
local Fake = dofile("spec/helpers/fakeframe.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Quick setup", function()
	local SB, A, QS, bags
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
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

	-- Mutation: drop the `not picked.mplus and not picked.raid` guard on Casual.
	it("presets: M+ and Raid switch things on; Casual alone switches the warning and the track off", function()
		assert.same({ { "focus.on.mplus", true }, { "consumables.warn", true }, { "overlays.keystone", true },
			{ "overlays.track", true } }, QS.Preset({ mplus = true }))
		assert.same({ { "consumables.warn", false }, { "overlays.track", false } }, QS.Preset({ casual = true }))
		assert.same(QS.Preset({ mplus = true }), QS.Preset({ mplus = true, casual = true }))
		assert.same({ { "prices.headerTotals", true } }, QS.Preset({ gold = true }))
	end)

	it("Gold moves Trade Goods and BoE gear up after Keystone & Crests; Collector moves the collectibles", function()
		local display = { "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_collect", "c_other" }
		assert.same({ "c_keystone", "c_tradegoods", "c_boe", "c_collect", "c_consumables", "c_gear", "c_other" },
			QS.Order(display, { gold = true, collector = true }))
		assert.is_nil(QS.Order(display, { mplus = true }))
	end)

	it("Apply with nothing picked asks for a pick and stays open", function()
		login()
		Fake.Fire(QS.applyButton, "OnClick")
		assert.truthy(QS.IsOpen())
		assert.equal(SB.L.QS_PICK_FIRST, QS.frame.status.text)
		assert.equal(false, SB.Config.Get("setup.done"))
	end)

	-- Mutation: remove `C.Set("setup.done", true)` from Apply.
	it("Apply sets each picked style's preset and the slots per row, says what it did, and closes", function()
		login()
		pick("mplus")
		pick("gold")
		Fake.Fire(QS.columnButtons[14], "OnClick")
		bags.open = true
		Fake.Fire(QS.applyButton, "OnClick")
		assert.falsy(QS.IsOpen())
		assert.equal(true, SB.Config.Get("setup.done"))
		assert.equal(14, SB.Config.Get("bags.columns"))
		assert.equal(true, SB.Config.Get("prices.headerTotals"))
		assert.same({ "c_keystone", "c_tradegoods", "c_boe" },
			{ SB.Config.db.categoryOrder[1], SB.Config.db.categoryOrder[2], SB.Config.db.categoryOrder[3] })
		assert.equal("c_tradegoods", SB.Categories.SectionOrder()[3], "the categories follow at once")
		assert.equal(1, bags.layouts, "the open bags regroup")
		assert.same({ "Set up for M+, Gold-making. Change anything later: type /swagbag." }, A.Lines())
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

	it("read-only settings: Apply and Skip refuse with the reason and change nothing", function()
		QS.Show()
		pick("raid")
		SB.Config.readOnly = true
		Fake.Fire(QS.applyButton, "OnClick")
		Fake.Fire(QS.skipButton, "OnClick")
		assert.same({ SB.L.SETTINGS_READONLY, SB.L.SETTINGS_READONLY }, A.Lines())
		assert.truthy(QS.IsOpen())
		assert.is_nil(SB.Config.db.settings.focus)
	end)

	it("AC7.4: /swagbag setup shows it again; /swagbag tour answers (P2)", function()
		SB.Slash.Dispatch("setup")
		assert.truthy(QS.IsOpen())
		SB.Slash.Dispatch("tour")
		assert.same({ SB.L.QS_OPENED, SB.L.TOUR_LATER }, A.Lines())
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

	-- Mutation: call Apply bare in finish() (no ErrorTrap.Run), or give Apply window "bags".
	it("W4-6: an error in Apply says SETTINGS_FAILED on the status line and in chat, and never trips Safe Mode", function()
		QS.Show()
		pick("mplus")
		SB.Config.Set = function() error("boom") end
		Fake.Fire(QS.applyButton, "OnClick")
		assert.equal(SB.L.SETTINGS_FAILED, QS.frame.status.text)
		assert.same({ SB.L.SETTINGS_FAILED }, A.Lines())
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.truthy(QS.IsOpen(), "the screen stays so the user can retry or Skip")
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
		local SB = Loader.New(files)
		Fake.Install()
		SB.Config.Get = function() error("Config.Get called at load time") end
		local ok, err = pcall(Loader.LoadFile, SB, "SwagBag/UI/QuickSetup.lua")
		Fake.Uninstall()
		assert.truthy(ok, tostring(err))
	end)
end)
