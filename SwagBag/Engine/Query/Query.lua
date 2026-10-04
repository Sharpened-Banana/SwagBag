-- SwagBag query engine (spec 7). Pure Lua.
--   Query.RegisterKeyword{ name, aliases, class, eval, value }
--       class: "static" (per itemID) | "instance" (per link) | "volatile" (never cached)
--       eval(record)  -> true | false | nil   for bare use:      boe
--       value(record) -> number | false | nil for numeric use:   ilvl>250
--                        (false = item has no such field -> comparison is false;
--                         nil = data not loaded yet -> result unknown)
--   Query.Compile(text) -> { fn, cacheClass, keywords, errors, warnings, ast, id, text, empty }
--       warnings: { { kind = "unknown_keyword", value, position } } for #word with no such
--       keyword. Like Syndicator, such a term is simply false (spec 7.5 #3); not an error.
--   Query.Eval(compiled, record) -> true | false | nil   (nil when compiled has errors)
--   Query.Validate(compiled) -> { ok, problems, warnings }
--   Query.Pretty(ast) -> canonical text; Parse(Pretty(ast)) gives the same tree
--   Query.FormatError(err) -> "Expected a value after "&" at character 6"
--   Query.FormatWarning(w) -> "Unknown keyword "#potin" matches nothing (character 7)"
--   Query.MAX_QUERY = 500   the longest rule SwagBag keeps: a category's, a share string's, a paste's (week 11: one
--                           constant, read by Rows, Categories, Paste and Profiles)
--   Query.EscapeCode(text) -> bool   the text holds a chat code (week 11: one check, for Profiles, Categories, Paste)
-- Tri-state (Kleene): AND is false if any part is false, else nil if any is nil;
-- OR is true if any part is true, else nil if any is nil; NOT nil is nil.
local _, SB = ...

local Q = { keywords = {}, nextId = 0, MAX_QUERY = 500 }
SB.Query = Q

local RANK = { static = 1, instance = 2, volatile = 3 }

function Q.RegisterKeyword(def)
	if type(def) ~= "table" or type(def.name) ~= "string" then
		error("RegisterKeyword: name required", 2)
	end
	if not RANK[def.class] then
		error("RegisterKeyword: class must be static, instance or volatile", 2)
	end
	if not def.eval and not def.value then
		error("RegisterKeyword: eval or value required", 2)
	end
	local entry = { name = def.name:lower(), class = def.class, eval = def.eval, value = def.value }
	Q.keywords[entry.name] = entry
	for _, alias in ipairs(def.aliases or {}) do
		Q.keywords[alias:lower()] = entry
	end
	return entry
end

function Q.ResetKeywords()
	Q.keywords = {}
end

function Q.Lookup(name)
	return Q.keywords[name:lower()]
end

local OPS = {
	["="] = function(a, b) return a == b end,
	["<"] = function(a, b) return a < b end,
	["<="] = function(a, b) return a <= b end,
	[">"] = function(a, b) return a > b end,
	[">="] = function(a, b) return a >= b end,
}

-- Case-insensitive substring match on the item name (ASCII lower-casing only).
local function textMatcher(needle)
	needle = needle:lower()
	return function(r)
		local name = r.name
		if name == nil then
			return nil
		end
		return name:lower():find(needle, 1, true) ~= nil
	end
end

-- Build the closure tree; leaf(node) returns the function for a term node.
local function build(node, leaf)
	local t = node.type
	if t == "and" or t == "or" then
		local fns = {}
		for i, child in ipairs(node.items) do
			fns[i] = build(child, leaf)
		end
		local n = #fns
		if t == "and" then
			return function(r)
				local result = true
				for i = 1, n do
					local v = fns[i](r)
					if v == false then
						return false
					elseif v == nil then
						result = nil
					end
				end
				return result
			end
		end
		return function(r)
			local result = false
			for i = 1, n do
				local v = fns[i](r)
				if v == true then
					return true
				elseif v == nil then
					result = nil
				end
			end
			return result
		end
	elseif t == "not" then
		local f = build(node.item, leaf)
		return function(r)
			local v = f(r)
			if v == nil then
				return nil
			end
			return not v
		end
	elseif t == "all" then
		return function()
			return true
		end
	end
	-- Normalise leaf results to strict tri-state: nil stays nil, anything else is a boolean.
	local f = leaf(node)
	return function(r)
		local v = f(r)
		if v == nil then
			return nil
		end
		return v ~= false
	end
end

local function unknown()
	return nil
end

local function never()
	return false
end

function Q.Compile(text)
	text = text or ""
	local compiled = { text = text, keywords = {}, errors = {}, warnings = {}, cacheClass = "static" }
	if not text:find("%S") then
		compiled.empty = true
		compiled.ast = { type = "all" }
		compiled.fn = function()
			return true
		end
		return compiled
	end
	local ast, err = SB.QueryParser.Parse(text)
	if not ast then
		compiled.errors[1] = err
		return compiled
	end
	compiled.ast = ast
	local seen = {}
	local function use(kw)
		if RANK[kw.class] > RANK[compiled.cacheClass] then
			compiled.cacheClass = kw.class
		end
		if not seen[kw.name] then
			seen[kw.name] = true
			compiled.keywords[#compiled.keywords + 1] = kw.name
		end
	end
	local function fail(node, expected, got)
		compiled.errors[#compiled.errors + 1] = { position = node.s, expected = expected, got = got }
	end
	local fn = build(ast, function(node)
		if node.type == "word" or node.type == "exact" then
			local kw = Q.keywords[node.value:lower()]
			if kw and kw.eval then
				use(kw)
				return kw.eval
			end
			if node.type == "exact" then
				compiled.warnings[#compiled.warnings + 1] = { kind = "unknown_keyword", value = node.value, position = node.s }
				return never
			end
			return textMatcher(node.value)
		elseif node.type == "text" then
			return textMatcher(node.value)
		end
		-- numeric
		local kw = Q.keywords[node.name:lower()]
		if not (kw and kw.value) then
			fail(node, "NUMERIC", node.name)
			return unknown
		end
		use(kw)
		local get, cmp, target = kw.value, OPS[node.op], node.value
		return function(r)
			local v = get(r)
			if v == nil then
				return nil
			elseif v == false then
				return false
			end
			return cmp(v, target)
		end
	end)
	if #compiled.errors > 0 then
		return compiled
	end
	Q.nextId = Q.nextId + 1
	compiled.id = Q.nextId
	compiled.fn = fn
	return compiled
end

function Q.Eval(compiled, record)
	if not compiled.fn then
		return nil
	end
	return compiled.fn(record)
end

function Q.FormatError(err)
	local L = SB.L
	local full = rawget(L, "QUERY_ERR_" .. err.expected)
	if full then
		return full:format(err.position)
	end
	local expect = L["QUERY_EXPECT_" .. err.expected]
	if err.after and err.got == "" then
		return L.QUERY_ERR_AFTER:format(expect, err.after, err.position)
	end
	local found = err.got == "" and L.QUERY_FOUND_END or ("\"" .. err.got .. "\"")
	return L.QUERY_ERR_FOUND:format(expect, found, err.position)
end

-- A chat escape opener: |T |H |A |K, |c with eight hex digits, or a named colour: |cn (or |cN) followed by an
-- upper-case name and ":" (|cnIQ4:, |cnGREEN_FONT_COLOR:; week 8, the narrowest rule that still catches it). Every
-- other "|" is the OR operator ("herb|cloth", "herb|cname"). Share strings, the category writers and Paste all ask here.
function Q.EscapeCode(text)
	return text:find("|[THAK]") ~= nil or text:find("|c%x%x%x%x%x%x%x%x") ~= nil
		or text:find("|c[nN][%u_][%u%d_]*:") ~= nil
end

function Q.FormatWarning(w)
	return SB.L.QUERY_WARN_UNKNOWN_KEYWORD:format(w.value, w.position)
end

local function walk(node, fn)
	fn(node)
	if node.items then
		for _, child in ipairs(node.items) do
			walk(child, fn)
		end
	elseif node.item then
		walk(node.item, fn)
	end
end

local VALIDATE_MODES = { { name = "true", value = true }, { name = "false", value = false }, { name = "nil" } }

-- Spec 7.9: run the combinators with every leaf forced to true, false and nil;
-- each run must finish and return true, false or nil. Also warn about bare words
-- that are not keywords (they match item names).
function Q.Validate(compiled)
	local report = { ok = true, problems = {}, warnings = {} }
	if not compiled.fn then
		report.ok = false
		for _, err in ipairs(compiled.errors) do
			report.problems[#report.problems + 1] = { kind = "error", position = err.position, message = Q.FormatError(err) }
		end
		return report
	end
	for _, w in ipairs(compiled.warnings or {}) do
		report.warnings[#report.warnings + 1] = w
	end
	for _, mode in ipairs(VALIDATE_MODES) do
		local leafValue = mode.value
		local fn = build(compiled.ast, function()
			return function()
				return leafValue
			end
		end)
		local ok, result = pcall(fn, {})
		if not ok then
			report.ok = false
			report.problems[#report.problems + 1] = { kind = "crash", leaf = mode.name, message = tostring(result) }
		elseif result ~= true and result ~= false and result ~= nil then
			report.ok = false
			report.problems[#report.problems + 1] = { kind = "value", leaf = mode.name, message = tostring(result) }
		end
	end
	walk(compiled.ast, function(node)
		if node.type == "word" then
			local kw = Q.keywords[node.value:lower()]
			if not (kw and kw.eval) then
				report.warnings[#report.warnings + 1] = { kind = "text", value = node.value, position = node.s }
			end
		end
	end)
	return report
end

local PREC = { ["or"] = 1, ["and"] = 2, ["not"] = 3 }

local function prec(node)
	return PREC[node.type] or 4
end

local function pretty(node)
	local t = node.type
	if t == "all" then
		return ""
	elseif t == "word" then
		return node.value
	elseif t == "exact" then
		return "#" .. node.value
	elseif t == "text" then
		return "\"" .. node.value .. "\""
	elseif t == "num" then
		return node.name .. node.op .. node.raw
	elseif t == "not" then
		local inner = pretty(node.item)
		if prec(node.item) < PREC["not"] then
			inner = "(" .. inner .. ")"
		end
		return "!" .. inner
	end
	local parts = {}
	for i, child in ipairs(node.items) do
		local s = pretty(child)
		if prec(child) < prec(node) or child.type == t then
			s = "(" .. s .. ")"
		end
		parts[i] = s
	end
	return table.concat(parts, t == "and" and " & " or " | ")
end

function Q.Pretty(ast)
	return pretty(ast)
end
