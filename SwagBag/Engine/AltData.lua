-- SwagBag alt data (spec 3.2, 3.3, F13): which characters have an item, and what a saved character
-- holds, through providers. Pure Lua over the Adapter and SwagBag's own snapshots. Per call, the
-- available provider with the highest priority that answers wins (ties: name order); one that
-- answers nil hands the call to the next. A provider that throws three times in a session is
-- switched off with one chat line and one error-ring entry; the others carry on (spec 3.3).
-- Built in: "Own" (priority 0) over Engine/Snapshots.lua. Providers/Syndicator.lua adds
-- "Syndicator" (priority 10) while Syndicator is loaded and ready.
--   AltData.RegisterProvider(p)   p = { name, priority, available() -> bool,
--       characters() -> list | nil, counts(itemID) -> counts | nil, container(key, kind) -> c | nil }
--   AltData.Characters() -> list, source   { { key, name, realm, class, level, lastSeen, guild, current } },
--       the current character first, then by name. key is canonical (AltData.Canon)
--   AltData.Counts(itemID) -> counts, source   { chars = { { key, name, class, current, bags, bank, mail,
--       equipped, auctions, void } }, warband = n, guilds = { { key, name, count } } }: only non-zero counts
--   AltData.Container(key, kind) -> c, source   kind "bags" | "bank" | "warband" | "guild":
--       { at = epoch | nil, title = text | nil, containers = { [bag or guild tab] = { size, slots =
--       { [slot] = { link, count } } } } }, or nil when nothing is saved
--   AltData.Wealth() -> list, source   { { key, name, realm, class, current, money, currencies } }: the
--       characters with saved gold or currencies (money in copper, currencies = { [currencyID] = quantity });
--       a character saved before 0.17 has neither and is left out. {} when nothing is saved
--   AltData.Generation() -> n   moves on every SB_ALTDATA_CHANGED; providers may define invalidate()
--   AltData.OwnGuildCounts(itemID) -> { { key, name, count } }   SwagBag's own guild banks
--   AltData.Source() -> name   the provider that answers first now
--   AltData.Canon(key) -> "Name-Realm" with the realm's spaces and hyphens removed (the form
--       Syndicator uses), so both providers name a character the same way
--   AltData.ItemID(link) -> itemID | nil   from an item, keystone or battle pet link (pure)
-- Own counts: an index (itemID -> count) per saved container, built the first time it is asked
-- and dropped when that container is saved again (SB_SNAPSHOT_SAVED), never stored (spec 8.4).
-- The current character's bags are counted live (Engine/Inventory.lua), so a tooltip is never
-- 5 s behind the bag.
local _, SB = ...

local AD = { providers = {}, errors = {}, off = {}, MAX_ERRORS = 3, PET_CAGE = 82800, PREBUILD_DELAY = 5,
	KINDS = { "bags", "bank", "warband", "guild" } }
SB.AltData = AD

function AD.Canon(key)
	if type(key) ~= "string" then
		return nil
	end
	local name, realm = key:match("^([^%-]+)%-(.+)$")
	if not name then
		return key
	end
	return name .. "-" .. (realm:gsub("[%s%-]", ""))
end

function AD.ItemID(link)
	if type(link) ~= "string" then
		return nil
	end
	local id = link:match("item:(%d+)") or link:match("keystone:(%d+)")
	if id then
		return tonumber(id)
	end
	if link:find("battlepet:", 1, true) then
		return AD.PET_CAGE
	end
	return nil
end

---------------------------------------------------------------------------
-- Providers
---------------------------------------------------------------------------
function AD.RegisterProvider(p)
	AD.providers[#AD.providers + 1] = p
end

local function byPriority(a, b)
	if a.priority ~= b.priority then
		return a.priority > b.priority
	end
	return a.name < b.name
end

local function failed(p, message, stack)
	AD.errors[p.name] = (AD.errors[p.name] or 0) + 1
	if p.name == "Own" then
		-- the built-in provider has nothing to fall back to: never switched off, always recorded
		pcall(SB.ErrorTrap.OnError, "altdata:Own", "none", tostring(message), stack or "")
	elseif AD.errors[p.name] >= AD.MAX_ERRORS and not AD.off[p.name] then
		AD.off[p.name] = true
		pcall(SB.ErrorTrap.OnError, "altdata:" .. p.name, "none", tostring(message), stack or "")
		SB.Print(SB.L.ALTDATA_PROVIDER_OFF:format(p.name))
	end
end

-- pcall that keeps a stack trace: ok, results... | false, message, stack
local function trapped(fn, ...)
	local args, n, caught = { ... }, select("#", ...), nil
	local r = { xpcall(function()
		return fn(unpack(args, 1, n))
	end, function(err)
		local okS, st = pcall(SB.Adapter.Stack)
		caught = { message = err, stack = okS and st or "" }
		return caught
	end) }
	if r[1] then
		return true, r[2]
	end
	caught = caught or { message = "error in error handler", stack = "" }
	return false, caught.message, caught.stack
end

-- The available providers, best first. Asked on every call: Syndicator becomes ready after login.
-- An available() that throws counts as an error of that provider.
local function active()
	local list = {}
	for _, p in ipairs(AD.providers) do
		if not AD.off[p.name] then
			local ok, yes, stack = trapped(p.available)
			if not ok then
				failed(p, yes, stack)
			elseif yes then
				list[#list + 1] = p
			end
		end
	end
	table.sort(list, byPriority)
	return list
end

function AD.Source()
	local first = active()[1]
	return first and first.name or nil
end

local function call(method, ...)
	for _, p in ipairs(active()) do
		if p[method] then
			local ok, v, stack = trapped(p[method], ...)
			if not ok then
				failed(p, v, stack)
			elseif v ~= nil then
				return v, p.name
			end
		end
	end
	return nil, nil
end

function AD.Characters()
	return call("characters")
end

function AD.Counts(itemID)
	if type(itemID) ~= "number" then
		return nil, nil
	end
	return call("counts", itemID)
end

function AD.Container(key, kind)
	return call("container", key, kind)
end

function AD.Wealth()
	return call("wealth")
end

---------------------------------------------------------------------------
-- The built-in provider "Own": SwagBag's snapshots (Engine/Snapshots.lua)
---------------------------------------------------------------------------
local index = {} -- [source] = { [itemID] = count }; source = "bags:<raw key>", "bank:<raw key>", "warband", "guild:<guild key>"

local function countMap(snap)
	local map = {}
	if type(snap) == "table" and type(snap.containers) == "table" then
		for _, c in pairs(snap.containers) do
			for _, s in pairs(SB.Snapshots.Deserialize(c)) do
				local id = AD.ItemID(s.link)
				if id then
					map[id] = (map[id] or 0) + (s.count or 1)
				end
			end
		end
	end
	return map
end

local function mapOf(source, snap)
	local map = index[source]
	if not map then
		map = countMap(snap)
		index[source] = map
	end
	return map
end
-- The Own index as it is now (tests and /swagbag report).
function AD.Index()
	return index
end

-- The bags of the character playing now, read live.
local function liveBags(itemID)
	local n = 0
	for _, _, s in SB.Inventory.Iterate("bags") do
		if s and s.itemID == itemID then
			n = n + (s.count or 1)
		end
	end
	return n
end

local function splitKey(raw)
	local name, realm = raw:match("^([^%-]+)%-(.+)$")
	return name or raw, realm
end

local function guildName(guildKey)
	-- guild names have no hyphens; the realm may ("Azjol-Nerub")
	return type(guildKey) == "string" and (guildKey:match("^([^%-]+)%-") or guildKey) or nil
end

-- The saved character whose canonical key is key: its raw key and its table.
local function charOf(key)
	for raw, c in pairs(SB.Snapshots.DB().chars) do
		if type(c) == "table" and AD.Canon(raw) == key then
			return raw, c
		end
	end
	return nil, nil
end

local function decode(snap, title)
	if type(snap) ~= "table" or type(snap.containers) ~= "table" then
		return nil
	end
	local out = { at = snap.at, title = title, containers = {} }
	for bag, c in pairs(snap.containers) do
		if type(c) == "table" then
			out.containers[bag] = { size = tonumber(c.size) or 0, slots = SB.Snapshots.Deserialize(c) }
		end
	end
	return out
end

-- SwagBag's own guild-bank counts of an item: { { key = raw guild key, name, count } }, by key. A provider
-- that does not know guild banks (Syndicator, D11) appends these.
function AD.OwnGuildCounts(itemID)
	local out = {}
	for gk, g in pairs(SB.Snapshots.DB().guilds) do
		if type(g) == "table" then
			local n = mapOf("guild:" .. gk, g.snapshot)[itemID] or 0
			if n > 0 then
				out[#out + 1] = { key = gk, name = guildName(gk), count = n }
			end
		end
	end
	table.sort(out, function(a, b)
		return a.key < b.key
	end)
	return out
end

local own = { name = "Own", priority = 0 }

function own.available()
	return SB.Config.db ~= nil
end

function own.characters()
	local me, list = SB.Adapter.CharKey(), {}
	for raw, c in pairs(SB.Snapshots.DB().chars) do
		if type(c) == "table" then
			local name, realm = splitKey(raw)
			list[#list + 1] = { key = AD.Canon(raw), name = name, realm = realm, class = c.class, level = c.level,
				lastSeen = c.lastSeen, guild = c.guild, current = raw == me }
		end
	end
	table.sort(list, function(a, b)
		if a.current ~= b.current then
			return a.current
		end
		return a.key < b.key
	end)
	return list
end

-- Saved gold and currencies (Engine/Wealth.lua). The current character's gold is read live and the
-- character is listed even before its first save, so a tooltip always has "you".
function own.wealth()
	local me, list = SB.Adapter.CharKey(), {}
	local live = SB.Adapter.Money()
	if type(live) ~= "number" or SB.Adapter.IsSecret(live) then
		live = nil
	end
	local db, listed = SB.Snapshots.DB(), false
	for raw, c in pairs(db.chars) do
		if type(c) == "table" and (type(c.money) == "number" or type(c.currencies) == "table") then
			local name, realm = splitKey(raw)
			listed = listed or raw == me
			list[#list + 1] = { key = AD.Canon(raw), name = name, realm = realm, class = c.class,
				current = raw == me, money = raw == me and live or c.money, currencies = c.currencies }
		end
	end
	if not listed and live then
		local name, realm = splitKey(me)
		list[#list + 1] = { key = AD.Canon(me), name = name, realm = realm, class = SB.Adapter.CharInfo().class,
			current = true, money = live }
	end
	table.sort(list, function(a, b)
		if a.current ~= b.current then
			return a.current
		end
		return a.key < b.key
	end)
	return list
end

function own.container(key, kind)
	local db = SB.Snapshots.DB()
	if kind == "warband" then
		return decode(db.warband)
	end
	local _, c = charOf(key)
	if not c then
		return nil
	end
	if kind == "guild" then
		local g = c.guild and db.guilds[c.guild]
		local out = type(g) == "table" and decode(g.snapshot, guildName(c.guild)) or nil
		if out then
			out.names = type(g.tabs) == "table" and g.tabs or {}
		end
		return out
	end
	return decode(c[kind])
end

function own.counts(itemID)
	local db, me = SB.Snapshots.DB(), SB.Adapter.CharKey()
	local out = { chars = {}, warband = 0, guilds = {} }
	for raw, c in pairs(db.chars) do
		if type(c) == "table" then
			local bags = raw == me and liveBags(itemID) or (mapOf("bags:" .. raw, c.bags)[itemID] or 0)
			local bank = mapOf("bank:" .. raw, c.bank)[itemID] or 0
			if bags > 0 or bank > 0 then
				local name = splitKey(raw)
				out.chars[#out.chars + 1] = { key = AD.Canon(raw), name = name,
					class = raw == me and SB.Adapter.CharInfo().class or c.class, current = raw == me,
					bags = bags, bank = bank }
			end
		end
	end
	if not db.chars[me] then -- not saved yet (the first minutes of a new character)
		local bags = liveBags(itemID)
		if bags > 0 then
			out.chars[#out.chars + 1] = { key = AD.Canon(me), name = splitKey(me), class = SB.Adapter.CharInfo().class,
				current = true, bags = bags, bank = 0 }
		end
	end
	out.warband = mapOf("warband", db.warband)[itemID] or 0
	out.guilds = AD.OwnGuildCounts(itemID)
	table.sort(out.chars, function(a, b)
		if a.current ~= b.current then
			return a.current
		end
		return a.key < b.key
	end)
	return out
end

AD.RegisterProvider(own)
AD.Own = own

-- A container was saved again (Engine/Snapshots.lua): its index is rebuilt when next asked.
-- owner: the raw character key ("bags", "bank"), the guild key ("guild"), nil ("warband").
SB.On("SB_SNAPSHOT_SAVED", function(_, kind, owner)
	if kind == "warband" then
		index.warband = nil
	elseif owner then
		index[kind .. ":" .. owner] = nil
	end
end, "none")

-- A provider's own data changed (Providers/Syndicator.lua announces it once per burst of Syndicator's
-- callbacks): every provider drops what it cached, and Generation moves so a memo built on top of
-- AltData (tooltip lines, the alt viewer) knows it is stale. Own's index is not touched: it follows
-- SwagBag's own saves (SB_SNAPSHOT_SAVED), which Syndicator's data does not change.
AD.generation = 0
function AD.Generation()
	return AD.generation
end

SB.On("SB_ALTDATA_CHANGED", function()
	AD.generation = AD.generation + 1
	for _, p in ipairs(AD.providers) do
		if p.invalidate then
			local ok, message, stack = trapped(p.invalidate)
			if not ok then
				failed(p, message, stack)
			end
		end
	end
end, "none")

-- Build every saved container's index once, out of combat, 5 s after login (W5-7): a first tooltip
-- hover in a dungeon must not pay for it. The current character's bags are live, not indexed.
function AD.Prebuild()
	local db, me = SB.Snapshots.DB(), SB.Adapter.CharKey()
	for raw, c in pairs(db.chars) do
		if type(c) == "table" then
			if raw ~= me then
				mapOf("bags:" .. raw, c.bags)
			end
			mapOf("bank:" .. raw, c.bank)
		end
	end
	mapOf("warband", db.warband)
	for gk, g in pairs(db.guilds) do
		if type(g) == "table" then
			mapOf("guild:" .. gk, g.snapshot)
		end
	end
end

-- OutOfCombat queues the build for PLAYER_REGEN_ENABLED when the login happens in combat.
SB.On("SB_LOGIN", function()
	SB.Debounce("altdata.prebuild", AD.PREBUILD_DELAY, function()
		SB.OutOfCombat(AD.Prebuild, "altdata.prebuild", "none")
	end, "none")
end, "none")

-- New or reset settings: every index goes.
SB.On("SB_CONFIG_CHANGED", function(_, path)
	if path == nil then
		index = {}
	end
end, "none")
