-- SwagBag query tokenizer (spec 7.2). Pure Lua.
-- Token: { type, value, s, e } with 1-based character span s..e.
-- Types: WORD, STRING, OP (= < <= > >=), AND (&), OR (|), NOT (!), LPAREN, RPAREN,
--        HASH (#), EOF. A WORD is any run of characters that are not whitespace
--        and not one of  & | ! ( ) # " = < >
-- Errors are returned as { position, expected, got } (expected is a code, see Query.FormatError).
local _, SB = ...

local Lexer = {}
SB.QueryLexer = Lexer

local SINGLE = { ["&"] = "AND", ["|"] = "OR", ["!"] = "NOT", ["("] = "LPAREN", [")"] = "RPAREN", ["#"] = "HASH" }
local STOP = "[%s&|!()#\"=<>]"

function Lexer.Tokenize(text)
	local tokens, i, n = {}, 1, #text
	while i <= n do
		local c = text:sub(i, i)
		if c:find("%s") then
			i = i + 1
		elseif SINGLE[c] then
			tokens[#tokens + 1] = { type = SINGLE[c], value = c, s = i, e = i }
			i = i + 1
		elseif c == "<" or c == ">" then
			if text:sub(i + 1, i + 1) == "=" then
				tokens[#tokens + 1] = { type = "OP", value = c .. "=", s = i, e = i + 1 }
				i = i + 2
			else
				tokens[#tokens + 1] = { type = "OP", value = c, s = i, e = i }
				i = i + 1
			end
		elseif c == "=" then
			tokens[#tokens + 1] = { type = "OP", value = "=", s = i, e = i }
			i = i + 1
		elseif c == "\"" then
			local close = text:find("\"", i + 1, true)
			if not close then
				return nil, { position = n + 1, expected = "QUOTE", got = "" }
			end
			tokens[#tokens + 1] = { type = "STRING", value = text:sub(i + 1, close - 1), s = i, e = close }
			i = close + 1
		else
			local j = text:find(STOP, i) or (n + 1)
			tokens[#tokens + 1] = { type = "WORD", value = text:sub(i, j - 1), s = i, e = j - 1 }
			i = j
		end
	end
	tokens[#tokens + 1] = { type = "EOF", value = "", s = n + 1, e = n + 1 }
	return tokens
end
