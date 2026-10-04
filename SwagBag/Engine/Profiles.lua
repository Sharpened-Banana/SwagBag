-- SwagBag profiles and share strings (week 7, user pick 12). Account-wide, in SwagBagDB (read
-- defensively; the schema stays 2): profiles = { [name] = { settings = <copy>, saved = epoch } },
-- profile = the name last saved or loaded (shown only), backups.profile = { settings, and after an import
-- with categories also categories, userEdits, categoryOrder } as they were before the last load, import or
-- reset (one step of undo, ruling R6). A profile is a copy of the account settings the user set
-- (SwagBagDB.settings: only values somebody chose, Config.Get falls back to the defaults); Safe Mode and
-- the quick-setup flag are this machine's state and never travel. Character overrides stay as they are.
--   Profiles.List() -> { name }              Profiles.Save(name) / Load(name) / Delete(name) -> ok, why
--   Profiles.Reset() / Undo() -> ok, why     why: "readonly" | "name" | "unknown" | "none"
--   Profiles.Export(withCategories) -> text  "SWAGBAG:1:" then key=value entries joined by ";"
--   Profiles.Parse(text) -> data | nil, error, detail   never runs anything it reads (no load, no
--                                            loadstring): patterns only; every value is checked
--   Profiles.Preview(data) -> { line }        what an import would change, each setting by its name in the
--                                            settings window (Profiles.Label(path), ruling R18)
--   Profiles.Import(data) -> n               apply (current settings kept for Undo); n changes
-- Share string, version 1. Values: b1 / b0 (boolean), n<number>, s<text> with every character other
-- than letters, digits, "." "_" "-" written %XX (so spaces and line breaks a paste adds are dropped). Keys:
--   s.<setting path>            a setting the user set (a known path; the default's type)
--   w                           the consumables watch list: entries "q<query>*<n>*<name>" or "i<itemID>*<n>"
--                               joined by "," (each part escaped again)
--   cu.<id>.<field> / ce.<id>.<field>   a category of the user's / a built-in's edit (with categories):
--                               name (s), query (s), priority (n), displayOrder (n), enabled (b), inc / exc (s:
--                               item IDs joined by ",")
--   co                          the category order (s: ids joined by ",")
-- A string from a newer SwagBag, a damaged one, or one with a known setting of the wrong type or outside
-- what that setting may hold (VALID: a range or the allowed words, ruling R3) is refused whole; settings this
-- version does not know are skipped and named in the preview; NEVER settings (a safety switch of this
-- machine's) are never exported or imported, and the preview names them too.
local _, SB = ...

local L = SB.L
local Pr = { VERSION = 1, HEADER = "SWAGBAG:", MAX_TEXT = 30000, MAX_ENTRIES = 1500, MAX_STRING = 500,
	MAX_NAME = 24, MAX_ITEM = 10000000, MAX_NUM = 1000, MAX_CATEGORIES = 100, MAX_PRIORITY = 90, MAX_LIST = 2000, MAX_WATCH = 50 }
SB.Profiles = Pr

local KEEP = { safeMode = true, setup = true } -- this machine's state: never saved, loaded or shared
local FIELD_TYPES = { name = "string", query = "string", priority = "number", displayOrder = "number",
	enabled = "boolean", inc = "list", exc = "list" }
-- Never in a share string: withdrawAnyTab is the guild bank's safety switch (off until check G1, W3-10);
-- vendor.repair is a money choice (the guild bank's gold) that only its owner may make on this account.
local NEVER = { ["guildBank.withdrawAnyTab"] = true, ["vendor.repair"] = true }

-- What each setting may hold beyond its type (ruling R3): a number range (whole numbers where marked), the
-- allowed words, or a text pattern. A setting not listed here is checked by its type only (the booleans).
local function range(lo, hi, whole)
	return function(v)
		return v >= lo and v <= hi and (not whole or v == math.floor(v))
	end
end

local function words(...)
	local set = {}
	for _, w in ipairs({ ... }) do
		set[w] = true
	end
	return function(v)
		return set[v] == true
	end
end

local function pattern(p)
	return function(v)
		return v:match(p) ~= nil
	end
end

local COLUMNS, SECTION_IDS = range(4, 40, true), pattern("^[%w_,]*$")
local VALID = {
	["bags.columns"] = COLUMNS, ["bags.scale"] = range(0.5, 2), ["bags.newRows"] = range(0, 10, true),
	["bags.view"] = words("sections", "grid", "list"), ["bags.list.sort"] = words("value", "name", "count", "ilvl"),
	["bags.footer.entries"] = pattern("^[%a,%-]*$"),
	["bank.blizzardFrame"] = words("tiny", "beside"), ["bank.view"] = words("sections", "grid", "list"), ["bank.columns"] = COLUMNS,
	["guildBank.mode"] = words("full", "view"), ["guildBank.view"] = words("sections", "grid", "list"),
	["guildBank.columns"] = COLUMNS,
	["prices.worth"] = words("fixed", "top", "off"), ["prices.worthGold"] = range(1, 10000000, true),
	["prices.worthTop"] = range(1, 50, true),
	["focus.resolve"] = words("merge", "priority"), ["focus.peek"] = words("peek", "keep"),
	["focus.style"] = words("front", "collapse"),
	["vendor.repair"] = words("own", "guild", "off"), ["theme.name"] = words("blizzard", "flat", "elvui"),
	["tooltip.counts"] = words("auto", "on", "off"), ["sort.mode"] = words("blizzard", "stacks"),
}

local function valid(path, v)
	local check = VALID[path] or (path:match("^focus%.sections%.") and SECTION_IDS)
	return check == nil or check(v)
end

-- A setting's name in the settings window (ruling R18: the preview never shows a dotted path).
local LABELS = {
	["bags.view"] = "SET_VIEW", ["bags.columns"] = "SET_COLUMNS", ["bags.scale"] = "SET_SCALE",
	["bags.freeTile"] = "PROFILE_LABEL_FREE_TILE", ["bags.newAlways"] = "PROFILE_LABEL_NEW_ALWAYS",
	["bags.reagentSeparate"] = "PROFILE_LABEL_REAGENTS",
	["bags.newRows"] = "PROFILE_LABEL_NEW_ROWS", ["bags.showIlvl"] = "PROFILE_LABEL_SHOW_ILVL",
	["bags.list.sort"] = "SET_LIST_SORT", ["bags.list.desc"] = "PROFILE_LABEL_LIST_DESC",
	["bags.footer.entries"] = "PROFILE_LABEL_FOOTER",
	["bank.blizzardFrame"] = "SET_BANK_FRAME", ["bank.view"] = "PROFILE_LABEL_BANK_VIEW",
	["bank.columns"] = "PROFILE_LABEL_BANK_COLUMNS",
	["guildBank.mode"] = "SET_GUILD_MODE", ["guildBank.withdrawAnyTab"] = "PROFILE_LABEL_ANYTAB",
	["guildBank.view"] = "PROFILE_LABEL_GUILD_VIEW", ["guildBank.columns"] = "PROFILE_LABEL_GUILD_COLUMNS",
	["prices.headerTotals"] = "SET_TOTALS", ["prices.worth"] = "SET_WORTH",
	["prices.worthGold"] = "PROFILE_LABEL_WORTH_GOLD", ["prices.worthTop"] = "PROFILE_LABEL_WORTH_TOP",
	["overlays.ilvl"] = "SET_OV_ILVL", ["overlays.track"] = "SET_OV_TRACK", ["overlays.upgrade"] = "SET_OV_UPGRADE",
	["overlays.keystone"] = "SET_OV_KEYSTONE", ["overlays.junk"] = "SET_OV_JUNK", ["overlays.bind"] = "SET_OV_BIND",
	["overlays.learn"] = "SET_OV_LEARN", ["overlays.lock"] = "SET_OV_LOCK", ["overlays.uncollected"] = "SET_OV_UNCOLLECTED",
	["overlays.usePawn"] = "PROFILE_LABEL_PAWN",
	["focus.auto"] = "PROFILE_LABEL_FOCUS_AUTO", ["focus.resolve"] = "PROFILE_LABEL_FOCUS_RESOLVE",
	["focus.peek"] = "PROFILE_LABEL_FOCUS_PEEK", ["focus.announce"] = "PROFILE_LABEL_FOCUS_ANNOUNCE",
	["focus.style"] = "PROFILE_LABEL_FOCUS_STYLE",
	["vendor.autoSell"] = "SET_VENDOR_SELL", ["vendor.repair"] = "SET_VENDOR_REPAIR",
	["consumables.warn"] = "SET_WATCH_WARN", ["theme.name"] = "SET_LOOK", ["tooltip.counts"] = "SET_TIP",
	["sort.mode"] = "SET_SORT",
}
local MODES = { mplus = "MODE_MPLUS", raid = "MODE_RAID", delves = "MODE_DELVES", gathering = "MODE_GATHERING",
	fishing = "MODE_FISHING", market = "MODE_MARKET" }

function Pr.Label(path)
	local key = LABELS[path]
	if key then
		return L[key]
	end
	local kind, mode = path:match("^focus%.(%a+)%.(%a+)$")
	if MODES[mode] and kind == "on" then
		return L.PROFILE_LABEL_FOCUS_ON:format(L[MODES[mode]])
	elseif MODES[mode] and kind == "sections" then
		return L.PROFILE_LABEL_FOCUS_SECTIONS:format(L[MODES[mode]])
	end
	return path
end

local function db()
	return SB.Config.db
end

local function profiles()
	local d = db()
	if type(d.profiles) ~= "table" then
		d.profiles = {}
	end
	return d.profiles
end

local function cleanName(name)
	name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
	if name == "" or #name > Pr.MAX_NAME or name:find("[%c|]") then
		return nil
	end
	return name
end

-- The settings without this machine's state, copied.
local function shareable(settings)
	local out = {}
	for k, v in pairs(type(settings) == "table" and settings or {}) do
		if not KEEP[k] then
			out[k] = SB.Config.Copy(v)
		end
	end
	return out
end

-- The one step of undo: the settings as they are now, and with categories (an import that carries them,
-- ruling R6) the user's categories, built-in edits and order too.
local function backup(withCategories)
	local d = db()
	d.backups = type(d.backups) == "table" and d.backups or {}
	local back = { settings = SB.Config.Copy(type(d.settings) == "table" and d.settings or {}) }
	if withCategories then
		back.withCategories = true
		back.categories = SB.Config.Copy(type(d.categories) == "table" and d.categories or {})
		back.userEdits = SB.Config.Copy(type(d.userEdits) == "table" and d.userEdits or {})
		back.categoryOrder = SB.Config.Copy(d.categoryOrder)
	end
	d.backups.profile = back
end

-- Replace the account settings by `settings`, keeping this machine's state (the caller made the backup).
local function replace(settings)
	local d = db()
	local old = type(d.settings) == "table" and d.settings or {}
	local new = shareable(settings)
	for k in pairs(KEEP) do
		new[k] = SB.Config.Copy(old[k])
	end
	d.settings = new
	SB.Emit("SB_CONFIG_CHANGED", nil)
	Pr.Follow()
end

-- The open windows follow at once, exactly as after quick setup (SB.FollowSettings, Core/Init.lua: one
-- definition, ruling R12), and the look.
function Pr.Follow()
	SB.FollowSettings("profile")
	if SB.Theme and SB.Theme.Apply then
		SB.Theme.Apply(SB.Config.Get("theme.name"), false)
	end
end

function Pr.List()
	local out = {}
	for name, p in pairs(type(db().profiles) == "table" and db().profiles or {}) do
		if type(name) == "string" and type(p) == "table" and type(p.settings) == "table" then
			out[#out + 1] = name
		end
	end
	table.sort(out)
	return out
end

function Pr.Save(name)
	name = cleanName(name)
	if not name then
		return false, "name"
	elseif SB.Config.readOnly then
		return false, "readonly"
	end
	profiles()[name] = { settings = shareable(db().settings), saved = SB.Adapter.Time() }
	db().profile = name
	return true, name
end

function Pr.Load(name)
	local p = type(db().profiles) == "table" and db().profiles[name]
	if type(p) ~= "table" or type(p.settings) ~= "table" then
		return false, "unknown"
	elseif SB.Config.readOnly then
		return false, "readonly"
	end
	backup(false)
	replace(p.settings)
	db().profile = name
	return true
end

function Pr.Delete(name)
	if type(db().profiles) ~= "table" or db().profiles[name] == nil then
		return false, "unknown"
	elseif SB.Config.readOnly then
		return false, "readonly"
	end
	db().profiles[name] = nil
	if db().profile == name then
		db().profile = nil
	end
	return true
end

function Pr.Reset()
	if SB.Config.readOnly then
		return false, "readonly"
	end
	backup(false)
	replace({})
	db().profile = nil
	return true
end

function Pr.Undo()
	local d = db()
	if SB.Config.readOnly then
		return false, "readonly"
	elseif type(d.backups) ~= "table" or type(d.backups.profile) ~= "table"
		or type(d.backups.profile.settings) ~= "table" then
		return false, "none"
	end
	local back = d.backups.profile
	if back.withCategories then
		d.categories, d.userEdits = back.categories or {}, back.userEdits or {}
		d.categoryOrder = back.categoryOrder
	end
	replace(back.settings) -- Follow() loads the categories again
	d.backups.profile = nil
	return true
end

---------------------------------------------------------------------------
-- The share string
---------------------------------------------------------------------------
local function esc(text)
	return (tostring(text):gsub("[^%w%._%-]", function(c)
		return ("%%%02X"):format(c:byte())
	end))
end

local function unesc(text)
	if text:find("%%[^%x]") or text:find("%%%x[^%x]") or text:find("%%%x?$") then
		return nil
	end
	return (text:gsub("%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end))
end

local function encode(v)
	local t = type(v)
	if t == "boolean" then
		return v and "b1" or "b0"
	elseif t == "number" then
		return "n" .. ("%.17g"):format(v)
	end
	return "s" .. esc(v)
end

-- The scalar leaves of the defaults: { [path] = type } (consumables.watch is its own entry).
local function knownPaths()
	local out = {}
	local function walk(t, prefix)
		for k, v in pairs(t) do
			local path = prefix and (prefix .. "." .. k) or k
			if type(v) == "table" then
				walk(v, path)
			elseif not KEEP[path:match("^[^%.]+")] then
				out[path] = type(v)
			end
		end
	end
	walk(SB.Config.Defaults.settings, nil)
	return out
end
Pr.KnownPaths = knownPaths

local function leaves(t, prefix, out)
	for k, v in pairs(t) do
		local path = prefix and (prefix .. "." .. tostring(k)) or tostring(k)
		if type(v) == "table" then
			leaves(v, path, out)
		else
			out[path] = v
		end
	end
	return out
end

local function idList(t)
	local ids = {}
	for id, on in pairs(type(t) == "table" and t or {}) do
		if on and type(id) == "number" then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	for i, id in ipairs(ids) do
		ids[i] = tostring(id)
	end
	return table.concat(ids, ",")
end

local function categoryEntries(entries, prefix, id, def)
	for field, kind in pairs(FIELD_TYPES) do
		if kind == "list" then
			local which = field == "inc" and "include" or "exclude"
			local list = type(def.itemList) == "table" and idList(def.itemList[which]) or ""
			if list ~= "" then
				entries[#entries + 1] = prefix .. "." .. id .. "." .. field .. "=s" .. esc(list)
			end
		elseif type(def[field]) == kind then
			entries[#entries + 1] = prefix .. "." .. id .. "." .. field .. "=" .. encode(def[field])
		end
	end
end

function Pr.Export(withCategories)
	local d, known, entries = db(), knownPaths(), {}
	for path, v in pairs(leaves(shareable(d.settings), nil, {})) do
		if known[path] and type(v) == known[path] and not NEVER[path] then
			entries[#entries + 1] = "s." .. path .. "=" .. encode(v)
		end
	end
	local watch = type(d.settings) == "table" and type(d.settings.consumables) == "table" and d.settings.consumables.watch
	if type(watch) == "table" then
		local parts = {}
		for _, e in ipairs(watch) do
			if type(e) == "table" and type(e.threshold) == "number" then
				if type(e.itemID) == "number" then
					parts[#parts + 1] = esc("i" .. e.itemID .. "*" .. e.threshold)
				elseif type(e.query) == "string" then
					parts[#parts + 1] = esc("q" .. esc(e.query) .. "*" .. e.threshold .. "*" .. esc(e.name or ""))
				end
			end
		end
		entries[#entries + 1] = "w=s" .. esc(table.concat(parts, ","))
	end
	if withCategories then
		for id, def in pairs(type(d.categories) == "table" and d.categories or {}) do
			if type(def) == "table" then
				categoryEntries(entries, "cu", id, def)
			end
		end
		for id, def in pairs(type(d.userEdits) == "table" and d.userEdits or {}) do
			if type(def) == "table" then
				categoryEntries(entries, "ce", id, def)
			end
		end
		if type(d.categoryOrder) == "table" then
			local ids = {}
			for _, id in ipairs(d.categoryOrder) do
				if type(id) == "string" or type(id) == "number" then
					ids[#ids + 1] = tostring(id)
				end
			end
			entries[#entries + 1] = "co=s" .. esc(table.concat(ids, ","))
		end
	end
	table.sort(entries)
	return Pr.HEADER .. Pr.VERSION .. ":" .. table.concat(entries, ";")
end

local function decode(raw)
	local kind, body = raw:sub(1, 1), raw:sub(2)
	if kind == "b" and (body == "1" or body == "0") then
		return true, body == "1"
	elseif kind == "n" then
		local n = tonumber(body)
		if n and n == n and n ~= math.huge and n ~= -math.huge and body:match("^%-?[%d%.]+$") then
			return true, n
		end
	elseif kind == "s" then
		local s = unesc(body)
		if s then
			return true, s
		end
	end
	return false
end

local function numbers(text)
	local out, count = {}, 0
	for part in text:gmatch("[^,]+") do
		count = count + 1
		local n = tonumber(part)
		if count > Pr.MAX_LIST or not n or n < 1 or n > Pr.MAX_ITEM or n ~= math.floor(n) or n == math.huge or not part:match("^%d+$") then
			return nil
		end
		out[n] = true
	end
	return out
end

-- A real chat escape opener in a query: |T |H |A |K, |c with eight hex digits, or a named colour: |cn (or |cN)
-- followed by an upper-case name and ":" (|cnIQ4:, |cnGREEN_FONT_COLOR:; week 8, the narrowest rule that
-- still catches it). Every other "|" is the OR operator ("herb|cloth", "herb|cname").
local function escapeCode(text)
	return text:find("|[THAK]") ~= nil or text:find("|c%x%x%x%x%x%x%x%x") ~= nil
		or text:find("|c[nN][%u_][%u%d_]*:") ~= nil
end

-- Built-in categories whose priority an import never changes (protected: Junk, Sets, Keystone, Reagents).
local PINNED = { c_junk = true, c_sets = true, c_keystone = true, c_reagents = true }
Pr.PINNED = PINNED -- read by the drift-guard spec

-- A user category id has the shape SwagBag makes (u_...), which is never a built-in or a section id
-- (new, free, c_...); an edit may only name a built-in category.
local function idOk(prefix, id)
	if prefix == "cu" then
		return id:match("^u_[%w_]+$") ~= nil
	end
	for _, def in ipairs(SB.CategoryDefaults or {}) do
		if def.id == id then
			return true
		end
	end
	return false
end

local function parseWatch(text)
	local out = {}
	for part in text:gmatch("[^,]+") do
		local e = unesc(part)
		if not e then
			return nil
		end
		local id, n = e:match("^i(%d+)%*(%d+)$")
		local entry
		if id then
			entry = { itemID = tonumber(id), threshold = tonumber(n) }
		else
			local q, n2, name = e:match("^q([^%*]*)%*(%d+)%*([^%*]*)$")
			q, name = q and unesc(q), name and unesc(name)
			if not q or q == "" or #q > 200 or (name ~= "" and not name:match("^[%u_]+$")) then
				return nil
			end
			entry = { query = q, threshold = tonumber(n2), name = name ~= "" and name or nil }
		end
		if entry.threshold < 1 or entry.threshold > 200 or #out >= Pr.MAX_WATCH then
			return nil
		end
		out[#out + 1] = entry
	end
	return out
end

-- data = { settings = { [path] = value }, watch, users = { [id] = def }, edits = { [id] = def }, order,
--          skipped = { path }, ignored = { path } (NEVER settings), lowered = { id } (a priority of 90 or
--          more, imported as MAX_PRIORITY - 1, week 8; user categories and built-in edits other than the four
--          below), pinned = { id } (a priority edit of Junk, Sets, Keystone or Reagents: not imported) }
function Pr.Parse(text)
	if type(text) ~= "string" then
		return nil, "empty"
	end
	text = text:gsub("%s+", "")
	if text == "" then
		return nil, "empty"
	end
	local version, body = text:match("^SWAGBAG:(%d+):(.*)$")
	if not version then
		return nil, "notours"
	elseif tonumber(version) < 1 then
		return nil, "notours"
	elseif tonumber(version) > Pr.VERSION then
		return nil, "newer"
	elseif #text > Pr.MAX_TEXT then
		return nil, "toolong"
	end
	local known = knownPaths()
	local data = { settings = {}, users = {}, edits = {}, skipped = {}, ignored = {}, lowered = {}, pinned = {} }
	local seenLowered, seenPinned = {}, {}
	local count, cats = 0, {}
	for entry in body:gmatch("[^;]+") do
		count = count + 1
		if count > Pr.MAX_ENTRIES then
			return nil, "toolong"
		end
		local key, raw = entry:match("^([%w_%.]+)=(.+)$")
		local ok, value = false, nil
		if key then
			ok, value = decode(raw)
		end
		if not ok then
			return nil, "damaged", entry:sub(1, 40)
		end
		local path = key:match("^s%.(.+)$")
		local prefix, id, field = key:match("^(c[ue])%.([%w_]+)%.(%a+)$")
		if path then
			if NEVER[path] then
				data.ignored[#data.ignored + 1] = path
			elseif known[path] == nil then
				data.skipped[#data.skipped + 1] = path
			elseif type(value) ~= known[path] or (type(value) == "string" and #value > Pr.MAX_STRING) then
				return nil, "type", path
			elseif not valid(path, value) then
				return nil, "type", path -- outside the setting's range or words: refused whole (R3)
			else
				data.settings[path] = value
			end
		elseif key == "w" then
			data.watch = type(value) == "string" and parseWatch(value)
			if not data.watch then
				return nil, "damaged", "w"
			end
		elseif key == "co" then
			if type(value) ~= "string" then
				return nil, "damaged", "co"
			end
			data.order = {}
			for oid in value:gmatch("[^,]+") do
				if not oid:match("^[%w_]+$") then
					return nil, "damaged", "co"
				end
				data.order[#data.order + 1] = oid
			end
		elseif prefix and FIELD_TYPES[field] and #id <= 40 then
			if not idOk(prefix, id) then
				return nil, "type", key
			end
			local into = prefix == "cu" and data.users or data.edits
			if not into[id] then
				cats[#cats + 1] = id
				if #cats > Pr.MAX_CATEGORIES then
					return nil, "toolong"
				end
				into[id] = {}
			end
			local kind = FIELD_TYPES[field]
			if kind == "list" then
				local ids = type(value) == "string" and numbers(value)
				if not ids then
					return nil, "type", key
				end
				into[id].itemList = into[id].itemList or {}
				into[id].itemList[field == "inc" and "include" or "exclude"] = ids
			elseif type(value) ~= kind then
				return nil, "type", key
			elseif kind == "string" and (#value > Pr.MAX_STRING or value:find("%c")
				or (field == "name" and value:find("|", 1, true)) or (field == "query" and escapeCode(value))) then
				return nil, "type", key
			elseif kind == "number" and math.abs(value) > Pr.MAX_NUM then
				return nil, "type", key
			elseif field == "priority" and prefix == "ce" and PINNED[id] then
				-- Junk, Sets, Keystone and Reagents keep their rank here (week 8, ruling Q6): the edit is not
				-- imported, and the preview names it, once
				if not seenPinned[id] then
					seenPinned[id] = true
					data.pinned[#data.pinned + 1] = id
				end
			elseif field == "priority" and value >= Pr.MAX_PRIORITY then
				-- an imported category never outranks Junk, Sets, Keystone or Reagents (week 7), but a string the
				-- user exported is never refused for it either (week 8): it comes in just below them, and the
				-- preview names it, once
				into[id][field] = Pr.MAX_PRIORITY - 1
				if not seenLowered[id] then
					seenLowered[id] = true
					data.lowered[#data.lowered + 1] = id
				end
			elseif field == "query" and not SB.Query.Compile(value).fn then
				return nil, "type", key
			else
				into[id][field] = value
			end
		else
			data.skipped[#data.skipped + 1] = key
		end
	end
	for id, def in pairs(data.users) do
		if def.name == nil and def.query == nil then
			return nil, "type", id
		end
	end
	table.sort(data.skipped)
	for id in pairs(seenPinned) do
		if data.edits[id] and next(data.edits[id]) == nil then
			data.edits[id] = nil -- the ignored priority was all of that edit
		end
	end
	table.sort(data.ignored)
	table.sort(data.lowered)
	table.sort(data.pinned)
	return data
end

-- A value as the preview shows it: on / off, a focus mode's sections by their names, else as it is.
local function show(v, path)
	if type(v) == "boolean" then
		return v and L.OVERLAY_ON or L.OVERLAY_OFF
	elseif type(v) == "string" and path:match("^focus%.sections%.") and SB.Categories then
		local names = {}
		for id in v:gmatch("[^,]+") do
			names[#names + 1] = SB.Categories.Name(id)
		end
		return table.concat(names, ", ")
	end
	return tostring(v)
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- The string's watch list differs from the one in force (ruling R7: the user's own list is no change).
local function watchChanged(data)
	return data.watch ~= nil and not same(data.watch, SB.Config.Get("consumables.watch"))
end

local function labels(paths)
	local out = {}
	for i, path in ipairs(paths) do
		out[i] = Pr.Label(path)
	end
	return table.concat(out, ", ")
end

function Pr.Preview(data)
	local lines, paths = {}, {}
	for path in pairs(data.settings) do
		paths[#paths + 1] = path
	end
	table.sort(paths)
	for _, path in ipairs(paths) do
		local now, new = SB.Config.Get(path), data.settings[path]
		if now ~= new then
			lines[#lines + 1] = L.PROFILE_PREVIEW_LINE:format(Pr.Label(path), show(now, path), show(new, path))
		end
	end
	if watchChanged(data) then
		lines[#lines + 1] = #data.watch == 1 and L.PROFILE_PREVIEW_WATCH_ONE or L.PROFILE_PREVIEW_WATCH:format(#data.watch)
	end
	local nu, ne = 0, 0
	for _ in pairs(data.users) do
		nu = nu + 1
	end
	for _ in pairs(data.edits) do
		ne = ne + 1
	end
	if nu + ne > 0 or data.order then
		lines[#lines + 1] = L.PROFILE_PREVIEW_CATEGORIES:format(nu, ne, data.order and L.REPORT_YES or L.REPORT_NO)
	end
	if #data.lowered > 0 then
		local names = {}
		for i, id in ipairs(data.lowered) do
			local def = data.users[id]
			names[i] = (def and def.name) or (SB.Categories and SB.Categories.Name(id)) or id
		end
		lines[#lines + 1] = L.PROFILE_PREVIEW_LOWERED:format(table.concat(names, ", "))
	end
	if #data.pinned > 0 then
		local names = {}
		for i, id in ipairs(data.pinned) do
			names[i] = (SB.Categories and SB.Categories.Name(id)) or id
		end
		lines[#lines + 1] = L.PROFILE_PREVIEW_PINNED:format(table.concat(names, ", "))
	end
	if #data.skipped > 0 then
		lines[#lines + 1] = L.PROFILE_PREVIEW_SKIPPED:format(table.concat(data.skipped, ", "))
	end
	if #data.ignored > 0 then
		lines[#lines + 1] = L.PROFILE_PREVIEW_IGNORED:format(labels(data.ignored))
	end
	if #lines == 0 then
		lines[1] = L.PROFILE_PREVIEW_NOTHING
	end
	return lines
end

local function setPath(t, path, value)
	local parts = {}
	for p in path:gmatch("[^%.]+") do
		parts[#parts + 1] = p
	end
	for i = 1, #parts - 1 do
		if type(t[parts[i]]) ~= "table" then
			t[parts[i]] = {}
		end
		t = t[parts[i]]
	end
	t[parts[#parts]] = value
end

function Pr.Import(data)
	if SB.Config.readOnly then
		return false, "readonly"
	end
	local d = db()
	local withCategories = next(data.users) ~= nil or next(data.edits) ~= nil or data.order ~= nil
	backup(withCategories) -- before anything changes: undo brings it all back (R6)
	local settings = shareable(d.settings)
	local n = 0
	for path, value in pairs(data.settings) do
		if SB.Config.Get(path) ~= value then
			n = n + 1
		end
		setPath(settings, path, value)
	end
	if watchChanged(data) then
		settings.consumables = type(settings.consumables) == "table" and settings.consumables or {}
		settings.consumables.watch = data.watch
		n = n + 1
	end
	for id, def in pairs(data.users) do
		d.categories = type(d.categories) == "table" and d.categories or {}
		def.source = "import" -- spec 7.7: a category that came from a share string (ruling R22)
		d.categories[id] = def
		n = n + 1
	end
	for id, def in pairs(data.edits) do
		d.userEdits = type(d.userEdits) == "table" and d.userEdits or {}
		d.userEdits[id] = def
		n = n + 1
	end
	if data.order then
		d.categoryOrder = data.order
		n = n + 1
	end
	replace(settings) -- Follow() loads the categories again
	return true, n
end

---------------------------------------------------------------------------
-- /swagbag profile ...
---------------------------------------------------------------------------
local REASON = { readonly = "SETTINGS_READONLY", name = "PROFILE_BAD_NAME", unknown = "PROFILE_UNKNOWN",
	none = "PROFILE_NO_UNDO" }

local function why(reason, name)
	return L[REASON[reason] or "PROFILE_USAGE"]:format(tostring(name or ""))
end

SB.Slash.Register("profile", L.HELP_PROFILE, function(arg)
	local verb, rest = (arg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	verb = verb:lower()
	if verb == "" or verb == "list" then
		local list = Pr.List()
		return L.PROFILE_STATE:format(#list > 0 and table.concat(list, ", ") or L.REPORT_NONE,
			tostring(db().profile or L.REPORT_NONE))
	elseif verb == "save" then
		local ok, r = Pr.Save(rest)
		return ok and L.PROFILE_SAVED:format(r) or why(r, rest)
	elseif verb == "load" then
		local ok, r = Pr.Load(rest)
		return ok and L.PROFILE_LOADED:format(rest) or why(r, rest)
	elseif verb == "delete" then
		local ok, r = Pr.Delete(rest)
		return ok and L.PROFILE_DELETED:format(rest) or why(r, rest)
	elseif verb == "reset" then
		local ok, r = Pr.Reset()
		return ok and L.PROFILE_RESET or why(r)
	elseif verb == "undo" then
		local ok, r = Pr.Undo()
		return ok and L.PROFILE_UNDONE or why(r)
	elseif verb == "export" and (rest == "" or rest:lower() == "categories") then
		local text = Pr.Export(rest ~= "")
		if SB.ShareBox then
			SB.ShareBox.ShowExport(text)
		end
		return rest ~= "" and L.PROFILE_EXPORTED_CATEGORIES or L.PROFILE_EXPORTED
	elseif verb == "import" and rest == "" then
		if SB.ShareBox then
			SB.ShareBox.ShowImport()
		end
		return L.PROFILE_IMPORT_OPENED
	end
	return L.PROFILE_USAGE
end)
