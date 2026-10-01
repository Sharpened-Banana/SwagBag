-- SwagBag snapshots (spec F13, 5.7, 8.3, 8.4). October CAPTURES them so the data exists when
-- the offline view arrives in November (spec 12.1); nothing shows them yet except
-- /swagbag snapshot and /swagbag report.
-- Format (spec 8.3): snapshot = { v = 1, at = epoch, containers = { [bag] = { size, s } } },
-- one string per container of "slot:link;count\n" lines in slot order, full links verbatim
-- (caged pets, keystones and bonus IDs round-trip), no derived values.
-- Where they live (spec 8.2): SwagBagDB.chars["Name-Realm"] = { class, level, lastSeen, bags,
-- bank }, SwagBagDB.warband (one for the account), SwagBagDB.guilds["Guild-Realm"] =
-- { lastSeen, tabs = { [tab] = name }, snapshot }.
-- When (spec AC13.1, 5.7): bags on logout and 5 s after the last bag update; the character
-- bank and warband bank 0.3 s after the bank opens, after each bank update while open (1 s
-- debounce) and when it closes. Ruling W3-9: a snapshot is CAPTURED the moment it is due, even in
-- combat; only the write into SwagBagDB waits for combat to end (spec 9), keyed per kind so the
-- newest capture wins.
-- Budget (spec 8.4): over 1.5 MB in all, the bank snapshots of the characters seen longest
-- ago are dropped first (never the current character's), with one chat line per session.
local _, SB = ...

-- HARD_CAP is the spec 8.4 limit. Enforce trims from TRIGGER (1.45 MB) instead, because Bytes()
-- is an estimate (strings plus a small per-container overhead) and the real file must stay
-- under the cap, not merely the estimate.
local Snap = {
	HARD_CAP = 1.5 * 1024 * 1024,
	TRIGGER = 1.45 * 1024 * 1024,
	BAGS_DELAY = 5,
	BANK_DELAY = 1,
	OPEN_DELAY = 0.3,
	trimmedSaid = false,
}
SB.Snapshots = Snap

---------------------------------------------------------------------------
-- Format (pure)
---------------------------------------------------------------------------
-- slots[slot] = { link, count } (nil = empty) for slots 1..size.
function Snap.Serialize(slots, size)
	local parts = {}
	for slot = 1, size do
		local s = slots[slot]
		if s and s.link then
			parts[#parts + 1] = slot .. ":" .. s.link .. ";" .. (s.count or 1) .. "\n"
		end
	end
	return { size = size, s = table.concat(parts) }
end

-- The inverse: slots[slot] = { link, count }. A damaged line is skipped.
function Snap.Deserialize(container)
	local slots = {}
	if type(container) ~= "table" or type(container.s) ~= "string" then
		return slots
	end
	for line in container.s:gmatch("[^\n]+") do
		local slot, link, count = line:match("^(%d+):(.*);(%d+)$")
		if slot then
			slots[tonumber(slot)] = { link = link, count = tonumber(count) }
		end
	end
	return slots
end

---------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------
local function tableOr(v)
	return type(v) == "table" and v or {}
end

-- The saved tables, repaired if damaged (a hand-edited or broken file never errors).
function Snap.DB()
	local db = SB.Config.db
	db.chars = tableOr(db.chars)
	db.guilds = tableOr(db.guilds)
	if db.warband ~= nil and type(db.warband) ~= "table" then
		db.warband = nil
	end
	return db
end

function Snap.Char()
	local A, db = SB.Adapter, Snap.DB()
	local key = A.CharKey()
	local c = tableOr(db.chars[key])
	db.chars[key] = c
	local info = A.CharInfo()
	c.class, c.level, c.lastSeen = info.class, info.level, A.Time()
	return c, key
end

-- A snapshot of every bag of a kind ("bags" | "bank" | "warband") from Inventory's model.
function Snap.Capture(kind)
	local Inv = SB.Inventory
	local snap = { v = 1, at = SB.Adapter.Time(), containers = {} }
	for _, bag in ipairs(SB.Adapter.GetBagIDs(kind)) do
		local size, slots = Inv.Size(bag), {}
		for slot = 1, size do
			slots[slot] = Inv.GetSlot(bag, slot)
		end
		snap.containers[bag] = Snap.Serialize(slots, size)
	end
	return snap
end

-- Captures and serialized guild tabs whose write is waiting for combat to end. A save at logout
-- or /reload must not lose them (W3-28), so PLAYER_LOGOUT flushes them.
local pending, pendingGuild = {}, {}

-- Write an already captured snapshot (never when the schema is newer, spec 8.5). A bank read
-- that comes back empty (the client reports 0 slots away from a banker or mid-close) never
-- replaces a saved container that had slots, and an all-empty capture writes nothing (W3-29).
local function store(kind, snap)
	if SB.Config.readOnly then
		return
	end
	if kind == "bank" or kind == "warband" then
		local total = 0
		for _, c in pairs(snap.containers) do
			total = total + (c.size or 0)
		end
		if total == 0 then
			return
		end
		local old
		if kind == "warband" then
			old = Snap.DB().warband
		else
			local oc = Snap.DB().chars[SB.Adapter.CharKey()]
			old = type(oc) == "table" and oc.bank or nil
		end
		if type(old) == "table" and type(old.containers) == "table" then
			for bag, c in pairs(snap.containers) do
				local o = old.containers[bag]
				if (c.size or 0) == 0 and type(o) == "table" and (o.size or 0) > 0 then
					snap.containers[bag] = o
				end
			end
		end
	end
	if kind == "warband" then
		Snap.DB().warband = snap
	else
		local c = Snap.Char()
		c[kind] = snap
	end
	Snap.Enforce()
end

-- Capture now (W3-9), write now or, in combat, as soon as combat ends (no snapshot writes in
-- combat, spec 9). The queue is keyed per kind, so the newest capture wins. Returns true if written.
function Snap.Save(kind)
	pending[kind] = Snap.Capture(kind)
	return SB.OutOfCombat(function()
		local snap = pending[kind]
		pending[kind] = nil
		if snap then
			store(kind, snap)
		end
	end, "snapshot." .. kind, "none")
end

local function storeGuild(guildKey, ser)
	if SB.Config.readOnly then
		return
	end
	local db = Snap.DB()
	local g = tableOr(db.guilds[guildKey])
	db.guilds[guildKey] = g
	g.lastSeen = SB.Adapter.Time()
	g.tabs = tableOr(g.tabs)
	g.snapshot = type(g.snapshot) == "table" and g.snapshot or { v = 1, containers = {} }
	g.snapshot.containers = tableOr(g.snapshot.containers)
	g.snapshot.at = g.lastSeen
	for tab, t in pairs(ser) do
		g.tabs[tab] = t.name
		g.snapshot.containers[tab] = t.container
	end
	Snap.Enforce()
end

-- tabs[tab] = { name, slots = { [slot] = { link, count } } } for the tabs read this visit.
-- Serialized now (W3-9), so the caller may reuse its tables; only the strings wait for combat.
function Snap.SaveGuild(guildKey, tabs)
	if not guildKey then
		return false
	end
	local ser = {}
	for tab, t in pairs(tabs) do
		ser[tab] = { name = t.name, container = Snap.Serialize(t.slots or {}, SB.Adapter.GUILD_SLOTS) }
	end
	pendingGuild[guildKey] = ser
	return SB.OutOfCombat(function()
		local q = pendingGuild[guildKey]
		pendingGuild[guildKey] = nil
		if q then
			storeGuild(guildKey, q)
		end
	end, "snapshot.guild." .. guildKey, "none")
end

---------------------------------------------------------------------------
-- Budget (spec 8.4)
---------------------------------------------------------------------------
local function snapshotBytes(snap)
	local n = 0
	if type(snap) == "table" and type(snap.containers) == "table" then
		for _, c in pairs(snap.containers) do
			if type(c) == "table" and type(c.s) == "string" then
				n = n + #c.s + 16
			end
		end
	end
	return n
end

-- Approximate saved size of every snapshot (strings plus a small per-container overhead).
function Snap.Bytes()
	local db = Snap.DB()
	local n = snapshotBytes(db.warband)
	for _, c in pairs(db.chars) do
		if type(c) == "table" then
			n = n + snapshotBytes(c.bags) + snapshotBytes(c.bank)
		end
	end
	for _, g in pairs(db.guilds) do
		if type(g) == "table" then
			n = n + snapshotBytes(g.snapshot)
		end
	end
	return n
end

-- Over the hard cap: drop other characters' bank snapshots, seen longest ago first (ties: name
-- order), until under the cap. Returns the names dropped.
function Snap.Enforce()
	local dropped = {}
	if Snap.Bytes() <= Snap.TRIGGER then
		return dropped
	end
	local db, me = Snap.DB(), SB.Adapter.CharKey()
	local list = {}
	for key, c in pairs(db.chars) do
		if key ~= me and type(c) == "table" and c.bank then
			list[#list + 1] = { key = key, seen = tonumber(c.lastSeen) or 0 }
		end
	end
	table.sort(list, function(a, b)
		if a.seen ~= b.seen then
			return a.seen < b.seen
		end
		return a.key < b.key
	end)
	for _, e in ipairs(list) do
		if Snap.Bytes() <= Snap.TRIGGER then
			break
		end
		db.chars[e.key].bank = nil
		dropped[#dropped + 1] = e.key
	end
	if #dropped > 0 and not Snap.trimmedSaid then
		Snap.trimmedSaid = true
		SB.Print(SB.L.SNAPSHOT_TRIMMED:format(table.concat(dropped, ", ")))
	end
	return dropped
end

---------------------------------------------------------------------------
-- Ages for /swagbag snapshot
---------------------------------------------------------------------------
function Snap.Age(seconds)
	local L = SB.L
	if seconds < 60 then
		return L.AGE_NOW
	elseif seconds < 3600 then
		return L.AGE_MINUTES:format(math.floor(seconds / 60))
	elseif seconds < 86400 then
		return L.AGE_HOURS:format(math.floor(seconds / 3600))
	end
	return L.AGE_DAYS:format(math.floor(seconds / 86400))
end

function Snap.Lines()
	local L, db, now = SB.L, Snap.DB(), SB.Adapter.Time()
	local c = db.chars[SB.Adapter.CharKey()]
	local chars = Snap.Count()
	local function age(snap)
		if type(snap) ~= "table" or not snap.at then
			return L.SNAPSHOT_NEVER
		end
		return Snap.Age(now - snap.at)
	end
	return {
		L.SNAPSHOT_LINE:format(L.SNAPSHOT_BAGS, age(c and c.bags)),
		L.SNAPSHOT_LINE:format(L.SNAPSHOT_BANK, age(c and c.bank)),
		L.SNAPSHOT_LINE:format(L.SNAPSHOT_WARBAND, age(db.warband)),
		L.SNAPSHOT_TOTAL:format(chars, math.floor(Snap.Bytes() / 1024 + 0.5)),
	}
end

-- characters, guilds
function Snap.Count()
	local chars, guilds = 0, 0
	local db = Snap.DB()
	for _, c in pairs(db.chars) do
		if type(c) == "table" then
			chars = chars + 1
		end
	end
	for _, g in pairs(db.guilds) do
		if type(g) == "table" then
			guilds = guilds + 1
		end
	end
	return chars, guilds
end

---------------------------------------------------------------------------
-- When to capture
---------------------------------------------------------------------------
local bankOpen = false

-- The game is closing (or reloading): there is no later, so this writes even in combat. First
-- what was captured in combat and is still waiting (W3-28), then a visit still open, then bags.
-- store and storeGuild refuse a newer schema themselves.
SB.On("PLAYER_LOGOUT", function()
	for kind, snap in pairs(pending) do
		pending[kind] = nil
		store(kind, snap)
	end
	for key, ser in pairs(pendingGuild) do
		pendingGuild[key] = nil
		storeGuild(key, ser)
	end
	if bankOpen then
		store("bank", Snap.Capture("bank"))
		store("warband", Snap.Capture("warband"))
	end
	store("bags", Snap.Capture("bags"))
end, "none")

SB.On("BANKFRAME_OPENED", function()
	bankOpen = true
	-- runs 0.3 s later, after the BANKFRAME_OPENED scan of the model; a visit that already ended
	-- has saved at its close and must not save again from a model the client has since blanked
	SB.Debounce("snapshot.bankOpen", Snap.OPEN_DELAY, function()
		if bankOpen then
			Snap.Save("bank")
			Snap.Save("warband")
		end
	end, "none")
end, "none")

SB.On("BANKFRAME_CLOSED", function()
	if bankOpen then
		bankOpen = false
		Snap.Save("bank")
		Snap.Save("warband")
	end
end, "none")

SB.Inventory.OnChanged(SB.ErrorTrap.Guard("snapshot.inventory", function(_, changes)
	local bags, bank = false, false
	for _, c in ipairs(changes) do
		local kind = SB.Adapter.BagKind(c.bag)
		if kind == "bank" or kind == "warband" then
			bank = true
		elseif kind then
			bags = true
		end
	end
	if bags then
		SB.Debounce("snapshot.bags", Snap.BAGS_DELAY, function()
			Snap.Save("bags")
		end, "none")
	end
	if bank and bankOpen then
		SB.Debounce("snapshot.bank", Snap.BANK_DELAY, function()
			if bankOpen then
				Snap.Save("bank")
				Snap.Save("warband")
			end
		end, "none")
	end
end, "none"))

SB.Slash.Register("snapshot", SB.L.HELP_SNAPSHOT, function()
	return Snap.Lines()
end)
