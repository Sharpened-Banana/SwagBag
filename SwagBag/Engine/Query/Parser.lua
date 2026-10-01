-- SwagBag query parser (spec 7.2). Pure Lua. Precedence: ! > & > | ; parentheses override.
--   or      := and ( "|" and )*
--   and     := not ( "&" not )*
--   not     := "!" not | primary
--   primary := "(" or ")" | STRING | "#" phrase | OP NUMBER | phrase [ OP NUMBER ]
--   phrase  := WORD+            adjacent words form ONE phrase (spec 7.5 #1)
-- Syndicator-style item level (spec 7.5 #8), always on the "ilvl" keyword:
--   <N >N =N   bare comparison; < and > INCLUDE N (<536 is ilvl<=536)
--   N          a single all-digit word: ilvl=N
--   N-M        a single word: ilvl>=min(N,M) & ilvl<=max(N,M)
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

-- Bare < and > include the number, as in Syndicator.
local INCLUSIVE = { ["<"] = "<=", [">"] = ">=" }

local function levelNode(op, value, raw, s, e)
	return { type = "num", name = "ilvl", op = op, value = value, raw = raw, s = s, e = e }
end

function Parser.Parse(text)
	local tokens, lexErr = SB.QueryLexer.Tokenize(text)
	if not tokens then
		return nil, lexErr
	end
	local pos = 1
	local depth = 0

	local function peek()
		return tokens[pos]
	end

	local function fail(expected, position)
		local tok, prev = tokens[pos], tokens[pos - 1]
		error({
			isQueryError = true,
			position = position or tok.s,
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
		return table.concat(words, " "), first.s, last.e, #words
	end

	local parseOr

	local function parsePrimary()
		local tok = peek()
		if tok.type == "LPAREN" then
			depth = depth + 1
			if depth > 100 then
				fail("SHALLOWER")
			end
			pos = pos + 1
			if peek().type == "RPAREN" then
				fail("VALUE")
			end
			local inner = parseOr()
			if peek().type ~= "RPAREN" then
				fail("RPAREN")
			end
			pos = pos + 1
			depth = depth - 1
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
		elseif tok.type == "OP" then
			pos = pos + 1
			local num = peek()
			local n = num.type == "WORD" and tonumber(num.value) or nil
			if n == nil then
				fail("NUMBER")
			end
			pos = pos + 1
			return levelNode(INCLUSIVE[tok.value] or tok.value, n, num.value, tok.s, num.e)
		elseif tok.type == "WORD" then
			local value, s, e, wordCount = phrase()
			if peek().type ~= "OP" then
				if wordCount == 1 then
					local lo, hi = value:match("^(%d+)%-(%d+)$")
					if lo then
						lo, hi = tonumber(lo), tonumber(hi)
						if lo > hi then
							lo, hi = hi, lo
						end
						return { type = "and", s = s, e = e, items = {
							levelNode(">=", lo, tostring(lo), s, e), levelNode("<=", hi, tostring(hi), s, e) } }
					elseif value:match("^%d+$") then
						return levelNode("=", tonumber(value), value, s, e)
					end
				end
				return { type = "word", value = value, s = s, e = e }
			end
			if wordCount > 1 then
				fail("AND_BEFORE_COMPARISON", s)
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
			depth = depth + 1
			if depth > 100 then
				fail("SHALLOWER")
			end
			pos = pos + 1
			local item = parseNot()
			depth = depth - 1
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
