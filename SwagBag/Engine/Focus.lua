-- SwagBag focus modes (spec section 6). Pure Lua: signals in, "which sections are open" out.
-- No frames and no WoW calls; Engine/Signals.lua feeds the signals, the bags window asks.
--   Focus.SetSignal(name, value) -> changed      one fact about the world (spec 6.2)
--   Focus.Recompute(reason) -> changed           re-evaluate the triggers (signals call it)
--   Focus.Refresh(reason)                        a focus setting changed: always tell the windows
--   Focus.Active() -> { ids }                    enabled modes whose trigger is true (MODES order)
--   Focus.Expanded() -> set | nil                the open sections, or nil when no mode applies
--                                                (none active, paused, switched off, or a mode
--                                                that expands everything: the bank)
--   Focus.CollapsedView(userSet) -> lookup       collapsed[id] for Layout.Position / Apply:
--                                                userSet itself when no mode applies
--   Focus.HeaderClick(id, collapsedNow) -> "peek" | "close"   a header click while a mode applies
--   Focus.Pin(id) -> "pin" | "unpin"             right-click: keep a section open until the
--                                                mode changes (spec 6.1 pin)
--   Focus.OverrideOf(id) -> nil | "peek" | "pin" | "closed"
--   Focus.WindowClosed()                         peeks and closes end; pins stay (spec 6.1)
--   Focus.Pause() / Focus.Resume() -> changed; Focus.IsPaused()   for this session only
--   Focus.Label() -> text | nil                  "M+", "M+ + Fishing", "Paused" (title, AC8.5)
--   Focus.Sections(id, raw) -> { category ids }       a mode's section set (settings or default)
--   Focus.SetSections(id, list) -> bool, Focus.ResetSections(id) -> bool, Focus.SetEnabled(id, on) -> bool
-- No announce while paused; Resume recomputes silently (the title and the view change, no chat line).
-- A view change with the same active set (bank opens, professions arrive) emits and keeps peeks and pins.
-- The windows hear SB_FOCUS_CHANGED(reason) whenever what is open may have changed: the active set
-- changed ("signal"), "pause", "resume", or a focus setting ("settings"). A change of the active
-- set ends every peek and pin (spec 6.4). New is never collapsed by a mode.
-- Settings (Core/Config.lua): focus.auto, focus.resolve ("merge" | "priority"), focus.peek
-- ("peek" | "keep"), focus.announce, focus.on.<id>, focus.sections.<id> (comma-separated ids).
local _, SB = ...

local Focus = { signals = {}, overrides = {}, paused = false, key = "", viewKey = "", active = {} }
SB.Focus = Focus

local CLASS_RANK = { combat = 3, activity = 2, location = 1 }

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

function Focus.Active()
	local out = {}
	if cfg("focus.auto") == false then
		return out
	end
	for _, m in ipairs(Focus.MODES) do
		if Focus.IsEnabled(m.id) and m.trigger(Focus.signals) then
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
		if not best or CLASS_RANK[byId[id].class] > CLASS_RANK[byId[best].class] then
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
		local m = byId[id]
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
local function invalidate()
	cacheValid = false
end

local function computeExpanded()
	if Focus.paused or #Focus.active == 0 then
		return nil
	end
	local set = { new = true }
	for _, id in ipairs(deciding()) do
		local m = byId[id]
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

-- What Layout sees as collapsed. The user's own set while no mode applies; otherwise the mode's
-- set with this session's peeks, pins and closes on top. The user's saved set is never written.
function Focus.CollapsedView(userSet)
	local open = Focus.Expanded()
	if not open then
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

function Focus.Applies()
	return Focus.Expanded() ~= nil
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
	local L, names = SB.L, {}
	for _, id in ipairs(ids) do
		names[#names + 1] = L[byId[id].name]
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
function Focus.Recompute(reason)
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
	if cfg("focus.announce") and not Focus.paused then
		SB.Print(SB.L.FOCUS_ANNOUNCE:format(#active > 0 and label(deciding()) or SB.L.FOCUS_NONE))
	end
	emit(reason or "signal")
	return true
end

function Focus.Refresh(reason)
	invalidate()
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
	if not byId[id] then
		return "unknown"
	elseif SB.Config.readOnly then
		return "readonly"
	end
end

function Focus.SetEnabled(id, on)
	local why = refuse(id)
	if why then
		return false, why
	end
	if not SB.Config.Set("focus.on." .. id, on and true or false) then
		return false, "readonly"
	end
	return true
end

function Focus.SetSections(id, list)
	local why = refuse(id)
	if why then
		return false, why
	end
	if not SB.Config.Set("focus.sections." .. id, table.concat(list, ",")) then
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

-- Any focus setting changed, by a writer above, a character override, a reset or a new Init: the
-- cached view is stale. Refresh never writes settings, so this cannot loop.
SB.On("SB_CONFIG_CHANGED", function(_, path)
	if path == nil or path:sub(1, 6) == "focus." then
		Focus.Refresh("settings")
	end
end, "bags")
