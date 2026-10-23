local Loader = dofile("spec/helpers/loader.lua")
local Globals = dofile("spec/helpers/globals.lua")

describe("Checks", function()
	local SB, A
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/SafeMode.lua", "SwagBag/Core/Checks.lua" })
		A = SB.Adapter
		A.globals = Globals.AllPresent(A)
	end)

	it("passes every check when all APIs are present", function()
		local results = SB.Checks.Run()
		assert.equal(#A.CHECKS, #results)
		assert.same({}, SB.Checks.Failed(results))
		assert.same({}, SB.Checks.Apply(results))
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("a missing required bags API fails and turns on Safe Mode for bags only", function()
		A.globals.C_Container.GetContainerItemInfo = nil
		local results = SB.Checks.Run()
		local failed = SB.Checks.Failed(results, true)
		assert.equal(1, #failed)
		assert.equal("C_Container.GetContainerItemInfo", failed[1].name)
		assert.equal("missing", failed[1].detail)
		assert.same({ "bags" }, SB.Checks.Apply(results))
		assert.equal("check", SB.SafeMode.state.bags.reason)
		assert.falsy(SB.SafeMode.IsOn("bank"))
	end)

	it("a wrong enum value fails with expected/got detail", function()
		A.globals.Enum.BankType.Account = 1
		local failed = SB.Checks.Failed(SB.Checks.Run(), true, "bank")
		assert.equal(1, #failed)
		assert.equal("expected 2, got 1", failed[1].detail)
	end)

	it("an optional failure never turns on Safe Mode", function()
		A.globals.C_ToyBox = nil
		local results = SB.Checks.Run()
		assert.equal(1, #SB.Checks.Failed(results))
		assert.equal(0, #SB.Checks.Failed(results, true))
		assert.same({}, SB.Checks.Apply(results))
	end)

	it("Lines prints one line per check and a summary", function()
		A.globals.C_ToyBox = nil
		local lines = SB.Checks.Lines(SB.Checks.Run())
		assert.equal(#A.CHECKS + 1, #lines)
		assert.equal("|cff44ff44PASS|r C_Container.GetContainerNumSlots", lines[1])
		local summary = ("Checks: %d passed, 1 failed (0 required)."):format(#A.CHECKS - 1)
		assert.equal(summary, lines[#lines])
	end)

	-- Mutation: Checks.Run (or A.CheckExpected) ignoring foreverValue.
	it("on Forever the warband bank's first ID is checked against 15", function()
		A.globals.Enum.BagIndex.AccountBankTab_1 = 15
		A.flavor = "forever"
		assert.same({}, SB.Checks.Failed(SB.Checks.Run(), true, "bank"))
	end)

	-- Characterization (passes before and after Task 2). Mutation: using foreverValue on both clients.
	it("on Retail, 15 still fails the warband check", function()
		A.globals.Enum.BagIndex.AccountBankTab_1 = 15
		A.flavor = "retail"
		local failed = SB.Checks.Failed(SB.Checks.Run(), true, "bank")
		assert.equal(1, #failed)
		assert.equal("Enum.BagIndex.AccountBankTab_1", failed[1].name)
		assert.equal("expected 12, got 15", failed[1].detail)
	end)
end)

describe("Adapter pure helpers", function()
	local A
	before_each(function()
		A = Loader.New().Adapter
	end)

	it("BagKind maps bag IDs to locations and bank tab numbers", function()
		assert.same({ "backpack" }, { A.BagKind(0) })
		assert.same({ "bags" }, { A.BagKind(4) })
		assert.same({ "reagentbag" }, { A.BagKind(5) })
		assert.same({ "bank", 2 }, { A.BagKind(7) })
		assert.same({ "warband", 2 }, { A.BagKind(13) })
		assert.same({}, { A.BagKind(99) })
	end)

	it("BindKind maps bind types to names", function()
		assert.equal("pickup", A.BindKind(1))
		assert.equal("equip", A.BindKind(2))
		assert.equal("wue", A.BindKind(9))
		assert.equal("none", A.BindKind(42))
		assert.is_nil(A.BindKind(nil))
	end)
end)
