-- SwagBag item locks (week 7, user pick 5): items the user never wants sold. A lock is per item ID
-- (every stack and copy of that item), account-wide, in SwagBagDB.locks = { [itemID] = true } (read
-- defensively: a damaged table is treated as empty; schema stays 2). A locked item is never sold by
-- SwagBag (Engine/Vendor.lua: auto-sell and Sell all skip it), wears a small lock (overlays.lock), says so
-- on its tooltip, and the search keyword `locked` finds it. Selling one by hand still works (SwagBag
-- cannot stop Blizzard's own right-click without hooking it, spec 5.3); a chat line then says so.
--   Locks.Has(itemID) -> bool
--   Locks.Toggle(itemID) -> true, locked | false, "readonly" | "invalid"
--   Locks.List() -> { itemID }  sorted
--   Locks.Clear() -> n | false, "readonly"   unlocks all at once and keeps the set (one step of undo)
--   Locks.AskClear() -> "ask", n | n | false, "readonly"   the user's way: the first call asks, a second within
--     Locks.CONFIRM seconds clears (Settings > Vendor "Unlock all" and /swagbag lock clear)
--   Locks.Undo() -> n | false, "none" | "readonly"   puts back the set the last clear removed
--   Locks.Name(itemID) -> the item's name (or "item 123" while it loads)
--   Locks.TooltipLine(tooltip, itemID)   the item tooltip's "Locked" line (UI/LockButton.lua hooks it)
--   Locks.KeywordNote() -> bool   the one-time note about the `locked` keyword's new meaning (ruling R21)
-- Every change emits SB_LOCKS_CHANGED; the open windows re-draw their lock marks, a search re-applies (a
-- `locked` search follows at once) and Settings > Vendor's count follows.
local _, SB = ...

local L = SB.L
-- Every caged battle pet is the one item 82800: a lock on it would lock every cage, so it is refused.
local Locks = { PET_CAGE = 82800, CONFIRM = 10 }
SB.Locks = Locks

local function store(create)
	local db = SB.Config.db
	if not db then
		return nil
	end
	if type(db.locks) ~= "table" then
		if not create then
			return nil
		end
		db.locks = {}
	end
	return db.locks
end

local function valid(itemID)
	return type(itemID) == "number" and itemID >= 1 and itemID == math.floor(itemID) and itemID < math.huge
end

function Locks.Has(itemID)
	local t = store(false)
	return t ~= nil and valid(itemID) and t[itemID] == true
end

function Locks.Toggle(itemID)
	if not valid(itemID) or itemID == Locks.PET_CAGE then
		return false, "invalid"
	end
	if SB.Config.readOnly then
		return false, "readonly"
	end
	local t = store(true)
	t[itemID] = (t[itemID] ~= true) or nil
	SB.Emit("SB_LOCKS_CHANGED")
	return true, t[itemID] == true
end

function Locks.List()
	local out = {}
	for id, on in pairs(store(false) or {}) do
		if on == true and valid(id) then
			out[#out + 1] = id
		end
	end
	table.sort(out)
	return out
end

function Locks.Clear()
	if SB.Config.readOnly then
		return false, "readonly"
	end
	local list = Locks.List()
	local d = SB.Config.db
	if d then
		if #list > 0 then
			if type(d.backups) ~= "table" then
				d.backups = {}
			end
			d.backups.locks = list -- one step of undo: the set that was cleared
		end
		d.locks = nil
	end
	Locks.asked = nil
	SB.Emit("SB_LOCKS_CHANGED")
	return #list
end

-- Unlocking everything is a big step with no per-item trace: the first call only asks; a second one within
-- Locks.CONFIRM seconds does it. (The set is kept either way: `lock undo` brings it back.)
function Locks.AskClear()
	if SB.Config.readOnly then
		return false, "readonly"
	end
	local n = #Locks.List()
	local now = SB.Adapter.Now()
	if n > 0 and not (Locks.asked and now - Locks.asked <= Locks.CONFIRM) then
		Locks.asked = now
		return "ask", n
	end
	return Locks.Clear()
end

function Locks.Undo()
	if SB.Config.readOnly then
		return false, "readonly"
	end
	local d = SB.Config.db
	local back = d and type(d.backups) == "table" and d.backups.locks
	if type(back) ~= "table" then
		return false, "none"
	end
	local t = store(true)
	local n = 0
	for _, id in ipairs(back) do
		if valid(id) and id ~= Locks.PET_CAGE then
			t[id] = true
			n = n + 1
		end
	end
	d.backups.locks = nil
	SB.Emit("SB_LOCKS_CHANGED")
	return n
end

function Locks.Name(itemID)
	local info = SB.Adapter.GetItemInfo(itemID)
	return info and info.name or L.ITEM_N:format(itemID)
end

function Locks.TooltipLine(tooltip, itemID)
	if Locks.Has(itemID) then
		SB.Adapter.TooltipLine(tooltip, L.LOCK_TOOLTIP)
	end
end

-- Ruling R21: `locked` changed meaning in 0.7.0 (the user's lock; the client's lock is now `inuse`). At the
-- first login with this version, a saved category or consumables-watch query that uses the word gets one chat
-- note. SwagBagDB.notes.lockedKeyword (read defensively; schema stays 2) remembers that the check was made.
local function usesLocked(query)
	return type(query) == "string" and query:lower():find("%f[%w_]locked%f[^%w_]") ~= nil
end

function Locks.KeywordNote()
	local d = SB.Config.db
	if not d or SB.Config.readOnly then
		return false
	end
	if type(d.notes) ~= "table" then
		d.notes = {}
	end
	if d.notes.lockedKeyword then
		return false
	end
	d.notes.lockedKeyword = true
	local found = false
	for _, key in ipairs({ "categories", "userEdits" }) do
		for _, def in pairs(type(d[key]) == "table" and d[key] or {}) do
			found = found or (type(def) == "table" and usesLocked(def.query))
		end
	end
	local watch = SB.Config.Get("consumables.watch")
	for _, e in ipairs(type(watch) == "table" and watch or {}) do
		found = found or (type(e) == "table" and usesLocked(e.query))
	end
	if found then
		SB.Print(L.LOCK_KEYWORD_NOTE)
	end
	return found
end

SB.On("SB_LOGIN", Locks.KeywordNote, "none")

-- A lock or unlock made meanwhile starts the question over.
SB.On("SB_LOCKS_CHANGED", function()
	Locks.asked = nil
end, "none")

-- /swagbag lock [list|clear|undo]: how to lock, the locked items, or unlock them all (P2).
SB.Slash.Register("lock", L.HELP_LOCK, function(arg)
	arg = (arg or ""):lower()
	local list = Locks.List()
	if arg == "" then
		return L.LOCK_STATE:format(#list)
	elseif arg == "list" then
		if #list == 0 then
			return L.LOCK_NONE
		end
		local names = {}
		for i, id in ipairs(list) do
			names[i] = Locks.Name(id)
		end
		return L.LOCK_LIST:format(table.concat(names, ", "))
	elseif arg == "clear" then
		local n, count = Locks.AskClear()
		if n == "ask" then
			return L.LOCK_CLEAR_ASK:format(count)
		elseif not n then
			return L.SETTINGS_READONLY
		end
		return L.LOCK_CLEARED:format(n)
	elseif arg == "undo" then
		local n, why = Locks.Undo()
		if not n then
			return why == "readonly" and L.SETTINGS_READONLY or L.LOCK_UNDO_NONE
		end
		return L.LOCK_UNDONE:format(n)
	end
	return L.LOCK_USAGE
end)
