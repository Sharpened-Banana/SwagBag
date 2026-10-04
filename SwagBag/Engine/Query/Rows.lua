-- SwagBag rule rows (week 11, spec F6 AC6.1): a category's query as rows the category editor shows and changes,
-- and back to text. Pure Lua: reads SB.QueryParser and SB.Query only.
-- The rows (rules) are two levels deep, as the editor shows them:
--   rules = { join = "and" | "or", blocks = { block, ... } }      how the groups combine
--   block = { join = "and" | "or", negate = bool, rows = { row, ... } }
--   row   = { kind = "word", value, negate }    a bare word: a keyword ("boe"), else an item-name match ("fish")
--           { kind = "text", value, negate }    a quoted item name ("Healing Potion")
--           { kind = "exact", value, negate }   #keyword: the keyword only
--           { kind = "num", name, op, raw, negate }   ilvl>=600 (op = < <= > >=, raw = the number as typed)
-- Lossless (AC6.1): for every query FromText accepts, ToText(FromText(t)) is Query.Pretty of t's tree (the same
-- tree, the same items), and FromText(ToText(r)) gives r back for every r FromText made. A query the rows cannot
-- show (nesting deeper than groups of rows, "!!", too many rows, too long, or not a query at all) opens as text
-- only; FromText says why. Nothing here runs or stores anything.
--   Rows.FromText(text) -> rules | nil, why, err   why: "error" (err = the parse error), "deep", "long", "toolong"
--   Rows.ToText(rules) -> text          empty groups are left out; "" when there is no row at all
--   Rows.FAMILIES                       the editor's keyword lists: { { label = Locale key, words = { ... } } }
--   Rows.KindOf(word) -> "flag" | "number" | "both" | nil (not a keyword: an item-name match)
--   Rows.NewRow(word, asNumber) -> row  a keyword row, a number row (asNumber), or an empty name row (word nil)
--   Rows.Problem(row) -> nil | "EMPTY" | "QUOTE" | "NUMBER" | "WORD"   what keeps a row from being saved
local _, SB = ...

local Rows = { MAX_ROWS = 40, MAX_BLOCKS = 10, MAX_TEXT = SB.Query.MAX_QUERY }
SB.QueryRows = Rows

-- Every registered keyword, once, by family (the spec 7.3 table). A test checks this against the registry.
Rows.FAMILIES = {
	{ label = "KW_FAMILY_TYPE", words = { "gear", "armor", "weapon", "consumable", "potion", "flask", "food", "elixir",
		"rune", "reagent", "tradegoods", "herb", "ore", "leather", "cloth", "enchanting", "cooking", "gem", "recipe",
		"questitem", "key", "keystone", "crest", "pet", "mount", "toy", "housing", "cosmetic", "container",
		"miscellaneous", "junk", "profession", "profession tool", "profession gear" } },
	{ label = "KW_FAMILY_QUALITY", words = { "poor", "common", "uncommon", "rare", "epic", "legendary", "artifact",
		"heirloom" } },
	{ label = "KW_FAMILY_BINDING", words = { "boe", "bop", "warbound", "wue", "bound", "soulbound", "tradeable" } },
	{ label = "KW_FAMILY_NUMBER", numbers = true, words = { "ilvl", "gear", "level", "value", "count", "stack", "tab" } },
	{ label = "KW_FAMILY_STATE", words = { "new", "locked", "inuse", "uncollected", "cooldown", "usable", "equipped",
		"upgrade", "partial" } },
	{ label = "KW_FAMILY_SLOT", words = { "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs",
		"feet", "finger", "trinket", "mainhand", "offhand", "one-hand", "twohand", "ranged", "shirt", "tabard", "bag" } },
	{ label = "KW_FAMILY_PLACE", words = { "bags", "backpack", "reagentbag", "bank", "warband" } },
}

Rows.NUMBER_OPS = { ">=", ">", "=", "<", "<=" }

function Rows.KindOf(word)
	local kw = type(word) == "string" and SB.Query.Lookup(word) or nil
	if not kw then
		return nil
	end
	if kw.eval and kw.value then
		return "both"
	end
	return kw.eval and "flag" or "number"
end

local function asRow(node)
	local negate = false
	if node.type == "not" then
		negate, node = true, node.item
	end
	local t = node.type
	if t == "word" or t == "text" or t == "exact" then
		return { kind = t, value = node.value, negate = negate }
	elseif t == "num" then
		return { kind = "num", name = node.name, op = node.op, raw = node.raw, negate = negate }
	end
	return nil
end

-- A group: one row, rows joined by one operator, or "!" before such a join.
local function asBlock(node)
	local row = asRow(node)
	if row then
		return { join = "and", negate = false, rows = { row } }
	end
	local negate = false
	if node.type == "not" then
		negate, node = true, node.item
	end
	if node.type ~= "and" and node.type ~= "or" then
		return nil
	end
	local rows = {}
	for i, child in ipairs(node.items) do
		rows[i] = asRow(child)
		if not rows[i] then
			return nil
		end
	end
	return { join = node.type, negate = negate, rows = rows }
end

function Rows.FromText(text)
	text = type(text) == "string" and text or ""
	if #text > Rows.MAX_TEXT then
		return nil, "toolong"
	end
	if not text:find("%S") then
		return { join = "and", blocks = {} }
	end
	local ast, err = SB.QueryParser.Parse(text)
	if not ast then
		return nil, "error", err
	end
	local rules
	local whole = asBlock(ast)
	if whole then
		rules = { join = "and", blocks = { whole } }
	elseif ast.type == "and" or ast.type == "or" then
		rules = { join = ast.type, blocks = {} }
		for i, child in ipairs(ast.items) do
			rules.blocks[i] = asBlock(child)
			if not rules.blocks[i] then
				return nil, "deep"
			end
		end
	else
		return nil, "deep"
	end
	local n = 0
	for _, b in ipairs(rules.blocks) do
		n = n + #b.rows
	end
	if n > Rows.MAX_ROWS or #rules.blocks > Rows.MAX_BLOCKS then
		return nil, "long"
	end
	return rules
end

local function rowText(r, negate)
	local s
	if r.kind == "num" then
		s = r.name .. r.op .. r.raw
	elseif r.kind == "text" then
		s = "\"" .. r.value .. "\""
	elseif r.kind == "exact" then
		s = "#" .. r.value
	else
		s = r.value
	end
	return negate and ("!" .. s) or s
end

-- inside: the operator joining the groups, or nil for a group on its own. Parentheses only where Query.Pretty
-- puts them, so the text is the canonical one.
local function blockText(b, inside)
	if #b.rows == 1 then
		-- "!" on a one-row group is that row's own "!" (never "!!", which the rows cannot show)
		return rowText(b.rows[1], b.rows[1].negate ~= (b.negate == true))
	end
	local parts = {}
	for i, r in ipairs(b.rows) do
		parts[i] = rowText(r, r.negate)
	end
	local s = table.concat(parts, b.join == "or" and " | " or " & ")
	if b.negate then
		return "!(" .. s .. ")"
	end
	if inside and (inside == b.join or b.join == "or") then
		return "(" .. s .. ")"
	end
	return s
end

function Rows.ToText(rules)
	local blocks = {}
	for _, b in ipairs(rules.blocks or {}) do
		if #b.rows > 0 then
			blocks[#blocks + 1] = b
		end
	end
	if #blocks == 0 then
		return ""
	elseif #blocks == 1 then
		return blockText(blocks[1], nil)
	end
	local parts = {}
	for i, b in ipairs(blocks) do
		parts[i] = blockText(b, rules.join)
	end
	return table.concat(parts, rules.join == "or" and " | " or " & ")
end

function Rows.NewRow(word, asNumber)
	if word == nil then
		return { kind = "text", value = "", negate = false }
	elseif asNumber then
		return { kind = "num", name = word, op = ">=", raw = "", negate = false }
	end
	return { kind = "word", value = word, negate = false }
end

-- What keeps a row from being saved: an empty value, a double quote in a name (it would end the name), a number
-- that is not one, or a bare word that would not read back as the same word.
function Rows.Problem(row)
	if row.kind == "num" then
		if not (type(row.raw) == "string" and row.raw:match("^%d+%.?%d*$") and tonumber(row.raw)) then
			return "NUMBER"
		end
		return nil
	end
	local v = row.value
	if type(v) ~= "string" or not v:find("%S") then
		return "EMPTY"
	elseif v:find("\"", 1, true) then
		return "QUOTE"
	elseif row.kind ~= "text" and (v:find("[&|!~()#=<>]") or v:find("%s%s") or v ~= v:match("^%s*(.-)%s*$")
		or (row.kind == "word" and (v:match("^%d+$") or v:match("^%d+%-%d+$")))) then
		return "WORD" -- a bare 536 or 400-450 is an item level, not a word
	end
	return nil
end
