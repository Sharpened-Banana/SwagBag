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

	it("opts.top shifts every header and cell down by top, and the height includes it", function()
		local opts = {}
		for k, val in pairs(OPTS) do
			opts[k] = val
		end
		opts.top = 100
		local base, shifted = L.Position(sample(), OPTS, {}), L.Position(sample(), opts, {})
		for i, h in ipairs(base.headers) do
			assert.equal(h.y - 100, shifted.headers[i].y)
		end
		for k, c in pairs(base.byKey) do
			assert.same({ c.x, c.y - 100 }, { shifted.byKey[k].x, shifted.byKey[k].y })
		end
		assert.equal(base.height + 100, shifted.height)
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

	it("builds and positions the 1,290-slot fixture in under 20 ms of plain Lua (spec 11.1)", function()
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

describe("Layout.Apply (spec 4.3: what happens while the window is open)", function()
	local SB, L, st
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/Layout.lua" })
		L = SB.Layout
		-- a: (0,1) (0,5)   b: (0,3)   New: (0,4) [capacity 8]   Free: (0,2) (1,1)
		st = L.Build({ S(0, 1, "a"), S(0, 2, false), S(0, 3, "b"), S(0, 4, nil), S(0, 5, "a"), S(1, 1, false) },
			assign, { "a", "b" }, { columns = 4, newRows = 2 })
	end)

	local function where(bag, slot)
		local w = st.where[L.Key(bag, slot)]
		return w and (w.section .. "#" .. w.index)
	end

	local function change(bag, slot, kind, icon)
		return { bag = bag, slot = slot, kind = kind, icon = icon }
	end

	it("an item leaving a category section leaves a placeholder with its icon; the button goes to Free", function()
		local r = L.Apply(st, { change(0, 1, "left", 111) })
		local ph = st.sections.a.cells[1]
		assert.same({ bag = 0, slot = 1, placeholder = true, icon = 111 }, ph)
		assert.equal("free#3", where(0, 1))
		assert.same({ L.Key(0, 1) }, r.moved)
		assert.equal(1, r.placeholders)
		assert.truthy(st.needsReflow)
		local pos = L.Position(st, OPTS, {})
		assert.same({ 1, -36 }, { pos.placeholders[1].x, pos.placeholders[1].y }, "placeholder sits where the button was")
		assert.same({ 25, -72 }, { pos.byKey[L.Key(0, 1)].x, pos.byKey[L.Key(0, 1)].y }, "button is Free's 3rd cell")
		assert.equal(1, pos.headers[2].count, "a now counts one item")
	end)

	it("an item leaving a button that is in Free or New only repaints", function()
		local r = L.Apply(st, { change(0, 4, "left"), change(0, 2, "left") })
		assert.equal("new#1", where(0, 4))
		assert.equal("free#1", where(0, 2))
		assert.same({}, r.moved)
		assert.falsy(st.needsReflow)
	end)

	it("a different item arriving in a category section leaves a placeholder; the button goes to New", function()
		L.Apply(st, { change(0, 3, "arrived", 333) })
		assert.truthy(st.sections.b.cells[1].placeholder)
		assert.equal(333, st.sections.b.cells[1].icon)
		assert.equal("new#2", where(0, 3))
	end)

	it("an item arriving in a Free slot moves its button to New and leaves a hole: nothing else shifts", function()
		local before = L.Position(st, OPTS, {})
		L.Apply(st, { change(0, 2, "arrived") })
		assert.equal("new#2", where(0, 2))
		assert.is_nil(st.sections.free.cells[1])
		local after = L.Position(st, OPTS, {})
		assert.same({ L.Key(0, 2) }, L.Moves(before, after))
	end)

	it("an item arriving in a button already in New only repaints", function()
		local r = L.Apply(st, { change(0, 4, "arrived") })
		assert.equal("new#1", where(0, 4))
		assert.same({}, r.moved)
	end)

	it("when New's two rows are full, arrivals go to the end of Free and New's header says how many", function()
		local slots = { S(0, 1, nil) }
		for slot = 2, 12 do
			slots[slot] = S(0, slot, "a")
		end
		slots[13] = S(0, 13, false)
		st = L.Build(slots, assign, { "a" }, { columns = 4, newRows = 2 })
		local changes = {}
		for slot = 2, 10 do
			changes[#changes + 1] = change(0, slot, "arrived")
		end
		changes[#changes + 1] = change(0, 13, "arrived") -- already in Free: stays, counted
		local r = L.Apply(st, changes)
		assert.equal(8, st.sections.new.size)
		assert.equal("new#8", where(0, 8))
		assert.equal("free#2", where(0, 9))
		assert.equal("free#3", where(0, 10))
		assert.equal("free#1", where(0, 13))
		assert.equal(3, r.overflowed)
		assert.equal(3, L.Position(st, OPTS, {}).headers[1].overflow)
	end)

	it("with New collapsed, arrivals go to the end of Free instead of disappearing", function()
		L.Apply(st, { change(0, 3, "arrived") }, nil, { new = true })
		assert.equal("free#3", where(0, 3))
		assert.equal(1, st.sections.new.overflow)
	end)

	it("an overflowed arrival that later finds room in New stops counting as overflow (I1)", function()
		L.Apply(st, { change(0, 3, "arrived") }, nil, { new = true })
		assert.equal("free#3", where(0, 3))
		assert.equal(1, st.sections.new.overflow)
		L.Apply(st, { change(0, 3, "arrived") }, nil, {}) -- New expanded again
		assert.equal(0, st.sections.new.overflow)
		assert.truthy(where(0, 3):match("^new#"), "the slot is in New")
	end)

	it("a bag that grows adds its new slots at the end of Free; a removed slot leaves a hole", function()
		L.Apply(st, { change(2, 1, "added"), change(2, 2, "added"), change(1, 1, "removed") })
		assert.equal("free#3", where(2, 1))
		assert.equal("free#4", where(2, 2))
		assert.is_nil(where(1, 1))
		assert.is_nil(st.sections.free.cells[2])
		assert.truthy(st.needsReflow)
	end)

	it("a button under the cursor does not move: its changes wait, in order, for the next Apply", function()
		local hovered = true
		local function busy(bag, slot)
			return hovered and bag == 0 and slot == 1
		end
		local r = L.Apply(st, { change(0, 1, "left", 111), change(0, 5, "left", 555) }, busy)
		assert.equal(1, r.deferred)
		assert.equal("a#1", where(0, 1))
		assert.equal("free#3", where(0, 5), "other buttons are not held back")
		r = L.Apply(st, { change(0, 1, "arrived", 112) }, busy)
		assert.equal(2, r.deferred, "a later change of a held slot waits behind it")
		hovered = false
		r = L.Apply(st, {}, busy)
		assert.equal(0, r.deferred)
		assert.truthy(st.sections.a.cells[1].placeholder)
		assert.equal(111, st.sections.a.cells[1].icon)
		assert.equal("new#2", where(0, 1), "left then arrived: Free, then New")
	end)

	it("an item on the cursor holds every move", function()
		local r = L.Apply(st, { change(0, 1, "left"), change(0, 3, "arrived") }, function() return true end)
		assert.equal(2, r.deferred)
		assert.same({}, r.moved)
		assert.falsy(st.needsReflow)
	end)

	it("the next full layout has no placeholders and clears needsReflow", function()
		L.Apply(st, { change(0, 1, "left") })
		st = L.Build({ S(0, 1, false), S(0, 2, false), S(0, 3, "b"), S(0, 4, nil), S(0, 5, "a") }, assign, { "a", "b" },
			{ columns = 4 })
		assert.falsy(st.needsReflow)
		assert.same({}, L.Position(st, OPTS, {}).placeholders)
	end)

	it("New's +N more count follows the slots that overflowed: a slot that leaves stops counting, a repeat is not counted twice", function()
		local slots = { S(0, 1, nil) }
		for slot = 2, 12 do
			slots[slot] = S(0, slot, "a")
		end
		st = L.Build(slots, assign, { "a" }, { columns = 4, newRows = 2 })
		local changes = {}
		for slot = 2, 11 do
			changes[#changes + 1] = change(0, slot, "arrived")
		end
		local r = L.Apply(st, changes) -- 7 fit in New (cells 2-8), slots 9, 10, 11 overflow
		assert.equal(3, r.overflowed)
		assert.equal(3, st.sections.new.overflow)
		r = L.Apply(st, { change(0, 10, "arrived") }) -- same slot again
		assert.equal(0, r.overflowed)
		assert.equal(3, st.sections.new.overflow)
		L.Apply(st, { change(0, 11, "removed") })
		assert.equal(2, st.sections.new.overflow)
		L.Apply(st, { change(0, 9, "left") })
		assert.equal(1, st.sections.new.overflow)
		assert.equal(1, L.Position(st, OPTS, {}).headers[1].overflow)
	end)

	it("a bag that grows (added only) sets needsReflow", function()
		assert.falsy(st.needsReflow)
		L.Apply(st, { change(2, 1, "added") })
		assert.truthy(st.needsReflow)
	end)

	it("section truth: random swaps, returns, batches, overflow and hover holds never put a wrong item in a section", function()
		local totals = { leavePh = 0, toNew = 0, overflowed = 0, swaps = 0, deferrals = 0, leaves = 0 }
		for seedNo = 1, 24 do
			local content, built, slots = {}, {}, {}
			for slot = 1, 20 do
				content[slot] = slot % 4 ~= 0 and slot or nil
				built[slot] = content[slot]
				slots[slot] = { bag = 0, slot = slot, record = content[slot] and { cat = "c" .. (content[slot] % 3) } or nil }
			end
			st = L.Build(slots, assign, { "c0", "c1", "c2" }, { columns = 4, newRows = 2 })
			local headerY = {}
			for _, h in ipairs(L.Position(st, OPTS, {}).headers) do
				headerY[h.id] = h.y
			end
			local seed = seedNo * 7919
			local function rand(n)
				seed = (seed * 1103515245 + 12345) % 2147483648
				return math.floor(seed / 65536) % n + 1
			end
			local nextItem = 100
			local function occupied()
				for _ = 1, 30 do
					local slot = rand(20)
					if content[slot] ~= nil then
						return slot
					end
				end
			end
			local function leave()
				local slot = occupied()
				if not slot then
					return nil
				end
				content[slot] = nil
				totals.leaves = totals.leaves + 1
				return change(0, slot, "left", 1000 + slot)
			end
			local function arrive(slot)
				nextItem = nextItem + 1
				content[slot] = nextItem
				return change(0, slot, "arrived", nextItem)
			end
			local function ret()
				for _ = 1, 30 do
					local slot = rand(20)
					if content[slot] == nil and built[slot] ~= nil then
						content[slot] = built[slot]
						return change(0, slot, "arrived", built[slot])
					end
				end
			end
			local function one()
				local k = rand(4)
				if k == 1 then
					return leave()
				elseif k == 2 then
					return ret()
				end
				return arrive(rand(20))
			end

			local function checkInvariants(label)
				-- invariant 1: every (bag, slot) is placed exactly once
				local seen, count = {}, 0
				for id, sec in pairs(st.sections) do
					for i = 1, sec.size do
						local c = sec.cells[i]
						if c and not c.placeholder then
							local key = L.Key(c.bag, c.slot)
							assert.falsy(seen[key], label .. ": button placed twice")
							seen[key] = true
							count = count + 1
							assert.same({ section = id, index = i }, st.where[key])
						end
					end
				end
				assert.equal(20, count, label .. ": a button was lost")
				local held = {}
				for _, ch in ipairs(st.deferred) do
					held[ch.slot] = true
				end
				-- invariant 2: a shown button in a category section shows that section's item, or is a placeholder
				local pos = L.Position(st, OPTS, {})
				for _, cell in ipairs(pos.cells) do
					local w = st.where[L.Key(cell.bag, cell.slot)]
					if w.section ~= "new" and w.section ~= "free" and not held[cell.slot] then
						assert.truthy(cell.shown)
						assert.equal(built[cell.slot], content[cell.slot], label .. ": wrong item in section " .. w.section)
					end
				end
				for id, sec in pairs(st.sections) do
					if id ~= "new" and id ~= "free" then
						for i = 1, sec.size do
							local c = sec.cells[i]
							assert.truthy(c and (c.placeholder or held[c.slot] or built[c.slot] == content[c.slot]),
								label .. ": hole or wrong item in " .. id)
						end
					end
				end
				for _, h in ipairs(pos.headers) do
					assert.equal(headerY[h.id], h.y, label .. ": header " .. h.id .. " moved")
				end
				local n = 0
				for _ in pairs(st.sections.new.overflowKeys or {}) do
					n = n + 1
				end
				assert.equal(n, st.sections.new.overflow)
			end

			for step = 1, 400 do
				local changes = {}
				local kind = rand(10)
				local swapped = false
				if kind <= 3 then
					changes[1] = leave()
				elseif kind <= 5 then
					changes[1] = arrive(rand(20))
				elseif kind <= 7 then
					local a, b = occupied(), occupied()
					if a and b and a ~= b and content[a] ~= content[b] then
						content[a], content[b] = content[b], content[a]
						changes[1] = change(0, a, "arrived", content[a])
						changes[2] = change(0, b, "arrived", content[b])
						swapped = true
					end
				elseif kind == 8 then
					changes[1] = ret()
				else
					for _ = 1, rand(4) + 1 do
						changes[#changes + 1] = one()
					end
				end
				local before = {}
				for k, w in pairs(st.where) do
					before[k] = w.section .. "#" .. w.index
				end
				local holdSet
				if rand(3) == 1 then
					holdSet = {}
					for _ = 1, rand(5) do
						holdSet[rand(20)] = true
					end
				end
				local r = L.Apply(st, changes, holdSet and function(_, slot)
					return holdSet[slot] == true
				end or nil)
				if swapped then
					totals.swaps = totals.swaps + 1
				end
				if r.deferred > 0 then
					totals.deferrals = totals.deferrals + 1
				end
				totals.overflowed = totals.overflowed + r.overflowed
				if #changes == 1 and changes[1].kind == "left" then
					totals.leavePh = totals.leavePh + r.placeholders
				end
				for k, w in pairs(st.where) do
					if before[k] and before[k]:sub(1, 4) == "free" and w.section == "new" then
						totals.toNew = totals.toNew + 1
					end
				end
				local moved = {}
				for _, k in ipairs(r.moved) do
					moved[k] = true
				end
				for k, w in pairs(st.where) do
					if not moved[k] then
						assert.equal(before[k], w.section .. "#" .. w.index, "a button moved that was not changed")
					end
				end
				checkInvariants(("seed %d step %d"):format(seedNo, step))
			end
			local r = L.Apply(st, {}, nil) -- drain: nothing is held now
			assert.equal(0, r.deferred)
			assert.same({}, st.deferred)
			checkInvariants(("seed %d drained"):format(seedNo))
		end
		assert.truthy(totals.leaves > 0, "no leave events happened")
		assert.truthy(totals.leavePh > 0, "no placeholder was made by a leave")
		assert.truthy(totals.toNew > 0, "nothing arrived in a Free slot")
		assert.truthy(totals.overflowed > 0, "New never overflowed")
		assert.truthy(totals.swaps > 0, "no swaps")
		assert.truthy(totals.deferrals > 0, "the hover guard never held anything")
	end)
end)

describe("Layout free tile (plan D19)", function()
	local SB, L
	before_each(function()
		SB = Loader.New({ "SwagBag/Engine/Layout.lua" })
		L = SB.Layout
	end)

	local function family(bag)
		return bag == 5 and "reagent" or "any"
	end

	-- a: (0,1) (0,4)   empty "any": (0,2) (0,3) (0,5) (1,1) (1,2)   empty "reagent": (5,1) (5,2)
	-- New holds one row of 4.
	local function build()
		return L.Build({ S(0, 1, "a"), S(0, 2, false), S(0, 3, false), S(0, 4, "a"), S(0, 5, false), S(1, 1, false),
			S(1, 2, false), S(5, 1, false), S(5, 2, false) }, assign, { "a" },
			{ columns = 4, newRows = 1, freeTile = true, family = family })
	end

	local function change(bag, slot, kind, icon)
		return { bag = bag, slot = slot, kind = kind, icon = icon }
	end

	-- "bag:slot=count" for every shown tile, in display order.
	local function tiles(pos)
		local out = {}
		for _, t in ipairs(pos.tiles) do
			if t.shown then
				out[#out + 1] = t.bag .. ":" .. t.slot .. "=" .. t.count
			end
		end
		return out
	end

	local function xy(pos, bag, slot)
		local c = pos.byKey[L.Key(bag, slot)]
		return { c.x, c.y, c.shown }
	end

	it("Build: Free holds the first empty slot of each family as its tile; the other empty slots are hidden spares",
		function()
			local st = build()
			local pos = L.Position(st, OPTS, {})
			assert.same({ "0:2=5", "5:1=2" }, tiles(pos))
			assert.same({ section = "free", index = 1 }, st.where[L.Key(0, 2)])
			assert.same({ section = "free", spare = "any" }, st.where[L.Key(0, 3)])
			assert.same({ L.Key(0, 3), L.Key(0, 5), L.Key(1, 1), L.Key(1, 2) }, st.tiles.spares.any)
			assert.same({ L.Key(5, 2) }, st.tiles.spares.reagent)
			for _, k in ipairs({ L.Key(0, 3), L.Key(0, 5), L.Key(1, 1), L.Key(1, 2), L.Key(5, 2) }) do
				assert.same({ false, nil }, { pos.byKey[k].shown, pos.byKey[k].x }, "a spare is hidden and has no cell")
			end
			assert.equal(7, pos.headers[#pos.headers].count, "Free's header counts every free slot")
			assert.equal(9, #pos.cells, "every slot is in the view (search still sees the spares)")
		end)

	-- Mutation: `return { key }` instead of `return { key, tile and promote(...) or nil }` at the end of
	-- applyTile (the tile leaves and nothing takes its cell).
	it("when the tile fills it goes to New and the next empty button takes the same cell, its count one lower",
		function()
			local st = build()
			local old = L.Position(st, OPTS, {})
			local r = L.Apply(st, { change(0, 2, "arrived", 7) })
			local pos = L.Position(st, OPTS, {})
			assert.same({ L.Key(0, 2), L.Key(0, 3) }, r.moved)
			assert.equal("new", st.where[L.Key(0, 2)].section)
			assert.same(xy(old, 0, 2), xy(pos, 0, 3), "the next empty button is in the tile's cell")
			assert.same({ "0:3=4", "5:1=2" }, tiles(pos))
			assert.same({ L.Key(0, 2), L.Key(0, 3) }, L.Moves(old, pos), "the swap is a move of both buttons")
		end)

	-- Mutation: `if held[key] or (isBusy and isBusy(ch.bag, ch.slot)) then` in Apply (no partner check):
	-- the swap's second half fails. Mutation: drop the isBusy check entirely: every half fails.
	it("a busy tile is not swapped: under the mouse, with an item on the cursor, or while the next spare is busy",
		function()
			local st = build()
			local old = L.Position(st, OPTS, {})
			for _, busy in ipairs({
				function(bag, slot) return bag == 0 and slot == 2 end, -- the mouse is on the tile
				function() return true end, -- an item is on the cursor
				function(bag, slot) return bag == 0 and slot == 3 end, -- the button that would take the cell
			}) do
				local r = L.Apply(st, { change(0, 2, "arrived", 7) }, busy)
				assert.same({}, r.moved)
				assert.equal(1, r.deferred)
				assert.same(old, L.Position(st, OPTS, {}), "nothing moved")
				st.deferred = {}
			end
			L.Apply(st, { change(0, 2, "arrived", 7) }, function(bag, slot) return bag == 0 and slot == 2 end)
			local r = L.Apply(st, {}, nil) -- 300 ms later the mouse has left
			assert.same({ L.Key(0, 2), L.Key(0, 3) }, r.moved)
			assert.same(xy(old, 0, 2), xy(L.Position(st, OPTS, {}), 0, 3))
		end)

	-- Mutation: in applyTile's "left" branch, `append(st, Layout.FREE, cell)` instead of
	-- `Layout.ToFamily(st, key, cell)`: the emptied button shows as a second empty slot in Free.
	it("an emptied button becomes a hidden spare and the count goes up; nothing else moves", function()
		local st = build()
		local old = L.Position(st, OPTS, {})
		local r = L.Apply(st, { change(0, 1, "left", 77) })
		local pos = L.Position(st, OPTS, {})
		assert.equal(1, r.placeholders)
		assert.same({ L.Key(0, 1) }, L.Moves(old, pos), "only the emptied button (it is hidden now)")
		assert.same({ false, nil }, { pos.byKey[L.Key(0, 1)].shown, pos.byKey[L.Key(0, 1)].x })
		assert.same({ "0:2=6", "5:1=2" }, tiles(pos))
		-- an item that arrives and leaves again in New: the button goes back to the spares
		L.Apply(st, { change(1, 1, "arrived", 8) })
		assert.equal("new", st.where[L.Key(1, 1)].section)
		L.Apply(st, { change(1, 1, "left", 8) })
		assert.same({ section = "free", spare = "any" }, st.where[L.Key(1, 1)])
		assert.same({ "0:2=6", "5:1=2" }, tiles(L.Position(st, OPTS, {})))
	end)

	it("a family with no free slot has no tile; its next empty slot comes back in the same cell", function()
		local st = build()
		local cell = xy(L.Position(st, OPTS, {}), 5, 1)
		L.Apply(st, { change(5, 1, "arrived", 9), change(5, 2, "arrived", 10) })
		assert.same({ "0:2=5" }, tiles(L.Position(st, OPTS, {})))
		L.Apply(st, { change(5, 1, "left", 9) })
		local pos = L.Position(st, OPTS, {})
		assert.same({ "0:2=5", "5:1=1" }, tiles(pos))
		assert.same(cell, xy(pos, 5, 1))
	end)

	it("an item looted into a hidden slot goes to New; the tile stays where it is, its count one lower", function()
		local st = build()
		local old = L.Position(st, OPTS, {})
		local r = L.Apply(st, { change(1, 2, "arrived", 11) })
		local pos = L.Position(st, OPTS, {})
		assert.same({ L.Key(1, 2) }, r.moved)
		assert.same({ L.Key(1, 2) }, L.Moves(old, pos))
		assert.same({ "0:2=4", "5:1=2" }, tiles(pos))
	end)

	it("with New full, a filled tile stays where it is and the next spare is the tile at Free's end", function()
		local st = build()
		L.Apply(st, { change(0, 3, "arrived", 1), change(0, 5, "arrived", 2), change(1, 1, "arrived", 3),
			change(1, 2, "arrived", 4) })
		local old = L.Position(st, OPTS, {})
		local r = L.Apply(st, { change(5, 1, "arrived", 5) })
		local pos = L.Position(st, OPTS, {})
		assert.same({ L.Key(5, 2) }, r.moved, "only the next spare moves (it is shown)")
		assert.same(xy(old, 5, 1), xy(pos, 5, 1), "the filled tile did not move")
		assert.same({ "0:2=1", "5:2=1" }, tiles(pos))
		assert.equal(1, st.sections.new.overflow)
	end)

	-- W3-21: a herb bag that holds its family's tile is taken off (or swapped) while the window is
	-- open. BagFamily already answers for the new bag before the old slots are "removed", so the
	-- layout must use the family each slot had when it joined. Mutation: in isTile, use the live
	-- `st.tiles.family(bagOf(key))` instead of the stored family: no spare takes the tile's cell
	-- and bag 3's free slots stay hidden with no tile.
	it("a bag taken off whose family changed first: the tile still hands its cell to the next spare (W3-21)",
		function()
			local fam = { [0] = "any", [2] = "family8", [3] = "family8" }
			local st = L.Build({ S(0, 1, "a"), S(0, 2, false), S(2, 1, false), S(2, 2, false), S(2, 3, false),
				S(3, 1, false), S(3, 2, false) }, assign, { "a" },
				{ columns = 4, newRows = 1, freeTile = true, family = function(bag) return fam[bag] end })
			local old = L.Position(st, OPTS, {})
			assert.same({ "0:2=1", "2:1=5" }, tiles(old))
			fam[2] = "any" -- the herb bag is swapped for a plain bag: the game answers for the new bag
			local r = L.Apply(st, { change(2, 1, "removed"), change(2, 2, "removed"), change(2, 3, "removed") })
			local pos = L.Position(st, OPTS, {})
			assert.same({ "0:2=1", "3:1=2" }, tiles(pos))
			assert.same(xy(old, 2, 1), xy(pos, 3, 1), "bag 3's first free slot is where the tile was")
			assert.same({ L.Key(3, 2) }, st.tiles.spares.family8)
			assert.same({}, st.tiles.spares.any, "the removed slots never joined \"any\"")
			for _, k in ipairs({ L.Key(2, 1), L.Key(2, 2), L.Key(2, 3) }) do
				assert.is_nil(st.where[k])
				assert.is_nil(pos.byKey[k])
			end
			assert.equal(0, r.deferred)
			-- every remaining slot is in exactly one cell or one spare list
			local seen = {}
			for id, sec in pairs(st.sections) do
				for i = 1, sec.size do
					local c = sec.cells[i]
					if c and not c.placeholder then
						local k = L.Key(c.bag, c.slot)
						assert.is_nil(seen[k])
						seen[k] = true
						assert.same({ section = id, index = i }, st.where[k])
					end
				end
			end
			for f, list in pairs(st.tiles.spares) do
				for _, k in ipairs(list) do
					assert.is_nil(seen[k])
					seen[k] = true
					assert.same({ section = "free", spare = f }, st.where[k])
				end
			end
			for _, k in ipairs({ L.Key(0, 1), L.Key(0, 2), L.Key(3, 1), L.Key(3, 2) }) do
				assert.truthy(seen[k], "slot " .. k)
			end
			-- the bag comes back as a plain bag: its slots join "any" now
			fam[2] = "any"
			L.Apply(st, { change(2, 1, "added"), change(2, 2, "added") })
			assert.same({ "0:2=3", "3:1=2" }, tiles(L.Position(st, OPTS, {})))
		end)

	it("an added slot joins its family as a spare; a removed tile hands its cell to the next spare", function()
		local st = build()
		local cell = xy(L.Position(st, OPTS, {}), 0, 2)
		L.Apply(st, { change(1, 3, "added") })
		assert.same({ "0:2=6", "5:1=2" }, tiles(L.Position(st, OPTS, {})))
		local r = L.Apply(st, { change(0, 2, "removed") })
		local pos = L.Position(st, OPTS, {})
		assert.same({ L.Key(0, 2), L.Key(0, 3) }, r.moved)
		assert.same(cell, xy(pos, 0, 3))
		assert.same({ "0:3=5", "5:1=2" }, tiles(pos))
	end)

	-- The randomized check of W3-12. Park-Miller (seed * 16807 % 2147483647, exact in doubles).
	-- 40 runs of 60 steps over a bag model (backpack 12, bag 1 8 (a herb bag in half the runs),
	-- bag 2 6 (a herb bag at first),
	-- reagent bag 6): leaves, arrivals in hidden slots, drops on a tile (usually with the mouse on
	-- it), different items, hover and cursor holds, the mouse leaving, loot that fills a whole
	-- family, Reflows (a full Build of the bags as they are; one in four switches the tile off,
	-- one in two of those with it off switches it back on), and bags 1 and 2 taken off and put back. A bag taken off changes its family
	-- first (W3-21: the game already answers for the new bag), and comes back as "any" or
	-- "family8"; the layout must use the family each slot had when it joined.
	-- After EVERY step:
	--   every slot is in exactly one cell or spare list; a button moved only if it was not busy;
	--   no two shown buttons share a cell; a button that appears takes no busy button's cell;
	--   each family shows at most one tile, and a shown tile is an empty slot (or the slot under
	--   the mouse that just took a drop, its swap held back); with the tile off, no tile and no
	--   spare at all.
	-- After every step with nothing held back (and after each run's drain), exactly:
	--   one shown tile per family that has a free slot, none for a family without; the tile's
	--   count is that family's real number of free slots; every spare is empty; every item shows.
	-- Mutations that must make it fail: (1) `return { key }` instead of the promote at the end of
	-- applyTile; (2) `if held[key] then` in Apply (no busy check); (3) `1 + #st.tiles.spares[f]`
	-- -> `#st.tiles.spares[f]` in Position; (4) in applyTile's "left" branch,
	-- `append(st, Layout.FREE, cell)` instead of `Layout.ToFamily(st, key, cell)`; (5) the live
	-- `st.tiles.family(bagOf(key))` instead of the stored family in isTile (W3-21).
	it("randomized: one real empty tile per family with the real count; nothing moves under the cursor", function()
		local SIZES = { [0] = 12, [1] = 8, [2] = 6, [5] = 6 }
		local FAMILIES = { "any", "reagent", "family8" }
		local totals = { swaps = 0, heldSwaps = 0, spareLeaves = 0, spareArrivals = 0, reagentSwaps = 0, fullTile = 0,
			steps = 0, settled = 0, reflows = 0, tileOff = 0, tileBackOn = 0, removes = 0, adds = 0,
			removedTiles = 0, handedOn = 0, fills = 0, zeroToOneAny = 0, zeroToOneReagent = 0 }
		local seed = 20261002
		local function rand(n)
			seed = seed * 16807 % 2147483647
			return seed % n + 1
		end
		for run = 1, 40 do
			-- famOf: what the game answers now; joined: the family each slot had when it joined
			local famOf = { [0] = "any", [1] = rand(2) == 1 and "family8" or "any", [2] = "family8", [5] = "reagent" }
			local function liveFamily(bag)
				return famOf[bag]
			end
			local content, slots, keys, joined = {}, {}, {}, {}
			local present = { [0] = true, [1] = true, [2] = true, [5] = true }
			local nextItem = 100
			for _, bag in ipairs({ 0, 1, 2, 5 }) do
				for slot = 1, SIZES[bag] do
					local k = L.Key(bag, slot)
					keys[#keys + 1] = k
					joined[k] = famOf[bag]
					if rand(2) == 1 then
						nextItem = nextItem + 1
						content[k] = nextItem
					end
					slots[#slots + 1] = { bag = bag, slot = slot, record = content[k] and { cat = "c" .. (content[k] % 3) } or nil }
				end
			end
			local tileOn = true
			local st = L.Build(slots, assign, { "c0", "c1", "c2" },
				{ columns = 4, newRows = 1 + rand(2), freeTile = true, family = liveFamily })
			local pos = L.Position(st, OPTS, {})
			local hover, cursor = nil, false

			local function realFree(f)
				local n = 0
				for _, k in ipairs(keys) do
					if content[k] == nil and joined[k] == f then
						n = n + 1
					end
				end
				return n
			end

			local function tileOf(p, f)
				for _, t in ipairs(p.tiles) do
					if t.shown and t.tile == f then
						return t
					end
				end
			end

			local function check(old, new, busyKeys, label)
				local held, heldAdd = {}, {}
				for _, ch in ipairs(st.deferred) do
					held[L.Key(ch.bag, ch.slot)] = true
					if ch.kind == "added" then -- a bag put back while the cursor holds an item: it waits
						heldAdd[L.Key(ch.bag, ch.slot)] = true
					end
				end
				-- every slot exactly once
				local seen = {}
				for id, sec in pairs(st.sections) do
					for i = 1, sec.size do
						local c = sec.cells[i]
						if c and not c.placeholder then
							local k = L.Key(c.bag, c.slot)
							assert.is_nil(seen[k], label .. ": placed twice")
							seen[k] = true
							assert.same({ section = id, index = i }, st.where[k], label)
						end
					end
				end
				for f, list in pairs(st.tiles and st.tiles.spares or {}) do
					for _, k in ipairs(list) do
						assert.is_nil(seen[k], label .. ": a spare is also in a cell")
						seen[k] = true
						assert.same({ section = "free", spare = f }, st.where[k], label)
					end
				end
				for _, k in ipairs(keys) do
					assert.truthy(seen[k] or heldAdd[k], label .. ": a button was lost")
				end
				-- nothing moved under the cursor
				for _, k in ipairs(L.Moves(old, new)) do
					assert.falsy(busyKeys[k], label .. ": a busy button moved")
				end
				-- no two shown buttons in one cell; an appearing button takes no busy button's cell
				local at = {}
				for k, c in pairs(new.byKey) do
					if c.shown then
						local xyk = c.x .. "," .. c.y
						assert.is_nil(at[xyk], label .. ": two buttons in one cell")
						at[xyk] = k
						local o = old.byKey[k]
						if not (o and o.shown) then
							for bk in pairs(busyKeys) do
								local b = old.byKey[bk]
								assert.falsy(b and b.shown and b.x == c.x and b.y == c.y,
									label .. ": a hidden button was placed on the busy one")
							end
						end
					end
				end
				if not st.tiles then -- the tile is off: every free slot is shown, no tile, no spare
					assert.equal(0, #new.tiles, label .. ": a tile with the tile off")
					for k, c in pairs(new.byKey) do
						assert.truthy(c.shown and not c.spare, label .. ": a hidden slot with the tile off " .. k)
					end
					if #st.deferred == 0 then
						totals.settled = totals.settled + 1
					end
					return
				end
				for _, f in ipairs(FAMILIES) do
					local n = 0
					for _, t in ipairs(new.tiles) do
						if t.shown and t.tile == f then
							n = n + 1
							assert.truthy(content[L.Key(t.bag, t.slot)] == nil or held[L.Key(t.bag, t.slot)],
								label .. ": the tile is not an empty slot")
						end
					end
					assert.truthy(n <= 1, label .. ": two tiles for " .. f)
					if #st.deferred == 0 then
						local t = tileOf(new, f)
						if realFree(f) > 0 then
							assert.truthy(t, label .. ": no tile for " .. f)
							assert.equal(realFree(f), t.count, label .. ": the count of " .. f)
						else
							assert.is_nil(t, label .. ": a tile for a full family")
						end
					end
				end
				if #st.deferred == 0 then
					totals.settled = totals.settled + 1
					for _, list in pairs(st.tiles.spares) do
						for _, k in ipairs(list) do
							assert.is_nil(content[k], label .. ": an item in a hidden button")
						end
					end
					for _, k in ipairs(keys) do
						if content[k] then
							assert.truthy(new.byKey[k].shown, label .. ": an item is hidden")
						end
					end
				end
			end

			local function emptyKey(f)
				local list = {}
				for _, k in ipairs(keys) do
					if content[k] == nil and (not f or joined[k] == f) then
						list[#list + 1] = k
					end
				end
				return #list > 0 and list[rand(#list)] or nil
			end
			local function filledKey()
				local list = {}
				for _, k in ipairs(keys) do
					if content[k] then
						list[#list + 1] = k
					end
				end
				return #list > 0 and list[rand(#list)] or nil
			end
			local function ch(k, kind, icon)
				return { bag = math.floor(k / 1000), slot = k % 1000, kind = kind, icon = icon }
			end

			for step = 1, 60 do
				local changes, label = {}, ("run %d step %d"):format(run, step)
				local before = {}
				for _, f in ipairs(FAMILIES) do
					before[f] = realFree(f)
				end
				local kind = rand(15)
				local dropOnTile = nil
				local removedTileKeys, handedFamily = {}, nil
				if kind <= 3 then -- an item is used up or moved away
					local k = filledKey()
					if k then
						changes[1] = ch(k, "left", content[k])
						content[k] = nil
					end
				elseif kind <= 6 then -- a drop on a family's tile, usually with the mouse on it
					local t = tileOf(pos, FAMILIES[rand(3)])
					if t and content[L.Key(t.bag, t.slot)] == nil then
						dropOnTile = L.Key(t.bag, t.slot)
						nextItem = nextItem + 1
						content[dropOnTile] = nextItem
						changes[1] = ch(dropOnTile, "arrived", nextItem)
						if rand(4) ~= 1 then
							hover = dropOnTile
						end
					end
				elseif kind <= 8 then -- looted into whatever slot is free (often a hidden one)
					local k = emptyKey()
					if k then
						nextItem = nextItem + 1
						content[k] = nextItem
						changes[1] = ch(k, "arrived", nextItem)
					end
				elseif kind == 9 then -- the mouse moves on, the cursor empties
					hover = rand(2) == 1 and keys[rand(#keys)] or nil
					cursor = rand(5) == 1
				elseif kind == 10 then -- a different item in a filled slot
					local k = filledKey()
					if k then
						nextItem = nextItem + 1
						changes[1] = ch(k, "arrived", content[k])
						content[k] = nextItem
					end
				elseif kind == 11 then -- the mouse leaves the items
					hover, cursor = nil, false
				elseif kind == 12 then -- Reflow: a full layout of what is in the bags now
					if not hover and not cursor then
						if rand(tileOn and 4 or 2) == 1 then -- off one Reflow in four, back on one in two
							tileOn = not tileOn
							if tileOn then
								totals.tileBackOn = totals.tileBackOn + 1
							else
								totals.tileOff = totals.tileOff + 1
							end
						end
						local fresh = {}
						for _, k in ipairs(keys) do
							joined[k] = liveFamily(math.floor(k / 1000)) -- every slot joins again
							fresh[#fresh + 1] = { bag = math.floor(k / 1000), slot = k % 1000,
								record = content[k] and { cat = "c" .. (content[k] % 3) } or nil }
						end
						st = L.Build(fresh, assign, { "c0", "c1", "c2" },
							{ columns = 4, newRows = 1 + rand(2), freeTile = tileOn, family = liveFamily })
						pos = L.Position(st, OPTS, {})
						totals.reflows = totals.reflows + 1
					end
				elseif kind == 13 then -- loot fills every free slot of one family in one update
					local f = FAMILIES[rand(3)]
					for _, k in ipairs(keys) do
						if content[k] == nil and joined[k] == f then
							nextItem = nextItem + 1
							content[k] = nextItem
							changes[#changes + 1] = ch(k, "arrived", nextItem)
						end
					end
					if #changes > 0 then
						totals.fills = totals.fills + 1
					end
				elseif #st.deferred == 0 then -- bag 1 or 2 is taken off, or put back
					local bag = rand(2)
					local newFamily = rand(2) == 1 and "any" or "family8"
					if present[bag] then
						local changed, oldFamily = famOf[bag] ~= newFamily, famOf[bag]
						famOf[bag] = newFamily -- the game answers for the next bag before the slots go
						for slot = 1, SIZES[bag] do
							local k = L.Key(bag, slot)
							changes[#changes + 1] = ch(k, "removed")
							if changed and pos.byKey[k] and pos.byKey[k].tile then
								removedTileKeys[k], handedFamily = true, oldFamily
							end
							content[k], joined[k] = nil, nil
						end
						local kept = {}
						for _, k in ipairs(keys) do
							if math.floor(k / 1000) ~= bag then
								kept[#kept + 1] = k
							end
						end
						keys, present[bag] = kept, false
						totals.removes = totals.removes + 1
					else
						famOf[bag] = newFamily
						for slot = 1, SIZES[bag] do
							local k = L.Key(bag, slot)
							keys[#keys + 1] = k
							joined[k] = newFamily
							changes[#changes + 1] = ch(k, "added")
						end
						present[bag] = true
						totals.adds = totals.adds + 1
					end
				end
				local busyKeys = {}
				for _, k in ipairs(keys) do
					local c = pos.byKey[k]
					if cursor or (k == hover and c and c.shown) then
						busyKeys[k] = true
					end
				end
				local wasTile = {}
				for _, t in ipairs(pos.tiles) do
					wasTile[L.Key(t.bag, t.slot)] = t.tile
				end
				local heldBefore = {}
				for _, d in ipairs(st.deferred) do
					heldBefore[L.Key(d.bag, d.slot)] = true
				end
				local r = L.Apply(st, changes, function(bag, slot)
					return busyKeys[L.Key(bag, slot)] == true
				end)
				local new = L.Position(st, OPTS, {})
				for _, k in ipairs(r.moved) do
					if wasTile[k] and st.where[k] and st.where[k].section == "new" then
						totals.swaps = totals.swaps + 1
						if wasTile[k] == "reagent" then
							totals.reagentSwaps = totals.reagentSwaps + 1
						end
						if heldBefore[k] then -- a swap that waited for the mouse to leave
							totals.heldSwaps = totals.heldSwaps + 1
						end
					end
					if st.where[k] and st.where[k].spare and new.byKey[k] and not (pos.byKey[k] and pos.byKey[k].spare) then
						totals.spareLeaves = totals.spareLeaves + 1
					end
					if pos.byKey[k] and pos.byKey[k].spare and st.where[k] and not st.where[k].spare then
						totals.spareArrivals = totals.spareArrivals + 1
					end
					if removedTileKeys[k] and not st.where[k] then -- W3-21: its family had changed
						totals.removedTiles = totals.removedTiles + 1
					end
				end
				if dropOnTile and st.where[dropOnTile].section == "free" and r.overflowed > 0 then
					totals.fullTile = totals.fullTile + 1
				end
				totals.steps = totals.steps + 1
				check(pos, new, busyKeys, label)
				if handedFamily and st.tiles and #st.deferred == 0 and realFree(handedFamily) > 0 then
					totals.handedOn = totals.handedOn + 1 -- W3-21: another bag's free slot is the tile now
				end
				if st.tiles and #st.deferred == 0 then -- the check above saw the family's new tile
					if before.any == 0 and realFree("any") > 0 then
						totals.zeroToOneAny = totals.zeroToOneAny + 1
					end
					if before.reagent == 0 and realFree("reagent") > 0 then
						totals.zeroToOneReagent = totals.zeroToOneReagent + 1
					end
				end
				pos = new
			end
			local r = L.Apply(st, {}, nil) -- drain: the mouse has left and the cursor is empty
			assert.equal(0, r.deferred)
			local new = L.Position(st, OPTS, {})
			check(pos, new, {}, ("run %d drained"):format(run))
		end
		assert.truthy(totals.swaps >= 100, "swaps " .. totals.swaps)
		assert.truthy(totals.heldSwaps >= 60, "held swaps " .. totals.heldSwaps)
		assert.truthy(totals.reagentSwaps >= 30, "reagent swaps " .. totals.reagentSwaps)
		assert.truthy(totals.spareLeaves >= 200, "leaves into spares " .. totals.spareLeaves)
		assert.truthy(totals.spareArrivals >= 250, "arrivals in hidden slots " .. totals.spareArrivals)
		assert.truthy(totals.fullTile >= 20, "drops on the tile with New full " .. totals.fullTile)
		assert.truthy(totals.settled >= 400, "settled checks " .. totals.settled)
		assert.truthy(totals.reflows >= 25, "reflows " .. totals.reflows)
		assert.truthy(totals.tileOff >= 10, "builds with the tile off " .. totals.tileOff)
		assert.truthy(totals.tileBackOn >= 5, "builds with the tile back on " .. totals.tileBackOn)
		assert.truthy(totals.removes >= 60, "bags taken off " .. totals.removes)
		assert.truthy(totals.adds >= 40, "bags put back " .. totals.adds)
		assert.truthy(totals.removedTiles >= 9, "tiles taken off with a changed family " .. totals.removedTiles)
		assert.truthy(totals.handedOn >= 4, "a removed tile's family kept a tile " .. totals.handedOn)
		assert.truthy(totals.fills >= 60, "families filled by loot " .. totals.fills)
		assert.truthy(totals.zeroToOneAny >= 25, "'any' from 0 free to 1+ " .. totals.zeroToOneAny)
		assert.truthy(totals.zeroToOneReagent >= 15, "'reagent' from 0 free to 1+ " .. totals.zeroToOneReagent)
	end)
end)
