local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Checks.lua", "SwagBag/Core/Report.lua", "SwagBag/Core/Slash.lua", "SwagBag/Core/Commands.lua",
}

describe("Commands", function()
	local SB, A, SM, shown
	before_each(function()
		SB = Loader.New(FILES)
		A, SM = SB.Adapter, SB.SafeMode
		SB.Config.Init(nil, nil)
		shown = nil
		SB.ReportBox = { Show = function(text) shown = text end }
	end)

	it("safe with no argument prints both windows' state", function()
		SB.Slash.Dispatch("safe")
		assert.same({ "Safe Mode: bags=off bank=off" }, A.Lines())
	end)

	it("safe bags toggles bags, remembers it, and confirms each time", function()
		SB.Slash.Dispatch("safe bags")
		assert.truthy(SM.IsOn("bags"))
		assert.equal(true, SB.Config.Get("safeMode.bags"))
		SB.Slash.Dispatch("safe bags")
		assert.falsy(SM.IsOn("bags"))
		assert.equal(false, SB.Config.Get("safeMode.bags"))
		assert.same({
			"Safe Mode is ON for bags: Blizzard's frames are used. Type /swagbag safe off to switch back.",
			"Safe Mode is OFF for bags: SwagBag handles them again.",
		}, A.Lines())
	end)

	it("safe on switches both windows with one line each", function()
		SB.Slash.Dispatch("safe on")
		assert.truthy(SM.IsOn("bags"))
		assert.truthy(SM.IsOn("bank"))
		assert.equal(2, #A.printed)
		SB.Slash.Dispatch("safe on")
		assert.equal("Safe Mode was already ON for bank.", A.Lines()[4])
	end)

	it("safe with a wrong argument explains the usage", function()
		SB.Slash.Dispatch("safe maybe")
		assert.same({ SB.L.SAFE_USAGE }, A.Lines())
	end)

	it("debug error flips bags to Safe Mode, prints the error line, then confirms", function()
		SB.Slash.Dispatch("debug error")
		assert.truthy(SM.IsOn("bags"))
		assert.same({ SB.L.ERROR_SWITCHED, "Injected a test error into the bags path." }, A.Lines())
		local e = SB.ErrorTrap.Recent()[1]
		assert.equal("debug:error", e.label)
		assert.equal(SB.L.DEBUG_ERROR_TEXT, e.message)
	end)

	it("debug error bank flips only the bank", function()
		SB.Slash.Dispatch("debug error bank")
		assert.truthy(SM.IsOn("bank"))
		assert.falsy(SM.IsOn("bags"))
	end)

	it("debug v1 hands over to the V1 strip, or explains usage without it", function()
		SB.Slash.Dispatch("debug v1")
		assert.same({ SB.L.DEBUG_USAGE }, A.Lines())
		SB.DebugV1 = { Toggle = function() return "strip toggled" end }
		SB.Slash.Dispatch("debug v1")
		assert.equal("strip toggled", A.Lines()[2])
	end)

	it("check prints one line per check plus a summary", function()
		SB.Slash.Dispatch("check")
		assert.equal(#A.CHECKS + 1, #A.printed)
		assert.truthy(A.Lines()[#A.printed]:find("^Checks: 0 passed"))
	end)

	it("report opens the box with the built report and says how to copy it", function()
		SB.Slash.Dispatch("report")
		assert.truthy(shown:find("^SwagBag "))
		assert.same({ SB.L.REPORT_OPENED }, A.Lines())
	end)

	it("DoReset installs fresh saved tables and confirms", function()
		SB.Config.Set("bags.columns", 9)
		SB.Commands.DoReset()
		assert.equal(SB.Config.db, SwagBagDB)
		assert.equal(SB.Config.charDB, SwagBagCharDB)
		assert.equal(12, SB.Config.Get("bags.columns"))
		assert.same({ SB.L.RESET_DONE }, A.Lines())
	end)

	it("DoReset on a newer schema replaces the saved tables with a backup-carrying fresh pair", function()
		local newer = { schemaVersion = 7 }
		SB.Config.Init(newer, nil)
		SB.Commands.DoReset()
		assert.equal(SB.Config.db, SwagBagDB)
		assert.equal(2, SwagBagDB.schemaVersion)
		assert.same({ schemaVersion = 7 }, SwagBagDB.backups.reset)
	end)
end)
