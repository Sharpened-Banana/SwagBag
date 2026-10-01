-- SwagBag Config: account DB (SwagBagDB) + per-character DB (SwagBagCharDB).
--   Config.Init(db, charDB) -> status: "new" | "ok" | "migrated" | "reset" | "newer"
--   Config.Get(path) / Config.Set(path, value)   dotted paths, e.g. "bags.columns"
--   Config.CharOverride(path, on)                make one setting character-specific
--   Config.UI()                                  per-character UI state (positions)
--   Config.Reset()                               back up, then start from defaults
-- Schema rules (spec 8.5): a DB newer than CURRENT is never touched (read-only,
-- Safe Mode); older DBs run migrations[n] (n-1 -> n) in order inside pcall; a
-- failing migration keeps a backup under db.backups["v<old>"] and resets.
-- Schema 2 (spec 8.2, 8.5): SwagBagDB.categories (user categories), .userEdits (diffs
-- of built-in categories; built-ins themselves are never stored), .categoryOrder (nil =
-- default order); SwagBagCharDB.ui.collapsed[window][sectionId] = true.
local _, SB = ...

local Config = { CURRENT = 2, migrations = {}, charMigrations = {} }
SB.Config = Config

Config.Defaults = {
	settings = {
		-- view: "sections" (category view) | "grid"; newRows: rows kept for New while open;
		-- reagentSeparate: show the reagent bag as its own "Reagents" section (spec AC1.4).
		bags = { columns = 12, scale = 1.0, view = "sections", newRows = 2, reagentSeparate = false },
		safeMode = { bags = false, bank = false },
	},
}

local function copy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, val in pairs(v) do
		out[k] = copy(val)
	end
	return out
end
Config.Copy = copy

local function newDB()
	return { schemaVersion = Config.CURRENT, settings = {}, errors = {}, backups = {}, categories = {}, userEdits = {} }
end

local function newCharDB()
	return { schemaVersion = Config.CURRENT, overrides = {}, ui = { positions = {}, collapsed = {} }, backups = {} }
end

local function tableOr(v)
	return type(v) == "table" and v or {}
end

-- v0 -> v1: tables written before schemaVersion existed. Keep what we recognise.
Config.migrations[1] = function(db)
	db.settings = tableOr(db.settings)
	db.errors = tableOr(db.errors)
	db.backups = tableOr(db.backups)
end

Config.charMigrations[1] = function(c)
	c.overrides = tableOr(c.overrides)
	c.ui = tableOr(c.ui)
	c.ui.positions = tableOr(c.ui.positions)
	c.backups = tableOr(c.backups)
end

-- v1 -> v2: category storage (week 2). Nothing to convert; damaged values are dropped.
Config.migrations[2] = function(db)
	db.categories = tableOr(db.categories)
	db.userEdits = tableOr(db.userEdits)
	if type(db.categoryOrder) ~= "table" then
		db.categoryOrder = nil
	end
end

Config.charMigrations[2] = function(c)
	c.ui = tableOr(c.ui)
	c.ui.collapsed = tableOr(c.ui.collapsed)
end

-- Returns table, status, errorMessage
local function upgrade(db, steps, fresh)
	if type(db) ~= "table" then
		return fresh(), "new"
	end
	local from = tonumber(db.schemaVersion) or 0
	if from > Config.CURRENT then
		return db, "newer"
	end
	if from == Config.CURRENT then
		return db, "ok"
	end
	local backup = copy(db)
	backup.backups = nil
	local ok, err = pcall(function()
		for n = from + 1, Config.CURRENT do
			local step = steps[n]
			if not step then
				error("no migration to schema " .. n)
			end
			step(db)
			db.schemaVersion = n
		end
	end)
	if ok then
		return db, "migrated"
	end
	local reset = fresh()
	reset.backups["v" .. from] = backup
	return reset, "reset", tostring(err)
end

local RANK = { ok = 1, new = 2, migrated = 3, reset = 4 }

function Config.Init(db, charDB)
	Config.lastError = nil
	Config.source = { db = db, charDB = charDB }
	-- Check schema versions BEFORE upgrading: if either is newer, don't touch either table
	local dbVersion = type(db) == "table" and (tonumber(db.schemaVersion) or 0) or 0
	local charVersion = type(charDB) == "table" and (tonumber(charDB.schemaVersion) or 0) or 0
	if dbVersion > Config.CURRENT or charVersion > Config.CURRENT then
		Config.status = "newer"
		Config.readOnly = true
		Config.db, Config.charDB = newDB(), newCharDB() -- in memory only; saved tables untouched
		return Config.status
	end
	local a, sa, ea = upgrade(db, Config.migrations, newDB)
	local c, sc, ec = upgrade(charDB, Config.charMigrations, newCharDB)
	Config.readOnly = false
	Config.db, Config.charDB = a, c
	Config.status = RANK[sa] >= RANK[sc] and sa or sc
	Config.lastError = ea or ec
	return Config.status
end

local function split(path)
	local parts = {}
	for p in path:gmatch("[^%.]+") do
		parts[#parts + 1] = p
	end
	return parts
end

local function walk(t, parts)
	for i = 1, #parts do
		if type(t) ~= "table" then
			return nil
		end
		t = t[parts[i]]
	end
	return t
end

function Config.Get(path)
	local o = Config.charDB.overrides[path]
	if o ~= nil then
		return o
	end
	local parts = split(path)
	local v = walk(Config.db.settings, parts)
	if v ~= nil then
		return v
	end
	return walk(Config.Defaults.settings, parts)
end

-- Returns false (and changes nothing) while the DB is read-only.
function Config.Set(path, value)
	if Config.readOnly then
		return false
	end
	if Config.charDB.overrides[path] ~= nil then
		Config.charDB.overrides[path] = value
		return true
	end
	local parts = split(path)
	local t = Config.db.settings
	for i = 1, #parts - 1 do
		if type(t[parts[i]]) ~= "table" then
			t[parts[i]] = {}
		end
		t = t[parts[i]]
	end
	t[parts[#parts]] = value
	return true
end

function Config.CharOverride(path, on)
	if Config.readOnly then
		return false
	end
	if on then
		if Config.charDB.overrides[path] == nil then
			Config.charDB.overrides[path] = Config.Get(path)
		end
	else
		Config.charDB.overrides[path] = nil
	end
	return true
end

function Config.IsCharOverride(path)
	return Config.charDB.overrides[path] ~= nil
end

function Config.UI()
	return Config.charDB.ui
end

-- Wipe both DBs after keeping a copy of the saved data. Returns the new tables,
-- which the caller assigns to SwagBagDB / SwagBagCharDB.
function Config.Reset()
	if Config.readOnly then
		-- When read-only (newer schema), back up the saved tables without touching them
		local src = Config.source or {}
		local oldDB = type(src.db) == "table" and copy(src.db) or nil
		local oldChar = type(src.charDB) == "table" and copy(src.charDB) or nil
		if oldDB then
			oldDB.backups = nil
		end
		if oldChar then
			oldChar.backups = nil
		end
		Config.db, Config.charDB = newDB(), newCharDB()
		Config.db.backups.reset = oldDB
		Config.charDB.backups.reset = oldChar
		Config.source = { db = Config.db, charDB = Config.charDB }
		Config.readOnly = false
		Config.status = "ok"
		return Config.db, Config.charDB
	end
	-- When not read-only, back up the LIVE tables and preserve existing backups
	local oldDB = copy(Config.db)
	local oldChar = copy(Config.charDB)
	local existingDBBackups = oldDB.backups or {}
	local existingCharBackups = oldChar.backups or {}
	oldDB.backups = nil
	oldChar.backups = nil
	Config.db, Config.charDB = newDB(), newCharDB()
	-- Carry over existing backups (e.g., v<N> from failed migrations)
	for k, v in pairs(existingDBBackups) do
		Config.db.backups[k] = v
	end
	for k, v in pairs(existingCharBackups) do
		Config.charDB.backups[k] = v
	end
	Config.db.backups.reset = oldDB
	Config.charDB.backups.reset = oldChar
	Config.source = { db = Config.db, charDB = Config.charDB }
	Config.readOnly = false
	Config.status = "ok"
	return Config.db, Config.charDB
end
