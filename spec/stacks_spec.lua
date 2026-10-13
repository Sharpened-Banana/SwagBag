-- Stack grouping, Task 1: the pure rules (which stacks are "the same item", the total and the tooltip line).
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

describe("Stacks", function()
	local SB, A, Stacks, HERB
	before_each(function()
		SB = Loader.New({ "SwagBag/Core/Config.lua", "SwagBag/Engine/Items.lua", "SwagBag/Engine/Layout.lua",
			"SwagBag/Engine/Stacks.lua" })
		A, Stacks = SB.Adapter, SB.Stacks
		Fixtures.Install(A)
		HERB = Fixtures.HERB
	end)

	local function rec(link, extra)
		local r = { itemID = HERB, link = link, count = 10, maxStack = 1000, pending = false, isBound = false }
		for k, v in pairs(extra or {}) do
			r[k] = v
		end
		return r
	end

	local function differ(x, y, msg)
		assert.truthy(x ~= nil and y ~= nil and x ~= y, msg or "the keys differ")
	end

	it("two stacks of a trade good share a key", function()
		A.Put(0, 1, HERB, 45)
		A.Put(0, 2, HERB, 7)
		local a, b = SB.Items.Describe(0, 1), SB.Items.Describe(0, 2)
		assert.equal("string", type(Stacks.Key(a)))
		assert.equal(Stacks.Key(a), Stacks.Key(b))
	end)

	-- Mutation: in Stacks.normalise, do not blank the linkLevel and specializationID fields.
	it("a link that differs only in the viewer's level and spec still merges", function()
		local a = rec("item:" .. HERB .. "::::::::70:250::::")
		local b = rec("item:" .. HERB .. "::::::::80:62::::")
		assert.equal("string", type(Stacks.Key(a)))
		assert.equal(Stacks.Key(a), Stacks.Key(b))
		local wrapped = rec("|cff1eff00|Hitem:" .. HERB .. "::::::::80:62::::|h[Mycobloom]|h|r")
		assert.equal(Stacks.Key(a), Stacks.Key(wrapped), "a coloured link keys like its item string")
	end)

	-- Mutation: key on the itemID only.
	it("other bonus IDs never merge", function()
		local a = rec("item:" .. HERB .. "::::::::70:250:::1:9001")
		local b = rec("item:" .. HERB .. "::::::::70:250:::1:9002")
		differ(Stacks.Key(a), Stacks.Key(b))
		local other = rec("item:" .. HERB .. ":5000:::::::70:250")
		differ(Stacks.Key(rec("item:" .. HERB .. "::::::::70:250")), Stacks.Key(other), "another enchant")
	end)

	-- Mutation: drop the maxStack test (gear would group).
	it("gear, keystones and caged pets never group", function()
		local ring = rec("item:" .. Fixtures.BOE_RING, { itemID = Fixtures.BOE_RING, maxStack = 1 })
		assert.is_nil(Stacks.Key(ring))
		-- the keystone and the cage may report a large stack, only their flags keep them apart
		local key = rec("|Hkeystone:180653:503:12:10:9:0:0|h[Keystone]|h", { isKeystone = true })
		assert.is_nil(Stacks.Key(key))
		local pet = rec("|Hbattlepet:1234:25:3:1000:300:300:0|h[Pet]|h", { isCagedPet = true })
		assert.is_nil(Stacks.Key(pet))
		A.Put(0, 5, Fixtures.KEYSTONE, 1, { isBound = true, link = "|cffa335ee|Hkeystone:180653:503:12:10:9:0:0|h[K]|h|r" })
		assert.is_nil(Stacks.Key(SB.Items.Describe(0, 5)))
	end)

	it("a pending item never groups", function()
		assert.is_nil(Stacks.Key(rec("item:" .. HERB, { pending = true })))
	end)

	it("bound and unbound copies stay apart", function()
		local link = "item:" .. HERB
		differ(Stacks.Key(rec(link, { isBound = true })), Stacks.Key(rec(link, { isBound = false })))
	end)

	it("a secret link never becomes a key", function()
		local link = "item:" .. HERB
		A.secret = { [link] = true }
		A.IsSecret = function(v)
			return A.secret[v] == true
		end
		assert.is_nil(Stacks.Key(rec(link)))
		assert.equal("string", type(Stacks.Key(rec("item:" .. HERB .. ":1"))))
	end)

	it("no link falls back to the itemID", function()
		local a, b = rec(nil), rec(nil)
		assert.equal(tostring(HERB) .. "#u", Stacks.Key(a))
		assert.equal(Stacks.Key(a), Stacks.Key(b))
	end)

	it("CountText shows 4 digits, then thousands", function()
		assert.equal("52", Stacks.CountText(52))
		assert.equal("9999", Stacks.CountText(9999))
		assert.equal("12k", Stacks.CountText(12345))
	end)

	it("Line lists the stacks", function()
		assert.equal("2 stacks: 45 + 7", Stacks.Line({ 45, 7 }))
		assert.equal("6 stacks: 1 + 2 + 3 + 4 + 5 + 6", Stacks.Line({ 1, 2, 3, 4, 5, 6 }))
		assert.equal("8 stacks: 1 + 2 + 3 + 4 + 5 + 3 more", Stacks.Line({ 1, 2, 3, 4, 5, 6, 7, 8 }))
	end)

	it("Of totals a shown stack and its members", function()
		local recs = { ["0:1"] = { count = 45 }, ["0:2"] = { count = 7 } }
		local function recordOf(b, s)
			return recs[b .. ":" .. s]
		end
		local entry = { bag = 0, slot = 1, members = { { bag = 0, slot = 2 } } }
		assert.same({ total = 52, counts = { 45, 7 } }, Stacks.Of(entry, recordOf))
		recs["0:1"] = nil
		assert.is_nil(Stacks.Of(entry, recordOf), "the shown stack is gone")
		recs["0:1"], recs["0:2"] = { count = 45 }, nil
		assert.is_nil(Stacks.Of(entry, recordOf), "fewer than two stacks remain")
	end)

	it("Totals sums by key and skips nil keys", function()
		local slots = { { record = { count = 45, k = "a" } }, { record = { count = 7, k = "a" } },
			{ record = { count = 3, k = "b" } }, { record = { count = 99 } } }
		slots[6] = { record = { count = 1, k = "a" } } -- a hole at 5
		local totals = Stacks.Totals(slots, function(s)
			return s.record.k
		end)
		assert.same({ a = 53, b = 3 }, totals)
	end)

	-- Paint and Relight (shared by the bags window and GroupView): plain tables stand in for the buttons.
	local function world(counts)
		local buttons, records = {}, {}
		for slot, n in pairs(counts) do
			buttons[slot] = { slot = slot }
			records[slot] = { count = n }
		end
		local function buttonOf(_, slot) return buttons[slot] end
		local function recordOf(_, slot) return records[slot] end
		return buttons, records, buttonOf, recordOf
	end

	-- Mutations: Paint skips `e.shown`; Paint forgets to clear a button that left `prev`; paintRow without the total.
	it("Paint sets each shown group's total, paints its row, and clears what is no longer grouped", function()
		local buttons, records, buttonOf, recordOf = world({ [1] = 45, [2] = 7, [3] = 9, [4] = 2 })
		local set, painted = {}, {}
		local function setStack(b, st) set[b.slot] = st and st.total or false end
		local function paintRow(b, _, total) painted[b.slot] = total or false end
		local entries = {
			{ bag = 0, slot = 1, members = { { bag = 0, slot = 2 } }, shown = true },
			{ bag = 0, slot = 3, members = { { bag = 0, slot = 4 } }, shown = false }, -- in a folded section
		}
		local now = Stacks.Paint(entries, {}, recordOf, buttonOf, setStack, paintRow)
		assert.same({ [1] = 52 }, set)
		assert.same({ [1] = 52 }, painted)
		assert.equal(entries[1], now[buttons[1]])
		assert.is_nil(next(now, next(now)), "one group only")
		records[1] = nil -- the shown stack left: Of has no first record
		set, painted = {}, {}
		now = Stacks.Paint(entries, now, recordOf, buttonOf, setStack)
		assert.same({ [1] = false }, set, "its own number back")
		assert.same({}, painted, "no paintRow given: no row")
		assert.same({}, now)
	end)

	it("Paint with no entries clears every previous group", function()
		local buttons, _, buttonOf, recordOf = world({ [1] = 45 })
		local cleared = {}
		local now = Stacks.Paint(nil, { [buttons[1]] = { bag = 0, slot = 1 } }, recordOf, buttonOf, function(b, st)
			cleared[#cleared + 1] = { b.slot, st }
		end)
		assert.same({ { 1 } }, cleared)
		assert.same({}, now)
	end)

	-- Mutations: Relight lights without checking the members; Relight ignores `e.shown`.
	it("Relight lights a dimmed shown icon only while one of its hidden stacks is lit", function()
		local buttons, _, buttonOf = world({ [1] = 45, [2] = 7, [3] = 9, [4] = 2, [5] = 1, [6] = 1 })
		local dimmed = { [buttons[1]] = true, [buttons[2]] = false, -- the 7 matched: its icon lights
			[buttons[3]] = true, [buttons[4]] = true, -- nothing matched
			[buttons[5]] = true, [buttons[6]] = false } -- a folded group's: left alone
		local lit = {}
		Stacks.Relight({
			{ bag = 0, slot = 1, members = { { bag = 0, slot = 2 } }, shown = true },
			{ bag = 0, slot = 3, members = { { bag = 0, slot = 4 } }, shown = true },
			{ bag = 0, slot = 5, members = { { bag = 0, slot = 6 } }, shown = false },
		}, buttonOf, function(b) return dimmed[b] end, function(b) lit[#lit + 1] = b.slot end)
		assert.same({ 1 }, lit)
		Stacks.Relight(nil, buttonOf, function() return true end, error) -- no entries: nothing
	end)

	it("Enabled follows bags.stacks", function()
		SB.Config.Init(nil, nil)
		assert.equal(true, Stacks.Enabled())
		SB.Config.Set("bags.stacks", "all")
		assert.equal(false, Stacks.Enabled())
	end)
end)
