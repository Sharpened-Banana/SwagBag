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

	it("shows the bank setting, the last visit and the deposit target (check V2)", function()
		SB.Checks.last = {}
		SB.BankWindow = { Mode = function() return "tiny" end, lastVisit = "beside", target = "warband",
			GroupName = function() return "Warband bank" end }
		assert.truthy(SB.Report.Build():find("\nBank: setting tiny, last visit beside, last deposit target Warband bank",
			1, true))
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
