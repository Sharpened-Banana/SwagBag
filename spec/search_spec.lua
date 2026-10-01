local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua", "SwagBag/Engine/Search.lua",
}

describe("Search", function()
	local SB, S, slots, dimmed
	before_each(function()
		SB = Loader.New(FILES)
		S = SB.Search
		Fixtures.SmallBags(SB.Adapter)
		SB.Adapter.Put(0, 7, Fixtures.UNLOADED, 1)
		slots = {}
		for slot = 1, 8 do -- 1-6 items, 7 unloaded, 8 empty
			slots[slot] = { button = "b" .. slot, record = SB.Items.Describe(0, slot) }
		end
		dimmed = {}
	end)

	local function forEach(fn)
		for _, s in ipairs(slots) do
			fn(s.button, s.record)
		end
	end
	local function setDimmed(button, d)
		dimmed[button] = d
	end
	local function dimList()
		local out = {}
		for slot = 1, 8 do
			if dimmed["b" .. slot] then
				out[#out + 1] = slot
			end
		end
		return out
	end

	it("with no search nothing is dimmed", function()
		assert.truthy(S.SetText(""))
		assert.falsy(S.IsActive())
		local matches, total = S.Apply(forEach, setDimmed)
		assert.equal(8, matches)
		assert.equal(8, total)
		assert.same({}, dimList())
	end)

	it("dims everything that is not a definite match, including empty and unloaded slots", function()
		assert.truthy(S.SetText("gear"))
		local matches, total = S.Apply(forEach, setDimmed)
		assert.equal(3, matches) -- ring, helm, and the unloaded chest (armor is an instant fact)
		assert.equal(8, total)
		assert.same({ 1, 2, 5, 6, 8 }, dimList())
		S.SetText("boe")
		S.Apply(forEach, setDimmed)
		assert.same({ 1, 2, 4, 5, 6, 7, 8 }, dimList(), "unloaded item's boe is unknown -> dimmed")
	end)

	it("keeps the previous valid search when the new text has an error", function()
		S.SetText("potion")
		local ok, message = S.SetText("potion &")
		assert.falsy(ok)
		assert.equal("Expected a value after \"&\" at character 9", message)
		assert.equal(9, S.lastError.position)
		assert.equal("potion", S.text)
		S.Apply(forEach, setDimmed)
		assert.same({ 2, 3, 4, 5, 6, 7, 8 }, dimList())
	end)

	it("an unknown #keyword applies (matches nothing) and leaves a soft warning", function()
		assert.truthy(S.SetText("#potin"))
		assert.is_nil(S.lastError)
		assert.equal("Unknown keyword \"#potin\" matches nothing (character 1)", S.lastWarning)
		assert.equal(0, (S.Apply(forEach, setDimmed)))
		assert.truthy(S.SetText("potion"))
		assert.is_nil(S.lastWarning)
	end)

	it("a valid search after an error clears the error", function()
		S.SetText("(junk")
		assert.truthy(S.lastError)
		assert.truthy(S.SetText("junk"))
		assert.is_nil(S.lastError)
	end)

	it("re-evaluates 200 slots well under the 4 ms budget (spec AC5.4)", function()
		local many = {}
		for i = 1, 200 do
			many[i] = slots[(i % 7) + 1].record
		end
		S.SetText("(gear & ilvl>280 & !bound) | potion | \"tooth\"")
		local t0 = os.clock()
		for _ = 1, 10 do
			for i = 1, 200 do
				SB.Query.Eval(S.active, many[i])
			end
		end
		local perPassMs = (os.clock() - t0) * 1000 / 10
		assert.truthy(perPassMs < 4, ("%.3f ms per 200 slots"):format(perPassMs))
	end)

	it("does not recompile an unchanged query", function()
		S.SetText("gear")
		local first = S.active
		assert.truthy(S.SetText("gear"))
		assert.equal(first, S.active)
	end)

	it("an evaluation error is trapped: previous dimming kept, search shown as invalid, error recorded", function()
		S.SetText("gear")
		S.Apply(forEach, setDimmed)
		local before = dimList()
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function() error("keyword exploded") end })
		assert.truthy(S.SetText("boom"))
		local r
		local ok = pcall(function()
			r = { S.Apply(forEach, setDimmed) }
		end)
		assert.truthy(ok)
		assert.is_nil(r[1])
		local message = r[4]
		assert.truthy(S.lastEvalError)
		assert.truthy(message)
		assert.same(before, dimList(), "dim state untouched by the failed pass")
		local recorded = SB.ErrorTrap.Recent()[1]
		assert.equal("search.eval", recorded.label)
		assert.equal("none", recorded.window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
		-- a later good search recovers
		S.SetText("gear")
		assert.truthy(S.Apply(forEach, setDimmed))
		assert.is_nil(S.lastEvalError)
	end)

	describe("ErrorSpan (byte offsets, never past the end)", function()
		it("underlines the offending token", function()
			local err = { position = 6, expected = "NUMERIC", got = "foo" }
			local a, b = S.ErrorSpan("junk foo", err)
			assert.equal(6, a)
			assert.equal(8, b)
		end)
		it("a trailing operator underlines the token before EOF", function()
			local text = "potion &"
			local _, err = SB.QueryParser.Parse(text)
			local a, b = S.ErrorSpan(text, err)
			assert.equal("&", text:sub(a, b))
			assert.truthy(b <= #text)
		end)
		it("a trailing operator after trailing spaces stays inside the text", function()
			local text = "boe &  "
			local _, err = SB.QueryParser.Parse(text)
			local a, b = S.ErrorSpan(text, err)
			assert.equal("&", text:sub(a, b))
		end)
		it("clamps an oversized token and handles empty text", function()
			local a, b = S.ErrorSpan("ab", { position = 2, got = "bcdefg" })
			assert.equal(2, a)
			assert.equal(2, b)
			a, b = S.ErrorSpan("", { position = 1, got = "" })
			assert.equal(0, b)
			assert.truthy(a >= 1)
		end)
	end)
end)
