local Loader = dofile("spec/helpers/loader.lua")

-- "TYPE:value@s-e" strings, easy to compare.
local function brief(tokens)
	local out = {}
	for i, t in ipairs(tokens) do
		out[i] = t.type .. ":" .. t.value .. "@" .. t.s .. "-" .. t.e
	end
	return out
end

describe("Query lexer", function()
	local Lexer
	before_each(function()
		Lexer = Loader.New({ "SwagBag/Engine/Query/Lexer.lua" }).QueryLexer
	end)

	it("splits words and operators with character spans", function()
		assert.same({ "WORD:gear@1-4", "AND:&@6-6", "WORD:ilvl@8-11", "OP:>@12-12", "WORD:280@13-15", "EOF:@16-16" },
			brief(Lexer.Tokenize("gear & ilvl>280")))
	end)

	it("reads two-character operators", function()
		assert.same({ "WORD:lvl@1-3", "OP:>=@4-5", "WORD:80@6-7", "EOF:@8-8" }, brief(Lexer.Tokenize("lvl>=80")))
		assert.same({ "WORD:count@1-5", "OP:<=@6-7", "WORD:5@8-8", "EOF:@9-9" }, brief(Lexer.Tokenize("count<=5")))
		assert.same({ "WORD:tab@1-3", "OP:=@4-4", "WORD:2@5-5", "EOF:@6-6" }, brief(Lexer.Tokenize("tab=2")))
	end)

	it("reads !, |, parentheses and # as single tokens", function()
		assert.same({ "NOT:!@1-1", "LPAREN:(@2-2", "HASH:#@3-3", "WORD:rune@4-7", "OR:|@9-9", "WORD:x@11-11",
			"RPAREN:)@12-12", "EOF:@13-13" }, brief(Lexer.Tokenize("!(#rune | x)")))
	end)

	it("reads a quoted string as one STRING token spanning its quotes", function()
		assert.same({ "STRING:Healing Potion@1-16", "EOF:@17-17" }, brief(Lexer.Tokenize("\"Healing Potion\"")))
	end)

	it("keeps punctuation that is not an operator inside words", function()
		assert.same({ "WORD:Ara-Kara@1-8", "WORD:it's@10-13", "EOF:@14-14" }, brief(Lexer.Tokenize("Ara-Kara it's")))
	end)

	it("reports an unterminated quote at the end of the text", function()
		local tokens, err = Lexer.Tokenize("boe & \"heal")
		assert.is_nil(tokens)
		assert.same({ position = 12, expected = "QUOTE", got = "" }, err)
	end)

	it("returns only EOF for empty or blank text", function()
		assert.same({ "EOF:@1-1" }, brief(Lexer.Tokenize("")))
		assert.same({ "EOF:@4-4" }, brief(Lexer.Tokenize("   ")))
	end)

	-- Review Focus #5: odd input never throws
	it("does not throw on pattern characters", function()
		assert.truthy(Lexer.Tokenize("100%"))
		assert.truthy(Lexer.Tokenize("[a-z]"))
		assert.truthy(Lexer.Tokenize("%1 ("))
	end)

	it("keeps apostrophes and hyphens in multi-word compound names", function()
		assert.same({ "WORD:Hunter's@1-8", "WORD:Jack-o'-Lantern@10-24", "EOF:@25-25" },
			brief(Lexer.Tokenize("Hunter's Jack-o'-Lantern")))
	end)

	it("reports error for a lone unterminated quote", function()
		local tokens, err = Lexer.Tokenize("\"")
		assert.is_nil(tokens)
		assert.same({ position = 2, expected = "QUOTE", got = "" }, err)
	end)

	it("handles quotes within mixed text", function()
		assert.same({ "WORD:a@1-1", "STRING:b@2-4", "WORD:c@5-5", "EOF:@6-6" },
			brief(Lexer.Tokenize("a\"b\"c")))
	end)

	it("tokenizes empty quoted strings", function()
		assert.same({ "STRING:@1-2", "EOF:@3-3" }, brief(Lexer.Tokenize("\"\"")))
	end)

	it("tokenizes operators at the end of text", function()
		assert.same({ "OP:<@1-1", "EOF:@2-2" }, brief(Lexer.Tokenize("<")))
		assert.same({ "OP:>@1-1", "EOF:@2-2" }, brief(Lexer.Tokenize(">")))
		assert.same({ "OP:>=@1-2", "EOF:@3-3" }, brief(Lexer.Tokenize(">=")))
		assert.same({ "OP:<=@1-2", "EOF:@3-3" }, brief(Lexer.Tokenize("<=")))
	end)

	it("handles nil input by treating it as empty", function()
		assert.same({ "EOF:@1-1" }, brief(Lexer.Tokenize(nil)))
	end)

	it("uses byte offsets, not UTF-8 character positions", function()
		assert.same({ "WORD:café@1-5", "WORD:x@7-7", "EOF:@8-8" },
			brief(Lexer.Tokenize("café x")))
	end)
end)
