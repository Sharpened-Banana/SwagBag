-- SwagBag categories (spec 7.7, 8.5): built-ins + the user's diffs + user categories,
-- merged into runtime records. Pure (reads SB.Config.db, SB.CategoryDefaults, SB.Query).
--   Categories.Load()                  rebuild everything; bumps Categories.version
--   Categories.Get(id) -> category | nil
--   Categories.ByPriority()            enabled-or-not, priority desc, ties id asc (no pairs())
--   Categories.SectionOrder()          { "new", <enabled categories in display order>, "free" }
--   Categories.Name(sectionId)         display name, including "new" and "free"
--   Categories.AddToList(id, itemID)   manual include (drag onto a header, AC4.3)
--   Categories.ResetBuiltin(id)        remove the user's diff of a built-in
--   Categories.MarkFailed(id, message) a rule threw while evaluating (Categorizer)
--   Categories.Counts() -> total, edited, broken names (list)
-- Runtime category: { id, name, query, priority, displayOrder, enabled, builtin, source,
--   itemList = { include = {[itemID]=true}, exclude = {...} }, compiled, hasRule,
--   fallback, setting, error (compile error text), runtimeError (evaluation error text) }
-- A category whose query does not compile is disabled with `error` set and never
-- affects other categories (spec 7.10).
local _, SB = ...

local C = { version = 0, loaded = false, list = {}, byId = {}, byPriority = {}, display = {},
	NEW = "new", FREE = "free", OTHER = "c_other" }
SB.Categories = C

local FIELDS = { "name", "query", "priority", "displayOrder", "enabled" }

local function copySet(...)
	local out = {}
	for i = 1, select("#", ...) do
		local t = select(i, ...)
		if type(t) == "table" then
			for k, v in pairs(t) do
				if v then
					out[k] = true
				end
			end
		end
	end
	return out
end

local function list(t, which)
	return type(t) == "table" and type(t.itemList) == "table" and t.itemList[which] or nil
end

local function build(def, edit, builtin)
	local c = { id = def.id, builtin = builtin, source = builtin and "builtin" or (def.source or "user"),
		fallback = def.fallback, setting = def.setting }
	for _, f in ipairs(FIELDS) do
		c[f] = def[f]
	end
	if type(edit) == "table" then
		for _, f in ipairs(FIELDS) do
			if edit[f] ~= nil then
				c[f] = edit[f]
			end
		end
	end
	c.name = c.name or c.id
	c.priority = tonumber(c.priority) or 0
	c.displayOrder = tonumber(c.displayOrder) or 1000
	c.enabled = c.enabled ~= false
	c.itemList = {
		include = copySet(list(def, "include"), list(edit, "include")),
		exclude = copySet(list(def, "exclude"), list(edit, "exclude")),
	}
	if c.setting and not SB.Config.Get(c.setting) then
		c.enabled = false
	end
	local compiled = SB.Query.Compile(type(c.query) == "string" and c.query or "")
	if compiled.fn then
		c.compiled = compiled
		c.hasRule = not compiled.empty
	else
		c.error = SB.Query.FormatError(compiled.errors[1])
		c.enabled = false
	end
	return c
end

local function byPriority(a, b)
	if a.priority ~= b.priority then
		return a.priority > b.priority
	end
	return a.id < b.id
end

local function byDisplay(a, b)
	if a.displayOrder ~= b.displayOrder then
		return a.displayOrder < b.displayOrder
	end
	return a.id < b.id
end

function C.Load()
	local db = SB.Config.db or {}
	local edits = type(db.userEdits) == "table" and db.userEdits or {}
	local users = type(db.categories) == "table" and db.categories or {}
	C.list, C.byId = {}, {}
	for _, def in ipairs(SB.CategoryDefaults) do
		local c = build(def, edits[def.id], true)
		C.list[#C.list + 1] = c
		C.byId[c.id] = c
	end
	local userIds = {}
	for id, def in pairs(users) do
		if type(def) == "table" and not C.byId[id] then
			userIds[#userIds + 1] = id
		end
	end
	table.sort(userIds)
	for _, id in ipairs(userIds) do
		local def = {}
		for k, v in pairs(users[id]) do
			def[k] = v
		end
		def.id = id
		local c = build(def, nil, false)
		C.list[#C.list + 1] = c
		C.byId[id] = c
	end
	C.byPriority = {}
	for i, c in ipairs(C.list) do
		C.byPriority[i] = c
	end
	table.sort(C.byPriority, byPriority)
	-- Display order: the saved order first (unknown ids skipped), then the rest by displayOrder.
	local rest, placed = {}, {}
	C.display = {}
	if type(db.categoryOrder) == "table" then
		for _, id in ipairs(db.categoryOrder) do
			local c = C.byId[id]
			if c and not placed[id] then
				placed[id] = true
				C.display[#C.display + 1] = c
			end
		end
	end
	for _, c in ipairs(C.list) do
		if not placed[c.id] then
			rest[#rest + 1] = c
		end
	end
	table.sort(rest, byDisplay)
	for _, c in ipairs(rest) do
		C.display[#C.display + 1] = c
	end
	C.version = C.version + 1
	C.loaded = true
end

function C.Ensure()
	if not C.loaded then
		C.Load()
	end
end

function C.Get(id)
	C.Ensure()
	return C.byId[id]
end

function C.ByPriority()
	C.Ensure()
	return C.byPriority
end

function C.SectionOrder()
	C.Ensure()
	local order = { C.NEW }
	for _, c in ipairs(C.display) do
		if c.enabled then
			order[#order + 1] = c.id
		end
	end
	order[#order + 1] = C.FREE
	return order
end

function C.Name(sectionId)
	if sectionId == C.NEW then
		return SB.L.CAT_NEW
	elseif sectionId == C.FREE then
		return SB.L.CAT_FREE
	end
	local c = C.Get(sectionId)
	return c and c.name or tostring(sectionId)
end

-- The table that stores the user's version of a category's fields and lists:
-- the diff for a built-in, the category itself for a user category.
local function editFor(c)
	local db = SB.Config.db
	if c.builtin then
		db.userEdits = type(db.userEdits) == "table" and db.userEdits or {}
		if type(db.userEdits[c.id]) ~= "table" then
			db.userEdits[c.id] = {}
		end
		return db.userEdits[c.id]
	end
	db.categories = type(db.categories) == "table" and db.categories or {}
	if type(db.categories[c.id]) ~= "table" then
		db.categories[c.id] = {}
	end
	return db.categories[c.id]
end

-- Drop empty include/exclude tables, then an empty itemList, then (built-ins only) the
-- whole diff once nothing is left, so an unedited built-in is never stored (spec 8.5).
local function prune(c, e)
	if type(e.itemList) == "table" then
		for _, which in ipairs({ "include", "exclude" }) do
			if type(e.itemList[which]) == "table" and next(e.itemList[which]) == nil then
				e.itemList[which] = nil
			end
		end
		if next(e.itemList) == nil then
			e.itemList = nil
		end
	end
	if c.builtin and next(e) == nil then
		SB.Config.db.userEdits[c.id] = nil
	end
end

local function ensureList(e, which)
	e.itemList = type(e.itemList) == "table" and e.itemList or {}
	e.itemList[which] = type(e.itemList[which]) == "table" and e.itemList[which] or {}
	return e.itemList[which]
end

local function defaultIncludes(id)
	for _, def in ipairs(SB.CategoryDefaults) do
		if def.id == id then
			return list(def, "include") or {}
		end
	end
	return {}
end

-- Put itemID on targetId's manual include list and take it off every other list, so the
-- latest drag wins. A built-in's default include is overridden by a diff exclude.
-- Returns true, or false for an unknown category / item.
function C.AddToList(targetId, itemID)
	C.Ensure()
	local target = C.byId[targetId]
	if not target or type(itemID) ~= "number" or itemID < 1 or itemID ~= math.floor(itemID) or itemID == math.huge
		or SB.Config.readOnly then
		return false
	end
	for _, c in ipairs(C.list) do
		if c.id ~= targetId and c.itemList.include[itemID] then
			local e = editFor(c)
			local inc = list(e, "include")
			if inc then
				inc[itemID] = nil
			end
			if c.builtin and defaultIncludes(c.id)[itemID] then
				ensureList(e, "exclude")[itemID] = true
			end
			prune(c, e)
		end
	end
	local e = editFor(target)
	if not (target.builtin and defaultIncludes(targetId)[itemID]) then
		ensureList(e, "include")[itemID] = true
	end
	local exc = list(e, "exclude")
	if exc then
		exc[itemID] = nil
	end
	prune(target, e)
	C.Load()
	return true
end

function C.ResetBuiltin(id)
	local db = SB.Config.db
	if type(db.userEdits) == "table" then
		db.userEdits[id] = nil
	end
	C.Load()
end

-- Called by the Categorizer when a category's rule throws. Returns true the first time
-- (so the caller records the error once per category), false afterwards.
function C.MarkFailed(id, message)
	local c = C.byId[id]
	if not c or c.runtimeError then
		return false
	end
	c.runtimeError = tostring(message)
	return true
end

function C.Counts()
	C.Ensure()
	local db = SB.Config.db or {}
	local edited = 0
	for _, c in ipairs(C.list) do
		if not c.builtin or (type(db.userEdits) == "table" and db.userEdits[c.id] ~= nil) then
			edited = edited + 1
		end
	end
	local broken = {}
	for _, c in ipairs(C.display) do
		if c.error or c.runtimeError then
			broken[#broken + 1] = c.name
		end
	end
	return #C.list, edited, broken
end

SB.On("SB_LOGIN", function()
	C.Load()
end, "bags")
