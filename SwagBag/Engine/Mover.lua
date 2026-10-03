-- SwagBag mover (week 7): moves a list of bag items one at a time, a short delay apart. The auto-sell
-- (Engine/Vendor.lua) and the section actions (UI/SectionActions.lua) use it. One run at a time.
--   Mover.Start(job) -> true | false, why   why: "busy" (a run is going) | "combat" | "empty"
--     job = { items = { { bag, slot, itemID, link, count } },
--             act = fn(bag, slot) -> ok, err    the move itself (an Adapter call)
--             ready = fn(item) -> true | "skip" | "closed"   optional, asked right before each act: the
--                                              job's last look at the slot (rulings R2, R20)
--             still = fn() -> bool             false once the vendor or bank closed: the run stops
--             done = fn(result) }              result = { moved = { item... }, left = n, skipped = n,
--                                              kept = n, why = nil | "combat" | "closed" | "stuck" | "error" }
--   Mover.Busy() -> bool
--   Mover.IsBusy(bag, slot) -> bool   spec 4.2 rule 5: an item is on the cursor, or that slot's button is
--                                     under the mouse in the open bags window
-- Each step runs out of combat only (combat stops the run: nothing is queued) and only while still()
-- says yes. The slot must still hold the same item (item ID and link), else it is skipped: it was used
-- or moved by hand. P5: while an item is on the cursor every step waits RETRY and tries again (for as long
-- as the vendor or bank stays open); while the item's own button is under the mouse it waits the same way
-- MAX_WAITS times, then that item is left where it is. Right before the move the job's ready() looks at the
-- slot once more: "closed" stops the run, "skip" leaves that item (locked or put in a set since the list was
-- made). After a move the next step first checks the item really left:
-- while the client holds it locked (the server has not answered) the run waits; an item still there
-- and unlocked means the target refused it (a full bank, a vendor that will not buy it): the run stops
-- ("stuck"). Once the last item has gone the run is done, whatever happens next (ruling R8). left counts
-- the items not reached and the ones kept under the mouse; skipped ones are not counted as left.
-- No OnUpdate: every wait is an Adapter.After timer.
local _, SB = ...

local Mover = { DELAY = 0.2, RETRY = 0.3, MAX_WAITS = 20, MAX_PENDING = 10, run = nil }
SB.Mover = Mover

function Mover.Busy()
	return Mover.run ~= nil
end

function Mover.IsBusy(bag, slot)
	if SB.Adapter.CursorItem() ~= nil then
		return true
	end
	local W = SB.BagsWindow
	return W ~= nil and W.IsOpen ~= nil and W.IsOpen() and W.ButtonBusy ~= nil and W.ButtonBusy(bag, slot) == true
end

local function same(item)
	local s = SB.Adapter.GetSlot(item.bag, item.slot)
	return s ~= nil and s.itemID == item.itemID and s.link == item.link, s
end

local function finish(run, why)
	if Mover.run ~= run then
		return
	end
	Mover.run = nil
	run.result.why = why
	run.result.left = #run.items - run.index + 1 + run.result.kept -- not reached, or kept under the mouse
	if run.job.done then
		SB.ErrorTrap.Run("mover.done", "none", run.job.done, run.result)
	end
end

local step

local function later(run, seconds)
	SB.Adapter.After(seconds, SB.ErrorTrap.Guard("mover.step", function()
		step(run)
	end, "none"))
end

local function skip(run)
	run.index, run.waits = run.index + 1, 0
	run.result.skipped = run.result.skipped + 1
	return step(run)
end

step = function(run)
	if Mover.run ~= run then
		return
	end
	local A = SB.Adapter
	-- The previous move: wait while the server has not answered; stop if the target refused it.
	local last = run.sent
	if last then
		local there, s = same(last)
		if there and s.isLocked and run.pending < Mover.MAX_PENDING then
			run.pending = run.pending + 1
			return later(run, Mover.DELAY)
		elseif there then
			run.index = run.index - 1 -- that item is still in the bags: count it as left
			local closed = run.job.still and not run.job.still()
			return finish(run, closed and "closed" or "stuck")
		end
		run.result.moved[#run.result.moved + 1] = last
		run.sent, run.pending = nil, 0
	end
	local item = run.items[run.index]
	if not item then
		return finish(run, nil) -- the last item has gone: done, even if the window closes now (R8)
	end
	if run.job.still and not run.job.still() then
		return finish(run, "closed")
	end
	if A.InCombat() then
		return finish(run, "combat")
	end
	if not same(item) then
		return skip(run) -- used or moved by hand: nothing to do
	end
	if A.CursorItem() ~= nil then
		return later(run, Mover.RETRY) -- the user is moving an item by hand: wait, however long it takes
	end
	if Mover.IsBusy(item.bag, item.slot) then
		run.waits = run.waits + 1
		if run.waits <= Mover.MAX_WAITS then
			return later(run, Mover.RETRY)
		end
		run.index, run.waits = run.index + 1, 0 -- the mouse never left it: it stays
		run.result.kept = run.result.kept + 1
		return step(run)
	end
	-- The job's last look, right before the call (R2, R20): still open? may this item still move?
	local verdict = true
	if run.job.ready then
		verdict = run.job.ready(item)
	end
	if verdict == "closed" then
		return finish(run, "closed")
	elseif verdict ~= true then
		return skip(run) -- locked, put in a set, or otherwise no longer to move since the list was made
	end
	local ok, err = run.job.act(item.bag, item.slot)
	run.index, run.waits = run.index + 1, 0
	if not ok then
		if err ~= nil then
			SB.ErrorTrap.OnError("mover.act", "none", tostring(err), A.Stack())
		end
		run.index = run.index - 1
		return finish(run, "error")
	end
	run.sent = item
	return later(run, Mover.DELAY)
end

function Mover.Start(job)
	if Mover.run then
		return false, "busy"
	end
	if SB.Adapter.InCombat() then
		return false, "combat"
	end
	if not job.items or #job.items == 0 then
		return false, "empty"
	end
	local run = { job = job, items = job.items, index = 1, waits = 0, pending = 0,
		result = { moved = {}, skipped = 0, kept = 0, left = 0 } }
	Mover.run = run
	step(run)
	return true
end

-- Combat or a /reload ends nothing by itself: the next step sees combat and stops (P5, no queue).
function Mover.Stop(why)
	local run = Mover.run
	if run then
		finish(run, why or "closed")
	end
end
