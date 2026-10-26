-- SwagBag paste import (week 11, spec F6 AC6.3): a search or category string copied from Baganator (its search
-- language, spec 7.1) read into SwagBag's query language. Pure Lua: reads SB.QueryLexer and SB.Query only. The
-- pasted text is only read with the lexer and patterns: nothing in it is ever run, and nothing is stored here.
-- The languages are nearly the same (spec 7.1, 7.5); what Paste changes, adds a note for, or refuses:
--   the same in both            & | ! ~ || ( ) #word  N =N <N >N N-M  bare words  (passed through as they are)
--   !! and ~~ (and longer runs)  one ! (Baganator reads one NOT; SwagBag would read NOT NOT)       note "NOTS"
--   ( left open at the end      closed with ) at the end (Baganator closes them)                 note "PARENS"
--   >Ng <Ns =Nc Ng Ng-Mg        value>=N  value<=N/100  value=N/10000  value=N  (value>=N & value<=M)
--                               (gold per item; Baganator's < and > include the amount)            note "GOLD"
--   N, <N, >N, N-M              the same item-level tests; SwagBag counts gear only               note "ILVL"
--   #word SwagBag doesn't know  kept: it matches nothing, as in Baganator                         note "UNKNOWN"
--   a bare word that is not one of SwagBag's keywords: kept, it matches item names only (Baganator also tried
--                               keywords starting with it and some tooltip lines)                  note "NAME"
--   a bare keyword that other keywords start with (key: keystone): kept, it is that keyword only (Baganator also
--                               matched the ones starting with it)                                 note "ALSO"
--   upgrade, bop                kept: the same word means something else in SwagBag (spec 7.5 #10) note "DIFFERENT"
-- Refused whole, with the reason (never half a string: dropping one term of an AND or an OR changes which items
-- match, silently): empty, longer than MAX characters (Query.MAX_QUERY, a category's limit), a chat code
-- (|c........ |T |H |A |K |cnNAME:, Query.EscapeCode), a double quote (a letter for Baganator, the start of a quoted
-- name for SwagBag), anything SwagBag can't read (a stray ), an operator with nothing after it, a name before a
-- comparison...: the error and where, in the pasted text), or a string its gold amounts grow past MAX once read.
--   Paste.Translate(text) -> { query, notes = { { kind, value } } } | nil, why, detail
--     why: "EMPTY" | "LONG" (detail: its length) | "CODE" | "QUOTE" (detail: its character) | "ERROR" (detail: the
--     error in words, positioned in the pasted text) | "GROWN" (detail: its length once read as SwagBag's rule)
local _, SB = ...

local Paste = { MAX = SB.Query.MAX_QUERY }
SB.QueryPaste = Paste

local MONEY = { g = 1, s = 0.01, c = 0.0001 }
local INCLUSIVE = { ["<"] = "<=", [">"] = ">=", ["="] = "=", ["<="] = "<=", [">="] = ">=" }
local DIFFERENT = { upgrade = true, bop = true }
-- 0.16.0: phrases that only narrow the word they start with (cloth already finds cloth armor), so no ALSO note.
local NARROWS = { ["cloth armor"] = true, ["cloth material"] = true, ["leather armor"] = true,
	["leather material"] = true }
local TERM_START = { AND = true, OR = true, NOT = true, LPAREN = true }

-- Gold as SwagBag's value keyword reads it: a plain number, never an exponent ("1e+06").
local function gold(digits, unit)
	local n = tonumber(digits) * MONEY[unit:lower()]
	if n == math.floor(n) then
		return string.format("%d", n)
	end
	return (string.format("%.4f", n):gsub("0+$", ""))
end

local function amount(word)
	local digits, unit = word:match("^(%d+)([gGsScC])$")
	if digits and #digits <= 9 then
		return gold(digits, unit)
	end
end

local function addNote(notes, seen, kind, value)
	local key = kind .. ":" .. (value or "")
	if not seen[key] then
		seen[key] = true
		notes[#notes + 1] = { kind = kind, value = value }
	end
end

-- Where a character of the translated text came from in the pasted one.
local function original(edits, position)
	local shift = 0
	for _, e in ipairs(edits) do
		if position < e.s + shift then
			break
		elseif position <= e.s + shift + #e.new - 1 then
			return e.s
		end
		shift = shift + #e.new - (e.e - e.s + 1)
	end
	return position - shift
end

local function walk(node, fn)
	fn(node)
	for _, child in ipairs(node.items or {}) do
		walk(child, fn)
	end
	if node.item then
		walk(node.item, fn)
	end
end

function Paste.Translate(text)
	if type(text) ~= "string" then
		return nil, "EMPTY"
	end
	text = text:gsub("%c", " "):match("^%s*(.-)%s*$")
	if text == "" then
		return nil, "EMPTY"
	elseif #text > Paste.MAX then
		return nil, "LONG", #text
	elseif SB.Query.EscapeCode(text) then
		return nil, "CODE" -- the one chat-code check (Query.EscapeCode), as share strings and the editor
	end
	local quote = text:find("\"", 1, true)
	if quote then
		return nil, "QUOTE", quote
	end
	local tokens = SB.QueryLexer.Tokenize(text)
	local notes, seen, edits = {}, {}, {}
	local depth, i = 0, 1
	while tokens[i].type ~= "EOF" do
		local t, prev, nxt = tokens[i], tokens[i - 1], tokens[i + 1]
		local starts = prev == nil or TERM_START[prev.type]
		if t.type == "NOT" and nxt.type == "NOT" then
			local j = i
			while tokens[j + 1].type == "NOT" do
				j = j + 1
			end
			edits[#edits + 1] = { s = t.s, e = tokens[j].e, new = "!" }
			addNote(notes, seen, "NOTS")
			i = j
		elseif t.type == "OP" and starts and nxt.type == "WORD" and tokens[i + 2].type ~= "WORD" and amount(nxt.value) then
			edits[#edits + 1] = { s = t.s, e = nxt.e, new = "value" .. INCLUSIVE[t.value] .. amount(nxt.value) }
			addNote(notes, seen, "GOLD")
			i = i + 1
		elseif t.type == "WORD" and starts and nxt.type ~= "WORD" and nxt.type ~= "OP" then
			local lo, hi = t.value:match("^(%d+[gGsScC])%-(%d+[gGsScC])$")
			if amount(t.value) then
				edits[#edits + 1] = { s = t.s, e = t.e, new = "value=" .. amount(t.value) }
				addNote(notes, seen, "GOLD")
			elseif lo and amount(lo) and amount(hi) then
				local a, b = tonumber(amount(lo)), tonumber(amount(hi))
				if a > b then
					lo, hi = hi, lo
				end
				edits[#edits + 1] = { s = t.s, e = t.e, new = "(value>=" .. amount(lo) .. " & value<=" .. amount(hi) .. ")" }
				addNote(notes, seen, "GOLD")
			end
		elseif t.type == "LPAREN" then
			depth = depth + 1
		elseif t.type == "RPAREN" then
			depth = depth - 1
		end
		i = i + 1
	end
	local out = text
	for k = #edits, 1, -1 do
		local e = edits[k]
		out = out:sub(1, e.s - 1) .. e.new .. out:sub(e.e + 1)
	end
	if depth > 0 then
		out = out .. string.rep(")", depth)
		addNote(notes, seen, "PARENS")
	end
	local compiled = SB.Query.Compile(out)
	if not compiled.fn then
		local err = compiled.errors[1]
		err.position = math.min(original(edits, err.position), #text + 1) -- where it is in what was pasted
		return nil, "ERROR", SB.Query.FormatError(err)
	end
	walk(compiled.ast, function(node)
		local value = type(node.value) == "string" and node.value:lower() or nil
		if node.type == "num" and node.name == "ilvl" then
			addNote(notes, seen, "ILVL")
		elseif (node.type == "word" or node.type == "exact") and DIFFERENT[value] then
			addNote(notes, seen, "DIFFERENT", node.value)
		elseif node.type == "exact" and not (SB.Query.Lookup(value) and SB.Query.Lookup(value).eval) then
			addNote(notes, seen, "UNKNOWN", node.value)
		elseif node.type == "word" and not (SB.Query.Lookup(value) and SB.Query.Lookup(value).eval) then
			addNote(notes, seen, "NAME", node.value)
		elseif node.type == "word" and #Paste.Prefixed(value) > 0 then
			addNote(notes, seen, "ALSO", node.value)
		end
	end)
	if #out > Paste.MAX then
		return nil, "GROWN", #out -- short as pasted, too long once its gold amounts are written out
	end
	return { query = out, notes = notes }
end

-- SwagBag keywords starting with a word, for a NAME note ("pot" -> potion): Baganator matched those too. Never the
-- word's own narrower phrases (NARROWS) or a keyword that reads tooltips (0.16.0: Baganator had none of those).
function Paste.Prefixed(word)
	word = word:lower()
	local out = {}
	for name, kw in pairs(SB.Query.keywords) do
		if kw.name == name and kw.eval and not kw.tooltip and not NARROWS[name] and name ~= word
			and name:sub(1, #word) == word then
			out[#out + 1] = name
		end
	end
	table.sort(out)
	return out
end
