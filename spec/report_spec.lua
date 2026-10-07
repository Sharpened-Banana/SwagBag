local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Checks.lua", "SwagBag/Core/Blocked.lua", "SwagBag/Core/Report.lua",
}

describe("Report", function()
	local SB, A
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		SB.Config.Init(nil, nil)
	end)

	it("builds the full report for a clean session", function()
		SB.Checks.last = {}
		local expected = table.concat({
			"SwagBag " .. SB.VERSION .. " | WoW 12.1.0 (69933) | enUS | 2026-10-01 21:03",
			"Safe Mode: bags=off bank=off",
			"Failed checks: none",
			"Errors (last 10):",
			" none",
			"Blocked actions: none",
			"Bag-related addons: Auctionator (not loaded), Syndicator (not loaded)",
			"Other bag addons on: none",
			"Settings hash: " .. SB.Report.Hash({}) .. "  Schema: 2  Buttons: 0 (0 ms)",
		}, "\n")
		assert.equal(expected, SB.Report.Build())
	end)

	it("lists Safe Mode reasons, failed checks and errors with indented stacks", function()
		SB.Checks.last = {
			{ name = "BankFrame.TabSystem", pass = false, detail = "missing", required = true, window = "bank" },
			{ name = "C_Timer.After", pass = true, detail = "present", required = true, window = "bags" },
		}
		A.combat = true
		A.Stack = function() return "line one\nline two" end
		SB.ErrorTrap.Run("Views.Bank.Refresh", "bank", function() error("attempt to index nil", 0) end)
		local text = SB.Report.Build()
		assert.truthy(text:find("Safe Mode: bags=off bank=on (auto, 21:03)", 1, true))
		assert.truthy(text:find("Failed checks: BankFrame.TabSystem (missing)", 1, true))
		local expected = " 2026-10-01 21:03:07 [bank, in combat] Views.Bank.Refresh: attempt to index nil\n"
			.. "    line one\n    line two"
		assert.truthy(text:find(expected, 1, true))
	end)

	it("shows loaded bag addons with versions and hides other unloaded ones", function()
		SB.Checks.last = {}
		A.addons = { Auctionator = "12.1.3", Bagnon = "10.2", AdiBags = false }
		local text = SB.Report.Build()
		assert.truthy(text:find("Bag-related addons: Auctionator 12.1.3, Syndicator (not loaded), Bagnon 10.2\n", 1, true))
		assert.falsy(text:find("AdiBags", 1, true))
	end)

	-- Week 7 (user pick 2). Mutation: delete the Season data line in Report.Build.
	it("names the season's currencies and items (Footer.SeasonText), so their IDs can be confirmed", function()
		SB.Checks.last = {}
		SB.Footer = { SeasonText = function() return "Weathered Ethereal Crest (3107) 45", "Ascendant Venomstone (280562) 12" end }
		assert.truthy(SB.Report.Build():find("\nSeason data: crest currencies Weathered Ethereal Crest (3107) 45; season"
			.. " items in bags Ascendant Venomstone (280562) 12", 1, true))
	end)

	-- Final review fix 6. Mutation: call SB.Footer.SeasonText() without pcall (the report would fail whole).
	it("a failure reading the season data leaves the rest of the report intact", function()
		SB.Checks.last = {}
		SB.Footer = { SeasonText = function() error("boom") end }
		local text
		assert.truthy(pcall(function() text = SB.Report.Build() end))
		assert.truthy(text:find("\n" .. SB.L.REPORT_SEASON_FAILED, 1, true))
		assert.truthy(text:find("Bag-related addons", 1, true))
	end)

	it("lists SwagBag's blocked actions and ignores other addons'", function()
		SB.Checks.last = {}
		A.combat = true
		SB.eventFrame:Fire("ADDON_ACTION_BLOCKED", "SwagBag", "UseContainerItem()")
		SB.eventFrame:Fire("ADDON_ACTION_FORBIDDEN", "OtherAddon", "CastSpellByName()")
		local text = SB.Report.Build()
		assert.truthy(text:find("Blocked actions: UseContainerItem() at 21:03:07, in combat\n", 1, true))
		assert.falsy(text:find("CastSpellByName", 1, true))
	end)

	it("shows the last bags layout time, for the spec 9 open budgets", function()
		SB.Checks.last = {}
		SB.BagsWindow = { stats = { lastLayoutMs = 12.34, lastLayoutReason = "open" } }
		assert.truthy(SB.Report.Build():find("\nLast bags layout: 12.3 ms (open)", 1, true))
	end)

	-- Week 6, D16 (FM1 step 8). Mutation: drop the REPORT_BAG_HOOKS line in Report.Build.
	it("shows the last bag hook calls, for the vendor walk-away check", function()
		SB.Checks.last = {}
		SB.SafeModeHooks = { TRACE = 5, TraceText = function() return "CloseAllBags(nil) kept open at 10.5" end }
		assert.truthy(SB.Report.Build():find("\nBag hooks (last 5): CloseAllBags(nil) kept open at 10.5", 1, true))
	end)

	-- 0.13.2 diagnostics: the New log, oldest first, after the bag-hooks line. Mutations: drop the block in
	-- Report.Build; print the entries newest first; drop the GUARDED word.
	it("shows the New log after the bag hooks, oldest first", function()
		SB.Checks.last = {}
		SB.SafeModeHooks = { TRACE = 5, TraceText = function() return "none" end }
		SB.Inventory = { NEW_LOG_MAX = 10, newLog = {
			{ kind = "settle", at = 0, phase = "start", world = false, reason = "login" },
			{ kind = "flush", at = 12.34, source = "delayed", settling = false, left = 0, came = 3, arrivals = 3,
				marked = 3, stacks = 5, guarded = false, revealed = { known = 1, base = 0 }, fresh = 0, bags = { 0, 1 },
				secret = 2 },
			{ kind = "flush", at = 13, source = "failsafe", settling = true, left = 6, came = 0, arrivals = 32,
				marked = 0, stacks = 38, guarded = true, revealed = { known = 0, base = 0 }, fresh = 0, bags = {},
				secret = 0 },
			{ kind = "scankind", at = 20, scanned = "bank", changes = 0 },
			{ kind = "settle", at = 21, phase = "end", world = true, reason = "login cap" },
		} }
		local expected = table.concat({
			"Bag hooks (last 5): none",
			"New log (last 10):",
			"  +0.0s settle start (login)",
			"  +12.3s delayed: left 0, came 3, arrivals 3, marked 3 of 5 stacks; bags 0,1; known 1 base 0 fresh 0 secret 2",
			"  +13.0s failsafe (settling): left 6, came 0, arrivals 32, marked 0 of 38 stacks GUARDED; bags none; known 0"
				.. " base 0 fresh 0 secret 0",
			"  +20.0s rescan bank: 0 bag changes",
			"  +21.0s settle end (login cap)",
		}, "\n")
		assert.truthy(SB.Report.Build():find(expected, 1, true))
	end)

	-- Mutation: drop the REPORT_NEW_NONE line (an empty log prints only its title).
	it("an empty New log says nothing was logged", function()
		SB.Checks.last = {}
		SB.Inventory = { NEW_LOG_MAX = 10, newLog = {} }
		assert.truthy(SB.Report.Build():find("\nNew log (last 10):\n  (nothing logged)", 1, true))
	end)

	it("shows the bank setting, the last visit and the deposit target (check V2)", function()
		SB.Checks.last = {}
		SB.BankWindow = { Mode = function() return "tiny" end, Show = function() return "both" end,
			lastVisit = "beside", target = "warband",
			GroupName = function() return "Warband bank" end }
		assert.truthy(SB.Report.Build():find("\nBank: setting tiny, shows both, last visit beside, last deposit target Warband bank",
			1, true))
		SB.BankWindow.view = { stats = { lastLayoutMs = 61.27, lastLayoutReason = "open" } }
		assert.truthy(SB.Report.Build():find("\nLast bank layout: 61.3 ms (open)", 1, true), "spec 9: first bank open")
		-- Week 6, D20. Mutation: drop the REPORT_BANK_PHASES line.
		SB.BankWindow.view.stats.phases = { groups = 0.5, read = 40.04, categories = 12.3, positions = 6.1, drawing = 2 }
		assert.truthy(SB.Report.Build():find("\nBank layout parts: tabs 0.5 ms, reading 40.0 ms, categories 12.3 ms,"
			.. " positions 6.1 ms, drawing 2.0 ms", 1, true))
	end)

	it("shows the guild bank setting and the last visit (check G1)", function()
		SB.Checks.last = {}
		SB.GuildBankWindow = { Mode = function() return "full" end, lastVisit = "view" }
		assert.truthy(SB.Report.Build():find("\nGuild bank: setting full, last visit view", 1, true))
	end)

	it("shows the snapshot counts and size, for the spec 8.4 budgets (check V10)", function()
		SB.Checks.last = {}
		SB.Snapshots = { Count = function() return 3, 1 end, Bytes = function() return 40 * 1024 end }
		assert.truthy(SB.Report.Build():find("\nSnapshots: 3 characters, 1 guilds, 40 KB", 1, true))
		-- Week 6, D21. Mutation: drop the REPORT_SNAPSHOT_KINDS line.
		SB.Snapshots.BytesByKind = function() return { bags = 9216, bank = 20480, warband = 10240, guild = 512 } end
		assert.truthy(SB.Report.Build():find("\nSnapshot sizes: bags 9.0 KB, banks 20.0 KB, warband 10.0 KB,"
			.. " guild banks 0.5 KB", 1, true))
	end)

	it("shows which price source answers and how many prices are cached (F10)", function()
		SB.Checks.last = {}
		SB.Prices = { Source = function() return "Auctionator" end, cached = 412 }
		assert.truthy(SB.Report.Build():find("\nPrices: Auctionator, 412 cached", 1, true))
	end)

	-- Week 9. Mutation: Report uses Prices.Source() even when SourceText exists.
	it("names TSM's price string when TSM answers", function()
		SB.Checks.last = {}
		SB.Prices = { Source = function() return "TSM" end, SourceText = function() return "TSM (DBMarket)" end, cached = 7 }
		assert.truthy(SB.Report.Build():find("\nPrices: TSM (DBMarket), 7 cached", 1, true))
	end)

	-- Week 9 (user pick 11). Mutation: drop the Masque line from Report.Build.
	it("says whether Masque skins SwagBag's buttons, and how many", function()
		SB.Checks.last = {}
		SB.Skins = { Available = function() return false end, count = 0 }
		assert.truthy(SB.Report.Build():find("\nMasque: not loaded", 1, true))
		SB.Skins = { Available = function() return true end, count = 410 }
		assert.truthy(SB.Report.Build():find("\nMasque: 410 buttons skinned", 1, true))
	end)

	-- Week 10. Mutation: drop the Locks line from Report.Build.
	it("says how many items are locked and whether the destroy warnings are on", function()
		SB.Checks.last = {}
		SB.Locks = { List = function() return { 1, 2, 3 } end }
		assert.truthy(SB.Report.Build():find("\nLocks: 3 locked; destroy warnings on", 1, true))
		SB.Config.Set("locks.warn", false)
		assert.truthy(SB.Report.Build():find("\nLocks: 3 locked; destroy warnings off", 1, true))
	end)

	-- Week 9 (user pick 11b). Mutations: in A.OtherBagAddons drop the ElvUIBagsOn() check; or in A.ElvUIBagsOn
	-- drop `== true` (any ElvUI counts, bags module or not).
	it("names every other bag addon that is on, and ElvUI only while its own bags module is on", function()
		SB.Checks.last = {}
		A.addons = { Baganator = "833", Bagnon = false, AdiBags = "1.10", ElvUI = "14.0", Syndicator = "200" }
		A.globals.ElvUI = { { private = { bags = { enable = false } } } }
		assert.same({ "Baganator", "AdiBags" }, A.OtherBagAddons())
		A.globals.ElvUI[1].private.bags.enable = true
		assert.same({ "Baganator", "AdiBags", "ElvUI" }, A.OtherBagAddons())
		A.globals.ElvUI = { { private = {} } }
		assert.same({ "Baganator", "AdiBags" }, A.OtherBagAddons(), "no bags settings yet: not counted")
		assert.truthy(SB.Report.Build():find("\nOther bag addons on: Baganator, AdiBags\n", 1, true))
	end)

	-- Never disables anything. Mutations: drop the login warning; or drop its Safe Mode check; or drop its
	-- bags.warnOtherAddons check (preflight S16).
	it("at login one line names them and suggests /swagbag safe on; silent when none, when switched off, or in Safe Mode", function()
		SB.Emit("SB_LOGIN")
		assert.same({}, A.Lines(), "none on: nothing said")
		A.addons = { Baganator = "833", BetterBags = "0.3" }
		SB.Emit("SB_LOGIN")
		assert.same({ SB.L.OTHER_BAGS_WARN:format("Baganator, BetterBags") }, A.Lines())
		SB.Config.Set("bags.warnOtherAddons", false)
		SB.Emit("SB_LOGIN")
		assert.equal(1, #A.Lines(), "the user switched the warning off")
		SB.Config.Set("bags.warnOtherAddons", true)
		SB.SafeMode.Enable("bags", "manual")
		SB.Emit("SB_LOGIN")
		assert.equal(1, #A.Lines(), "SwagBag has stepped aside already")
		assert.same({ "833", "0.3" }, { A.addons.Baganator, A.addons.BetterBags }, "nothing was switched off")
	end)

	it("Hash is stable, order-independent and changes with content", function()
		local h1 = SB.Report.Hash({ bags = { columns = 12 }, x = "a" })
		local h2 = SB.Report.Hash({ x = "a", bags = { columns = 12 } })
		local h3 = SB.Report.Hash({ bags = { columns = 10 }, x = "a" })
		assert.equal(h1, h2)
		assert.truthy(h1 ~= h3)
		assert.truthy(h1:match("^%x%x%x%x%x%x%x%x$"))
	end)
end)
