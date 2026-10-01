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

describe("Adapter pure functions (real code)", function()
	it("Resolve walks dotted paths via _G and returns nil when missing", function()
		-- Set up temporary globals
		_G.TEST_RESOLVE_NS = { SortBags = print }
		_G.TEST_RESOLVE_FN = function() end

		-- Test the real Adapter's Resolve via the global _G
		local ok, result = pcall(function()
			local chunk = assert(loadfile("SwagBag/Core/Adapter.lua"))
			local SB = {}
			chunk("SwagBag", SB)
			local A = SB.Adapter

			-- Test successful resolution
			assert.equal(print, A.Resolve("TEST_RESOLVE_NS.SortBags"))
			assert.equal(_G.TEST_RESOLVE_FN, A.Resolve("TEST_RESOLVE_FN"))

			-- Test missing keys
			assert.is_nil(A.Resolve("TEST_RESOLVE_NS.Missing"))
			assert.is_nil(A.Resolve("MISSING.Path"))

			-- Test path through non-table returns nil
			assert.is_nil(A.Resolve("TEST_RESOLVE_FN.property"))
		end)

		-- Clean up
		_G.TEST_RESOLVE_NS = nil
		_G.TEST_RESOLVE_FN = nil

		assert.truthy(ok, result)
	end)

	it("IsSecret checks for issecretvalue builtin", function()
		local ok, result = pcall(function()
			local chunk = assert(loadfile("SwagBag/Core/Adapter.lua"))
			local SB = {}
			chunk("SwagBag", SB)
			local A = SB.Adapter

			-- In test environment issecretvalue doesn't exist, so IsSecret returns false
			assert.equal(false, A.IsSecret("test"))
			assert.equal(false, A.IsSecret(123))
			assert.equal(false, A.IsSecret(print))
		end)

		assert.truthy(ok, result)
	end)
end)
