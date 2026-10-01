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
	local P, Lexer
	before_each(function()
		local SB = Loader.New({ "SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua" })
		P = SB.QueryParser
		Lexer = SB.QueryLexer
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

	it("reads Syndicator-style bare item levels: <N and >N include N, =N and N are equal", function()
		assert.same({ type = "num", name = "ilvl", op = "<=", value = 536, raw = "536" }, parse("<536"))
		assert.same({ type = "num", name = "ilvl", op = ">=", value = 150, raw = "150" }, parse("> 150"))
		assert.same({ type = "num", name = "ilvl", op = "=", value = 536, raw = "536" }, parse("=536"))
		assert.same({ type = "num", name = "ilvl", op = "=", value = 536, raw = "536" }, parse("536"))
		assert.same({ type = "num", name = "ilvl", op = "<=", value = 80, raw = "80" }, parse("<=80"))
		assert.same({ type = "num", name = "ilvl", op = "<=", value = 536, s = 1, e = 4, raw = "536" }, P.Parse("<536"))
	end)

	it("reads N-M as an inclusive item-level range, in either order", function()
		local range = { type = "and", items = {
			{ type = "num", name = "ilvl", op = ">=", value = 400, raw = "400" },
			{ type = "num", name = "ilvl", op = "<=", value = 450, raw = "450" } } }
		assert.same(range, parse("400-450"))
		assert.same(range, parse("450-400"))
	end)

	it("keeps numbers inside phrases and other hyphenated words as name text", function()
		assert.same({ type = "word", value = "potion 2" }, parse("potion 2"))
		assert.same({ type = "word", value = "Ara-Kara" }, parse("Ara-Kara"))
		assert.same({ type = "word", value = "1-2-3" }, parse("1-2-3"))
	end)

	it("combines bare levels with keywords, ~ and || as published Baganator strings do", function()
		assert.same({ type = "and", items = { { type = "exact", value = "gear" },
			{ type = "num", name = "ilvl", op = "<=", value = 536, raw = "536" } } }, parse("#gear&<536"))
		assert.same({ type = "or", items = { { type = "not", item = W("a") }, W("b") } }, parse("~a || b"))
		assert.same({ type = "and", items = { { type = "word", value = "a b" },
			{ type = "num", name = "ilvl", op = ">=", value = 5, raw = "5" } } }, parse("a b & >5"))
	end)

	it("reports a bare comparison without a number", function()
		local _, err = P.Parse("<")
		assert.same({ position = 2, expected = "NUMBER", got = "", after = "<" }, err)
		_, err = P.Parse("#gear & >x")
		assert.same({ position = 10, expected = "NUMBER", got = "x", after = ">" }, err)
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

	it("reports empty query", function()
		local _, err = P.Parse("")
		assert.same({ position = 1, expected = "VALUE", got = "" }, err)
	end)

	it("reports lone NOT operator", function()
		local _, err = P.Parse("!")
		assert.same({ position = 2, expected = "VALUE", got = "", after = "!" }, err)
	end)

	it("reports trailing AND operator", function()
		local _, err = P.Parse("a &")
		assert.same({ position = 4, expected = "VALUE", got = "", after = "&" }, err)
	end)

	it("parses combined precedence !a & b | c", function()
		local expected = {
			type = "or",
			items = {
				{ type = "and", items = { { type = "not", item = W("a") }, W("b") } },
				W("c")
			}
		}
		assert.same(expected, parse("!a & b | c"))
	end)

	it("allows multi-word phrases with logical operators", function()
		assert.same({ type = "and", items = { { type = "word", value = "a b" }, W("c") } }, parse("a b & c"))
		assert.same({ type = "and", items = { W("a"), { type = "word", value = "b c" } } }, parse("a & b c"))
	end)

	it("rejects multi-word phrase before comparison operator", function()
		local _, err = P.Parse("a b ilvl>5")
		assert.same({ position = 1, expected = "AND_BEFORE_COMPARISON", got = ">", after = "ilvl" }, err)
	end)

	it("handles deep nesting without throwing", function()
		local ast, err = P.Parse(string.rep("(", 1000) .. "a")
		assert.is_nil(ast)
		assert.truthy(err)
		assert.equal("SHALLOWER", err.expected)

		ast, err = P.Parse(string.rep("!", 1000) .. "a")
		assert.is_nil(ast)
		assert.truthy(err)
		assert.equal("SHALLOWER", err.expected)
	end)

	it("applies the depth limit to ~ chains and mixed ~/! chains like ! chains", function()
		local ast, err = P.Parse(string.rep("~", 1000) .. "a")
		assert.is_nil(ast)
		assert.equal("SHALLOWER", err.expected)
		ast, err = P.Parse(string.rep("~!", 500) .. "a")
		assert.is_nil(ast)
		assert.equal("SHALLOWER", err.expected)
		assert.truthy(P.Parse(string.rep("~", 100) .. "a"))
		local ast101, err101 = P.Parse(string.rep("~", 101) .. "a")
		assert.is_nil(ast101)
		assert.equal("SHALLOWER", err101.expected)
	end)

	it("never throws on any mix of the new syntax; errors point inside the text", function()
		local pieces = { "||", "|", "&", "~", "!", "(", ")", "\"", "<", "<=", ">", ">=", "=", "#", "1", "285", "99999999999999999999", "5-9",
			"9-5", "-", "0x10", "a", "boe", "gear", "potion", "ilvl", "a b", "Ara-Kara", "1-2-3", "x", " " }
		local seed = 12345
		local function rnd(n)
			seed = seed * 16807 % 2147483647 -- Park-Miller, exact in doubles
			return seed % n + 1
		end
		local distinct, nDistinct = {}, 0
		for _ = 1, 2000 do
			local parts = {}
			for i = 1, rnd(8) do
				parts[i] = pieces[rnd(#pieces)]
			end
			local text = table.concat(parts, rnd(2) == 1 and " " or "")
			if not distinct[text] then
				distinct[text] = true
				nDistinct = nDistinct + 1
			end
			local ok, ast, err = pcall(function()
				Lexer.Tokenize(text)
				return P.Parse(text)
			end)
			assert.truthy(ok, text)
			if ast == nil then
				assert.truthy(type(err) == "table" and err.position >= 1 and err.position <= #text + 1, text)
			end
		end
		assert.truthy(nDistinct > 1000, "generator is degenerate: " .. nDistinct)
	end)

	it("allows exactly 100 levels of nesting", function()
		local ast = P.Parse(string.rep("(", 100) .. "a" .. string.rep(")", 100))
		assert.truthy(ast)
		assert.equal("word", ast.type)
	end)
end)
