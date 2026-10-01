local Loader = dofile("spec/helpers/loader.lua")

describe("ErrorTrap", function()
	local SB, ET, SM, A
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua" })
		ET, SM, A = SB.ErrorTrap, SB.SafeMode, SB.Adapter
	end)

	it("Run passes arguments and returns true plus the results", function()
		local ok, a, b = ET.Run("t", "bags", function(x, y) return x + y, "two" end, 2, 3)
		assert.equal(true, ok)
		assert.equal(5, a)
		assert.equal("two", b)
		assert.equal(0, #ET.Recent())
	end)

	it("Run returns false and records label, window, message and stack", function()
		local ok = ET.Run("Views.Bags.Refresh", "bags", function() error("kaboom") end)
		assert.equal(false, ok)
		local e = ET.Recent()[1]
		assert.equal("Views.Bags.Refresh", e.label)
		assert.equal("bags", e.window)
		assert.truthy(e.message:find("kaboom", 1, true))
		assert.equal("[stack]", e.stack)
		assert.equal("2026-10-01 21:03:07", e.time)
		assert.equal(SB.VERSION, e.version)
	end)

	it("records whether the error happened in combat", function()
		A.combat = true
		ET.Run("x", "bags", function() error("in a fight") end)
		assert.equal(true, ET.Recent()[1].combat)
		assert.truthy(SM.IsOn("bags"))
	end)

	it("an error in the bags path switches bags to Safe Mode with one chat line", function()
		ET.Run("x", "bags", function() error("1") end)
		assert.truthy(SM.IsOn("bags"))
		assert.falsy(SM.IsOn("bank"))
		assert.equal("auto", SM.state.bags.reason)
		assert.same({ SB.L.ERROR_SWITCHED }, A.Lines())
	end)

	it("further errors while in Safe Mode are recorded silently", function()
		ET.Run("x", "bags", function() error("1") end)
		ET.Run("x", "bags", function() error("2") end)
		assert.equal(1, #A.printed)
		assert.equal(2, #ET.Recent())
	end)

	it("an error with no window switches both windows, still one line", function()
		ET.Run("x", nil, function() error("1") end)
		assert.truthy(SM.IsOn("bags"))
		assert.truthy(SM.IsOn("bank"))
		assert.equal(1, #A.printed)
		assert.equal("both", ET.Recent()[1].window)
	end)

	it("window \"none\" records without Safe Mode or chat", function()
		ET.Run("slash:report", "none", function() error("1") end)
		assert.falsy(SM.IsOn("bags"))
		assert.equal(0, #A.printed)
		assert.equal(1, #ET.Recent())
	end)

	it("keeps only the last 10 errors", function()
		for i = 1, 12 do
			ET.Run("x", "none", function() error("e" .. i) end)
		end
		local recent = ET.Recent()
		assert.equal(10, #recent)
		assert.truthy(recent[1].message:find("e3", 1, true))
		assert.truthy(recent[10].message:find("e12", 1, true))
	end)

	it("says 'still failing' when an error follows a manual safe off within 10 s", function()
		SM.Enable("bags", "manual")
		SM.Disable("bags")
		A.Advance(5)
		ET.Run("x", "bags", function() error("again") end)
		assert.truthy(SM.IsOn("bags"))
		assert.same({ SB.L.ERROR_STILL_FAILING }, A.Lines())
	end)

	it("Guard wraps a function for hooks and returns its results", function()
		local wrapped = ET.Guard("hook", function(v) return v * 2 end, "bags")
		assert.equal(8, wrapped(4))
		local broken = ET.Guard("hook", function() error("x") end, "bags")
		assert.is_nil(broken())
		assert.truthy(SM.IsOn("bags"))
	end)

	it("Attach adopts the saved list, keeps earlier entries and trims to 10", function()
		ET.Run("early", "none", function() error("before attach") end)
		local saved = {}
		for i = 1, 10 do
			saved[i] = { label = "old" .. i, message = "m" }
		end
		ET.Attach(saved)
		assert.equal(saved, ET.buffer)
		assert.equal(10, #saved)
		assert.equal("old2", saved[1].label)
		assert.equal("early", saved[10].label)
	end)
end)
