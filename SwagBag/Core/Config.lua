-- SwagBag Config: account DB (SwagBagDB) + per-character DB (SwagBagCharDB).
--   Config.Init(db, charDB) -> status: "new" | "ok" | "migrated" | "reset" | "newer"
--   Config.Get(path) / Config.Set(path, value)   dotted paths, e.g. "bags.columns"
--   Config.CharOverride(path, on)                make one setting character-specific
--   Config.CharOverrideMany(paths, on)           the same for many paths, one SB_CONFIG_CHANGED(nil)
--   Config.UI()                                  per-character UI state (positions, collapsed)
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
		-- view: "sections" (category view) | "grid" | "list" | "bags" (one section per bag, 0.17);
		-- newRows: rows kept for New while open;
		-- reagentSeparate: show the reagent bag as its own "Reagents" section (spec AC1.4);
		-- showIlvl: the title shows the average equipped item level (plan D18);
		-- freeTile: Free shows one tile per bag family with the number of free slots, false shows
		-- every free slot (plan D19; the bank window follows it too). newAlways: New keeps its header
		-- and rows when empty; false (default) shows New only once something new arrives (W4-15). One setting
		-- for the bags, bank and guild bank windows.
		-- stacks: "one" shows several stacks of one item as one icon with the total (display only); "all" every stack.
		bags = { columns = 12, scale = 1.0, view = "sections", newRows = 2, reagentSeparate = false,
			showIlvl = true, freeTile = true, newAlways = false, stacks = "one",
			-- warnOtherAddons (week 9): one chat line at login while another bag addon is on too (Core/Report.lua).
			warnOtherAddons = true,
			-- list: the list view's order (Engine/Sort.lua; the bags window's third view). sort: "value" |
			-- "name" | "count" | "ilvl"; desc: highest first (Z to A for names). Default: worth most first.
			list = { sort = "value", desc = true },
			-- footer.entries: the bar under the items (UI/Footer.lua, W4-14), left to right; "-" before
			-- an entry that is off. Unknown ids are dropped; an entry added later joins at its default place, on (W4-23).
			footer = { entries = "gold,currencies,crests,keystone,free" } },
		safeMode = { bags = false, bank = false },
		-- blizzardFrame: "tiny" (Blizzard's bank invisible, its tabs on SwagBag's window) |
		-- "beside" (Blizzard's bank visible, SwagBag's window next to it; spec 5.4, check V2).
		-- view: "sections" | "grid" | "list" | "bags" (one section per bank tab, 0.17); columns: slots per row in
		-- the bank window.
		-- show (week 13): "one" (the bank Blizzard's selected tab deposits into is open, the other folds to one
		-- line) | "both" (both open; the saved group folds decide).
		-- gold (0.14.2): the Warband gold row (balance, Deposit, Withdraw) under the bank window's items.
		bank = { blizzardFrame = "tiny", show = "one", groupColors = true, view = "sections", columns = 14, gold = true },
		-- mode: "full" (SwagBag's window replaces Blizzard's; spec F16) | "view" (read-only window
		-- with Blizzard's frame beside it; the fallback if check G1 fails). withdrawAnyTab: a
		-- right-click withdraws from any tab (false: only from the tab Blizzard has selected).
		-- Off until check G1 proves the client withdraws from the tab it is given (ruling W3-10).
		-- view / columns: as for the bank window.
		guildBank = { mode = "full", withdrawAnyTab = false, view = "sections", columns = 14 },
		-- headerTotals: each section header shows its total value (spec F10).
		-- worth (week 7, user pick 7; spec v1.1 "worth-money highlight"): while the bank is open, a gold glow
		-- on items worth "fixed" (worthGold gold or more a stack, default 100) | "top" (your most valuable
		-- worthTop percent) | "off". source (week 9, user pick 10): who prices items: "auto" (Auctionator, else TSM,
		-- else the vendor) | "auctionator" | "tsm" | "vendor"; tsm: TSM's price string (Engine/Prices.lua).
		prices = { headerTotals = true, worth = "fixed", worthGold = 100, worthTop = 10, source = "auto", tsm = "DBMarket" },
		-- Overlays on item buttons (spec F9); usePawn: Pawn decides the upgrade arrow. bind: the "BoE" /
		-- "WuE" badge, off by default since week 6 (user request: the item level, track and badge were
		-- too cluttered; the "BoE gear" and "Warbound until equipped" sections say it instead). Only a
		-- value the user saved is stored (Config.Get falls back to these defaults), so whoever never
		-- touched it gets the new default and whoever saved "on" keeps it.
		-- learn (week 7): a green glow on items to open or learn (caches, toys, mounts, pets, decor, knowledge).
		-- lock (week 7): a small padlock on items the user locked (Engine/Locks.lua).
		-- uncollected (week 7): a star on gear whose look is not collected, and on new toys, mounts, pets.
		-- ilvlColors / ilvlSteps (0.17, Engine/IlvlColors.lua): colour the item level by steps, off by
		-- default (item levels stay white); steps is text like "680:green,690:blue", up to 4.
		overlays = { ilvl = true, track = true, upgrade = true, keystone = true, junk = true, bind = false,
			learn = true, lock = true, uncollected = true, usePawn = false, ilvlColors = false, ilvlSteps = "" },
		-- Focus modes (spec 6, Engine/Focus.lua). auto: modes switch by themselves (AC8.1); off by
		-- default since 0.14.3 (user request: sections moving with what you do is opt-in);
		-- resolve: "merge" (open the union, default) | "priority" (combat > activity > location,
		-- AC8.4); peek: a click on a collapsed header opens it until the bag closes ("peek") or
		-- until the mode changes ("keep", AC8.3); announce: one chat line per mode change (spec
		-- 6.4, default off); on.<mode>: each built-in mode (all on); sections.<mode>: the sections
		-- the mode opens, comma-separated category ids (New is always open). style: "front" (default:
		-- a mode moves its sections to the top, right after New, and collapses nothing) | "collapse"
		-- (a mode collapses every section it does not open; week 4's behaviour). Week 6, user request.
		-- Equipment sets (c_sets, week 7) join every mode that opens Gear.
		focus = { auto = false, resolve = "merge", peek = "peek", announce = false, style = "front",
			on = { mplus = true, raid = true, delves = true, gathering = true, fishing = true, market = true },
			sections = {
				mplus = "c_consumables,c_keystone,c_gear,c_sets",
				raid = "c_consumables,c_gear,c_sets",
				delves = "c_consumables,c_gear,c_sets",
				gathering = "c_herbs,c_ore,c_leathercloth,c_tools",
				fishing = "c_fish,c_cooking",
				market = "c_junk,c_tradegoods,c_boe,c_wue",
			} },
		-- At a vendor (week 7, user pick 4; Engine/Vendor.lua). autoSell: sell gray junk at every vendor (on).
		-- repair: "off" (default since 0.14.5, user request: repairing by itself is opt-in) | "own" (repair with
		-- your gold) | "guild" (the guild bank first).
		vendor = { autoSell = true, repair = "off" },
		-- mode: what the Sort buttons (bags, bank, warband) do (week 9, user pick 8): "blizzard" (Blizzard's own
		-- sort, the default) | "stacks" (SwagBag merges partial stacks, then puts each item's partial stack in front
		-- of its full ones, for TSM posting; Engine/Stacker.lua).
		sort = { mode = "blizzard" },
		-- The low-consumables warning (spec 6.6, F11). warn: on by default. watch: nil means the
		-- default list (Engine/Consumables.lua); the user's edited list is stored here.
		consumables = { warn = true },
		-- done: the setup wizard was finished or skipped (UI/QuickSetup.lua); account-wide,
		-- like the settings it sets, so it shows once per account, not once per character.
		-- styles (week 12): the playstyles picked at the last Finish ("mplus,gold"), so /swagbag setup starts from
		-- them. This machine's state, like done: never in a profile or a share string (Engine/Profiles.lua KEEP).
		setup = { done = false, styles = "" },
		-- name: the look of SwagBag's own windows (UI/Theme.lua): "blizzard" (the default, AC14.1) |
		-- "flat" | "classic" (0.14.5) | "elvui" (UI/Themes.lua).
		theme = { name = "blizzard" },
		-- counts: other characters' counts on item tooltips (UI/TooltipCounts.lua): "auto" (shown unless
		-- Syndicator is loaded, which writes its own), "on", "off".
		tooltip = { counts = "auto" },
		-- warn (week 10, UI/LockWarnings.lua): warn before a locked item is destroyed (a spell waiting for its
		-- target, the delete box, the scrapper). Warnings only: SwagBag never stops Blizzard's own flows.
		locks = { warn = true },
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
	-- Captured before the migrations run: migration 1 reassigns db.backups.
	local kept = type(db.backups) == "table" and copy(db.backups) or {}
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
	for k, v in pairs(kept) do
		reset.backups[k] = v
	end
	reset.backups["v" .. from] = backup
	return reset, "reset", tostring(err)
end

local RANK = { ok = 1, new = 2, migrated = 3, reset = 4 }

-- SB_CONFIG_CHANGED(path): a setting changed (path), or everything may have (nil: Init, Reset).
-- Engines that cache a view of the settings (Engine/Focus.lua) listen. Harmless before Events loads.
local function changed(path)
	if SB.Emit then
		SB.Emit("SB_CONFIG_CHANGED", path)
	end
end

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
		changed(nil)
		return Config.status
	end
	local a, sa, ea = upgrade(db, Config.migrations, newDB)
	local c, sc, ec = upgrade(charDB, Config.charMigrations, newCharDB)
	Config.readOnly = false
	Config.db, Config.charDB = a, c
	Config.status = RANK[sa] >= RANK[sc] and sa or sc
	Config.lastError = ea or ec
	changed(nil)
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
		changed(path)
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
	changed(path)
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
	changed(path)
	return true
end

-- Many overrides as one change: all applied, then one SB_CONFIG_CHANGED(nil). Nothing is
-- applied while read-only.
function Config.CharOverrideMany(paths, on)
	if Config.readOnly then
		return false
	end
	for _, path in ipairs(paths) do
		if on then
			if Config.charDB.overrides[path] == nil then
				Config.charDB.overrides[path] = Config.Get(path)
			end
		else
			Config.charDB.overrides[path] = nil
		end
	end
	changed(nil)
	return true
end

function Config.IsCharOverride(path)
	return Config.charDB.overrides[path] ~= nil
end

function Config.UI()
	return Config.charDB.ui
end

-- The account DB's saved snapshots (Engine/Snapshots.lua): kept by Reset (ruling W3-39).
local SNAPSHOT_KEYS = { "chars", "warband", "guilds" }

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
	-- When not read-only, back up the LIVE tables and preserve existing backups. The saved
	-- snapshots are not settings: they move to the new DB as they are and stay out of the
	-- backup (ruling W3-39).
	local kept = {}
	for _, k in ipairs(SNAPSHOT_KEYS) do
		kept[k] = Config.db[k]
		Config.db[k] = nil
	end
	local oldDB = copy(Config.db)
	local oldChar = copy(Config.charDB)
	local existingDBBackups = oldDB.backups or {}
	local existingCharBackups = oldChar.backups or {}
	oldDB.backups = nil
	oldChar.backups = nil
	Config.db, Config.charDB = newDB(), newCharDB()
	for _, k in ipairs(SNAPSHOT_KEYS) do
		Config.db[k] = kept[k]
	end
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
	changed(nil)
	return Config.db, Config.charDB
end
