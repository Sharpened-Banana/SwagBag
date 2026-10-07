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
-- was secret when it came arrives when it becomes readable. Session only: the login scan and a /reload mark nothing.
-- Hotfix 0.11.1 (the user's `New (133)` after a fresh client start): what is in the bags when the player gets
-- control is never unseen, whenever the client fills them in.
--   The settle: from the login scan, and from every PLAYER_ENTERING_WORLD (login, /reload, a loading screen),
--   until SETTLE_QUIET seconds pass with no flush (at most SETTLE_MAX after the world loaded), a flush updates the
--   model without anything arriving: slots that read empty and fill again are not loot. An unseen item that reads
--   empty and comes back during the settle stays unseen (the settle's carry pool).
--   A secret slot (Adapter.SlotIsSecret: an item whose ID is a secret value) is not empty: it keeps its last known
--   item, so it changes nothing when it reads again with that item. What it holds when it reads is an arrival
--   only if the slot's item was known when it went secret ("known"); a slot already secret at a login scan or
--   during a settle ("base") holds what was there before.
--   A secret slot that reads empty during the settle keeps its marker until the settle ends (a loading screen can
--   blank it for a moment). The `new` keyword (newSet) carries through a settle like New does.
--   Outside a settle, a flush that would bring in FLOOD_MIN stacks or more, and more than half the stacks in the
--   bags, is late login data (a cold client can be slower than the settle): nothing in it arrives.
--   A bag whose size first reads (0 before) holds nothing that arrived: a bag can be put on only when empty, so its
--   contents are the client's late data. A bag size that reads 0 while the bag holds items is unreadable (a bag
--   with items cannot be taken off): the bag keeps its items.
-- The bags window puts unseen items in New at every full layout,
-- whatever the focus mode (UI/BagsWindow.lua). Blizzard's own new-item flag is not used: SwagBag clears it
-- when the bags close (W4-15), so it cannot carry an item to the next open.
--   Inv.IsUnseen(bag, slot) -> bool;  Inv.Seen(bag, slot);  Inv.SeenAll() -> n (/swagbag new seen)
-- 0.13.2 diagnostics (the New flood after a vendor visit; the cause is not known yet): Inv.newLog keeps the last
-- NEW_LOG_MAX entries, session only, for /swagbag report (Core/Report.lua). It only watches: nothing in it changes
-- what arrives. Counts only, written at a flush with NEW_LOG_CHANGES or more item changes in the bags or
-- NEW_LOG_ARRIVALS or more arrivals, at a settle's start and end, and at a rescan of a kind (Inv.ScanKind):
--   { kind = "flush", at, source, settling, left, came, arrivals, marked, stacks, guarded,
--     revealed = { known, base }, fresh, bags = { bag IDs, ascending }, secret }
--   { kind = "settle", at, phase = "start" | "end", world, reason = "login" | "world" | "quiet" | "cap" | "login cap" }
--   { kind = "scankind", at, scanned = kind, changes = item changes in the bags }
-- `at` is seconds since the login scan (Inv.loginAt), to 0.1 s. A flush that marks NEW_HINT_MIN stacks or more
-- prints NEW_FLOOD_HINT once per session, on the next frame.
local _, SB = ...

local Inv = {
	slots = {}, -- [bag][slot] = { itemID, link, count, isLocked } (nil = empty)
	sizes = {}, -- [bag] = number of slots
	dirty = {}, -- [bag] = true
	listeners = {},
	newSet = {}, -- ["bag:slot"] = true for items that arrived this session
	unseen = {}, -- ["bag:slot"] = itemID: bags items that arrived and were not hovered yet (see the header)
	pending = {}, -- [itemID] = true while waiting for item data
	hidden = {}, -- ["bag:slot"] = "known" | "base": the slot's item ID reads secret (see the header)
	heldEmpty = {}, -- ["bag:slot"] = true: a hidden slot read empty during the settle; its marker waits
	settling = false, -- true during the settle (see the header)
	settleCarry = {}, -- [itemID] = n: unseen stacks that read empty during the settle and may come back
	settleNewCarry = {}, -- [itemID] = n: the same for the `new` keyword (newSet)
	scanned = false,
	failsafeArmed = false,
	DEBOUNCE = 0.05,
	FAILSAFE = 0.25,
	SETTLE_QUIET = 3, -- seconds with no flush that end the settle once the world is loaded
	SETTLE_MAX = 15, -- the settle ends at most this long after PLAYER_ENTERING_WORLD
	SETTLE_LOGIN_MAX = 120, -- and at most this long after the login scan if the world never loads
	FLOOD_MIN = 20, -- outside a settle, a flush bringing in at least this many stacks, more than half the bags, is
	-- the client's late data, not loot (see the header)
	newLog = {}, -- 0.13.2 diagnostics (see the header)
	NEW_LOG_MAX = 10,
	NEW_LOG_CHANGES = 5,
	NEW_LOG_ARRIVALS = 3,
	NEW_HINT_MIN = 20,
	floodHinted = false,
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

-- The New log (see the header): a ring of the last NEW_LOG_MAX entries.
local function logNew(entry)
	local now = SB.Adapter.Now()
	entry.at = math.floor((now - (Inv.loginAt or now)) * 10 + 0.5) / 10
	local log = Inv.newLog
	log[#log + 1] = entry
	while #log > Inv.NEW_LOG_MAX do
		table.remove(log, 1)
	end
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

local function isBagsBag(bag)
	for _, id in ipairs(SB.Adapter.GetBagIDs("bags")) do
		if id == bag then
			return true
		end
	end
	return false
end

-- Can this change bring an item into the bags (see the header)? Not a bag's first contents, not what a slot held
-- since a login scan or a settle, and during the settle only what came while a known slot was secret.
local function canArrive(c)
	if c.fresh or c.revealed == "base" then
		return false
	end
	return not Inv.settling or c.revealed == "known"
end

-- Rescan one bag. Returns mask, changes.
function Inv.ScanBag(bag)
	local A = SB.Adapter
	local size = A.NumSlots(bag)
	local oldSize = Inv.sizes[bag] or 0
	local old = Inv.slots[bag] or {}
	if size == 0 and oldSize > 0 and next(old) ~= nil and isBagsBag(bag) then
		return 0, {} -- unreadable now: a bag with items in it cannot be taken off (see the header)
	end
	local fresh = oldSize == 0 and size > 0 and Inv.scanned and isBagsBag(bag) or nil
	local new, changes = {}, {}
	local mask = size ~= oldSize and Inv.R.SIZE or 0
	for slot = 1, math.max(size, oldSize) do
		local k = key(bag, slot)
		local snap, secret = nil, false
		if slot <= size then
			snap = snapshot(bag, slot)
			secret = snap == nil and A.SlotIsSecret(bag, slot)
		end
		local revealed
		if secret then -- not empty: keep the last known item (see the header)
			snap = old[slot]
			Inv.heldEmpty[k] = nil
			if Inv.hidden[k] == nil then
				Inv.hidden[k] = (Inv.scanned and not Inv.settling) and "known" or "base"
			end
		elseif snap == nil and Inv.settling and Inv.hidden[k] then
			Inv.heldEmpty[k] = true -- an empty read in a loading screen: the marker waits (forgotten when it ends)
		else
			revealed = Inv.hidden[k]
			Inv.hidden[k], Inv.heldEmpty[k] = nil, nil
		end
		new[slot] = snap
		local r = Inv.DiffSlot(old[slot], snap)
		if r ~= 0 then
			local change = { bag = bag, slot = slot, reasons = r, fresh = fresh, revealed = revealed }
			changes[#changes + 1] = change
			mask = Inv.Or(mask, r)
			if r == Inv.R.ITEM then -- whatever was unseen (or new) here left (Flush carries it if it only moved)
				change.wasUnseen = Inv.unseen[k]
				Inv.unseen[k] = nil
				change.wasNew = Inv.newSet[k] and old[slot] and old[slot].itemID or nil
			end
			if r == Inv.R.ITEM and Inv.scanned then
				if snap == nil then -- the item left: the client's own flag for the slot goes too (W4-15)
					Inv.newSet[k] = nil
					A.ClearNewItem(bag, slot)
				else -- a new stack here: new if it came (or moved), not if it is the client's late data
					Inv.newSet[k] = canArrive(change) or nil
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

local function stacks(set)
	local n = 0
	for bag in pairs(set) do
		for slot = 1, Inv.Size(bag) do
			if Inv.GetSlot(bag, slot) then
				n = n + 1
			end
		end
	end
	return n
end

-- During the settle, a stack that comes back after reading empty is still new (the `new` keyword), like New.
local function carryNew(changes)
	local pool = Inv.settleNewCarry
	for _, c in ipairs(changes) do
		if c.wasNew then
			pool[c.wasNew] = (pool[c.wasNew] or 0) + 1
		end
	end
	for _, c in ipairs(changes) do
		local k, s = key(c.bag, c.slot), c.reasons == Inv.R.ITEM and Inv.GetSlot(c.bag, c.slot)
		if s and not Inv.newSet[k] and (pool[s.itemID] or 0) > 0 then
			pool[s.itemID] = pool[s.itemID] - 1
			Inv.newSet[k] = true
		end
	end
end

-- After a flush: a bags slot that gained a stack is unseen when the bags now hold more of the item than before
-- (it came from outside), or when an unseen stack of the item left a slot in the same flush (it only moved).
-- During the settle, the carry pools last from flush to flush (see the header). Outside it, a flush that would
-- bring in FLOOD_MIN stacks or more, and more than half the stacks now in the bags, is the client's late login
-- data: nothing in it arrives (a mailbox Take-All or a vendor spree never fills half the bags).
-- Returns, for the New log: the number of arrivals, how many keys it added to Inv.unseen, and whether the flood
-- guard fired.
local function markUnseen(changes, set, before)
	local marked = 0
	local after = totals(set)
	local carried = Inv.settling and Inv.settleCarry or {}
	for _, c in ipairs(changes) do
		if c.wasUnseen then
			carried[c.wasUnseen] = (carried[c.wasUnseen] or 0) + 1
		end
	end
	local arrivals = {}
	for _, c in ipairs(changes) do
		local s = c.reasons == Inv.R.ITEM and set[c.bag] and Inv.GetSlot(c.bag, c.slot)
		if s then
			local id = s.itemID
			if canArrive(c) and (after[id] or 0) > (before[id] or 0) then
				arrivals[#arrivals + 1] = c
			elseif (carried[id] or 0) > 0 then
				carried[id] = carried[id] - 1
				local k = key(c.bag, c.slot)
				if Inv.unseen[k] == nil then
					marked = marked + 1
				end
				Inv.unseen[k] = id
			end
		end
	end
	if not Inv.settling and #arrivals >= Inv.FLOOD_MIN and #arrivals * 2 > stacks(set) then
		for _, c in ipairs(changes) do
			if c.reasons == Inv.R.ITEM then
				Inv.newSet[key(c.bag, c.slot)] = nil
			end
		end
		return #arrivals, marked, true
	end
	for _, c in ipairs(arrivals) do
		local k = key(c.bag, c.slot)
		if Inv.unseen[k] == nil then
			marked = marked + 1
		end
		Inv.unseen[k] = Inv.GetSlot(c.bag, c.slot).itemID
	end
	if Inv.settling then
		carryNew(changes)
	end
	return #arrivals, marked, false
end

-- The New log's flush entry (see the header): counts only, and nothing unless the flush was a big one.
local function logFlush(changes, set, source, arrivals, marked, guarded)
	local left, came, fresh, bagSeen = 0, 0, 0, {}
	local revealed = { known = 0, base = 0 }
	for _, c in ipairs(changes) do
		if set[c.bag] then
			if c.reasons == Inv.R.ITEM then
				if Inv.GetSlot(c.bag, c.slot) == nil then
					left = left + 1
				else
					came = came + 1
				end
				bagSeen[c.bag] = true
			end
			if c.revealed then
				revealed[c.revealed] = (revealed[c.revealed] or 0) + 1
			end
			if c.fresh then
				fresh = fresh + 1
			end
		end
	end
	if left + came < Inv.NEW_LOG_CHANGES and arrivals < Inv.NEW_LOG_ARRIVALS then
		return
	end
	local bags = {}
	for bag in pairs(bagSeen) do
		bags[#bags + 1] = bag
	end
	table.sort(bags)
	local secret = 0
	for _ in pairs(Inv.hidden) do
		secret = secret + 1
	end
	logNew({ kind = "flush", source = source, settling = Inv.settling, left = left, came = came, arrivals = arrivals,
		marked = marked, stacks = stacks(set), guarded = guarded, revealed = revealed, fresh = fresh, bags = bags,
		secret = secret })
end

-- A flush that marked NEW_HINT_MIN stacks or more: one chat hint per session, on the next frame (see the header).
local function floodHint(marked)
	if marked < Inv.NEW_HINT_MIN or Inv.floodHinted then
		return
	end
	Inv.floodHinted = true
	SB.Adapter.After(0, function()
		SB.ErrorTrap.Run("inventory.floodhint", "bags", function()
			SB.Print(SB.L.NEW_FLOOD_HINT:format(marked))
		end)
	end)
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
	if Inv.settling and Inv.settleUntil and SB.Adapter.Now() >= Inv.settleUntil then
		Inv.EndSettle(Inv.worldLoaded and "cap" or "login cap") -- the cap (see Inv.Settle)
	end
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
		local arrivals, marked, guarded = markUnseen(all, set, before)
		logFlush(all, set, source, arrivals, marked, guarded)
		floodHint(marked)
	else
		logFlush(all, set, source, 0, 0, false)
	end
	if Inv.settling and Inv.worldLoaded then
		Inv.Quiet() -- the bags are still filling: the settle waits for them to be quiet
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
	local itemChanges = 0
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
			local _, changes = Inv.ScanBag(bag)
			if isBagsBag(bag) then -- the log (see the header): a rescan of the banks should change no bags slot
				for _, c in ipairs(changes) do
					if c.reasons == Inv.R.ITEM then
						itemChanges = itemChanges + 1
					end
				end
			end
			Inv.dirty[bag] = nil
		end
	end)
	Inv.scanned = was
	logNew({ kind = "scankind", scanned = kind, changes = itemChanges })
	if not ok then
		error(err, 0)
	end
end

-- The settle (see the header). Inv.Settle(false) starts it at the login scan: it lasts until the world loads (at
-- most SETTLE_LOGIN_MAX). Inv.Settle(true) at every PLAYER_ENTERING_WORLD: it lasts until SETTLE_QUIET seconds pass
-- with no flush (each flush waits again), at most SETTLE_MAX. The caps are checked by the clock at a flush, so no
-- timer is left waiting once the settle is over.
local settleGen = 0

-- reason: for the New log ("quiet" when omitted).
function Inv.EndSettle(reason)
	logNew({ kind = "settle", phase = "end", world = Inv.worldLoaded, reason = reason or "quiet" })
	Inv.settling, Inv.settleUntil = false, nil
	Inv.settleCarry, Inv.settleNewCarry = {}, {}
	for k in pairs(Inv.heldEmpty) do -- still empty after the loading screen: the slot is empty
		Inv.hidden[k] = nil
	end
	Inv.heldEmpty = {}
	settleGen = settleGen + 1
end

function Inv.Quiet()
	settleGen = settleGen + 1
	local gen = settleGen
	SB.Adapter.After(Inv.SETTLE_QUIET, function()
		SB.ErrorTrap.Run("inventory.settle", "bags", function()
			if gen == settleGen then
				Inv.EndSettle()
			end
		end)
	end)
end

function Inv.Settle(worldLoaded)
	if not Inv.settling then
		Inv.settleCarry, Inv.settleNewCarry = {}, {}
	end
	Inv.settling, Inv.worldLoaded = true, worldLoaded == true
	logNew({ kind = "settle", phase = "start", world = Inv.worldLoaded, reason = worldLoaded and "world" or "login" })
	Inv.settleUntil = SB.Adapter.Now() + (worldLoaded and Inv.SETTLE_MAX or Inv.SETTLE_LOGIN_MAX)
	if worldLoaded then
		Inv.Quiet()
	else
		settleGen = settleGen + 1 -- before the world loads, a quiet timer from an earlier settle ends nothing
	end
end

-- Initial full scan (no "new" marking). Called on SB_LOGIN; the settle starts here.
function Inv.ScanAll()
	Inv.loginAt = SB.Adapter.Now() -- the New log's clock (see the header)
	Inv.Settle(false)
	Inv.hidden, Inv.heldEmpty = {}, {}
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

-- /swagbag new seen (UI/BagsWindow.lua): every unseen bags item is seen, the bags' `new` keyword is cleared and so
-- is the client's own flag. Returns how many items were unseen. The open bags window regroups at its next layout.
function Inv.SeenAll()
	local n = 0
	for _ in pairs(Inv.unseen) do
		n = n + 1
	end
	Inv.unseen = {}
	local set = bagsSet()
	for k in pairs(Inv.newSet) do
		if set[tonumber(k:match("^(-?%d+):"))] then
			Inv.newSet[k] = nil
		end
	end
	SB.Adapter.ClearNewItems(SB.Adapter.GetBagIDs("bags"))
	return n
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

-- Login, /reload, or any loading screen: the bags may read empty or secret for a moment and fill again.
SB.On("PLAYER_ENTERING_WORLD", function()
	if Inv.scanned then
		Inv.Settle(true)
	end
end, "bags")

SB.On("BANKFRAME_OPENED", function()
	Inv.ScanKind("bank", true)
	Inv.ScanKind("warband", true)
end, "bank")
