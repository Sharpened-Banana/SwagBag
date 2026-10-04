-- SwagBag stacker (week 9, user pick 8): "partial stacks first", for TSM posting. Blizzard's own sort
-- (Adapter.SortBags / SortBank) takes no options, so this is SwagBag's own run, one move at a time:
--   1. merge: while an item has two partial stacks, the last one goes onto the first (Adapter.MoveStack: a
--      click on the stack and a click on the target, as a player does it; what does not fit stays);
--   2. order: an item's one partial stack swaps with the item's first full stack, so it comes first.
-- Nothing else moves. Only one scope at a time: the bags (bags and reagent bag), the character bank or the
-- warband bank (Adapter.GetBagIDs(kind)); a move only ever lands on a stack of the same item in the same
-- scope, so an item never changes bank type. Left as they are: items the user locked (Engine/Locks.lua),
-- equipment-set items, items that do not stack, items whose data has not loaded, and a secret link.
--   Stacker.Start(job) -> true | false, why   why: "busy" (this or the mover runs) | "combat" | "nothing"
--     job = { kind = "bags" | "bank" | "warband",
--             still = fn() -> bool         false once the window or the bank closed: the run stops
--             busy = fn(bag, slot) -> bool  the slot's button (or its list row) is under the mouse
--             done = fn(result) }          result = { merged = n, ordered = n, kept = n,
--                                           why = nil | "combat" | "closed" | "stuck" | "error" }
--   Stacker.Busy() -> bool;  Stacker.Stop(why);  Stacker.Plan(kind, skip, maxOf) -> the next move | nil
--   Stacker.ResultText(result) -> the one chat line for a finished run
-- A run's end is also announced as SB_STACKER_DONE(result) (a vendor opened meanwhile sells then: Vendor.lua).
-- Every step first stops the run on combat (nothing is queued; P5) or once still() says no, before anything
-- else is judged, so a closed bank reads "closed". Then: never while anything is on the cursor
-- (Adapter.CursorBusy: it waits RETRY, however long), and a pair whose slot is under the mouse waits RETRY up
-- to MAX_WAITS times, then that item is left as it is. After a move the next step waits while the game holds
-- either of that move's two slots locked (the server has not answered, up to MAX_PENDING), then checks the
-- move did what it should; one that changed nothing stops the run ("stuck"). A stack the game holds locked for
-- another reason (being posted at the Auction House, mailed or traded) is left out of the run. Each step plans
-- again from the slots as they are, so an item used or moved by hand meanwhile is simply read as it is now.
-- Every step runs in its own "none" trap (the first one too, not the Sort click's): an error is recorded,
-- never Safe Mode, and ends the run with its own line (STACK_STOP_ERROR, not the "stuck" one). No OnUpdate.
local _, SB = ...

local L = SB.L
local St = { DELAY = 0.2, RETRY = 0.3, MAX_WAITS = 20, MAX_PENDING = 10, run = nil }
SB.Stacker = St

function St.Busy()
	return St.run ~= nil
end

-- The slot must stay where it is: locked by the user, or part of an equipment set.
local function leftAlone(s)
	return (SB.Locks ~= nil and SB.Locks.Has(s.itemID)) or SB.Adapter.InEquipmentSet(s.bag, s.slot)
end

-- How many of the item make a full stack; nil when it does not stack or must stay.
local function stackable(s, maxOf)
	local A = SB.Adapter
	if type(s.link) ~= "string" or A.IsSecret(s.link) or leftAlone(s) then
		return nil
	end
	local max = maxOf[s.itemID]
	if max == nil then
		local info = A.GetItemInfo(s.itemID)
		max = info and type(info.maxStack) == "number" and not A.IsSecret(info.maxStack) and info.maxStack or false
		maxOf[s.itemID] = max
	end
	return max and max > 1 and max or nil
end

-- The stackable items of a scope, grouped by link, in slot order (bag IDs, then slots). A slot the game holds
-- locked (an auction being posted, a letter, a trade, or this run's own move not answered yet) is left out.
local function read(kind, skip, maxOf)
	local A = SB.Adapter
	local groups, order = {}, {}
	for _, bag in ipairs(A.GetBagIDs(kind)) do
		for slot = 1, A.NumSlots(bag) do
			local s = A.GetSlot(bag, slot)
			local max = s and not s.isLocked and stackable(s, maxOf)
			if max and not skip[s.link] then
				local g = groups[s.link]
				if not g then
					g = { max = max, list = {} }
					groups[s.link] = g
					order[#order + 1] = s.link
				end
				g.list[#g.list + 1] = s
			end
		end
	end
	return groups, order
end

function St.Plan(kind, skip, maxOf)
	local groups, order = read(kind, skip or {}, maxOf or {})
	for _, key in ipairs(order) do
		local g, partial = groups[key], {}
		for _, s in ipairs(g.list) do
			if s.count < g.max then
				partial[#partial + 1] = s
			end
		end
		if #partial >= 2 then
			return { what = "merge", key = key, from = partial[#partial], to = partial[1] }
		end
	end
	for _, key in ipairs(order) do
		local g = groups[key]
		local first = g.list[1]
		if first.count >= g.max then
			for _, s in ipairs(g.list) do
				if s.count < g.max then
					return { what = "order", key = key, from = s, to = first }
				end
			end
		end
	end
	return nil
end

local function finish(run, why)
	if St.run ~= run then
		return
	end
	St.run = nil
	run.result.why = why
	if run.job.done then
		SB.ErrorTrap.Run("stacker.done", "none", run.job.done, run.result)
	end
	SB.Emit("SB_STACKER_DONE", run.result)
end

local step

-- One step in its own trap (P6): an error is recorded under "none" and ends the run with its line, so the
-- stacker never stays busy (and the mover blocked) after one.
local function trapped(run)
	if not SB.ErrorTrap.Run("stacker.step", "none", step, run) then
		finish(run, "error")
	end
end

local function later(run, seconds)
	SB.Adapter.After(seconds, function()
		trapped(run)
	end)
end

-- Did the move do what it should? A merge: the target holds more of the item. An order: the target (the
-- item's first slot) now holds the partial stack's count.
local function progressed(m)
	local t = SB.Adapter.GetSlot(m.to.bag, m.to.slot)
	if not t or t.link ~= m.key then
		return false
	end
	if m.what == "merge" then
		return t.count > m.to.count
	end
	return t.count == m.from.count
end

local function lockedSlot(m)
	local A = SB.Adapter
	local t, f = A.GetSlot(m.to.bag, m.to.slot), A.GetSlot(m.from.bag, m.from.slot)
	return (t ~= nil and t.isLocked) or (f ~= nil and f.isLocked)
end

local function count(run, m)
	if m.what == "merge" then
		run.result.merged = run.result.merged + 1
	else
		run.result.ordered = run.result.ordered + 1
	end
end

step = function(run)
	if St.run ~= run then
		return
	end
	local A = SB.Adapter
	local m = run.sent
	-- Combat or a closed window first: the run stops before the last move is judged (a closed bank's slots may
	-- read empty); that move still counts when it shows.
	local stop
	if run.job.still and not run.job.still() then
		stop = "closed"
	elseif A.InCombat() then
		stop = "combat"
	end
	if stop then
		if m and progressed(m) then
			count(run, m)
		end
		return finish(run, stop)
	end
	if m then
		if lockedSlot(m) and run.pending < St.MAX_PENDING then
			run.pending = run.pending + 1
			return later(run, St.DELAY)
		end
		run.sent, run.pending = nil, 0
		if not progressed(m) then
			return finish(run, "stuck")
		end
		count(run, m)
	end
	if A.CursorBusy() then
		return later(run, St.RETRY) -- the user is moving something by hand: wait, however long it takes
	end
	local nextMove = St.Plan(run.kind, run.skip, run.maxOf)
	if not nextMove then
		return finish(run, nil)
	end
	local busy = run.job.busy
	if busy and (busy(nextMove.from.bag, nextMove.from.slot) or busy(nextMove.to.bag, nextMove.to.slot)) then
		run.waits = run.waits + 1
		if run.waits <= St.MAX_WAITS then
			return later(run, St.RETRY)
		end
		run.waits = 0
		run.skip[nextMove.key] = true -- the mouse never left it: this item stays as it is
		run.result.kept = run.result.kept + 1
		return step(run)
	end
	run.waits = 0
	local ok, err = A.MoveStack(nextMove.from.bag, nextMove.from.slot, nextMove.to.bag, nextMove.to.slot)
	if not ok then
		if err ~= nil then
			SB.ErrorTrap.OnError("stacker.move", "none", tostring(err), A.Stack())
		end
		return finish(run, "error")
	end
	run.sent = nextMove
	return later(run, St.DELAY)
end

function St.Start(job)
	if St.run or (SB.Mover and SB.Mover.Busy()) then
		return false, "busy"
	end
	if SB.Adapter.InCombat() then
		return false, "combat"
	end
	local maxOf = {}
	if not St.Plan(job.kind, {}, maxOf) then
		return false, "nothing"
	end
	local run = { job = job, kind = job.kind, skip = {}, maxOf = maxOf, waits = 0, pending = 0,
		result = { merged = 0, ordered = 0, kept = 0 } }
	St.run = run
	trapped(run) -- the first step too runs in the stacker's own trap, not the Sort click's
	return true
end

function St.Stop(why)
	if St.run then
		finish(St.run, why or "closed")
	end
end

-- The Sort buttons' run (week 9; UI/BagsWindow.lua and UI/BankWindow.lua share it, with sort.mode "stacks"):
-- starts a run for that scope; the click's one answer goes to flash(text) (the window's title: "Stacking...",
-- or why it cannot start); when the run ends its one chat line is printed, then regroup(). A run that ends
-- inside Start (its one answer is the chat line already) gets no title. -> ok
function St.SortButton(kind, busy, still, flash, regroup)
	local ended = false
	local ok, why = St.Start({ kind = kind, busy = busy, still = still, done = function(result)
		ended = true
		SB.Print(St.ResultText(result))
		regroup()
	end })
	if not ended then
		flash(ok and L.STACK_STARTED or (why == "busy" and L.MOVER_BUSY) or L.STACK_NOTHING)
	end
	return ok
end

-- /swagbag sort                    what the Sort buttons do
-- /swagbag sort stacks|blizzard    partial stacks first (SwagBag's stacker) | Blizzard's own sort
SB.Slash.Register("sort", L.HELP_SORT, function(arg)
	arg = (arg or ""):lower()
	if arg == "" then
		return L.SORT_MODE_STATE:format(SB.Config.Get("sort.mode") == "stacks" and L.SORT_MODE_STACKS or L.SORT_MODE_BLIZZARD)
	elseif arg ~= "stacks" and arg ~= "blizzard" then
		return L.SORT_MODE_USAGE
	end
	if not SB.Config.Set("sort.mode", arg) then
		return L.SETTINGS_READONLY
	end
	return arg == "stacks" and L.SORT_MODE_STACKS_ON or L.SORT_MODE_BLIZZARD_ON
end)

function St.ResultText(r)
	if r.why == "combat" then
		return L.STACK_STOP_COMBAT:format(r.merged, r.ordered)
	elseif r.why == "closed" then
		return L.STACK_STOP_CLOSED:format(r.merged, r.ordered)
	elseif r.why == "error" then
		return L.STACK_STOP_ERROR:format(r.merged, r.ordered) -- final review item 3: not the "did not move" line
	elseif r.why ~= nil then
		return L.STACK_STOP_STUCK:format(r.merged, r.ordered)
	end
	local text = L.STACK_DONE:format(r.merged, r.ordered)
	if r.kept > 0 then
		text = text .. " " .. L.STACK_KEPT:format(r.kept)
	end
	return text
end
