-- Week 9 (user pick 8): the stacker merges the partial stacks of an item, then moves the partial stack in
-- front of the item's full ones (for TSM posting), one move at a time, a short delay apart, out of combat,
-- never while an item is on the cursor or a slot it would touch is under the mouse (spec 4.2 rule 5), inside
-- one scope only (the bags, the character bank or the warband bank), and stops on combat or a closed window.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Core/Slash.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Locks.lua",
	"SwagBag/Engine/Mover.lua", "SwagBag/Engine/Stacker.lua",
}

describe("Stacker (week 9)", function()
	local SB, A, St, result, open, hovered
	local POTION, FLASK, JUNK = Fixtures.HEALING_POTION, Fixtures.FLASK, Fixtures.JUNK
	before_each(function()
		SB = Loader.New(FILES)
		A, St = SB.Adapter, SB.Stacker
		SB.Config.Init(nil, nil)
		Fixtures.Install(A) -- potions and flasks stack to 20, junk to 200
		A.SetBagSize(0, 8)
		result, open, hovered = nil, true, {}
	end)

	local function start(kind)
		return St.Start({ kind = kind or "bags", still = function() return open end,
			busy = function(bag, slot) return hovered[bag .. ":" .. slot] == true end,
			done = function(r) result = r end })
	end

	local function count(bag, slot)
		local s = A.GetSlot(bag, slot)
		return s and s.count or 0
	end

	-- Mutations: in St.Plan, take partial[#partial] as the target (merge onto the last one); or drop the
	-- order pass (return nil after the merges).
	it("merges an item's partial stacks one move at a time, then moves the partial in front of the full ones", function()
		A.Put(0, 1, POTION, 20)
		A.Put(0, 2, POTION, 5)
		A.Put(0, 3, FLASK, 2) -- a lone partial already first: nothing to do
		A.Put(0, 4, POTION, 8)
		assert.truthy(start())
		assert.same({ { 0, 4, 0, 2 } }, A.stackMoves, "the last partial onto the first, at once")
		assert.same({ 20, 13, 2, 0 }, { count(0, 1), count(0, 2), count(0, 3), count(0, 4) })
		A.Advance(St.DELAY)
		assert.same({ 0, 2, 0, 1 }, A.stackMoves[2], "then the partial swaps with the first full stack")
		assert.same({ 13, 20, 2, 0 }, { count(0, 1), count(0, 2), count(0, 3), count(0, 4) })
		A.Advance(St.DELAY)
		assert.equal(2, #A.stackMoves)
		assert.same({ 1, 1, 0 }, { result.merged, result.ordered, result.kept })
		assert.is_nil(result.why)
		assert.falsy(St.Busy())
	end)

	-- Item safety: an item never goes to another bank type. Mutation: in read(), take every bag and bank kind
	-- (A.GetBagIDs("bags") .. "bank" .. "warband") instead of the run's own kind.
	it("never pairs stacks across scopes: the bags, the character bank and the warband bank are stacked apart", function()
		A.bagIDs.bank, A.bagIDs.warband = { 6 }, { 12 }
		A.SetBagSize(6, 4)
		A.SetBagSize(12, 4)
		A.Put(0, 1, POTION, 5)
		A.Put(6, 1, POTION, 5)
		A.Put(12, 1, POTION, 5)
		assert.same({ false, "nothing" }, { start("bank") })
		A.Put(6, 2, POTION, 4)
		assert.truthy(start("bank"))
		A.Advance(St.DELAY * 3)
		assert.same({ { 6, 2, 6, 1 } }, A.stackMoves)
		assert.same({ 5, 9, 5 }, { count(0, 1), count(6, 1), count(12, 1) })
	end)

	-- Mutation: in stackable(), drop the leftAlone() check.
	it("leaves locked items, equipment-set items, single items and items not loaded yet where they are", function()
		SB.Locks.Toggle(POTION)
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.Put(0, 3, JUNK, 3, { inSet = true })
		A.Put(0, 4, JUNK, 4)
		A.Put(0, 5, Fixtures.BOE_RING, 1)
		A.Put(0, 6, Fixtures.BOE_RING, 1)
		A.items[FLASK].pending = true
		A.Put(0, 7, FLASK, 1)
		A.Put(0, 8, FLASK, 1)
		assert.same({ false, "nothing" }, { start() })
		assert.same({}, A.stackMoves)
		SB.Locks.Toggle(POTION)
		assert.truthy(start(), "unlocked: the potions stack")
		assert.same({ { 0, 2, 0, 1 } }, A.stackMoves)
	end)

	-- P5. Mutation: in step, drop the run.job.busy check.
	it("waits while an item is on the cursor or a slot it would touch is under the mouse, then moves", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		hovered["0:1"] = true
		start()
		assert.same({}, A.stackMoves, "the target is under the mouse")
		A.Advance(St.RETRY)
		assert.same({}, A.stackMoves)
		hovered["0:1"] = nil
		A.cursor = { itemID = 1, link = "x" }
		A.Advance(St.RETRY)
		assert.same({}, A.stackMoves, "an item on the cursor holds every step")
		A.cursor = nil
		A.Advance(St.RETRY)
		assert.same({ { 0, 2, 0, 1 } }, A.stackMoves)
	end)

	-- P5 (preflight S5). Mutation: in step, `if A.CursorBusy() then` -> `if A.CursorItem() ~= nil then`.
	it("waits while something other than an item is on the cursor (money, a spell, a merchant's item)", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.cursorOther = "money"
		assert.truthy(start())
		A.Advance(St.RETRY * (St.MAX_WAITS + 5))
		assert.same({}, A.stackMoves, "waited, however long")
		A.cursorOther = nil
		A.Advance(St.RETRY)
		assert.same({ { 0, 2, 0, 1 } }, A.stackMoves)
	end)

	-- Mutation: in step, `if run.waits <= St.MAX_WAITS` -> `if true` (the run never ends).
	it("a pair the mouse never leaves is left as it is; the run carries on with the next item", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.Put(0, 3, JUNK, 3)
		A.Put(0, 4, JUNK, 4)
		hovered["0:2"] = true
		start()
		A.Advance(St.RETRY * (St.MAX_WAITS + 1))
		assert.same({ { 0, 4, 0, 3 } }, A.stackMoves, "the junk stacks; the potions stay")
		A.Advance(St.DELAY)
		assert.same({ 0, 0, 1 }, { result.merged - 1, result.ordered, result.kept })
		assert.same({ 5, 5 }, { count(0, 1), count(0, 2) })
	end)

	-- Mutations: in step, drop the A.InCombat() check; or drop the still() check.
	it("combat or a closed window stops the run before the next move; nothing is queued", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.Put(0, 3, JUNK, 3)
		A.Put(0, 4, JUNK, 4)
		start()
		A.combat = true
		A.Advance(St.DELAY)
		assert.equal("combat", result.why)
		assert.equal(1, #A.stackMoves)
		A.combat = false
		SB.eventFrame:Fire("PLAYER_REGEN_ENABLED")
		A.Advance(5)
		assert.equal(1, #A.stackMoves, "nothing runs after combat")
		assert.equal(1, result.merged, "the move made before combat counts")
		A.onMoveStack = function() end -- a closed bank: the move in flight shows nothing
		start()
		open = false
		A.Advance(St.DELAY)
		assert.equal("closed", result.why, "said as closed, not as a move that went wrong")
		assert.equal(2, #A.stackMoves)
	end)

	-- Preflight S3: a stack the game holds locked for something else (posted at the Auction House, in the mail,
	-- in a trade) is no reason to wait or to stop. Mutation: in read(), drop `not s.isLocked and`.
	it("a stack the game holds locked for something else is left out; it never holds or stops the run", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.Put(0, 3, JUNK, 3)
		A.Put(0, 4, JUNK, 4)
		A.slots[0][3].isLocked = true -- being posted at the Auction House
		assert.truthy(start())
		A.Advance(St.DELAY * 3)
		assert.same({ { 0, 2, 0, 1 } }, A.stackMoves, "the potions merge; the locked junk is left out")
		assert.same({ 1, 0 }, { result.merged, result.ordered })
		assert.is_nil(result.why)
		assert.same({ false, "nothing" }, { start() }, "only the locked junk would stack: nothing to do")
	end)

	-- Mutations: in step, drop the pending wait (a locked slot is read at once); or drop the progressed() check.
	it("waits while the game holds a moved slot locked; a move that changes nothing stops the run", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.Put(0, 3, JUNK, 3)
		A.Put(0, 4, JUNK, 4)
		local apply = A.onMoveStack
		A.onMoveStack = function(fb, fs, tb, ts)
			A.slots[fb][fs].isLocked, A.slots[tb][ts].isLocked = true, true -- the server has not answered yet
		end
		start()
		A.Advance(St.DELAY * 3)
		assert.equal(1, #A.stackMoves, "waiting for the server")
		A.slots[0][1].isLocked, A.slots[0][2].isLocked = false, false
		apply(0, 2, 0, 1)
		A.onMoveStack = function() end -- the next move changes nothing
		A.Advance(St.DELAY)
		assert.equal(2, #A.stackMoves)
		A.Advance(St.DELAY)
		assert.same({ "stuck", 1 }, { result.why, result.merged })
		assert.equal(2, #A.stackMoves, "no third try")
	end)

	-- Final review (item 4): a lock the server never lifts does not hold the run for ever. Mutation: in step,
	-- `run.pending < St.MAX_PENDING` -> `true` (the run waits for ever, never ends).
	it("a moved slot still locked after MAX_PENDING checks stops the run as stuck", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.onMoveStack = function(fb, fs, tb, ts)
			A.slots[fb][fs].isLocked, A.slots[tb][ts].isLocked = true, true -- never answered, nothing changes
		end
		start()
		A.Advance(St.DELAY * (St.MAX_PENDING - 1))
		assert.is_nil(result, "still waiting for the server")
		A.Advance(St.DELAY * 3)
		assert.same({ "stuck", 0 }, { result and result.why, result and result.merged })
		assert.equal(1, #A.stackMoves, "no second try")
		assert.falsy(St.Busy())
	end)

	-- Mutation: in St.Start, drop the SB.Mover.Busy() check; or in Mover.Start drop the Stacker check.
	it("refuses in combat, while the mover runs, and with nothing to do; the mover waits for a run too", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		A.combat = true
		assert.same({ false, "combat" }, { start() })
		A.combat = false
		SB.Mover.run = {}
		assert.same({ false, "busy" }, { start() })
		SB.Mover.run = nil
		A.onMoveStack = function() end
		assert.truthy(start())
		assert.same({ false, "busy" }, { start() }, "one run at a time")
		assert.same({ false, "busy" }, { SB.Mover.Start({ items = { { bag = 0, slot = 1 } }, act = A.SellItem }) })
		St.Stop("closed")
		assert.equal("closed", result.why)
		A.Clear(0, 2)
		assert.same({ false, "nothing" }, { start() })
	end)

	-- P6 (preflight S8): the first step runs at the Sort click, inside the window's own trap. Mutation: in
	-- St.Start, `trapped(run)` -> `step(run)`.
	it("the first step runs in the stacker's own trap: an error is recorded, never Safe Mode, and the run ends", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		local started
		SB.ErrorTrap.Run("bags.sortButton", "bags", function()
			started = St.Start({ kind = "bags", busy = function() error("broken") end, done = function(r) result = r end })
		end)
		assert.truthy(started)
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.equal("stacker.step", SB.ErrorTrap.Recent()[1].label)
		assert.equal("error", result.why)
		assert.falsy(St.Busy(), "never left busy")
	end)

	-- Mutation: in the sort command, set sort.mode without checking Config.Set's answer.
	it("/swagbag sort says the Sort button's mode, sets stacks or blizzard, and refuses while read-only", function()
		local L = SB.L
		assert.same({ true, L.SORT_MODE_STATE:format(L.SORT_MODE_BLIZZARD) }, { SB.Slash.Run("sort") })
		assert.same({ true, L.SORT_MODE_STACKS_ON }, { SB.Slash.Run("sort stacks") })
		assert.equal("stacks", SB.Config.Get("sort.mode"))
		assert.same({ true, L.SORT_MODE_STATE:format(L.SORT_MODE_STACKS) }, { SB.Slash.Run("sort") })
		assert.same({ true, L.SORT_MODE_BLIZZARD_ON }, { SB.Slash.Run("SORT Blizzard") })
		assert.same({ true, L.SORT_MODE_USAGE }, { SB.Slash.Run("sort shuffle") })
		SB.Config.readOnly = true
		assert.same({ true, L.SETTINGS_READONLY }, { SB.Slash.Run("sort stacks") })
		assert.equal("blizzard", SB.Config.Get("sort.mode"))
	end)

	-- P2 (carried from Task 1's review). Mutation: in St.SortButton, flash without checking `ended`.
	it("the Sort button answers once: a run that ends inside Start gets its chat line and no title", function()
		A.Put(0, 1, POTION, 5)
		A.Put(0, 2, POTION, 5)
		local flashes, regrouped = {}, 0
		local ok = St.SortButton("bags", function() error("broken") end, function() return open end,
			function(text) flashes[#flashes + 1] = text end, function() regrouped = regrouped + 1 end)
		assert.truthy(ok)
		assert.same({}, flashes, "the run already answered in chat")
		assert.same({ SB.L.STACK_STOP_ERROR:format(0, 0) }, A.Lines())
		assert.equal(1, regrouped)
	end)

	it("the result line says what was merged and moved first, and why a run stopped", function()
		local L = SB.L
		assert.equal(L.STACK_DONE:format(2, 1), St.ResultText({ merged = 2, ordered = 1, kept = 0 }))
		assert.equal(L.STACK_DONE:format(0, 1) .. " " .. L.STACK_KEPT:format(1),
			St.ResultText({ merged = 0, ordered = 1, kept = 1 }))
		assert.equal(L.STACK_STOP_COMBAT:format(1, 0), St.ResultText({ merged = 1, ordered = 0, kept = 0, why = "combat" }))
		assert.equal(L.STACK_STOP_CLOSED:format(0, 0), St.ResultText({ merged = 0, ordered = 0, kept = 0, why = "closed" }))
		assert.equal(L.STACK_STOP_STUCK:format(3, 0), St.ResultText({ merged = 3, ordered = 0, kept = 0, why = "stuck" }))
	end)

	-- Final review (item 3): an error is not "did not move as expected"; it has its own line. Mutation: in
	-- St.ResultText, drop the `r.why == "error"` branch (the stuck line again).
	it("an error stop has its own line, naming the report", function()
		local L = SB.L
		assert.equal(L.STACK_STOP_ERROR:format(0, 2), St.ResultText({ merged = 0, ordered = 2, kept = 0, why = "error" }))
		assert.truthy(L.STACK_STOP_ERROR ~= L.STACK_STOP_STUCK)
	end)
end)
