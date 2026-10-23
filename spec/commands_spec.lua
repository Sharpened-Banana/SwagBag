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

	-- Forever Stage A final review. Mutation: skipping the bank in safe on/off on Retail too.
	it("on Retail safe off still turns both windows off", function()
		SB.Slash.Dispatch("safe on")
		A.printed = {}
		SB.Slash.Dispatch("safe off")
		assert.falsy(SM.IsOn("bags"))
		assert.falsy(SM.IsOn("bank"))
		assert.equal(false, SB.Config.Get("safeMode.bank"))
		assert.equal(2, #A.Lines())
	end)

	-- Week 9 (preflight S16). Mutation: in the otherbags command, set bags.warnOtherAddons without checking
	-- Config.Set's answer.
	it("otherbags says whether the login warning is on, switches it, and refuses while read-only", function()
		local L = SB.L
		assert.same({ true, L.OTHER_BAGS_STATE:format(L.OVERLAY_ON) }, { SB.Slash.Run("otherbags") })
		assert.same({ true, L.OTHER_BAGS_OFF }, { SB.Slash.Run("otherbags off") })
		assert.equal(false, SB.Config.Get("bags.warnOtherAddons"))
		assert.same({ true, L.OTHER_BAGS_STATE:format(L.OVERLAY_OFF) }, { SB.Slash.Run("OTHERBAGS") })
		assert.same({ true, L.OTHER_BAGS_ON }, { SB.Slash.Run("otherbags On") })
		assert.same({ true, L.OTHER_BAGS_USAGE }, { SB.Slash.Run("otherbags maybe") })
		SB.Config.readOnly = true
		assert.same({ true, L.SETTINGS_READONLY }, { SB.Slash.Run("otherbags off") })
		assert.equal(true, SB.Config.Get("bags.warnOtherAddons"))
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

	it("DoReset reloads the categories from the fresh tables and closes the bags window (M1)", function()
		local loads, closes = 0, 0
		SB.Categories = { Load = function() loads = loads + 1 end }
		SB.BagsWindow = { Close = function() closes = closes + 1 end }
		SB.Commands.DoReset()
		assert.equal(1, loads)
		assert.equal(1, closes)
	end)

	it("DoReset on a newer schema replaces the saved tables with a backup-carrying fresh pair", function()
		local newer = { schemaVersion = 7 }
		SB.Config.Init(newer, nil)
		SB.Commands.DoReset()
		assert.equal(SB.Config.db, SwagBagDB)
		assert.equal(2, SwagBagDB.schemaVersion)
		assert.same({ schemaVersion = 7 }, SwagBagDB.backups.reset)
	end)

	-- Plan D19. Mutation: delete SB.Emit("SB_FREE_TILE_CHANGED") in the free command.
	it("free tile|all saves bags.freeTile, answers, and asks the open windows to regroup; else the usage", function()
		local regroups = 0
		SB.On("SB_FREE_TILE_CHANGED", function()
			regroups = regroups + 1
		end)
		assert.equal(true, SB.Config.Get("bags.freeTile"), "the tile is the default")
		SB.Slash.Dispatch("free all")
		assert.equal(false, SB.Config.Get("bags.freeTile"))
		SB.Slash.Dispatch("free tile")
		assert.equal(true, SB.Config.Get("bags.freeTile"))
		SB.Slash.Dispatch("free")
		SB.Config.readOnly = true
		SB.Slash.Dispatch("free all")
		assert.equal(true, SB.Config.Get("bags.freeTile"))
		assert.same({
			"Every free slot is shown again.",
			"Free slots now show as one slot with the number of free slots.",
			"Use /swagbag free tile or /swagbag free all (now: tile).",
			"SwagBag's saved settings are read-only, so nothing was changed.",
		}, A.Lines())
		assert.equal(2, regroups)
	end)

	-- Stack grouping. Mutation: delete SB.Emit("SB_STACKS_CHANGED") in the stacks command.
	it("stacks one|all sets the setting and answers", function()
		local changed = 0
		SB.On("SB_STACKS_CHANGED", function()
			changed = changed + 1
		end)
		assert.equal("one", SB.Config.Get("bags.stacks"), "one icon is the default")
		SB.Slash.Dispatch("stacks all")
		assert.equal("all", SB.Config.Get("bags.stacks"))
		assert.equal(1, changed)
		SB.Slash.Dispatch("stacks ONE")
		assert.equal("one", SB.Config.Get("bags.stacks"))
		assert.same({ SB.L.STACKS_MODE_ALL, SB.L.STACKS_MODE_ONE }, A.Lines())
		assert.equal(2, changed)
	end)

	it("stacks with no word gives the usage", function()
		local changed = 0
		SB.On("SB_STACKS_CHANGED", function()
			changed = changed + 1
		end)
		SB.Slash.Dispatch("stacks")
		SB.Slash.Dispatch("stacks some")
		assert.same({ SB.L.STACKS_USAGE:format("one"), SB.L.STACKS_USAGE:format("one") }, A.Lines())
		assert.equal("one", SB.Config.Get("bags.stacks"))
		assert.equal(0, changed)
	end)

	it("stacks refuses while read-only", function()
		SB.Config.readOnly = true
		SB.Slash.Dispatch("stacks all")
		assert.equal("one", SB.Config.Get("bags.stacks"))
		assert.same({ SB.L.SETTINGS_READONLY }, A.Lines())
	end)
end)
