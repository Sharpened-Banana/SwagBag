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

	it("Enabled follows bags.stacks", function()
		SB.Config.Init(nil, nil)
		assert.equal(true, Stacks.Enabled())
		SB.Config.Set("bags.stacks", "all")
		assert.equal(false, Stacks.Enabled())
	end)
end)
