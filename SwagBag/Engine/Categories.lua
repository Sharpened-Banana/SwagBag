-- SwagBag categories (spec 7.7, 8.5): built-ins + the user's diffs + user categories,
-- merged into runtime records. Pure (reads SB.Config.db, SB.CategoryDefaults, SB.Query).
--   Categories.Load()                  rebuild everything; bumps Categories.version
--   Categories.Get(id) -> category | nil
--   Categories.ByPriority()            enabled-or-not, priority desc, ties id asc (no pairs())
--   Categories.SectionOrder()          { "new", <enabled categories in display order>, "free" }
--   Categories.Name(sectionId)         display name, including "new" and "free"
--   Categories.AddToList(id, itemID)   manual include (drag onto a header, AC4.3)
--   Categories.ResetBuiltin(id) -> true | false, "readonly"   remove the user's whole diff of a built-in
--   Categories.MarkFailed(id, message) a rule threw while evaluating (Categorizer)
--   Categories.Counts() -> total, edited, broken names (list)
-- The category editor's writers (week 11, spec F6; UI/SettingsCategories.lua). Each refuses while the settings are
-- read-only and changes nothing then; each loads the categories again after a change:
--   Categories.CheckName(name, exceptId) -> name (trimmed) | nil, why   why: "EMPTY" | "LONG" | "CHARS" | "TAKEN"
--   Categories.Create(name, query, source) -> id | nil, why, detail      a user category ("u_..."), shown first
--   Categories.Save(id, fields) -> ok, why, detail   fields: name, query, priority, enabled (each optional). A
--     built-in keeps only what differs from its default (spec 8.5). Save and Create run Validate (spec 7.9). A query
--     that does not compile is never dropped (AC6.2): while the category has a rule that works, that rule stays in
--     use and on (spec 7.5 #3) and the new text is kept as its draft (true, "draft", the error text); with no rule
--     that works (a new category, or one already broken) it is saved switched off (true, "broken", the error text).
--     A rule that compiles replaces the rule and its draft, and a category that was broken is on again unless the
--     fields say Off. A changed rule that compiles with warnings answers true, "warned", the warnings (Validate's)
--   Categories.Delete(id) -> ok, why       a user category only; its id leaves the order, every focus mode's sections
--     (account-wide and this character's) and this character's collapsed sections
--   Categories.Move(id, step) -> ok, why   one place up (-1) or down (+1) in the display order
--   Categories.Preview(query) -> matches, total | nil, message     the bags' slots the query matches now
--   why (all writers): "readonly" | "unknown" | "builtin" | "pinned" | "priority" | "long" | "code" (a chat code
--     in a rule) | "edge" or a name why. A deleted category's id is never given again (its entry stays, false).
--   Every writer that changes the stored categories (AddToList and ResetBuiltin too) tells Profiles, so a profile
--     Undo never puts back categories from before them (Profiles.CategoriesChanged, week 11 final fix).
--   Categories.NameTaken(name, exceptId) -> true when a category has it (any case), it is a built-in's own or "New" / "Free"
--   Categories.FreeName(name, also) -> name, or "name (2)", "(3)"...: a name nothing has, also not in `also` (lowercase set)
--   Categories.FreeId(name, also) -> "u_..." an id no category has, live or deleted, nor in `also` (a set)
-- Runtime category: { id, name, query, priority, displayOrder, enabled, builtin, source,
--   itemList = { include = {[itemID]=true}, exclude = {...} }, compiled, hasRule,
--   fallback, setting, error (compile error text), runtimeError (evaluation error text),
--   draft, draftError (week 11: a change of the rule saved with an error while the rule before it stays in use) }
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

-- The stored categories changed: a profile Undo keeps them as they are now (Profiles.CategoriesChanged).
local function changed()
	if SB.Profiles and SB.Profiles.CategoriesChanged then
		SB.Profiles.CategoriesChanged()
	end
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
	-- The draft (week 11), read defensively: a save from before week 11 has none.
	local draft = type(edit) == "table" and edit.draft or def.draft
	if type(draft) == "string" then
		local d = SB.Query.Compile(draft)
		c.draft, c.draftError = draft, not d.fn and SB.Query.FormatError(d.errors[1]) or nil
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
	local failed = {}
	for id, old in pairs(C.byId) do
		if old.runtimeError then
			failed[id] = { query = old.query, runtimeError = old.runtimeError }
		end
	end
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
	-- A rule that threw stays failed (recorded once) until its query text changes.
	for id, f in pairs(failed) do
		local c = C.byId[id]
		if c and c.query == f.query then
			c.runtimeError = f.runtimeError
		end
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
		-- A built-in added in an update (def.after) joins the saved order right after the category it
		-- follows by default, when that one is placed; otherwise it follows with the rest (week 6).
		for _, def in ipairs(SB.CategoryDefaults) do
			if def.after and not placed[def.id] and placed[def.after] and C.byId[def.id] then
				for i, c in ipairs(C.display) do
					if c.id == def.after then
						table.insert(C.display, i + 1, C.byId[def.id])
						placed[def.id] = true
						break
					end
				end
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
	changed()
	C.Load()
	return true
end

function C.ResetBuiltin(id)
	if SB.Config.readOnly then
		return false, "readonly" -- week 11: the editor's Reset to default refuses, as every writer
	end
	local db = SB.Config.db
	if type(db.userEdits) == "table" then
		db.userEdits[id] = nil
	end
	changed()
	C.Load()
	return true
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

---------------------------------------------------------------------------
-- The category editor's writers (week 11, spec F6)
---------------------------------------------------------------------------
C.MAX_NAME, C.MAX_QUERY = 30, SB.Query.MAX_QUERY
-- A category you make starts at 88: above every built-in but Reagents, Keystone & Crests, Equipment sets and Junk,
-- which it may never outrank (the share-string rule, F20). Priorities go from 1 to 89.
C.USER_PRIORITY, C.MIN_PRIORITY, C.MAX_PRIORITY = 88, 1, 89
-- The four that keep their priority: one list, which Profiles' share strings read too.
C.PINNED = { c_junk = true, c_sets = true, c_keystone = true, c_reagents = true }

local function default(id)
	for _, def in ipairs(SB.CategoryDefaults) do
		if def.id == id then
			return def
		end
	end
end

function C.CheckName(name, exceptId)
	name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
	if name == "" then
		return nil, "EMPTY"
	elseif #name > C.MAX_NAME then
		return nil, "LONG"
	elseif name:find("[%c|]") then
		return nil, "CHARS" -- "|" starts a chat code (a colour, a link)
	end
	if C.NameTaken(name, exceptId) then
		return nil, "TAKEN"
	end
	return name
end

function C.NameTaken(name, exceptId)
	C.Ensure()
	local low = name:lower()
	if low == SB.L.CAT_NEW:lower() or low == SB.L.CAT_FREE:lower() then
		return true
	end
	for _, c in ipairs(C.list) do
		if c.id ~= exceptId and type(c.name) == "string" and c.name:lower() == low then
			return true
		end
	end
	-- A built-in's own name stays its own after a rename, so its Reset to default never makes two of one name.
	for _, def in ipairs(SB.CategoryDefaults) do
		if def.id ~= exceptId and type(def.name) == "string" and def.name:lower() == low then
			return true
		end
	end
	return false
end

-- A name no category has (an import's, week 11 final fix: it never takes the name of one of yours): the name itself,
-- else "name (2)", "name (3)"..., cut so it stays within MAX_NAME (never inside a letter of more than one byte).
function C.FreeName(name, also)
	also = also or {}
	if not C.NameTaken(name) and not also[name:lower()] then
		return name
	end
	for n = 2, 999 do
		local suffix = " (" .. n .. ")"
		local cut = C.MAX_NAME - #suffix
		local base = name
		if #base > cut then
			while cut > 0 and base:byte(cut + 1) >= 128 and base:byte(cut + 1) < 192 do
				cut = cut - 1 -- the byte after the cut continues a letter: cut before that letter
			end
			base = base:sub(1, cut)
		end
		local candidate = base:match("^(.-)%s*$") .. suffix
		if not C.NameTaken(candidate) and not also[candidate:lower()] then
			return candidate
		end
	end
	return name
end

-- An id for a user category: "u_" and the name's letters, else "_2", "_3"... An id a category has, or had (a deleted
-- one's stays, false), is never given again; nor one in `also` (an import's own ids).
function C.FreeId(name, also)
	also = also or {}
	local db = SB.Config.db
	local stored = type(db.categories) == "table" and db.categories or {}
	local slug = (type(name) == "string" and name or ""):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", ""):sub(1, 20)
	local base = "u_" .. (slug ~= "" and slug or "category")
	local id, n = base, 1
	while stored[id] ~= nil or C.byId[id] or also[id] do
		n = n + 1
		id = base .. "_" .. n
	end
	return id
end

local function queryWhy(query)
	if type(query) ~= "string" or #query > C.MAX_QUERY then
		return "long"
	elseif SB.Query.EscapeCode(query) then
		return "code" -- a chat code is never part of a rule, and a share string holding one is refused (F20)
	end
end

-- Spec 7.9, before a save: the error text of a rule that does not compile, else nil and Validate's warnings (a word
-- that is no keyword matches item names; an unknown #keyword matches nothing).
local function check(query)
	local compiled = SB.Query.Compile(query)
	if not compiled.fn then
		return SB.Query.FormatError(compiled.errors[1])
	end
	return nil, SB.Query.Validate(compiled).warnings
end

function C.Create(name, query, source)
	if SB.Config.readOnly then
		return nil, "readonly"
	end
	query = query or ""
	local clean, why = C.CheckName(name)
	if not clean then
		return nil, why
	end
	why = queryWhy(query)
	if why then
		return nil, why
	end
	local db = SB.Config.db
	db.categories = type(db.categories) == "table" and db.categories or {}
	local id = C.FreeId(clean)
	local def = { name = clean, query = query, priority = C.USER_PRIORITY, enabled = true,
		source = source == "import" and "import" or "user" }
	local err, warnings = check(query)
	if err then
		def.enabled = false -- AC6.2: no rule that works yet: made switched off, the error shown
	end
	if type(db.categoryOrder) == "table" then
		table.insert(db.categoryOrder, 1, id)
	else
		def.displayOrder = 5 -- before Keystone & Crests (10): a new category shows first
	end
	db.categories[id] = def
	changed()
	C.Load()
	if err then
		return id, "broken", err
	elseif #warnings > 0 then
		return id, "warned", warnings
	end
	return id
end

function C.Save(id, fields)
	if SB.Config.readOnly then
		return false, "readonly"
	end
	C.Ensure()
	local c = C.byId[id]
	if not c or type(fields) ~= "table" then
		return false, "unknown"
	end
	local out = {}
	if fields.name ~= nil then
		local clean, why = C.CheckName(fields.name, id)
		if not clean then
			return false, why
		end
		out.name = clean
	end
	if fields.query ~= nil then
		local why = queryWhy(fields.query)
		if why then
			return false, why
		end
		out.query = fields.query
	end
	local p = fields.priority
	if p ~= nil and p ~= c.priority then
		if C.PINNED[id] then
			return false, "pinned" -- Junk, Sets, Keystone & Crests and Reagents keep their rank
		elseif type(p) ~= "number" or p ~= math.floor(p) or p < C.MIN_PRIORITY or p > C.MAX_PRIORITY then
			return false, "priority"
		end
		out.priority = p
	end
	if fields.enabled ~= nil then
		out.enabled = fields.enabled == true
	end
	local err, warnings = check(out.query or c.query or "")
	local e, kept = editFor(c), false
	if err and out.query ~= nil and not c.error then
		-- Spec 7.5 #3: the rule that works stays in use, and on; the new text waits as its draft (AC6.2: never lost)
		e.draft, out.query, kept = out.query, nil, true
	elseif err then
		out.enabled = false -- AC6.2: no rule that works to keep: saved switched off, the error shown
	else
		if out.query ~= nil then
			e.draft = nil -- a rule that compiles replaces the rule in use and its draft
		end
		if c.error and fields.enabled == nil then
			out.enabled = true -- fixed: on again, also where the editor sends no On/Off (Reagents' is a setting)
		end
	end
	local def = c.builtin and default(id) or nil
	for f, v in pairs(out) do
		if def and (v == def[f] or (f == "enabled" and v == true and def.enabled == nil)) then
			e[f] = nil -- a built-in keeps only what differs from its default (spec 8.5)
		else
			e[f] = v
		end
	end
	prune(c, e)
	changed()
	C.Load()
	if err then
		return true, kept and "draft" or "broken", err
	elseif #warnings > 0 and out.query ~= nil and out.query ~= c.query then
		return true, "warned", warnings -- a changed rule's (an unchanged one's were said when it was saved)
	end
	return true
end

-- One section id out of a comma-separated list; the new list, or nil when it was not there.
local function without(ids, id)
	if type(ids) ~= "string" then
		return nil
	end
	local out, found = {}, false
	for sid in ids:gmatch("[^,]+") do
		if sid == id then
			found = true
		else
			out[#out + 1] = sid
		end
	end
	return found and table.concat(out, ",") or nil
end

function C.Delete(id)
	if SB.Config.readOnly then
		return false, "readonly"
	end
	C.Ensure()
	local c = C.byId[id]
	if not c then
		return false, "unknown"
	elseif c.builtin then
		return false, "builtin"
	end
	local Cfg = SB.Config
	Cfg.db.categories[id] = false -- deleted: Load skips it, and Create never gives its id again (a stale id elsewhere)
	if type(Cfg.db.categoryOrder) == "table" then
		for i = #Cfg.db.categoryOrder, 1, -1 do
			if Cfg.db.categoryOrder[i] == id then
				table.remove(Cfg.db.categoryOrder, i)
			end
		end
	end
	-- Focus modes that opened it (spec 6.1): the account's sections and this character's own, both layers.
	local account = type(Cfg.db.settings.focus) == "table" and type(Cfg.db.settings.focus.sections) == "table"
		and Cfg.db.settings.focus.sections or {}
	local focusChanged = false
	local modes = {}
	for mode in pairs(Cfg.Defaults.settings.focus.sections) do
		modes[mode] = true
	end
	for mode in pairs(account) do
		modes[mode] = true -- week 12: the user's own focus modes too (AC8.7)
	end
	for path in pairs(Cfg.charDB.overrides) do
		local mode = type(path) == "string" and path:match("^focus%.sections%.(.+)$")
		if mode then
			modes[mode] = true
		end
	end
	for mode in pairs(modes) do
		local left = without(account[mode], id)
		if left then
			account[mode], focusChanged = left, true
		end
		local path = "focus.sections." .. mode
		left = without(Cfg.charDB.overrides[path], id)
		if left then
			Cfg.charDB.overrides[path], focusChanged = left, true
		end
	end
	local collapsed = Cfg.UI().collapsed
	for _, windowSet in pairs(type(collapsed) == "table" and collapsed or {}) do
		if type(windowSet) == "table" then
			windowSet[id] = nil
		end
	end
	changed()
	C.Load()
	if focusChanged then
		SB.Emit("SB_CONFIG_CHANGED", "focus.sections") -- Focus forgets its section sets; nothing open moves (P5)
	end
	return true
end

function C.Move(id, step)
	if SB.Config.readOnly then
		return false, "readonly"
	end
	C.Ensure()
	local order, at = {}, nil
	for i, c in ipairs(C.display) do
		order[i] = c.id
		if c.id == id then
			at = i
		end
	end
	if not at then
		return false, "unknown"
	end
	local to = at + step
	if to < 1 or to > #order then
		return false, "edge"
	end
	order[at], order[to] = order[to], order[at]
	SB.Config.db.categoryOrder = order
	changed()
	C.Load()
	return true
end

-- How many of the bags' items (stacks) a query matches right now, of how many: for the editor's preview. A query
-- with an error, or one that fails while matching, answers nil and why.
function C.Preview(query)
	local compiled = SB.Query.Compile(query or "")
	if not compiled.fn then
		return nil, SB.Query.FormatError(compiled.errors[1])
	end
	local matches, total = 0, 0
	local ok = pcall(function()
		for bag, slot, s in SB.Inventory.Iterate("bags") do
			if s then
				local record = SB.Items.Describe(bag, slot)
				if record then
					total = total + 1
					if SB.Query.Eval(compiled, record) == true then
						matches = matches + 1
					end
				end
			end
		end
	end)
	if not ok then
		return nil, SB.L.SEARCH_EVAL_FAILED
	end
	return matches, total
end

SB.On("SB_LOGIN", function()
	C.Load()
end, "bags")
