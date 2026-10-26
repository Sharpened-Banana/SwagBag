-- SwagBag search notes (0.16.0, user answer Q14): bare cloth and leather now also find cloth and leather armor
-- ("cloth material" and "leather material" are the crafting goods only). At the first login with this version,
-- one chat note names the saved categories and watch-list searches that use either word bare, so nobody is
-- surprised by armor in a materials section. Nothing is rewritten. SwagBagDB.notes.clothLeather (read
-- defensively; schema stays 2) remembers that the check was made, as Locks.KeywordNote does for `locked`.
--   SearchNotes.BareClothLeather(query) -> bool   the rule uses cloth or leather as a keyword of its own
--   SearchNotes.ClothLeatherNote() -> bool        the note was printed
local _, SB = ...

local N = {}
SB.SearchNotes = N

local WORDS = { cloth = true, leather = true }

local function walk(node, fn)
	fn(node)
	for _, child in ipairs(node.items or {}) do
		walk(child, fn)
	end
	if node.item then
		walk(node.item, fn)
	end
end

function N.BareClothLeather(query)
	if type(query) ~= "string" then
		return false
	end
	local ast = SB.QueryParser.Parse(query)
	if not ast then
		return false
	end
	local found = false
	walk(ast, function(node)
		if (node.type == "word" or node.type == "exact") and WORDS[node.value:lower()] then
			found = true
		end
	end)
	return found
end

function N.ClothLeatherNote()
	local d = SB.Config.db
	if not d or SB.Config.readOnly then
		return false
	end
	if type(d.notes) ~= "table" then
		d.notes = {}
	end
	if d.notes.clothLeather then
		return false
	end
	d.notes.clothLeather = true
	local names = {}
	for _, key in ipairs({ "categories", "userEdits" }) do
		for id, def in pairs(type(d[key]) == "table" and d[key] or {}) do
			if type(def) == "table" and N.BareClothLeather(def.query) then
				local name = type(def.name) == "string" and def.name
					or (SB.Categories and SB.Categories.Name(id)) or tostring(id)
				names[#names + 1] = name
			end
		end
	end
	table.sort(names)
	local watch = SB.Config.Get("consumables.watch")
	for _, e in ipairs(type(watch) == "table" and watch or {}) do
		if type(e) == "table" and N.BareClothLeather(e.query) then
			names[#names + 1] = "\"" .. e.query .. "\""
		end
	end
	if #names == 0 then
		return false
	end
	SB.Print(SB.L.SEARCH_CLOTH_NOTE:format(table.concat(names, ", ")))
	return true
end

SB.On("SB_LOGIN", N.ClothLeatherNote, "none")
