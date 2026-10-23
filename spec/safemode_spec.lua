local Loader = dofile("spec/helpers/loader.lua")

describe("SafeMode state", function()
	local SB, SM
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/SafeMode.lua" })
		SM = SB.SafeMode
	end)

	it("starts off for bags and bank", function()
		assert.falsy(SM.IsOn("bags"))
		assert.falsy(SM.IsOn("bank"))
	end)

	it("Enable turns a window on once and remembers why", function()
		assert.truthy(SM.Enable("bags", "auto"))
		assert.truthy(SM.IsOn("bags"))
		assert.equal("auto", SM.state.bags.reason)
		assert.falsy(SM.Enable("bags", "manual"), "second Enable reports no change")
		assert.equal("auto", SM.state.bags.reason)
	end)

	it("Disable turns it off and RecentlyDisabled covers the next 10 seconds", function()
		SM.Enable("bags", "manual")
		assert.truthy(SM.Disable("bags"))
		assert.falsy(SM.IsOn("bags"))
		assert.truthy(SM.RecentlyDisabled("bags", 10))
		SB.Adapter.Advance(11)
		assert.falsy(SM.RecentlyDisabled("bags", 10))
		assert.falsy(SM.Disable("bags"), "already off")
	end)

	it("Describe reads off or on with reason and time", function()
		assert.equal("off", SM.Describe("bank"))
		SM.Enable("bank", "auto")
		assert.equal("on (auto, 21:03)", SM.Describe("bank"))
	end)

	it("keeps the two windows independent", function()
		SM.Enable("bank", "check")
		assert.falsy(SM.IsOn("bags"))
		assert.truthy(SM.IsOn("bank"))
		assert.falsy(SM.Enable("nonsense", "manual"))
	end)
end)

-- Forever Stage A, Task 4: the reason, and the one-line Forever notice.
describe("SafeMode reason and the Forever notice", function()
	local SB, SM
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/SafeMode.lua" })
		SM = SB.SafeMode
	end)

	it("Reason is nil while off and the reason while on", function()
		assert.is_nil(SM.Reason("bank"))
		SM.Enable("bank", "forever")
		assert.equal("forever", SM.Reason("bank"))
		SM.Disable("bank")
		assert.is_nil(SM.Reason("bank"))
		assert.is_nil(SM.Reason("nope"))
	end)

	-- Mutation: ForeverNotice without the foreverTold check, or without the reason check.
	it("ForeverNotice prints once, and only for reason forever", function()
		SM.Enable("bank", "manual")
		assert.falsy(SM.ForeverNotice())
		assert.same({}, SB.Adapter.Lines())
		SM.Disable("bank")
		SM.Enable("bank", "forever")
		assert.truthy(SM.ForeverNotice())
		assert.falsy(SM.ForeverNotice())
		assert.same({ SB.L.FOREVER_BANK_OFF }, SB.Adapter.Lines())
		assert.truthy(SM.foreverTold)
	end)
end)
