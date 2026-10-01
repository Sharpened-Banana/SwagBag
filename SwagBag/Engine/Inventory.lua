-- SwagBag Inventory: live model of every container plus event coalescing (spec 9).
--   BAG_UPDATE(bag)       -> mark bag dirty (no work)
--   BAG_UPDATE_DELAYED    -> flush once, 50 ms debounce
--   failsafe              -> flush 250 ms after the first dirty mark if DELAYED never came
--   ITEM_LOCK_CHANGED     -> LOCK for that slot
--   BAG_UPDATE_COOLDOWN   -> COOLDOWN (no rescan)
--   ITEM_DATA_LOAD_RESULT / GET_ITEM_INFO_RECEIVED -> LOADED for slots holding a pending item
-- Listeners: Inventory.OnChanged(fn) with fn(mask, changes); changes = { {bag, slot, reasons} }.
-- Reasons are bit flags combined with plain arithmetic (Lua 5.1 has no bit operators).
local _, SB = ...

local Inv = {
	slots = {}, -- [bag][slot] = { itemID, link, count, isLocked } (nil = empty)
	sizes = {}, -- [bag] = number of slots
	dirty = {}, -- [bag] = true
	listeners = {},
	newSet = {}, -- ["bag:slot"] = true for items that arrived this session
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
			changes[#changes + 1] = { bag = bag, slot = slot, reasons = r }
			mask = Inv.Or(mask, r)
			if r == Inv.R.ITEM and Inv.scanned then
				Inv.newSet[key(bag, slot)] = snap ~= nil or nil
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
	for _, bag in ipairs(bags) do
		local m, changes = Inv.ScanBag(bag)
		mask = Inv.Or(mask, m)
		for _, c in ipairs(changes) do
			all[#all + 1] = c
		end
	end
	Inv.lastFlush = source
	if mask ~= 0 then
		Inv.Notify(mask, all)
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

-- Initial full scan (no "new" marking). Called on SB_LOGIN.
function Inv.ScanAll()
	for _, bag in ipairs(Inv.TrackedBags()) do
		Inv.ScanBag(bag)
	end
	Inv.dirty = {}
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

local function onItemLoaded(_, itemID)
	if not Inv.pending[itemID] then
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
