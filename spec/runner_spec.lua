-- Self-test for spec/runner.lua: the assertions must catch what they claim to.
describe("runner assertions", function()
	it("equal passes on identical values and fails otherwise", function()
		assert.equal(3, 3)
		assert.falsy(pcall(assert.equal, 3, 4))
	end)

	it("same compares nested tables deeply", function()
		assert.same({ a = { 1, 2 }, b = "x" }, { a = { 1, 2 }, b = "x" })
		assert.falsy(pcall(assert.same, { a = { 1, 2 } }, { a = { 1, 3 } }))
		assert.falsy(pcall(assert.same, { a = 1 }, { a = 1, b = 2 }))
	end)

	it("truthy, falsy and is_nil", function()
		assert.truthy(0)
		assert.falsy(false)
		assert.is_nil(nil)
		assert.falsy(pcall(assert.truthy, nil))
		assert.falsy(pcall(assert.falsy, "x"))
		assert.falsy(pcall(assert.is_nil, false))
	end)

	it("has_error checks that an error happens and contains the text", function()
		assert.has_error(function() error("boom here") end, "boom")
		assert.falsy(pcall(assert.has_error, function() end))
		assert.falsy(pcall(assert.has_error, function() error("other") end, "boom"))
	end)

	it("assert itself is still callable", function()
		assert(true)
		assert.falsy(pcall(assert, false, "nope"))
	end)
end)

describe("runner hooks", function()
	local calls = {}
	before_each(function()
		calls[#calls + 1] = "before"
	end)
	after_each(function()
		calls[#calls + 1] = "after"
	end)

	it("runs before_each before the test", function()
		assert.equal("before", calls[#calls])
	end)

	it("ran after_each after the previous test", function()
		assert.same({ "before", "after", "before" }, calls)
	end)
end)
