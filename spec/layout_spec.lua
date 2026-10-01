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
