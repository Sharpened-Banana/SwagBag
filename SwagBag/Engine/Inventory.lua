-- SwagBag Inventory: live model of every container plus event coalescing (spec 9).
--   BAG_UPDATE(bag)       -> mark bag dirty (no work)
--   BAG_UPDATE_DELAYED    -> flush once, 50 ms debounce
--   failsafe              -> flush 250 ms after the first dirty mark if DELAYED never came
--   ITEM_LOCK_CHANGED     -> LOCK for that slot
--   BAG_UPDATE_COOLDOWN   -> COOLDOWN (no rescan)
--   ITEM_DATA_LOAD_RESULT / GET_ITEM_INFO_RECEIVED -> LOADED for slots holding a pending item
-- Listeners: Inventory.OnChanged(fn) with fn(mask, changes); changes = { {bag, slot, reasons} }.
-- Reasons are bit flags combined with plain arithmetic (Lua 5.1 has no bit operators).
-- Unseen (final review item 6, the user's rule; spec AC3.3): a bags item (Adapter.GetBagIDs("bags"): the bags and
-- the reagent bag; never the banks) is UNSEEN from the flush that brings it in until its button (or its list
-- row) is hovered (Inv.Seen), whether the window is open or closed, in combat too (data only: nothing is drawn
-- here). It arrives when a slot gains an item stack AND the bags hold more of that item than before the flush
-- (loot, a purchase, mail, a trade, a bank withdrawal, crafting); a move or a split inside the bags, and Blizzard's
-- sort, add nothing, and an unseen item moved inside the bags stays unseen in its new slot. An item whose ID
-- was secret when it came (the Adapter reads that slot as empty) arrives when it becomes readable. Session only:
-- the login scan and a /reload mark nothing. The bags window puts unseen items in New at every full layout,
-- whatever the focus mode (UI/BagsWindow.lua). Blizzard's own new-item flag is not used: SwagBag clears it
-- when the bags close (W4-15), so it cannot carry an item to the next open.
--   Inv.IsUnseen(bag, slot) -> bool;  Inv.Seen(bag, slot)
local _, SB = ...

local Inv = {
	slots = {}, -- [bag][slot] = { itemID, link, count, isLocked } (nil = empty)
	sizes = {}, -- [bag] = number of slots
	dirty = {}, -- [bag] = true
	listeners = {},
	newSet = {}, -- ["bag:slot"] = true for items that arrived this session
	unseen = {}, -- ["bag:slot"] = itemID: bags items that arrived and were not hovered yet (see the header)
	pending = {}, -- [itemID] = true while waiting for item data
	scanned = false,
	failsafeArmed = false,
	DEBOUNCE = 0.05,
	FAILSAFE = 0.25,
}
SB.Inventory = Inv

Inv.R = { COUNT = 1, ITEM = 2, SIZE = 4, LOCK = 8, COOLDOWN = 16, LOADED = 32 }
local FLAGS = { 1, 2, 4, 8, 16, 32 }

function Inv.Has(mask, flag)
	return math.floor(mask / flag) % 2 == 1
end

function Inv.Or(a, b)
	for _, flag in ipairs(FLAGS) do
		if Inv.Has(b, flag) and not Inv.Has(a, flag) then
			a = a + flag
		end
	end
	return a
end

local function key(bag, slot)
	return bag .. ":" .. slot
end

-- Pure: reasons (0 = unchanged) between two slot snapshots.
function Inv.DiffSlot(old, new)
	if old == nil and new == nil then
		return 0
	end
	if old == nil or new == nil or old.itemID ~= new.itemID or old.link ~= new.link then
		return Inv.R.ITEM
	end
	if old.count ~= new.count then
		return Inv.R.COUNT
	end
	return 0
end

local function snapshot(bag, slot)
	local s = SB.Adapter.GetSlot(bag, slot)
	if not s then
		return nil
	end
	return { itemID = s.itemID, link = s.link, count = s.count, isLocked = s.isLocked }
end

-- Rescan one bag. Returns mask, changes.
function Inv.ScanBag(bag)
	local size = SB.Adapter.NumSlots(bag)
	local oldSize = Inv.sizes[bag] or 0
	local old = Inv.slots[bag] or {}
	local new, changes = {}, {}
	local mask = size ~= oldSize and Inv.R.SIZE or 0
	for slot = 1, math.max(size, oldSize) do
		local snap = slot <= size and snapshot(bag, slot) or nil
		new[slot] = snap
		local r = Inv.DiffSlot(old[slot], snap)
		if r ~= 0 then
			local change = { bag = bag, slot = slot, reasons = r }
			changes[#changes + 1] = change
			mask = Inv.Or(mask, r)
			if r == Inv.R.ITEM then -- whatever was unseen here left (Flush carries it if it only moved)
				change.wasUnseen = Inv.unseen[key(bag, slot)]
				Inv.unseen[key(bag, slot)] = nil
			end
			if r == Inv.R.ITEM and Inv.scanned then
				Inv.newSet[key(bag, slot)] = snap ~= nil or nil
				if snap == nil then -- the item left: the client's own flag for the slot goes too (W4-15)
					SB.Adapter.ClearNewItem(bag, slot)
				end
			end
		end
	end
	Inv.slots[bag], Inv.sizes[bag] = new, size
	return mask, changes
end

function Inv.Notify(mask, changes)
	for _, fn in ipairs(Inv.listeners) do
		SB.ErrorTrap.Run("inventory.listener", "bags", fn, mask, changes)
	end
end

function Inv.OnChanged(fn)
	Inv.listeners[#Inv.listeners + 1] = fn
end

local failsafeGen = 0

-- The bags' bag IDs as a set, and how many of each item they hold now.
local function bagsSet()
	local set = {}
	for _, bag in ipairs(SB.Adapter.GetBagIDs("bags")) do
		set[bag] = true
	end
	return set
end

local function totals(set)
	local out = {}
	for bag in pairs(set) do
		for slot = 1, Inv.Size(bag) do
			local s = Inv.slots[bag] and Inv.slots[bag][slot]
			if s then
				out[s.itemID] = (out[s.itemID] or 0) + (s.count or 1)
			end
		end
	end
	return out
end

-- After a flush: a bags slot that gained a stack is unseen when the bags now hold more of the item than before
-- (it came from outside), or when an unseen stack of the item left a slot in the same flush (it only moved).
local function markUnseen(changes, set, before)
	local after, carried = totals(set), {}
	for _, c in ipairs(changes) do
		if c.wasUnseen then
			carried[c.wasUnseen] = (carried[c.wasUnseen] or 0) + 1
		end
	end
	for _, c in ipairs(changes) do
		local s = c.reasons == Inv.R.ITEM and set[c.bag] and Inv.GetSlot(c.bag, c.slot)
		if s then
			local id = s.itemID
			if (after[id] or 0) > (before[id] or 0) then
				Inv.unseen[key(c.bag, c.slot)] = id
			elseif (carried[id] or 0) > 0 then
				carried[id] = carried[id] - 1
				Inv.unseen[key(c.bag, c.slot)] = id
			end
		end
	end
end

function Inv.Flush(source)
	local bags = {}
	for bag in pairs(Inv.dirty) do
		bags[#bags + 1] = bag
	end
	table.sort(bags)
	Inv.dirty = {}
	Inv.failsafeArmed = false
	failsafeGen = failsafeGen + 1
	local mask, all = 0, {}
	local set = bagsSet()
	local before = Inv.scanned and totals(set)
	for _, bag in ipairs(bags) do
		local m, changes = Inv.ScanBag(bag)
		mask = Inv.Or(mask, m)
		for _, c in ipairs(changes) do
			all[#all + 1] = c
		end
	end
	if before then
		markUnseen(all, set, before)
	end
	if mask ~= 0 then
		Inv.lastFlush = source
		Inv.Notify(mask, all)
	end
end

-- Flush now the dirty bags of these kinds only (listeners are notified as usual); other
-- dirty bags keep waiting for their own flush.
function Inv.FlushKinds(kinds, source)
	local keep, any = {}, false
	local wanted = {}
	for _, kind in ipairs(kinds) do
		for _, bag in ipairs(SB.Adapter.GetBagIDs(kind)) do
			wanted[bag] = true
		end
	end
	for bag in pairs(Inv.dirty) do
		if wanted[bag] then
			any = true
		else
			keep[bag] = true
		end
	end
	if not any then
		return
	end
	for bag in pairs(keep) do
		Inv.dirty[bag] = nil
	end
	Inv.Flush(source)
	for bag in pairs(keep) do
		Inv.MarkDirty(bag) -- still waiting (this re-arms the failsafe the flush cancelled)
	end
end

function Inv.MarkDirty(bag)
	if type(bag) ~= "number" or SB.Adapter.IsSecret(bag) then
		return
	end
	Inv.dirty[bag] = true
	if Inv.failsafeArmed then
		return
	end
	Inv.failsafeArmed = true
	local gen = failsafeGen
	SB.Adapter.After(Inv.FAILSAFE, function()
		SB.ErrorTrap.Run("inventory.failsafe", "bags", function()
			if gen ~= failsafeGen then
				return
			end
			Inv.failsafeArmed = false
			if next(Inv.dirty) ~= nil then
				Inv.Flush("failsafe")
			end
		end)
	end)
end

function Inv.TrackedBags()
	local A, list = SB.Adapter, {}
	for _, kind in ipairs({ "bags", "bank", "warband" }) do
		for _, bag in ipairs(A.GetBagIDs(kind)) do
			list[#list + 1] = bag
		end
	end
	return list
end

-- Rescan every bag of a kind without marking anything "new". The character bank can only be
-- read at a banker (spec 5.7), so what is in it at a visit is not a new arrival. visit: true
-- at the start of a bank visit, which also forgets what was new during an earlier visit
-- (ruling W3-25); a rescan inside a visit keeps this visit's arrivals new.
-- Inv.scanned is put back even when a scan errors; the error is raised again for the caller's
-- trap.
function Inv.ScanKind(kind, visit)
	local was = Inv.scanned
	Inv.scanned = false
	local ok, err = pcall(function()
		for _, bag in ipairs(SB.Adapter.GetBagIDs(kind)) do
			if visit then
				local prefix = bag .. ":"
				for k in pairs(Inv.newSet) do
					if k:sub(1, #prefix) == prefix then
						Inv.newSet[k] = nil
					end
				end
			end
			Inv.ScanBag(bag)
			Inv.dirty[bag] = nil
		end
	end)
	Inv.scanned = was
	if not ok then
		error(err, 0)
	end
end

-- Initial full scan (no "new" marking). Called on SB_LOGIN.
function Inv.ScanAll()
	for _, bag in ipairs(Inv.TrackedBags()) do
		Inv.ScanBag(bag)
	end
	Inv.dirty = {}
	Inv.unseen = {} -- what is in the bags at login is not new (session only)
	Inv.scanned = true
end

function Inv.GetSlot(bag, slot)
	return Inv.slots[bag] and Inv.slots[bag][slot]
end

function Inv.Size(bag)
	return Inv.sizes[bag] or 0
end

function Inv.IsNew(bag, slot)
	return Inv.newSet[key(bag, slot)] == true
end

function Inv.IsUnseen(bag, slot)
	return Inv.unseen[key(bag, slot)] ~= nil
end

-- The item's button or list row was hovered: it joins its category at the next full layout (open, Reflow);
-- nothing moves now.
function Inv.Seen(bag, slot)
	if type(bag) == "number" and type(slot) == "number" then
		Inv.unseen[key(bag, slot)] = nil
	end
end

function Inv.MarkPending(itemID)
	Inv.pending[itemID] = true
end

-- Iterate every slot of a kind ("bags" | "bank" | "warband"): bag, slot, snapshot-or-nil.
function Inv.Iterate(kind)
	local bags = SB.Adapter.GetBagIDs(kind)
	local bi, slot = 1, 0
	return function()
		while bags[bi] do
			slot = slot + 1
			if slot <= Inv.Size(bags[bi]) then
				return bags[bi], slot, Inv.GetSlot(bags[bi], slot)
			end
			bi, slot = bi + 1, 0
		end
	end
end

local function onItemLoaded(_, itemID, success)
	if not Inv.pending[itemID] then
		return
	end
	if success == false then
		return
	end
	Inv.pending[itemID] = nil
	local changes = {}
	for bag, list in pairs(Inv.slots) do
		for slot = 1, Inv.Size(bag) do
			local s = list[slot]
			if s and s.itemID == itemID then
				changes[#changes + 1] = { bag = bag, slot = slot, reasons = Inv.R.LOADED }
			end
		end
	end
	table.sort(changes, function(a, b)
		return a.bag < b.bag or (a.bag == b.bag and a.slot < b.slot)
	end)
	if #changes > 0 then
		Inv.Notify(Inv.R.LOADED, changes)
	end
end

SB.On("BAG_UPDATE", function(_, bag)
	Inv.MarkDirty(bag)
end, "bags")

SB.On("BAG_UPDATE_DELAYED", function()
	SB.Debounce("inventory.flush", Inv.DEBOUNCE, function()
		Inv.Flush("delayed")
	end, "bags")
end, "bags")

SB.On("ITEM_LOCK_CHANGED", function(_, bag, slot)
	if type(bag) ~= "number" or type(slot) ~= "number" then
		return -- equipment-slot locks have no bag slot
	end
	local s = Inv.GetSlot(bag, slot)
	if s then
		local fresh = SB.Adapter.GetSlot(bag, slot)
		s.isLocked = fresh ~= nil and fresh.isLocked or false
	end
	Inv.Notify(Inv.R.LOCK, { { bag = bag, slot = slot, reasons = Inv.R.LOCK } })
end, "bags")

SB.On("BAG_UPDATE_COOLDOWN", function()
	Inv.Notify(Inv.R.COOLDOWN, {})
end, "bags")

SB.On("ITEM_DATA_LOAD_RESULT", onItemLoaded, "bags")
SB.On("GET_ITEM_INFO_RECEIVED", onItemLoaded, "bags")

SB.On("SB_LOGIN", function()
	Inv.ScanAll()
end, "bags")

SB.On("BANKFRAME_OPENED", function()
	Inv.ScanKind("bank", true)
	Inv.ScanKind("warband", true)
end, "bank")
