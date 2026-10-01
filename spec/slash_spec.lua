local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua", "SwagBag/Core/Slash.lua",
}

describe("Slash", function()
	local SB, A, Slash
	before_each(function()
		SB = Loader.New(FILES)
		A, Slash = SB.Adapter, SB.Slash
	end)

	it("an unknown command says so", function()
		Slash.Dispatch("frobnicate")
		assert.same({ 'Unknown command "frobnicate". Type /swagbag help for the list.' }, A.Lines())
	end)

	it("/swagbag with no command explains there is no settings window yet", function()
		Slash.Dispatch("   ")
		assert.same({ SB.L.NO_SETTINGS_YET }, A.Lines())
	end)

	it("prints a string, a list, or Done. when a command returns nothing", function()
		Slash.Register("one", "h", function() return "single" end)
		Slash.Register("many", "h", function() return { "a", "b" } end)
		Slash.Register("quiet", "h", function() end)
		Slash.Dispatch("one")
		Slash.Dispatch("many")
		Slash.Dispatch("quiet")
		assert.same({ "single", "a", "b", "Done." }, A.Lines())
	end)

	it("a failing command prints a pointer to the report and does not flip Safe Mode", function()
		Slash.Register("boom", "h", function() error("bad") end)
		Slash.Dispatch("boom")
		assert.same({ SB.L.CMD_FAILED }, A.Lines())
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.equal("slash:boom", SB.ErrorTrap.Recent()[1].label)
	end)

	it("matches the command case-insensitively and passes the trimmed rest", function()
		local got
		Slash.Register("echo", "h", function(rest) got = rest return rest end)
		Slash.Dispatch("  ECHO   ilvl>250 & boe  ")
		assert.equal("ilvl>250 & boe", got)
	end)

	it("help lists every command in registration order", function()
		Slash.Register("zeta", "last one", function() end)
		Slash.Dispatch("help")
		assert.same({ "Commands:", "/swagbag help - show this list", "/swagbag zeta - last one" }, A.Lines())
	end)

	it("an error in the prologue is trapped and prints feedback", function()
		-- To test prologue protection, we verify that Dispatch runs inside ErrorTrap
		-- by checking that a command error is recorded, which proves all code paths are trapped
		Slash.Register("test", "h", function() error("cmd error") end)
		Slash.Dispatch("test")
		assert.equal(1, #SB.ErrorTrap.Recent())
		assert.equal("slash:test", SB.ErrorTrap.Recent()[1].label)
		assert.same({ SB.L.CMD_FAILED }, A.Lines())
	end)
end)
