-- SwagBag low-consumables warning (spec 6.6, F11). Part of the M+ experience: when a key starts,
-- when the player zones into a Mythic dungeon holding a keystone, and when a dungeon teleport
-- ("Path of ...", Engine/FocusData.lua) is cast, each watched entry is counted in the bags and
-- one line names what is short: "Low: Flask (0/1), Potions (2/5)", on screen and in chat.
-- Nothing prints when every threshold is met. At most once per 60 s per trigger.
--   Consumables.List() -> { { query | itemID, threshold, name } }   the watch list (a copy)
--   Consumables.Low() -> { { name, have, need } }                    what is short now
--   Consumables.Check(trigger, force) -> low list | nil (nil: rate-limited or switched off)
--     force (the "Check now" button, /swagbag consumables check): no rate limit, always answers
--   Consumables.Add(itemID) / Remove(index) / SetThreshold(index, n) / Reset() -> ok, reason
--     reason "readonly" (newer settings), "known" (already watched), "invalid"
-- Settings: consumables.warn (default on); consumables.watch (nil = Consumables.DEFAULTS; a
-- list once the user edits it). The warning does not depend on the M+ mode being on or paused:
-- pausing only stops sections collapsing.
local _, SB = ...

local Cons = { RATE = 60, last = {}, compiled = {}, MAX_THRESHOLD = 200 }
SB.Consumables = Cons

-- name is a Locale key for keyword entries; item entries are named from the item.
Cons.DEFAULTS = {
	{ query = "flask", threshold = 1, name = "WATCH_FLASK" },
	{ query = "potion", threshold = 5, name = "WATCH_POTION" },
	{ query = "food", threshold = 5, name = "WATCH_FOOD" },
}

local function valid(e)
	if type(e) ~= "table" or type(e.threshold) ~= "number" or e.threshold < 1 or e.threshold ~= math.floor(e.threshold)
		or e.threshold > Cons.MAX_THRESHOLD then
		return false
	end
	if type(e.itemID) == "number" then
		return e.itemID >= 1 and e.itemID == math.floor(e.itemID) and e.itemID < math.huge
	end
	return type(e.query) == "string" and e.query ~= ""
end

-- The watch list as plain copies; damaged saved entries are skipped, never an error.
function Cons.List()
	local saved = SB.Config.Get("consumables.watch")
	local src = type(saved) == "table" and saved or Cons.DEFAULTS
	local out = {}
	for _, e in ipairs(src) do
		if valid(e) then
			out[#out + 1] = { query = e.query, itemID = e.itemID, threshold = e.threshold, name = e.name }
		end
	end
	return out
end

function Cons.Name(e)
	local L = SB.L
	if e.itemID then
		local info = SB.Adapter.GetItemInfo(e.itemID)
		return info and info.name or L.ITEM_N:format(e.itemID)
	end
	return e.name and L[e.name] or e.query
end

local function compiled(query)
	local c = Cons.compiled[query]
	if not c then
		c = SB.Query.Compile(query)
		Cons.compiled[query] = c
	end
	return c
end

-- How many of an entry the bags hold (backpack, bags and the reagent bag).
function Cons.Count(e)
	local n = 0
	local c = e.query and compiled(e.query)
	for bag, slot, s in SB.Inventory.Iterate("bags") do
		if s then
			if e.itemID then
				if s.itemID == e.itemID then
					n = n + (s.count or 1)
				end
			elseif c and c.fn then
				local record = SB.Items.Describe(bag, slot)
				if record and SB.Query.Eval(c, record) == true then
					n = n + (s.count or 1)
				end
			end
		end
	end
	return n
end

function Cons.Low()
	local low = {}
	for _, e in ipairs(Cons.List()) do
		local have = Cons.Count(e)
		if have < e.threshold then
			low[#low + 1] = { name = Cons.Name(e), have = have, need = e.threshold }
		end
	end
	return low
end

function Cons.Check(trigger, force)
	local A, L = SB.Adapter, SB.L
	if not force then
		if not SB.Config.Get("consumables.warn") then
			return nil
		end
		local now = A.Now()
		if Cons.last[trigger] and now - Cons.last[trigger] < Cons.RATE then
			return nil
		end
		Cons.last[trigger] = now
	end
	local low = Cons.Low()
	if #low == 0 then
		if force then
			SB.Print(L.CONSUMABLES_OK)
		end
		return low
	end
	local parts = {}
	for i, l in ipairs(low) do
		parts[i] = L.CONSUMABLES_PART:format(l.name, l.have, l.need)
	end
	local text = L.CONSUMABLES_LOW:format(table.concat(parts, ", "))
	A.ScreenMessage(text)
	SB.Print(text)
	return low
end

---------------------------------------------------------------------------
-- Editing the watch list (Settings, /swagbag consumables). Every write refuses while the
-- settings are read-only (a newer schema) and changes nothing then.
---------------------------------------------------------------------------
local function save(list)
	if not SB.Config.Set("consumables.watch", list) then
		return false, "readonly"
	end
	return true
end

function Cons.Add(itemID)
	if type(itemID) ~= "number" or not valid({ itemID = itemID, threshold = 1 }) then
		return false, "invalid"
	end
	local list = Cons.List()
	for _, e in ipairs(list) do
		if e.itemID == itemID then
			return false, "known"
		end
	end
	list[#list + 1] = { itemID = itemID, threshold = 1 }
	return save(list)
end

function Cons.Remove(index)
	local list = Cons.List()
	if not list[index] then
		return false, "invalid"
	end
	table.remove(list, index)
	return save(list)
end

function Cons.SetThreshold(index, n)
	local list = Cons.List()
	if not list[index] or type(n) ~= "number" then
		return false, "invalid"
	end
	list[index].threshold = math.max(1, math.min(Cons.MAX_THRESHOLD, math.floor(n)))
	return save(list)
end

function Cons.Reset()
	return save(nil)
end

-- Why an edit refused, as a line for the user (the Settings status line, chat).
function Cons.ReasonText(reason)
	local L = SB.L
	if reason == "readonly" then
		return L.SETTINGS_READONLY
	elseif reason == "known" then
		return L.SET_WATCH_KNOWN
	end
	return L.SET_WATCH_INVALID
end

function Cons.Summary()
	local L, parts = SB.L, {}
	for i, e in ipairs(Cons.List()) do
		parts[i] = L.CONSUMABLES_ENTRY:format(Cons.Name(e), e.threshold)
	end
	return #parts > 0 and table.concat(parts, ", ") or L.REPORT_NONE
end

---------------------------------------------------------------------------
-- Triggers (spec 6.6). They wait for login like the signals. Consumables relies on Signals handling
-- PLAYER_ENTERING_WORLD first (TOC order: Signals.lua loads before this file), so the zone
-- signals are fresh here.
---------------------------------------------------------------------------
local function on(event, fn)
	SB.On(event, function(...)
		if SB.Signals.ready then
			fn(...)
		end
	end, "bags")
end

on("CHALLENGE_MODE_START", function()
	Cons.Check("start")
end)

on("PLAYER_ENTERING_WORLD", function()
	local s = SB.Focus.signals
	if s.instanceType == "party" and (s.challengeMode or (s.mythic and s.keystone)) then
		Cons.Check("enter")
	end
end)

-- Player casts only (W4-11: RegisterUnitEvent keeps other units' casts out of Lua; the unit check
-- stays as a guard). Matches refuses a secret or non-number spell ID before any lookup (W4-3).
SB.OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, unit, _, spellID)
	if not SB.Signals.ready then
		return
	end
	if unit == "player" and SB.FocusData.Matches(SB.FocusData.teleports, spellID) then
		Cons.Check("portal")
	end
end, "bags")

SB.Slash.Register("consumables", SB.L.HELP_CONSUMABLES, function(arg)
	local L, C = SB.L, SB.Config
	arg = (arg or ""):lower()
	if arg == "" then
		return L.CONSUMABLES_LIST:format(C.Get("consumables.warn") and L.OVERLAY_ON or L.OVERLAY_OFF, Cons.Summary())
	elseif arg == "check" then
		Cons.Check("manual", true)
		return {}
	elseif arg == "on" or arg == "off" then
		if not C.Set("consumables.warn", arg == "on") then
			return L.SETTINGS_READONLY
		end
		return arg == "on" and L.CONSUMABLES_ON or L.CONSUMABLES_OFF
	elseif arg == "reset" then
		if not Cons.Reset() then
			return L.SETTINGS_READONLY
		end
		return L.CONSUMABLES_RESET:format(Cons.Summary())
	end
	return L.CONSUMABLES_USAGE
end, "bags")
