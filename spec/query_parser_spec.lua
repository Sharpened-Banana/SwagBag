local Loader = dofile("spec/helpers/loader.lua")

-- Remove spans so tree shapes are easy to compare.
local function strip(node)
	if type(node) ~= "table" then
		return node
	end
	local out = {}
	for k, v in pairs(node) do
		if k ~= "s" and k ~= "e" then
			out[k] = strip(v)
		end
	end
	return out
end

local function W(v) return { type = "word", value = v } end

describe("Query parser", function()
	local P
	before_each(function()
		local SB = Loader.New({ "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua" })
		P = SB.QueryParser
	end)

	local function parse(text)
		return strip((P.Parse(text)))
	end

	it("parses a single word with its span", function()
		assert.same({ type = "word", value = "gear", s = 1, e = 4 }, P.Parse("gear"))
	end)

	it("joins adjacent words into one phrase", function()
		assert.same({ type = "word", value = "healing potion", s = 1, e = 15 }, P.Parse("healing  potion"))
	end)

	it("parses quoted text, #exact and numeric terms", function()
		assert.same({ type = "text", value = "Healing Potion" }, parse("\"Healing Potion\""))
		assert.same({ type = "exact", value = "rune" }, parse("#rune"))
		assert.same({ type = "num", name = "ilvl", op = ">=", value = 250, raw = "250" }, parse("ilvl >= 250"))
	end)

	it("gives & precedence over |", function()
		assert.same({ type = "or", items = { W("a"), { type = "and", items = { W("b"), W("c") } } } }, parse("a | b & c"))
	end)

	it("gives ! precedence over &", function()
		assert.same({ type = "and", items = { { type = "not", item = W("a") }, W("b") } }, parse("!a & b"))
	end)

	it("lets parentheses override precedence", function()
		assert.same({ type = "and", items = { { type = "or", items = { W("a"), W("b") } }, W("c") } }, parse("(a | b) & c"))
	end)

	it("flattens chains of the same operator", function()
		assert.same({ type = "and", items = { W("a"), W("b"), W("c") } }, parse("a & b & c"))
	end)

	it("records spans on combined nodes", function()
		local ast = P.Parse("boe & ilvl>250")
		assert.equal(1, ast.s)
		assert.equal(14, ast.e)
		assert.equal(7, ast.items[2].s)
	end)

	it("reports a missing value after & with position and the token before", function()
		local ast, err = P.Parse("boe &")
		assert.is_nil(ast)
		assert.same({ position = 6, expected = "VALUE", got = "", after = "&" }, err)
	end)

	it("reports a missing or bad number after an operator", function()
		local _, err = P.Parse("ilvl>")
		assert.same({ position = 6, expected = "NUMBER", got = "", after = ">" }, err)
		_, err = P.Parse("ilvl>abc")
		assert.same({ position = 6, expected = "NUMBER", got = "abc", after = ">" }, err)
	end)

	it("reports unbalanced and empty parentheses", function()
		local _, err = P.Parse("(boe")
		assert.same({ position = 5, expected = "RPAREN", got = "", after = "boe" }, err)
		_, err = P.Parse("()")
		assert.same({ position = 2, expected = "VALUE", got = ")", after = "(" }, err)
		_, err = P.Parse("boe)")
		assert.same({ position = 4, expected = "OPERATOR", got = ")", after = "boe" }, err)
	end)

	it("reports # without a keyword and passes lexer errors through", function()
		local _, err = P.Parse("# & boe")
		assert.same({ position = 3, expected = "KEYWORD", got = "&", after = "#" }, err)
		_, err = P.Parse("\"open")
		assert.same({ position = 6, expected = "QUOTE", got = "" }, err)
	end)
end)
