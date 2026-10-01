local Loader = dofile("spec/helpers/loader.lua")

local FILES = {
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua", "SwagBag/Core/Slash.lua",
}

-- Ensure SlashCmdList exists for tests (not normally defined in test environment)
SlashCmdList = SlashCmdList or {}

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
		assert.falsy(SB.SafeMode.IsOn("bank"))
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
		-- Call entry point with non-string msg to make prologue (:match call) error
		SlashCmdList.SWAGBAG({})
		-- Verify prologue error was trapped by dispatcher label
		local recent = SB.ErrorTrap.Recent()
		assert.equal(1, #recent)
		assert.equal("slash:dispatcher", recent[1].label)
		-- Verify user got feedback
		assert.same({ SB.L.CMD_FAILED }, A.Lines())
		-- Verify Safe Mode stays off for both windows
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.falsy(SB.SafeMode.IsOn("bank"))
	end)

	it("a Print error in the handler is contained and does not escape", function()
		-- Stub Print to throw on every call
		local Print_orig = SB.Print
		SB.Print = function() error("Print failed") end
		-- Call entry point with valid command - prologue succeeds, but Print throws
		SlashCmdList.SWAGBAG("help")
		-- Restore Print for assertions
		SB.Print = Print_orig
		-- Verify no error escaped (test would have crashed otherwise)
		-- Note: the Print stub prevented normal feedback, but pcall contained the error
		assert.truthy(true)  -- If we get here, the error was contained
	end)
end)
