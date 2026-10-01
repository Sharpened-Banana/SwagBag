local Loader = dofile("spec/helpers/loader.lua")

describe("Init and test harness", function()
	local SB
	before_each(function()
		SB = Loader.New()
	end)

	it("SB.Print prefixes the line and sends it through the Adapter", function()
		SB.Print("hello")
		assert.equal("|cff33ff99SwagBag|r: hello", SB.Adapter.printed[1])
		assert.same({ "hello" }, SB.Adapter.Lines())
	end)

	it("has a version string", function()
		assert.equal("string", type(SB.VERSION))
		assert.truthy(SB.VERSION:match("^%d+%.%d+%.%d+"))
	end)

	it("mock timers run in time order when the clock advances", function()
		local A, order = SB.Adapter, {}
		A.After(2, function() order[#order + 1] = "b" end)
		A.After(0.5, function() order[#order + 1] = "a" end)
		A.Advance(1)
		assert.same({ "a" }, order)
		A.Advance(2)
		assert.same({ "a", "b" }, order)
		assert.equal(3, A.Now())
	end)

	it("mock Resolve walks dotted paths and returns nil when missing", function()
		local A = SB.Adapter
		A.globals = { C_Container = { SortBags = print } }
		assert.equal(print, A.Resolve("C_Container.SortBags"))
		assert.is_nil(A.Resolve("C_Container.Nope"))
		assert.is_nil(A.Resolve("C_Bank.FetchPurchasedBankTabIDs"))
	end)
end)
