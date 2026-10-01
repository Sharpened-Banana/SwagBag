local Loader = dofile("spec/helpers/loader.lua")
local Big = dofile("spec/fixtures/big.lua")

-- Small numbers keep the expected pixel positions easy to check by hand: step = 12.
local OPTS = { columns = 4, size = 10, gap = 2, padding = 1, header = 5, sectionGap = 3 }

local function S(bag, slot, cat)
	return { bag = bag, slot = slot, record = cat ~= false and { cat = cat } or nil }
end

local function assign(r)
	return r.cat
end

describe("Layout (build, position, collapse)", function()
	local SB, L
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/GridLayout.lua", "SwagBag/Engine/Layout.lua" })
		L = SB.Layout
	end)

	-- a: (0,1) (0,5)   b: (0,3)   New: (0,4) pending   Free: (0,2) (1,1)
	local function sample()
		return L.Build({ S(0, 1, "a"), S(0, 2, false), S(0, 3, "b"), S(0, 4, nil), S(0, 5, "a"), S(1, 1, false) },
			assign, { "a", "b" }, { columns = 4, newRows = 2 })
	end

	local function slotsOf(sec)
		local out = {}
		for i = 1, sec.size do
			local c = sec.cells[i]
			out[i] = c and (c.bag .. ":" .. c.slot) or "hole"
		end
		return out
	end

	it("groups slots by section in physical order; empty slots go to Free, pending items to New", function()
		local st = sample()
		assert.same({ "new", "a", "b", "free" }, st.order)
		assert.same({ "0:1", "0:5" }, slotsOf(st.sections.a))
		assert.same({ "0:3" }, slotsOf(st.sections.b))
		assert.same({ "0:4" }, slotsOf(st.sections.new))
		assert.same({ "0:2", "1:1" }, slotsOf(st.sections.free))
		assert.same({ section = "a", index = 2 }, st.where[L.Key(0, 5)])
		assert.falsy(st.needsReflow)
	end)

	it("keeps New first and Free last whatever the order says; unknown ids get a section before Free", function()
		local st = L.Build({ S(0, 1, "a"), S(0, 2, "zzz") }, assign, { "free", "b", "new", "a" }, { columns = 4 })
		assert.same({ "new", "b", "a", "zzz", "free" }, st.order)
		assert.same({ "0:2" }, slotsOf(st.sections.zzz))
	end)

	it("New reserves newRows rows even when empty, and grows to fit every pending item on a full layout", function()
		assert.equal(8, L.Build({}, assign, {}, { columns = 4, newRows = 2 }).sections.new.capacity)
		local slots = {}
		for slot = 1, 9 do
			slots[slot] = S(0, slot, nil)
		end
		assert.equal(12, L.Build(slots, assign, {}, { columns = 4, newRows = 2 }).sections.new.capacity)
	end)

	it("positions headers and cells top to bottom (y grows down as negative offsets)", function()
		local pos = L.Position(sample(), OPTS, {})
		local headers = {}
		for i, h in ipairs(pos.headers) do
			headers[i] = h.id .. "@" .. h.y .. "#" .. h.count
		end
		assert.same({ "new@-1#1", "a@-31#2", "b@-49#1", "free@-67#2" }, headers)
		assert.same({ x = 1, y = -6 }, { x = pos.byKey[L.Key(0, 4)].x, y = pos.byKey[L.Key(0, 4)].y })
		assert.same({ x = 13, y = -36 }, { x = pos.byKey[L.Key(0, 5)].x, y = pos.byKey[L.Key(0, 5)].y })
		assert.same({ x = 13, y = -72 }, { x = pos.byKey[L.Key(1, 1)].x, y = pos.byKey[L.Key(1, 1)].y })
		assert.equal(48, pos.width)
		assert.equal(86, pos.height)
		assert.equal(6, #pos.cells)
	end)

	it("collapsing hides a section and re-stacks the ones below; expanding returns every item to its cell", function()
		local st = sample()
		local open = L.Position(st, OPTS, {})
		local closed = L.Position(st, OPTS, { a = true })
		assert.falsy(closed.byKey[L.Key(0, 1)].shown)
		assert.truthy(closed.headers[2].collapsed)
		assert.equal(-39, closed.headers[3].y, "b moved up by a's row")
		assert.equal(open.height - 10, closed.height)
		assert.same(open, L.Position(st, OPTS, {}))
	end)

	it("a collapsed New keeps only its header", function()
		local pos = L.Position(sample(), OPTS, { new = true })
		assert.equal(-1, pos.headers[1].y)
		assert.equal(-9, pos.headers[2].y, "a follows right after New's header")
	end)

	it("Moves lists the buttons a re-stack would move, show or hide", function()
		local st = sample()
		local open = L.Position(st, OPTS, {})
		local closed = L.Position(st, OPTS, { a = true })
		assert.same({ L.Key(0, 1), L.Key(0, 2), L.Key(0, 3), L.Key(0, 5), L.Key(1, 1) }, L.Moves(open, closed))
		assert.same({}, L.Moves(open, L.Position(st, OPTS, {})))
	end)

	it("the scroll offset is clamped when a collapse makes the content shorter (spec 4.4)", function()
		local st = sample()
		local view = 40
		local offset = SB.GridLayout.ClampOffset(46, L.Position(st, OPTS, {}).height, view)
		assert.equal(46, offset)
		offset = SB.GridLayout.ClampOffset(offset, L.Position(st, OPTS, { a = true, free = true }).height, view)
		assert.equal(26, offset)
	end)

	it("builds and positions the 1,290-slot fixture in under 20 ms of plain Lua", function()
		local ids = { "c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9", "c10", "c11", "c12", "c13", "c14", "c15", "c16" }
		local function cat(n) -- every 5th slot empty, every 23rd pending, the rest spread over 16 sections
			if n % 5 == 0 then
				return false
			elseif n % 23 == 0 then
				return nil
			end
			return ids[n % #ids + 1]
		end
		local slots, n = {}, 0
		for _, b in ipairs(Big.BAGS) do
			for slot = 1, b[2] do
				n = n + 1
				slots[n] = S(b[1], slot, cat(n))
			end
		end
		assert.equal(Big.SLOTS, n)
		local t0 = os.clock()
		local st = L.Build(slots, assign, ids, { columns = 12, newRows = 2 })
		local pos = L.Position(st, { columns = 12, size = 37, gap = 4, padding = 4, header = 20, sectionGap = 6 }, {})
		local ms = (os.clock() - t0) * 1000
		assert.equal(n, #pos.cells)
		assert.equal(45, st.sections.new.size)
		assert.truthy(ms < 20, ("%.2f ms"):format(ms))
	end)

	-- Extra tests (Task 6 dispatch): the big fixture, pending contract, determinism.
	local function bigSlots()
		local ids = { "c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9", "c10", "c11", "c12", "c13", "c14", "c15", "c16" }
		local slots, n = {}, 0
		for _, b in ipairs(Big.BAGS) do
			for slot = 1, b[2] do
				n = n + 1
				local cat = ids[n % #ids + 1]
				if n % 5 == 0 then
					cat = false
				elseif n % 23 == 0 then
					cat = nil
				end
				slots[n] = S(b[1], slot, cat)
			end
		end
		return slots, ids
	end

	it("big fixture: collapsing then expanding every section returns each item to exactly the same cell", function()
		local slots, ids = bigSlots()
		local st = L.Build(slots, assign, ids, { columns = 12, newRows = 2 })
		local o = { columns = 12, size = 37, gap = 4, padding = 4, header = 20, sectionGap = 6 }
		local before = L.Position(st, o, {})
		local all = { new = true, free = true }
		for _, id in ipairs(ids) do
			all[id] = true
		end
		local closed = L.Position(st, o, all)
		assert.truthy(closed.height < before.height)
		for _, c in ipairs(closed.cells) do
			assert.falsy(c.shown)
		end
		for key, c in pairs(before.byKey) do -- collapse never moves a cell inside its section
			assert.equal(c.x, closed.byKey[key].x)
		end
		local one = L.Position(st, o, { c3 = true, c9 = true })
		assert.truthy(one.height < before.height)
		local after = L.Position(st, o, {})
		assert.same(before, after)
		for key, c in pairs(before.byKey) do
			local a = after.byKey[key]
			assert.equal(c.x, a.x)
			assert.equal(c.y, a.y)
			assert.truthy(a.shown)
		end
	end)

	it("pending items (assign returns nil, 'pending') go to New; empty slots go to Free", function()
		local slots = { S(0, 1, "a"), S(0, 2, "p"), S(0, 3, false) }
		local st = L.Build(slots, function(r)
			if r.cat == "p" then
				return nil, "pending"
			end
			return r.cat
		end, { "a" }, { columns = 4, newRows = 2 })
		assert.same({ section = "new", index = 1 }, st.where[L.Key(0, 2)])
		assert.same({ section = "free", index = 1 }, st.where[L.Key(0, 3)])
		assert.same({ section = "a", index = 1 }, st.where[L.Key(0, 1)])
	end)

	it("is deterministic: the same input gives identical state and positions", function()
		local slots, ids = bigSlots()
		local o = { columns = 12, size = 37, gap = 4, padding = 4, header = 20, sectionGap = 6 }
		local a = L.Build(slots, assign, ids, { columns = 12, newRows = 2 })
		local b = L.Build(slots, assign, ids, { columns = 12, newRows = 2 })
		assert.same(a, b)
		assert.same(L.Position(a, o, { c2 = true }), L.Position(b, o, { c2 = true }))
	end)

	it("big fixture: Moves is sorted and only lists buttons whose cell or visibility changes", function()
		local slots, ids = bigSlots()
		local st = L.Build(slots, assign, ids, { columns = 12, newRows = 2 })
		local o = { columns = 12, size = 37, gap = 4, padding = 4, header = 20, sectionGap = 6 }
		local moves = L.Moves(L.Position(st, o, {}), L.Position(st, o, { c4 = true }))
		assert.truthy(#moves > 0)
		for i = 2, #moves do
			assert.truthy(moves[i - 1] < moves[i])
		end
		assert.same({}, L.Moves(L.Position(st, o, {}), L.Position(st, o, {})))
	end)
end)
