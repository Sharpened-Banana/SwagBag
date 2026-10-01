local Loader = dofile("spec/helpers/loader.lua")

local FILES = { "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua" }

describe("Events", function()
	local SB, A
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
	end)

	it("On registers the WoW event and delivers its arguments", function()
		local got
		assert.truthy(SB.On("BAG_UPDATE", function(event, bag) got = { event, bag } end, "bags"))
		assert.truthy(SB.eventFrame.events.BAG_UPDATE)
		SB.eventFrame:Fire("BAG_UPDATE", 3)
		assert.same({ "BAG_UPDATE", 3 }, got)
	end)

	it("On returns false for an event WoW does not know", function()
		Loader.Stub.unknownEvents.BANK_TAB_SETTINGS_UPDATED = true
		assert.falsy(SB.On("BANK_TAB_SETTINGS_UPDATED", function() end))
	end)

	it("internal SB_ messages are not registered with WoW but still dispatch", function()
		local count = 0
		SB.On("SB_TEST", function() count = count + 1 end)
		assert.is_nil(SB.eventFrame.events.SB_TEST)
		SB.Emit("SB_TEST")
		assert.equal(1, count)
	end)

	it("a failing handler is trapped, flips its window, and later handlers still run", function()
		local ran = false
		SB.On("SB_TEST", function() error("bad handler") end, "bags")
		SB.On("SB_TEST", function() ran = true end, "none")
		SB.Emit("SB_TEST")
		assert.truthy(ran)
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.equal("event:SB_TEST", SB.ErrorTrap.Recent()[1].label)
	end)

	it("SafeMode changes are announced as SB_SAFEMODE_CHANGED", function()
		local got
		SB.On("SB_SAFEMODE_CHANGED", function(_, window, on, reason) got = { window, on, reason } end)
		SB.SafeMode.Enable("bank", "manual")
		assert.same({ "bank", true, "manual" }, got)
	end)

	it("OutOfCombat runs immediately when not in combat", function()
		local ran = false
		assert.truthy(SB.OutOfCombat(function() ran = true end, "x"))
		assert.truthy(ran)
	end)

	it("OutOfCombat queues in combat, dedupes by label, and drains on PLAYER_REGEN_ENABLED", function()
		A.combat = true
		local log = {}
		assert.falsy(SB.OutOfCombat(function() log[#log + 1] = "grow-old" end, "grow"))
		SB.OutOfCombat(function() log[#log + 1] = "other" end, "other")
		SB.OutOfCombat(function() log[#log + 1] = "grow-new" end, "grow")
		assert.equal(2, SB.OutOfCombatPending())
		assert.same({}, log)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		assert.same({ "grow-new", "other" }, log)
		assert.equal(0, SB.OutOfCombatPending())
	end)

	it("Debounce runs once, delay after the last call", function()
		local count = 0
		SB.Debounce("k", 0.15, function() count = count + 1 end)
		A.Advance(0.1)
		SB.Debounce("k", 0.15, function() count = count + 1 end)
		A.Advance(0.1)
		assert.equal(0, count)
		A.Advance(0.1)
		assert.equal(1, count)
		A.Advance(1)
		assert.equal(1, count)
	end)

	it("Debounce keys are independent", function()
		local hits = {}
		SB.Debounce("a", 0.05, function() hits[#hits + 1] = "a" end)
		SB.Debounce("b", 0.05, function() hits[#hits + 1] = "b" end)
		A.Advance(0.1)
		assert.same({ "a", "b" }, hits)
	end)
end)
