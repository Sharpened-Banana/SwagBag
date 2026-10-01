-- SwagBag query parser (spec 7.2). Pure Lua. Precedence: ! > & > | ; parentheses override.
--   or      := and ( "|" and )*
--   and     := not ( "&" not )*
--   not     := "!" not | primary
--   primary := "(" or ")" | STRING | "#" phrase | phrase [ OP NUMBER ]
--   phrase  := WORD+            adjacent words form ONE phrase (spec 7.5 #1)
-- AST nodes (every node has a 1-based character span s..e):
--   { type = "or" | "and", items = {...} }      { type = "not", item = node }
--   { type = "word", value }   bare word/phrase: keyword if registered, else name text
--   { type = "exact", value }  #word: keyword only
--   { type = "text", value }   "quoted": always name text
--   { type = "num", name, op, value = number, raw = string }
-- Parse(text) -> ast | nil, { position, expected, got, after }
local _, SB = ...

local Parser = {}
SB.QueryParser = Parser

function Parser.Parse(text)
	local tokens, lexErr = SB.QueryLexer.Tokenize(text)
	if not tokens then
		return nil, lexErr
	end
	local pos = 1

	local function peek()
		return tokens[pos]
	end

	local function fail(expected)
		local tok, prev = tokens[pos], tokens[pos - 1]
		error({
			isQueryError = true,
			position = tok.s,
			expected = expected,
			got = tok.type == "EOF" and "" or tok.value,
			after = prev and prev.value or nil,
		}, 0)
	end

	local function phrase()
		local first, last = tokens[pos], tokens[pos]
		local words = { first.value }
		pos = pos + 1
		while tokens[pos].type == "WORD" do
			last = tokens[pos]
			words[#words + 1] = last.value
			pos = pos + 1
		end
		return table.concat(words, " "), first.s, last.e
	end

	local parseOr

	local function parsePrimary()
		local tok = peek()
		if tok.type == "LPAREN" then
			pos = pos + 1
			if peek().type == "RPAREN" then
				fail("VALUE")
			end
			local inner = parseOr()
			if peek().type ~= "RPAREN" then
				fail("RPAREN")
			end
			pos = pos + 1
			return inner
		elseif tok.type == "STRING" then
			pos = pos + 1
			return { type = "text", value = tok.value, s = tok.s, e = tok.e }
		elseif tok.type == "HASH" then
			pos = pos + 1
			if peek().type ~= "WORD" then
				fail("KEYWORD")
			end
			local value, _, e = phrase()
			return { type = "exact", value = value, s = tok.s, e = e }
		elseif tok.type == "WORD" then
			local value, s, e = phrase()
			if peek().type ~= "OP" then
				return { type = "word", value = value, s = s, e = e }
			end
			local op = peek()
			pos = pos + 1
			local num = peek()
			local n = num.type == "WORD" and tonumber(num.value) or nil
			if n == nil then
				fail("NUMBER")
			end
			pos = pos + 1
			return { type = "num", name = value, op = op.value, value = n, raw = num.value, s = s, e = num.e }
		end
		fail("VALUE")
	end

	local function parseNot()
		local tok = peek()
		if tok.type == "NOT" then
			pos = pos + 1
			local item = parseNot()
			return { type = "not", item = item, s = tok.s, e = item.e }
		end
		return parsePrimary()
	end

	local function chain(kind, tokenType, sub)
		local first = sub()
		if peek().type ~= tokenType then
			return first
		end
		local node = { type = kind, items = { first }, s = first.s }
		while peek().type == tokenType do
			pos = pos + 1
			node.items[#node.items + 1] = sub()
		end
		node.e = node.items[#node.items].e
		return node
	end

	local function parseAnd()
		return chain("and", "AND", parseNot)
	end

	parseOr = function()
		return chain("or", "OR", parseAnd)
	end

	local ok, result = pcall(function()
		local ast = parseOr()
		if peek().type ~= "EOF" then
			fail("OPERATOR")
		end
		return ast
	end)
	if ok then
		return result
	end
	if type(result) == "table" and result.isQueryError then
		result.isQueryError = nil
		return nil, result
	end
	error(result, 0)
end
