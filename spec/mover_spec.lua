-- Week 7 (user picks 4 and 6): the mover sells or banks a list of items one at a time, a short delay
-- apart, out of combat, never while an item is on the cursor or the item's button is under the mouse
-- (spec 4.2 rule 5), and stops when the vendor or bank closes or the target refuses an item.
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Inventory.lua", "SwagBag/Engine/Mover.lua",
}

describe("Mover (week 7)", function()
	local SB, A, Mover, result, open, hovered
	before_each(function()
		SB = Loader.New(FILES)
		A, Mover = SB.Adapter, SB.Mover
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A) -- 1 potion x5, 2 flask x2, 3 BoE ring, 4 helm, 5 keystone, 6 junk x3
		result, open, hovered = nil, true, {}
		SB.BagsWindow = { IsOpen = function() return true end, ButtonBusy = function(bag, slot)
			return hovered[bag .. ":" .. slot] == true
		end }
	end)

	local function items(...)
		local out = {}
		for i, slot in ipairs({ ... }) do
			local s = A.GetSlot(0, slot)
			out[i] = { bag = 0, slot = slot, itemID = s.itemID, link = s.link, count = s.count }
		end
		return out
	end

	local function start(list)
		return Mover.Start({ items = list, act = A.SellItem, still = function() return open end, done = function(r)
			result = r
		end })
	end

	local function usedSlots()
		local out = {}
		for i, u in ipairs(A.used) do
			out[i] = u.slot
		end
		return out
	end

	-- Mutation: in step, call `step(run)` instead of `later(run, Mover.DELAY)` after a move (all at once).
	it("moves one item per DELAY, in order, then reports what moved", function()
		assert.truthy(start(items(1, 2, 6)))
		assert.same({ 1 }, usedSlots(), "the first at once")
		A.Advance(Mover.DELAY)
		assert.same({ 1, 2 }, usedSlots())
		A.Advance(Mover.DELAY * 2)
		assert.same({ 1, 2, 6 }, usedSlots())
		assert.same({ 3, 0, nil }, { #result.moved, result.left, result.why })
		assert.falsy(Mover.Busy())
	end)

	-- P5. Mutation: in step, drop the Mover.IsBusy check.
	it("waits while an item is on the cursor or the item's button is under the mouse, then moves it", function()
		hovered["0:1"] = true
		start(items(1, 2))
		assert.same({}, usedSlots(), "the hovered potion waits")
		A.Advance(Mover.RETRY)
		assert.same({}, usedSlots())
		hovered["0:1"] = nil
		A.cursor = { itemID = 1, link = "x" }
		A.Advance(Mover.RETRY)
		assert.same({}, usedSlots(), "an item on the cursor holds every step")
		A.cursor = nil
		A.Advance(Mover.RETRY)
		assert.same({ 1 }, usedSlots())
	end)

	-- Week 9 (preflight S5): GetCursorInfo answers more than items. Mutation: in step, `if A.CursorBusy() then`
	-- -> `if A.CursorItem() ~= nil then`.
	it("waits while anything else is on the cursor too (money, a spell, a merchant's item), however long", function()
		A.cursorOther = "merchant"
		start(items(1))
		A.Advance(Mover.RETRY * (Mover.MAX_WAITS + 5))
		assert.same({}, usedSlots(), "waited")
		A.cursorOther = nil
		A.Advance(Mover.RETRY)
		assert.same({ 1 }, usedSlots())
	end)

	-- Mutation: in step, `if run.waits <= Mover.MAX_WAITS` -> `if true` (the run never ends). An item on the
	-- cursor is waited for without a limit (the vendor closing ends the run).
	it("an item the mouse never leaves stays where it is; the run goes on with the next", function()
		hovered["0:1"] = true
		start(items(1, 2))
		A.Advance(Mover.RETRY * (Mover.MAX_WAITS + 1))
		A.Advance(Mover.DELAY * 2)
		assert.same({ 2 }, usedSlots())
		assert.same({ 1, 1 }, { #result.moved, result.kept })
		assert.equal(1, result.left, "kept items count as left")
		A.cursor = { itemID = 1, link = "x" }
		start(items(6))
		A.Advance(Mover.RETRY * (Mover.MAX_WAITS + 5))
		assert.same({ 2 }, usedSlots(), "still waiting for the cursor")
		A.cursor = nil
		A.Advance(Mover.RETRY)
		assert.same({ 2, 6 }, usedSlots())
	end)

	-- Mutations: drop the A.InCombat() check in step; or drop the still() check.
	it("combat stops the run (nothing queued); a vendor or bank that closes stops it too", function()
		start(items(1, 2, 6))
		A.combat = true
		A.Advance(Mover.DELAY)
		assert.same({ 1 }, usedSlots())
		assert.same({ "combat", 1, 2 }, { result.why, #result.moved, result.left })
		A.combat = false
		start(items(2, 6))
		open = false
		A.Advance(Mover.DELAY)
		assert.same({ "closed", 1, 1 }, { result.why, #result.moved, result.left })
		A.combat = true
		assert.same({ false, "combat" }, { start(items(6)) }, "nothing starts in combat")
	end)

	-- Mutation: in step, drop the `if not same(item)` skip (the wrong item would be sold).
	it("a slot that no longer holds the item is skipped, never acted on", function()
		local list = items(1, 2)
		A.Put(0, 1, Fixtures.HERB, 20) -- the potion was used up and a herb took its slot
		start(list)
		A.Advance(Mover.DELAY)
		assert.same({ 2 }, usedSlots())
		assert.same({ 1, 1 }, { #result.moved, result.skipped })
	end)

	-- Mutation: in step, treat an item still there as moved (drop the `elseif there` branch).
	it("waits while the client holds a sent item; an item still there and free means refused: the run stops", function()
		A.onUse = function(bag, slot)
			A.slots[bag][slot].isLocked = true -- sent: the server has not answered yet
		end
		start(items(1, 2))
		A.Advance(Mover.DELAY * 2)
		assert.same({ 1 }, usedSlots(), "waits for the answer")
		A.slots[0][1].isLocked = false -- the target refused it (a full bank tab)
		A.Advance(Mover.DELAY)
		assert.same({ "stuck", 0, 2 }, { result.why, #result.moved, result.left })
	end)

	-- Mutation: Mover.Start does not check Mover.run.
	it("one run at a time; an empty list starts nothing", function()
		A.onUse = function() end -- nothing leaves: the first step waits
		hovered["0:1"] = true
		assert.truthy(start(items(1)))
		assert.same({ false, "busy" }, { start(items(2)) })
		Mover.Stop()
		assert.same({ false, "empty" }, { start({}) })
	end)

	-- Ruling R8: once the last item has gone the run is done, even if the vendor closes (or combat starts) in
	-- the 0.2 s before the step that sees it. Mutation: in step, `if not item then` -> `if not item and
	-- run.job.still() then` (the closing would be reported, with 0 stayed).
	it("a run whose last item moved ends as done, even if the window closes right after", function()
		start(items(1))
		open = false
		A.Advance(Mover.DELAY)
		assert.same({ true, 1, 0 }, { result.why == nil, #result.moved, result.left })
	end)

	-- Rulings R2 and R20: right before each move the job looks at the slot once more (job.ready): a window
	-- that closed stops the run, an item that may no longer move (locked or put in a set since the list was
	-- made) is skipped. Mutations: in step, `if verdict == "closed" then` -> `if false then`; or
	-- `elseif verdict ~= true then` -> `elseif false then`.
	it("right before each move the job checks again: closed stops the run, an item it refuses is skipped", function()
		local verdicts = { [1] = "skip", [2] = true, [6] = "closed" }
		Mover.Start({ items = items(1, 2, 6), act = A.SellItem, still = function() return true end,
			ready = function(item) return verdicts[item.slot] end, done = function(r)
				result = r
			end })
		A.Advance(Mover.DELAY * 3)
		assert.same({ 2 }, usedSlots())
		assert.same({ "closed", 1, 1, 1 }, { result.why, #result.moved, result.skipped, result.left })
	end)
end)
