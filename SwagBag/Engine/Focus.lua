-- SwagBag focus modes (spec section 6). Pure Lua: signals in, "which sections are open" out.
-- No frames and no WoW calls; Engine/Signals.lua feeds the signals, the bags window asks.
--   Focus.SetSignal(name, value) -> changed      one fact about the world (spec 6.2)
--   Focus.Recompute(reason) -> changed           re-evaluate the triggers (signals call it)
--   Focus.Refresh(reason)                        a focus setting changed: always tell the windows
--   Focus.Active() -> { ids }                    enabled modes whose trigger is true (MODES order)
--   Focus.Expanded() -> set | nil                the open sections, or nil when no mode applies
--                                                (none active, paused, switched off, or a mode
--                                                that expands everything: the bank)
--   Focus.Style() -> "front" | "collapse"         what an active mode does (focus.style, week 6):
--                                                "front" (default) moves its sections to the top and
--                                                collapses nothing; "collapse" collapses the rest
--   Focus.Front() -> { ids } | nil               "front" style: the sections the deciding modes move
--                                                up, in the modes' order (never New or Free), or nil
--   Focus.SectionOrder(order) -> order           the drawn section order: order itself, or in "front"
--                                                style New, then Front(), then the rest as they were
--   Focus.Applies() -> bool                      a mode's collapse set is in force ("collapse" style)
--   Focus.CollapsedView(userSet) -> lookup       collapsed[id] for Layout.Position / Apply:
--                                                userSet itself when no mode collapses ("front" too)
--   Focus.HeaderClick(id, collapsedNow) -> "peek" | "close"   a header click while a mode applies
--   Focus.Pin(id) -> "pin" | "unpin"             right-click: keep a section open until the
--                                                mode changes (spec 6.1 pin)
--   Focus.OverrideOf(id) -> nil | "peek" | "pin" | "closed"
--   Focus.WindowClosed()                         peeks and closes end; pins stay (spec 6.1)
--   Focus.Pause() / Focus.Resume() -> changed; Focus.IsPaused()   for this session only
--   Focus.Label() -> text | nil                  "M+", "M+ + Fishing", "Paused" (title, AC8.5)
--   Focus.Sections(id, raw) -> { category ids }       a mode's section set (settings or default)
--   Focus.SetSections(id, list) -> bool, Focus.ResetSections(id) -> bool, Focus.SetEnabled(id, on) -> bool
--   Focus.SetStyle(style) -> bool                "front" | "collapse"; false, "unknown" | "readonly"
-- A writer whose value is already in force writes nothing (no SB_CONFIG_CHANGED, so no re-stack:
-- week-4 deferred M5).
--   Focus.ListLines() -> { lines }               one chat line per mode (/swagbag mode list)
-- Week 12 (AC8.7): the user's own modes, next to the six built-ins (Focus.All() lists both, built-ins first):
--   Focus.TRIGGERS                               when one switches on: "manual" (only when the user says so), or one
--                                                of the built-in signals (a key, a dungeon, a raid, a delve, PvP,
--                                                fishing, gathering, a vendor, the auction house, the bank)
--   Focus.CheckName(name, exceptId) -> name | nil, why   why: "empty" | "long" | "code" | "builtin" | "taken"
--   Focus.CreateMode(name, trigger) -> id | nil, why     why also "readonly" | "full" | "trigger"
--   Focus.RenameMode(id, name), Focus.SetTrigger(id, trigger), Focus.DeleteMode(id) -> ok, why ("unknown" too)
--   Focus.SetManual(id, on) -> ok, why           a manual mode on or off, for this session ("notmanual")
--   Focus.Mode(id), Focus.NameOf(id), Focus.FindMode(name) -> id, Focus.IsCustom(id), Focus.ManualOn(id)
-- Stored account-wide in SwagBagDB.modes (schema 2, no migration, read defensively: Focus.LoadCustom):
-- modes[id] = { name, trigger, n = the order it was made in }; a deleted one stays false, so its id (m_<name>) is
-- never given again (another character's own sections can still name it). A mode's on/off and sections are the
-- ordinary settings focus.on.<id> and focus.sections.<id>, so "This character only" and profiles treat them as the
-- built-ins'. A manual mode is on only while the user has switched it on (this session: a log out or reload ends it);
-- it needs neither "Switch by themselves" (focus.auto) nor its own On switch (focus.on, which governs triggered
-- modes), but Pause stops it like every mode. In strict priority a manual
-- mode the user switched on decides first, then combat > activity > location; within a class, built-ins first.
-- No announce while paused; Resume recomputes silently (the title and the view change, no chat line).
-- A view change with the same active set (bank opens, professions arrive) emits and keeps peeks and pins.
-- The windows hear SB_FOCUS_CHANGED(reason) whenever what is open may have changed: the active set
-- changed ("signal"), "pause", "resume", or a focus setting ("settings"). A change of the active
-- set ends every peek and pin (spec 6.4). New is never collapsed by a mode.
-- Settings (Core/Config.lua): focus.auto, focus.resolve ("merge" | "priority"), focus.peek
-- ("peek" | "keep"), focus.announce, focus.on.<id>, focus.sections.<id> (comma-separated ids),
-- focus.style ("front" | "collapse"). In "front" style a mode never collapses anything: there is no
-- peek, pin or close, and a header click is the user's own collapse, saved as without a mode.
local _, SB = ...

local Focus = { signals = {}, overrides = {}, paused = false, key = "", viewKey = "", active = {} }
SB.Focus = Focus

local CLASS_RANK = { manual = 4, combat = 3, activity = 2, location = 1 }

-- The six v1.0 modes (spec 6.3, AC8.1), in "user order" for strict priority within a class.
Focus.MODES = {
	{ id = "mplus", class = "activity", name = "MODE_MPLUS", trigger = function(s)
		return s.challengeMode == true or (s.instanceType == "party" and s.keystone == true and s.mythic == true)
	end },
	{ id = "raid", class = "activity", name = "MODE_RAID", trigger = function(s)
		return s.instanceType == "raid"
	end },
	{ id = "delves", class = "activity", name = "MODE_DELVES", trigger = function(s)
		return s.delve == true
	end },
	{ id = "gathering", class = "activity", name = "MODE_GATHERING", trigger = function(s)
		return s.gathering == true
	end },
	{ id = "fishing", class = "activity", name = "MODE_FISHING", trigger = function(s)
		return s.fishing == true
	end },
	{ id = "market", class = "location", name = "MODE_MARKET", trigger = function(s)
		return s.auctionOpen == true or s.merchantOpen == true or s.bankOpen == true
	end, expandAll = function(s)
		return s.bankOpen == true -- at the bank everything stays open (spec 6.3)
	end },
}
local byId = {}
for _, m in ipairs(Focus.MODES) do
	byId[m.id] = m
end
Focus.byId = byId

-- Week 12 (AC8.7): what a mode of the user's can switch on with. class decides strict priority, as for the built-ins.
Focus.TRIGGERS = {
	{ id = "manual", name = "TRIGGER_MANUAL", class = "manual" },
	{ id = "mplus", name = "TRIGGER_MPLUS", class = "activity", test = function(s)
		return s.challengeMode == true
	end },
	{ id = "dungeon", name = "TRIGGER_DUNGEON", class = "activity", test = function(s)
		return s.instanceType == "party"
	end },
	{ id = "raid", name = "TRIGGER_RAID", class = "activity", test = function(s)
		return s.instanceType == "raid"
	end },
	{ id = "delve", name = "TRIGGER_DELVE", class = "activity", test = function(s)
		return s.delve == true
	end },
	{ id = "pvp", name = "TRIGGER_PVP", class = "activity", test = function(s)
		return s.instanceType == "pvp" or s.instanceType == "arena"
	end },
	{ id = "fishing", name = "TRIGGER_FISHING", class = "activity", test = function(s)
		return s.fishing == true
	end },
	{ id = "gathering", name = "TRIGGER_GATHERING", class = "activity", test = function(s)
		return s.gathering == true
	end },
	{ id = "vendor", name = "TRIGGER_VENDOR", class = "location", test = function(s)
		return s.merchantOpen == true
	end },
	{ id = "auction", name = "TRIGGER_AUCTION", class = "location", test = function(s)
		return s.auctionOpen == true
	end },
	{ id = "bank", name = "TRIGGER_BANK", class = "location", test = function(s)
		return s.bankOpen == true
	end },
}
local TRIGGER = {}
for _, t in ipairs(Focus.TRIGGERS) do
	TRIGGER[t.id] = t
end
Focus.MAX_CUSTOM, Focus.MAX_NAME = 10, 24
Focus.custom, Focus.manual = {}, {} -- the user's modes (made order), and the manual ones switched on now
local customById = {}

-- A mode by id: a built-in, or one of the user's.
local function mode(id)
	return byId[id] or customById[id]
end
Focus.Mode = mode

function Focus.IsCustom(id)
	return customById[id] ~= nil
end

function Focus.NameOf(id)
	local m = mode(id)
	if not m then
		return tostring(id)
	end
	return m.custom and m.name or SB.L[m.name]
end

-- Built-ins first, then the user's modes in the order they were made.
function Focus.All()
	local out = {}
	for _, m in ipairs(Focus.MODES) do
		out[#out + 1] = m
	end
	for _, m in ipairs(Focus.custom) do
		out[#out + 1] = m
	end
	return out
end

function Focus.ManualOn(id)
	return Focus.manual[id] == true
end

local function cleanName(name)
	name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
	if name == "" then
		return nil, "empty"
	elseif #name > Focus.MAX_NAME then
		return nil, "long"
	elseif name:find("[%c|]") then
		return nil, "code"
	end
	return name
end

-- The user's modes as stored, read defensively: a damaged entry is skipped, an unknown trigger reads as manual, and
-- no more than MAX_CUSTOM are used. Called by Refresh (every focus setting change, a new Init) and the writers.
function Focus.LoadCustom()
	local list, stored = {}, SB.Config.db and SB.Config.db.modes
	for id, def in pairs(type(stored) == "table" and stored or {}) do
		if type(id) == "string" and #id <= 40 and id:match("^m_[%w_]+$") and type(def) == "table"
			and cleanName(def.name) == def.name then
			local t = TRIGGER[def.trigger] or TRIGGER.manual
			local mid = id
			list[#list + 1] = { id = id, name = def.name, custom = true, triggerId = t.id, class = t.class,
				n = tonumber(def.n) or 0, trigger = t.test or function()
					return Focus.manual[mid] == true
				end }
		end
	end
	table.sort(list, function(a, b)
		if a.n ~= b.n then
			return a.n < b.n
		end
		return a.id < b.id
	end)
	-- A name already taken (an earlier mode of the user's, or a built-in's name or id, in any case) is skipped.
	local taken = {}
	for _, m in ipairs(Focus.MODES) do
		taken[SB.L[m.name]:lower()], taken[m.id] = true, true
	end
	local kept = {}
	for _, m in ipairs(list) do
		local low = m.name:lower()
		if not taken[low] then
			taken[low] = true
			kept[#kept + 1] = m
		end
	end
	list = kept
	while #list > Focus.MAX_CUSTOM do
		table.remove(list)
	end
	customById = {}
	for _, m in ipairs(list) do
		customById[m.id] = m
	end
	Focus.custom = list
	for id in pairs(Focus.manual) do
		local m = customById[id]
		if not (m and m.triggerId == "manual") then
			Focus.manual[id] = nil -- a mode that is gone, or no longer manual, is not "switched on"
		end
	end
end

-- Gathering opens only the materials of the gathering professions the character has
-- (spec 6.2 "professions"); without that signal it opens all three.
local PROFESSION_OF = { c_herbs = "herb", c_ore = "ore", c_leathercloth = "skin" }

local ON_PATH = {}
for _, m in ipairs(Focus.MODES) do
	ON_PATH[m.id] = "focus.on." .. m.id
end

local function cfg(path)
	return SB.Config.Get(path)
end

local function split(text)
	local out = {}
	if type(text) == "string" then
		for id in text:gmatch("[^,%s]+") do
			out[#out + 1] = id
		end
	end
	return out
end

function Focus.IsEnabled(id)
	return cfg(ON_PATH[id] or ("focus.on." .. id)) ~= false
end

-- raw = true returns the stored or default list unfiltered (for the settings pages, W4-2);
-- only the effective view (Expanded) filters Gathering by the character's professions.
function Focus.Sections(id, raw)
	local list = split(cfg("focus.sections." .. id))
	if raw or id ~= "gathering" or type(Focus.signals.professions) ~= "table" then
		return list
	end
	local out = {}
	for _, sid in ipairs(list) do
		local need = PROFESSION_OF[sid]
		if not need or Focus.signals.professions[need] then
			out[#out + 1] = sid
		end
	end
	return out
end

-- With "Switch by themselves" off only the user's manual modes can be on: the user switched them on.
function Focus.Active()
	local out = {}
	local auto = cfg("focus.auto") ~= false
	for _, m in ipairs(Focus.MODES) do
		if auto and Focus.IsEnabled(m.id) and m.trigger(Focus.signals) then
			out[#out + 1] = m.id
		end
	end
	for _, m in ipairs(Focus.custom) do
		-- A manual mode ignores focus.on (that switch governs triggered modes): switched on by the user, it applies.
		local manual = m.class == "manual"
		if (auto or manual) and (manual or Focus.IsEnabled(m.id)) and m.trigger(Focus.signals) then
			out[#out + 1] = m.id
		end
	end
	return out
end

-- The modes that decide what is open: all active ones (merge), or the strongest (priority).
local function decidingOf(active)
	if cfg("focus.resolve") ~= "priority" or #active <= 1 then
		return active
	end
	local best
	for _, id in ipairs(active) do
		if not best or CLASS_RANK[mode(id).class] > CLASS_RANK[mode(best).class] then
			best = id
		end
	end
	return { best }
end

local function deciding()
	return decidingOf(Focus.active)
end

-- The view inputs besides the active ids: whether a deciding mode expands everything (the bank),
-- and, while Gathering decides, which professions the character has. A change here with the same
-- active set is a view change (W4-8): it emits, and keeps peeks and pins.
local function viewKeyOf(active)
	if #active == 0 then
		return ""
	end
	local parts = {}
	for _, id in ipairs(decidingOf(active)) do
		local m = mode(id)
		if m.expandAll and m.expandAll(Focus.signals) then
			parts[#parts + 1] = "all"
		end
		if id == "gathering" and type(Focus.signals.professions) == "table" then
			local keys = {}
			for k, v in pairs(Focus.signals.professions) do
				if v then
					keys[#keys + 1] = tostring(k)
				end
			end
			table.sort(keys)
			parts[#parts + 1] = "p:" .. table.concat(keys, ",")
		end
	end
	return table.concat(parts, ";")
end

local expandedCache, cacheValid = nil, false
local frontCache, frontValid = nil, false
local function invalidate()
	cacheValid, frontValid = false, false
end

function Focus.Style()
	return cfg("focus.style") == "collapse" and "collapse" or "front"
end

local function computeExpanded()
	if Focus.paused or #Focus.active == 0 then
		return nil
	end
	local set = { new = true }
	for _, id in ipairs(deciding()) do
		local m = mode(id)
		if m.expandAll and m.expandAll(Focus.signals) then
			return nil
		end
		for _, sid in ipairs(Focus.Sections(id)) do
			set[sid] = true
		end
	end
	return set
end

-- Cached until Recompute, Pause, Resume or Refresh (a focus setting) invalidates it.
function Focus.Expanded()
	if not cacheValid then
		expandedCache, cacheValid = computeExpanded(), true
	end
	return expandedCache
end

-- The sections the deciding modes move to the top in "front" style, each once, in the modes'
-- order (merge: the first mode's, then the next one's new ones). nil while no mode applies, in
-- "collapse" style, or while a deciding mode expands everything (the bank: nothing moves there).
local function computeFront()
	if Focus.Style() ~= "front" or Focus.paused or #Focus.active == 0 then
		return nil
	end
	local list, seen = {}, { new = true, free = true }
	for _, id in ipairs(deciding()) do
		local m = mode(id)
		if m.expandAll and m.expandAll(Focus.signals) then
			return nil
		end
		for _, sid in ipairs(Focus.Sections(id)) do
			if not seen[sid] then
				seen[sid] = true
				list[#list + 1] = sid
			end
		end
	end
	return list
end

-- Cached like Expanded(). Read only: callers never change the list.
function Focus.Front()
	if not frontValid then
		frontCache, frontValid = computeFront(), true
	end
	return frontCache
end

-- The order the sections are drawn in. order (New first, Free last, as Layout keeps it) is
-- returned as it is unless "front" style moves sections: then a new list with New, the mode's
-- sections that are in order, and every other id in its own order (Free stays last). A section the
-- mode names but the bag does not have is skipped. Nothing is saved: the user's category order and
-- collapse set are never written (W10: each section moves whole, with its header).
function Focus.SectionOrder(order)
	local front = Focus.Front()
	if not front or #front == 0 then
		return order
	end
	local present, moved, out = {}, {}, {}
	for _, id in ipairs(order) do
		present[id] = true
	end
	if present.new then
		out[1] = "new"
	end
	for _, id in ipairs(front) do
		if present[id] then
			out[#out + 1] = id
			moved[id] = true
		end
	end
	for _, id in ipairs(order) do
		if id ~= "new" and not moved[id] then
			out[#out + 1] = id
		end
	end
	return out
end

-- What Layout sees as collapsed. The user's own set while no mode collapses (none applies, paused,
-- or "front" style); otherwise the mode's set with this session's peeks, pins and closes on top.
-- The user's saved set is never written.
function Focus.CollapsedView(userSet)
	local open = Focus.Expanded()
	if not open or Focus.Style() ~= "collapse" then
		return userSet
	end
	local overrides = Focus.overrides
	return setmetatable({}, {
		__newindex = function()
			error("Focus view is read-only", 2)
		end,
		__index = function(_, id)
		local o = overrides[id]
		if o == "peek" or o == "pin" then
			return nil
		elseif o == "closed" then
			return true
		end
		return (id ~= "new" and not open[id]) or nil
	end })
end

-- A mode's collapse set is in force: peeks, pins and closes mean something only then.
function Focus.Applies()
	return Focus.Expanded() ~= nil and Focus.Style() == "collapse"
end

function Focus.OverrideOf(id)
	return Focus.overrides[id]
end

function Focus.HeaderClick(id, collapsedNow)
	if not Focus.Applies() then
		return false
	end
	if collapsedNow then
		Focus.overrides[id] = cfg("focus.peek") == "keep" and "pin" or "peek"
		return "peek"
	end
	Focus.overrides[id] = "closed"
	return "close"
end

function Focus.Pin(id)
	if not Focus.Applies() then
		return false
	end
	if Focus.overrides[id] == "pin" then
		Focus.overrides[id] = nil
		return "unpin"
	end
	Focus.overrides[id] = "pin"
	return "pin"
end

function Focus.WindowClosed()
	for id, o in pairs(Focus.overrides) do
		if o ~= "pin" then
			Focus.overrides[id] = nil
		end
	end
end

local function label(ids)
	local names = {}
	for _, id in ipairs(ids) do
		names[#names + 1] = Focus.NameOf(id)
	end
	return table.concat(names, " + ")
end

function Focus.Label()
	if Focus.paused then
		return SB.L.FOCUS_PAUSED
	end
	if #Focus.active == 0 then
		return nil
	end
	return label(deciding())
end

local function emit(reason)
	SB.Emit("SB_FOCUS_CHANGED", reason)
end

-- Re-evaluate the triggers. A different active set ends every peek and pin and tells the windows.
function Focus.Recompute(reason, quiet)
	invalidate()
	local active = Focus.Active()
	local key = table.concat(active, ",")
	if key == Focus.key then
		local vk = viewKeyOf(active)
		if vk == Focus.viewKey then
			return false
		end
		Focus.viewKey = vk -- same modes, different view: tell the windows, keep peeks and pins
		emit(reason or "signal")
		return true
	end
	Focus.key, Focus.active, Focus.overrides = key, active, {}
	Focus.viewKey = viewKeyOf(active)
	if cfg("focus.announce") and not Focus.paused and not quiet then
		SB.Print(SB.L.FOCUS_ANNOUNCE:format(#active > 0 and label(deciding()) or SB.L.FOCUS_NONE))
	end
	emit(reason or "signal")
	return true
end

-- The style the overrides were made under: peeks, pins and closes mean something only in "collapse",
-- so a style change (SetStyle, a character override, a reset) drops them; they must not come back
-- when the user returns to "collapse" within the same mode.
local overridesStyle = nil

function Focus.Refresh(reason)
	Focus.LoadCustom()
	invalidate()
	local style = Focus.Style()
	if overridesStyle ~= nil and style ~= overridesStyle then
		Focus.overrides = {}
	end
	overridesStyle = style
	if not Focus.Recompute(reason or "settings") then
		emit(reason or "settings")
	end
end

function Focus.SetSignal(name, value)
	if Focus.signals[name] == value then
		return false
	end
	Focus.signals[name] = value
	return Focus.Recompute("signal")
end

function Focus.IsPaused()
	return Focus.paused
end

function Focus.Pause()
	if Focus.paused then
		return false
	end
	Focus.paused, Focus.overrides = true, {}
	invalidate()
	emit("pause")
	return true
end

function Focus.Resume()
	if not Focus.paused then
		return false
	end
	Focus.paused, Focus.overrides = false, {}
	invalidate()
	emit("resume")
	return true
end

-- Settings writes. Config.Set emits SB_CONFIG_CHANGED; the listener below refreshes.
-- Each returns true, or false plus "unknown" (no such mode) or "readonly" (a newer
-- schema: nothing is written).
local function refuse(id)
	if not mode(id) then
		return "unknown"
	elseif SB.Config.readOnly then
		return "readonly"
	end
end

-- M5: a value already in force is not written again (no event, so nothing re-stacks).
local function write(path, value)
	if SB.Config.Get(path) == value then
		return true
	end
	return SB.Config.Set(path, value)
end

function Focus.SetEnabled(id, on)
	local why = refuse(id)
	if why then
		return false, why
	end
	if not write("focus.on." .. id, on and true or false) then
		return false, "readonly"
	end
	return true
end

function Focus.SetSections(id, list)
	local why = refuse(id)
	if why then
		return false, why
	end
	if not write("focus.sections." .. id, table.concat(list, ",")) then
		return false, "readonly"
	end
	return true
end

-- "front" (move the mode's sections to the top, collapse nothing) or "collapse" (week-4 behaviour).
function Focus.SetStyle(style)
	if style ~= "front" and style ~= "collapse" then
		return false, "unknown"
	elseif SB.Config.readOnly then
		return false, "readonly"
	end
	if not write("focus.style", style) then
		return false, "readonly"
	end
	return true
end

-- Back to the built-in set. Account-wide: the stored value is removed, so a new default in an
-- update applies (spec 8.5). With a character override the override takes the default.
function Focus.ResetSections(id)
	local why = refuse(id)
	if why then
		return false, why
	end
	local path = "focus.sections." .. id
	local value = nil
	if SB.Config.IsCharOverride(path) then
		value = SB.Config.Defaults.settings.focus.sections[id]
	end
	if not SB.Config.Set(path, value) then
		return false, "readonly"
	end
	return true
end

---------------------------------------------------------------------------
-- Week 12 (AC8.7): the user's own modes. Each writer refuses while read-only, writing nothing; a change emits
-- SB_CONFIG_CHANGED("focus.modes"), which the listener below turns into a Refresh (the modes are read again).
---------------------------------------------------------------------------
local function stored()
	local d = SB.Config.db
	if type(d.modes) ~= "table" then
		d.modes = {}
	end
	return d.modes
end

local function modesChanged()
	SB.Emit("SB_CONFIG_CHANGED", "focus.modes")
end

-- A name the user's mode may have: trimmed, 1 to 24 characters, no chat code, not a built-in mode's name or id (any
-- case), not another of the user's modes (exceptId: the mode being renamed).
function Focus.CheckName(name, exceptId)
	local clean, why = cleanName(name)
	if not clean then
		return nil, why
	end
	local low = clean:lower()
	for _, m in ipairs(Focus.MODES) do
		if low == SB.L[m.name]:lower() or low == m.id then
			return nil, "builtin"
		end
	end
	for _, m in ipairs(Focus.custom) do
		if m.id ~= exceptId and low == m.name:lower() then
			return nil, "taken"
		end
	end
	return clean
end

-- m_<the name in lower case, letters and digits>, then _2, _3...: never an id the user's modes have or had.
local function freeId(name, taken)
	local slug = name:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", ""):sub(1, 20)
	if slug == "" then
		slug = "mode"
	end
	local id, n = "m_" .. slug, 1
	while taken[id] ~= nil do
		n = n + 1
		id = "m_" .. slug .. "_" .. n
	end
	return id
end

function Focus.CreateMode(name, trigger)
	trigger = trigger or "manual"
	if SB.Config.readOnly then
		return nil, "readonly"
	elseif not TRIGGER[trigger] then
		return nil, "trigger"
	end
	local clean, why = Focus.CheckName(name)
	if not clean then
		return nil, why
	elseif #Focus.custom >= Focus.MAX_CUSTOM then
		return nil, "full"
	end
	local modes, n = stored(), 0
	for _, def in pairs(modes) do
		if type(def) == "table" and type(def.n) == "number" and def.n > n then
			n = def.n
		end
	end
	local id = freeId(clean, modes)
	modes[id] = { name = clean, trigger = trigger, n = n + 1 }
	-- Its switch and its (empty) sections are explicit values from the start, so "This character only" can copy them.
	local settings = SB.Config.db.settings
	settings.focus = type(settings.focus) == "table" and settings.focus or {}
	for kind, v in pairs({ on = true, sections = "" }) do
		settings.focus[kind] = type(settings.focus[kind]) == "table" and settings.focus[kind] or {}
		settings.focus[kind][id] = v
	end
	modesChanged()
	return id
end

local function ownMode(id)
	if not customById[id] then
		return "unknown"
	elseif SB.Config.readOnly then
		return "readonly"
	end
end

function Focus.RenameMode(id, name)
	local why = ownMode(id)
	if why then
		return false, why
	end
	local clean
	clean, why = Focus.CheckName(name, id)
	if not clean then
		return false, why
	end
	stored()[id].name = clean
	modesChanged()
	return true
end

function Focus.SetTrigger(id, trigger)
	local why = ownMode(id)
	if why then
		return false, why
	elseif not TRIGGER[trigger] then
		return false, "trigger"
	end
	stored()[id].trigger = trigger
	modesChanged()
	return true
end

-- The mode goes, with its on/off and its sections (the account's and this character's own); its id stays taken.
function Focus.DeleteMode(id)
	local why = ownMode(id)
	if why then
		return false, why
	end
	local C = SB.Config
	stored()[id] = false
	local focus = type(C.db.settings.focus) == "table" and C.db.settings.focus or {}
	for _, kind in ipairs({ "on", "sections" }) do
		if type(focus[kind]) == "table" then
			focus[kind][id] = nil
		end
		C.charDB.overrides["focus." .. kind .. "." .. id] = nil
	end
	Focus.manual[id] = nil
	modesChanged()
	return true
end

-- A manual mode on or off (this session). Returns true, changed; or false, why.
function Focus.SetManual(id, on)
	local m = customById[id]
	if not m then
		return false, "unknown"
	elseif m.triggerId ~= "manual" then
		return false, "notmanual"
	end
	if (Focus.manual[id] == true) == (on == true) then
		return true, false
	end
	Focus.manual[id] = on and true or nil
	Focus.Recompute("signal", true) -- the user's own command answers; no "Focus mode:" line on top (P2)
	return true, true
end

-- A mode by its name as shown (any case, spaces around ignored), built-in or the user's.
function Focus.FindMode(name)
	local low = type(name) == "string" and name:match("^%s*(.-)%s*$"):lower() or ""
	for _, m in ipairs(Focus.All()) do
		if Focus.NameOf(m.id):lower() == low then
			return m.id
		end
	end
	return nil
end

-- The user's modes' names (for /swagbag mode on and the share-string note).
function Focus.CustomNames(manualOnly)
	local out = {}
	for _, m in ipairs(Focus.custom) do
		if not manualOnly or m.triggerId == "manual" then
			out[#out + 1] = m.name
		end
	end
	return out
end

---------------------------------------------------------------------------
-- /swagbag mode [pause|resume|list|style [front|collapse]] (spec 10.5). Every form answers (P2).
---------------------------------------------------------------------------
local function sectionNames(id)
	local names = {}
	for _, sid in ipairs(Focus.Sections(id)) do
		-- week 11: a deleted category (a stale id in another character's own sections) is left out
		if not SB.Categories or sid == SB.Categories.FREE or SB.Categories.Get(sid) then
			names[#names + 1] = SB.Categories and SB.Categories.Name(sid) or sid
		end
	end
	return #names > 0 and table.concat(names, ", ") or SB.L.REPORT_NONE
end

function Focus.ListLines()
	local L, lines = SB.L, {}
	local active = {}
	for _, id in ipairs(Focus.active) do
		active[id] = true
	end
	for _, m in ipairs(Focus.All()) do
		local name, on = Focus.NameOf(m.id), Focus.IsEnabled(m.id)
		if m.triggerId == "manual" then -- week 12: the user's manual mode says so, and whether it is switched on
			name, on = L.MODE_LIST_MANUAL:format(name), Focus.manual[m.id] == true
		end
		lines[#lines + 1] = L.MODE_LIST_LINE:format(name, on and L.OVERLAY_ON or L.OVERLAY_OFF,
			active[m.id] and L.MODE_ACTIVE or "", sectionNames(m.id))
	end
	return lines
end

-- /swagbag mode on <name> | off [<name>] (week 12, AC8.7): the user's manual modes. Every form answers (P2).
local function manualList()
	local names = Focus.CustomNames(true)
	return #names > 0 and table.concat(names, ", ") or SB.L.REPORT_NONE
end

local function manualCommand(word, rest)
	local L = SB.L
	if rest == "" and word == "on" then
		return L.MODE_MANUAL_USAGE:format(manualList())
	elseif rest == "" then
		local off = {}
		for _, m in ipairs(Focus.custom) do
			if Focus.manual[m.id] then
				off[#off + 1] = m.name
				Focus.manual[m.id] = nil
			end
		end
		if #off > 0 then
			Focus.Recompute("signal", true) -- once: one re-stack, no in-between states
		end
		return #off > 0 and L.MODE_MANUAL_ALL_OFF:format(table.concat(off, ", ")) or L.MODE_MANUAL_NONE_ON
	end
	local id = Focus.FindMode(rest)
	if not id then
		return L.MODE_MANUAL_UNKNOWN:format(rest, manualList())
	end
	local name = Focus.NameOf(id)
	local ok, changed = Focus.SetManual(id, word == "on")
	if not ok then
		return L.MODE_MANUAL_AUTO:format(name)
	elseif word == "off" then
		return changed and L.MODE_MANUAL_OFF:format(name) or L.MODE_MANUAL_ALREADY_OFF:format(name)
	elseif not changed then
		return L.MODE_MANUAL_ALREADY_ON:format(name)
	end
	return Focus.paused and { L.MODE_MANUAL_ON:format(name), L.MODE_MANUAL_PAUSED } or L.MODE_MANUAL_ON:format(name)
end

-- /swagbag mode style [front|collapse]: the style now, or switch it. A wrong word gets the style now
-- and how to type it; read-only settings refuse (P2).
local function styleCommand(word)
	local L = SB.L
	if word == "front" or word == "collapse" then
		if not Focus.SetStyle(word) then
			return L.SETTINGS_READONLY
		end
		return word == "front" and L.MODE_STYLE_FRONT or L.MODE_STYLE_COLLAPSE
	end
	return L.MODE_STYLE_STATE:format(Focus.Style() == "front" and L.MODE_STYLE_NAME_FRONT or L.MODE_STYLE_NAME_COLLAPSE)
end

SB.Slash.Register("mode", SB.L.HELP_MODE, function(arg)
	local L = SB.L
	arg = (arg or ""):lower()
	local word, rest = arg:match("^(%S*)%s*(.-)%s*$")
	if word == "style" then
		return styleCommand(rest)
	elseif word == "on" or word == "off" then
		return manualCommand(word, rest)
	end
	if arg == "pause" then
		return Focus.Pause() and L.MODE_PAUSED or L.MODE_ALREADY_PAUSED
	elseif arg == "resume" then
		return Focus.Resume() and L.MODE_RESUMED or L.MODE_NOT_PAUSED
	elseif arg == "list" then
		return Focus.ListLines()
	end
	local status = L.MODE_STATUS:format(Focus.Label() or L.FOCUS_NONE)
	if arg ~= "" then
		return { status, L.MODE_USAGE } -- an unknown word: the status, and how to type it (P2)
	end
	return status
end, "bags")

-- Any focus setting changed, by a writer above, a character override, a reset or a new Init: the
-- cached view is stale. Refresh never writes settings, so this cannot loop.
SB.On("SB_CONFIG_CHANGED", function(_, path)
	if path == "focus.sections" then
		-- week 11: a deleted category's id left the section sets (Categories.Delete). It had no section in the
		-- bags, so nothing open changes: the sets are read again, and the open bags are not re-stacked (P5).
		invalidate()
	elseif path == nil or path:sub(1, 6) == "focus." then
		Focus.Refresh("settings")
	end
end, "bags")
