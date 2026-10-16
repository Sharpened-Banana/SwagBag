-- Week 12 (spec F7: AC7.1, AC7.2; AC9.2): the setup wizard's draft and what Finish writes (Engine/Setup.lua).
-- Nothing is written before Finish; a picked style's settings are written as explicit values; nothing else is.
local Loader = dofile("spec/helpers/loader.lua")
local Env = dofile("spec/helpers/uienv.lua")

describe("Setup wizard: the draft and Finish (week 12)", function()
	local SB, S, C, bags
	before_each(function()
		local files = { unpack(Env.ENGINE) }
		files[#files + 1] = "SwagBag/Engine/Focus.lua"
		files[#files + 1] = "SwagBag/Engine/Setup.lua"
		SB = Loader.New(files)
		SB.Config.Init(nil, nil)
		SB.Categories.Load()
		S, C = SB.Setup, SB.Config
		bags = { layouts = 0, open = false, scales = {} }
		function bags.IsOpen() return bags.open end
		function bags.RequestLayout() bags.layouts = bags.layouts + 1 end
		function bags.RefreshTitle() end
		function bags.SetScale(v, quiet) bags.scales[#bags.scales + 1] = { v, quiet } end
		SB.BagsWindow = bags
	end)

	local function keys(t)
		local out = {}
		for k in pairs(t or {}) do
			out[#out + 1] = k
		end
		table.sort(out)
		return out
	end

	-- AC9.2. Mutations: in Setup.Preset, drop `set("overlays.upgrade", true)` from the M+ block; or drop the Collector
	-- block's `set("overlays.learn", true)`.
	it("AC9.2: each playstyle sets its overlays; Casual alone switches the warning and the track off", function()
		assert.same({ { "focus.on.mplus", true }, { "consumables.warn", true }, { "overlays.keystone", true },
			{ "overlays.track", true }, { "overlays.upgrade", true }, { "overlays.ilvl", true } }, S.Preset({ mplus = true }))
		assert.same({ { "focus.on.raid", true }, { "consumables.warn", true }, { "overlays.upgrade", true },
			{ "overlays.ilvl", true }, { "overlays.track", true } }, S.Preset({ raid = true }))
		assert.same({ { "prices.headerTotals", true }, { "overlays.junk", true } }, S.Preset({ gold = true }))
		assert.same({ { "overlays.uncollected", true }, { "overlays.learn", true } }, S.Preset({ collector = true }))
		assert.same({ { "consumables.warn", false }, { "overlays.track", false } }, S.Preset({ casual = true }))
		assert.same(S.Preset({ mplus = true }), S.Preset({ mplus = true, casual = true }))
	end)

	-- Mutation: in Setup.Preset, `if get and get("prices.worth") == "off" then` -> `if get then`.
	it("Gold switches the gold glow on only when it is off; a glow the user set stays", function()
		assert.same({ { "prices.headerTotals", true }, { "overlays.junk", true } }, S.Preset({ gold = true }, C.Get))
		C.Set("prices.worth", "off")
		assert.same({ { "prices.headerTotals", true }, { "overlays.junk", true }, { "prices.worth", "fixed" } },
			S.Preset({ gold = true }, C.Get))
		C.Set("prices.worth", "top")
		local d = S.New()
		S.Toggle(d, "gold")
		assert.equal("top", S.Value(d, "prices.worth"))
	end)

	it("Gold moves Trade Goods and BoE gear up after Keystone & Crests; Collector moves the collectibles", function()
		local display = { "c_keystone", "c_consumables", "c_gear", "c_boe", "c_tradegoods", "c_collect", "c_other" }
		assert.same({ "c_keystone", "c_tradegoods", "c_boe", "c_collect", "c_consumables", "c_gear", "c_other" },
			S.Order(display, { gold = true, collector = true }))
		assert.is_nil(S.Order(display, { mplus = true }))
		assert.is_nil(S.Order(display, { gold = false }))
	end)

	-- Controller ruling (week 12 review). Mutations: in Setup.Order, drop the `if not placed then` append (a promoted
	-- category is lost when Keystone & Crests is not listed); or drop the `listed[id]` check (an id that is not in
	-- the display list is added).
	it("Order never loses a promoted category (no Keystone & Crests listed) and never adds one that is not listed", function()
		assert.same({ "c_consumables", "c_gear", "c_tradegoods", "c_boe" },
			S.Order({ "c_consumables", "c_boe", "c_gear", "c_tradegoods" }, { gold = true }))
		assert.same({ "c_keystone", "c_tradegoods", "c_gear" },
			S.Order({ "c_keystone", "c_gear", "c_tradegoods" }, { gold = true }), "c_boe is not listed: not added")
		assert.is_nil(S.Order({ "c_keystone", "c_gear" }, { gold = true }), "nothing listed moves")
	end)

	-- Y6. Mutation: in Setup.Plan, drop `(key ~= "prices.worthGold" or fixed)`.
	it("the plan writes the glow's amount only while the glow is fixed", function()
		local d = S.New()
		S.Set(d, "prices.worth", "fixed")
		S.Set(d, "prices.worthGold", 500)
		assert.same({ { "prices.worthGold", 500 } }, S.Plan(d), "fixed is the default: only the amount changed")
		S.Set(d, "prices.worth", "off")
		assert.same({ { "prices.worth", "off" } }, S.Plan(d), "the amount is not written for Off")
		S.Set(d, "prices.worth", "top")
		assert.same({ { "prices.worth", "top" } }, S.Plan(d), "nor for the top %")
	end)

	-- AC7.4 (a re-run starts from the settings as they are). Mutation: in Setup.New, drop the `if STYLE[id] then` check
	-- (a damaged or unknown word becomes a picked style).
	it("a new draft starts from the styles picked last time and every setting as it is now", function()
		local d = S.New()
		assert.same({}, d.styles)
		assert.equal(12, S.Value(d, "bags.columns"))
		C.Set("setup.styles", "gold,nonsense,mplus")
		C.Set("bags.columns", 14)
		d = S.New()
		assert.same({ gold = true, mplus = true }, d.styles)
		assert.equal(14, S.Value(d, "bags.columns"))
		C.Set("setup.styles", 7)
		assert.same({}, S.New().styles, "a damaged value reads as nothing picked")
	end)

	-- Mutation: in Setup.Value, drop the `if d.touched[key] ~= nil then` branch (the user's switch would be lost).
	it("what the wizard shows: the user's choice, else what a picked style sets, else the setting now", function()
		C.Set("overlays.track", false)
		local d = S.New()
		assert.equal(false, S.Value(d, "overlays.track"))
		S.Toggle(d, "mplus")
		assert.equal(true, S.Value(d, "overlays.track"), "M+ switches the track on")
		S.Set(d, "overlays.track", false)
		assert.equal(false, S.Value(d, "overlays.track"), "the user switched it off again")
		S.Toggle(d, "mplus")
		assert.equal(false, S.Value(d, "overlays.track"))
		assert.is_nil(d.styles.mplus)
		assert.equal(true, S.Value(d, "focus.on.mplus"), "unpicked: back to the setting now")
	end)

	-- Mutation: in Setup.Switches, drop the loop over Focus.MODES.
	it("step 2 lists the six focus modes, then what the picked styles switch, once each, then the categories they move up", function()
		local d = S.New()
		assert.same({ "focus.auto", "focus.on.mplus", "focus.on.raid", "focus.on.delves", "focus.on.gathering",
			"focus.on.fishing", "focus.on.market" }, S.Switches(d))
		S.Toggle(d, "raid")
		S.Toggle(d, "gold")
		S.Toggle(d, "collector")
		assert.same({ "focus.auto", "focus.on.mplus", "focus.on.raid", "focus.on.delves", "focus.on.gathering",
			"focus.on.fishing", "focus.on.market", "consumables.warn", "overlays.upgrade", "overlays.ilvl", "overlays.track",
			"prices.headerTotals", "overlays.junk", "overlays.uncollected", "overlays.learn", "order.gold",
			"order.collector" }, S.Switches(d))
		assert.equal("Raid mode", S.Label("focus.on.raid"))
		assert.equal(SB.L.WIZ_SW_ORDER_GOLD, S.Label("order.gold"))
		for _, key in ipairs(S.Switches(d)) do
			assert.truthy(S.Label(key) ~= key, "no words for " .. key)
		end
	end)

	-- 0.14.3. Mutations: Setup.Preset sets "focus.auto" for M+ or Raid; Setup.Switches drops "focus.auto"; Setup.Label
	-- has no words for it.
	it("Switch by themselves: step 2's first line, off, and no picked style turns it on; only the user's click writes it",
		function()
			local d = S.New()
			assert.equal("focus.auto", S.Switches(d)[1])
			assert.equal(SB.L.WIZ_SW_AUTO, S.Label("focus.auto"))
			assert.equal(false, S.Value(d, "focus.auto"))
			for _, style in ipairs({ "mplus", "raid", "gold", "casual", "collector" }) do
				S.Toggle(d, style)
			end
			assert.equal(false, S.Value(d, "focus.auto"), "picking every style leaves it off")
			for _, p in ipairs(S.Plan(d)) do
				assert.truthy(p[1] ~= "focus.auto", "no style sets the master switch")
			end
			S.Set(d, "focus.auto", true)
			assert.equal(true, S.Value(d, "focus.auto"))
			local found
			for _, p in ipairs(S.Plan(d)) do
				if p[1] == "focus.auto" then
					found = p[2]
				end
			end
			assert.equal(true, found, "switched on by the user: written")
			S.Set(d, "focus.auto", false)
			for _, p in ipairs(S.Plan(d)) do
				assert.truthy(p[1] ~= "focus.auto", "switched back to what it is: nothing to write")
			end
		end)

	-- Config keeps only explicit values. Mutation: in Setup.Plan, `if preset[key] ~= nil or v ~= get(key) then` ->
	-- `if v ~= get(key) then` (a picked style's settings, equal to the defaults, would not be written).
	it("the plan: a picked style's settings, written even when they equal the default; other values only if changed", function()
		local d = S.New()
		assert.same({}, S.Plan(d))
		S.Toggle(d, "collector")
		S.Set(d, "bags.columns", 12)
		S.Set(d, "bags.scale", 1.1)
		S.Set(d, "focus.on.fishing", false)
		assert.same({ { "bags.scale", 1.1 }, { "focus.on.fishing", false }, { "overlays.learn", true },
			{ "overlays.uncollected", true } }, S.Plan(d))
		S.Set(d, "order.collector", false)
		assert.same(4, #S.Plan(d), "the order switch is no setting")
	end)

	-- Mutations: in Setup.Finish, drop the `C.Set("setup.styles", styles)` write; or drop `C.Set("setup.done", true)`.
	it("Finish writes the plan, moves the picked styles' categories up, remembers the styles, and the bags follow", function()
		local d = S.New()
		S.Toggle(d, "mplus")
		S.Toggle(d, "gold")
		S.Set(d, "bags.columns", 14)
		bags.open = true
		assert.equal("Set up for M+, Gold-making. Change anything later: type /swagbag."
			.. " Settings are saved when you log out or /reload.", S.Finish(d)) -- Y14
		assert.equal(true, C.Get("setup.done"))
		assert.equal("mplus,gold", C.Get("setup.styles"))
		assert.equal(14, C.Get("bags.columns"))
		assert.same({ "bags", "consumables", "focus", "overlays", "prices", "setup" }, keys(C.db.settings))
		assert.same({ "ilvl", "junk", "keystone", "track", "upgrade" }, keys(C.db.settings.overlays))
		assert.same({ "headerTotals" }, keys(C.db.settings.prices))
		assert.same({ "c_keystone", "c_tradegoods", "c_boe" },
			{ C.db.categoryOrder[1], C.db.categoryOrder[2], C.db.categoryOrder[3] })
		assert.equal("c_tradegoods", SB.Categories.SectionOrder()[3], "the categories follow at once")
		assert.equal(1, bags.layouts, "the open bags regroup")
		assert.same({}, bags.scales, "the size did not change")
	end)

	-- Mutation: in Setup.Finish, `promote[o.style] = d.styles[o.style] == true and Setup.Value(d, o.key) == true` ->
	-- `promote[o.style] = d.styles[o.style] == true`.
	it("a category switch turned off on step 2 leaves the order as it is", function()
		local d = S.New()
		S.Toggle(d, "gold")
		S.Set(d, "order.gold", false)
		S.Finish(d)
		assert.is_nil(C.db.categoryOrder)
		assert.equal(true, C.Get("prices.headerTotals"))
	end)

	it("Finish with no style picked writes only what was changed, and says so", function()
		local d = S.New()
		S.Set(d, "bags.scale", 1.25)
		bags.open = true
		assert.equal(SB.L.WIZ_DONE_NONE, S.Finish(d))
		assert.same({ "bags", "setup" }, keys(C.db.settings))
		assert.same({ "scale" }, keys(C.db.settings.bags))
		assert.same({ "done" }, keys(C.db.settings.setup))
		assert.same({ { 1.25, true } }, bags.scales, "the open bags take the new size, quietly")
	end)

	-- Mutation: in Setup.Finish, move the readOnly check below the plan's writes.
	it("read-only settings: Finish and Skip refuse with the reason and write nothing", function()
		local d = S.New()
		S.Toggle(d, "gold")
		S.Set(d, "bags.columns", 16)
		C.readOnly = true
		assert.equal(SB.L.SETTINGS_READONLY, S.Finish(d))
		assert.equal(SB.L.SETTINGS_READONLY, S.Skip())
		C.readOnly = false
		assert.same({}, keys(C.db.settings))
		assert.is_nil(C.db.categoryOrder)
	end)

	-- AC7.2. Mutation: make Skip always answer with L.QS_SKIPPED.
	it("AC7.2: Skip writes only that setup is done, and says the defaults (or your settings) are kept", function()
		assert.equal(SB.L.QS_SKIPPED, S.Skip())
		assert.same({ "setup" }, keys(C.db.settings))
		assert.equal(SB.L.QS_SKIPPED_KEPT, S.Skip())
	end)

	-- Mutation: run follow() bare in Finish (no ErrorTrap.Run).
	it("a refresh error after Finish still says the settings were saved, with a note, and never trips Safe Mode", function()
		local d = S.New()
		S.Toggle(d, "raid")
		bags.open = true
		function bags.RequestLayout() error("layout boom") end
		assert.equal(SB.L.QS_APPLIED:format("Raid") .. " " .. SB.L.QS_REFRESH_NOTE, S.Finish(d))
		assert.equal(true, C.Get("setup.done"))
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)
end)
