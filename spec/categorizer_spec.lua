local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")
local Big = dofile("spec/fixtures/big.lua")

local FILES = {
	"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Config.lua",
	"SwagBag/Engine/Query/Lexer.lua", "SwagBag/Engine/Query/Parser.lua", "SwagBag/Engine/Query/Query.lua",
	"SwagBag/Engine/Items.lua", "SwagBag/Engine/Keywords.lua",
	"SwagBag/Engine/CategoryDefaults.lua", "SwagBag/Engine/Categories.lua", "SwagBag/Engine/Categorizer.lua",
}

describe("Categorizer", function()
	local SB, A, Z, C
	before_each(function()
		SB = Loader.New(FILES)
		A, Z, C = SB.Adapter, SB.Categorizer, SB.Categories
		SB.Config.Init(nil, nil)
		Fixtures.SmallBags(A)
		C.Load()
	end)

	local function at(slot, bag)
		return (Z.Assign(SB.Items.Describe(bag or 0, slot)))
	end

	-- A user category with a counting keyword; returns the counter table.
	local function counting(name, class, priority, result)
		local counter = { n = 0 }
		SB.Query.RegisterKeyword({ name = name, class = class, eval = function()
			counter.n = counter.n + 1
			return result
		end })
		SB.Config.db.categories["u_" .. name] = { name = name, query = name, priority = priority }
		C.Load()
		return counter
	end

	it("files the fixture bag into the default sections, keystones and caged pets by link", function()
		A.Put(0, 7, Fixtures.HERB, 40)
		A.Put(0, 8, Fixtures.ORE, 10)
		A.Put(0, 9, Fixtures.PET_CAGE, 1, { link = "|cff0070dd|Hbattlepet:1387:25:3:1546:276:276:0|h[Hatespark]|h|r" })
		A.Put(0, 10, Fixtures.TOY, 1)
		A.Put(0, 11, Fixtures.QUEST, 1, { quest = true })
		A.Put(0, 12, Fixtures.BAG, 1)
		A.Put(0, 13, Fixtures.BOE_RING, 1, { isWUE = true })
		-- slot 13, a warbound-until-equipped ring: its own section since week 6 (Gear before)
		local expected = { "c_consumables", "c_consumables", "c_boe", "c_gear", "c_keystone", "c_junk", "c_herbs", "c_ore",
			"c_collect", "c_collect", "c_quest", "c_other", "c_wue" }
		for slot, id in ipairs(expected) do
			assert.equal(id, at(slot), "slot " .. slot)
		end
	end)

	it("a manual include beats every rule; an exclude keeps an item out of a category", function()
		C.AddToList("c_junk", Fixtures.HEALING_POTION)
		assert.equal("c_junk", at(1))
		assert.same({ "c_junk", "manual" }, { Z.Assign(SB.Items.Describe(0, 1)) })
		SB.Config.db.userEdits.c_consumables = { itemList = { exclude = { [Fixtures.FLASK] = true } } }
		C.Load()
		assert.equal("c_other", at(2), "excluded from Consumables, no other rule claims it")
	end)

	it("a rule that cannot decide (nil) stops the search: the item is pending, not mis-filed", function()
		A.Put(0, 7, Fixtures.UNLOADED, 1)
		assert.same({ nil, "pending" }, { Z.Assign(SB.Items.Describe(0, 7)) })
		A.items[Fixtures.UNLOADED] = { name = "Robe", classID = A.ITEM_CLASS.Armor, subclassID = 0, quality = 3,
			equipLoc = "INVTYPE_CHEST", ilvl = 280, maxStack = 1, bind = "equip" }
		assert.equal("c_boe", at(7), "once loaded it is filed normally")
	end)

	it("a loading item that instant facts already decide is filed directly (tri-state, spec 7.7)", function()
		A.AddItem(300001, { classID = A.ITEM_CLASS.Consumable, subclassID = A.CONSUMABLE_SUB.Potion, quality = 1,
			pending = true })
		A.Put(0, 7, 300001, 1)
		local r = SB.Items.Describe(0, 7)
		assert.truthy(r.pending)
		assert.equal("c_consumables", (Z.Assign(r)))
	end)

	it("a rule that throws is isolated: recorded once, disabled, and every other category still works", function()
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function() error("kaboom") end })
		SB.Config.db.categories.u_boom = { name = "Boom", query = "boom", priority = 200 }
		C.Load()
		for _ = 1, 3 do
			assert.equal("c_consumables", at(1))
			assert.equal("c_junk", at(6))
		end
		local recent = SB.ErrorTrap.Recent()
		assert.equal(1, #recent)
		assert.equal("category:u_boom", recent[1].label)
		assert.equal("none", recent[1].window)
		assert.falsy(SB.SafeMode.IsOn("bags"))
		assert.truthy(C.Get("u_boom").runtimeError:find("kaboom", 1, true))
	end)

	it("memoizes static rules per itemID and instance rules per link + bind; never volatile ones", function()
		local s = counting("cstatic", "static", 300, false)
		local i = counting("cinst", "instance", 299, false)
		local v = counting("cvol", "volatile", 298, false)
		at(1)
		at(1)
		assert.same({ 1, 1, 2 }, { s.n, i.n, v.n })
		A.Put(0, 7, Fixtures.HEALING_POTION, 1, { isBound = true }) -- same item and link, now bound
		at(7)
		assert.same({ 1, 2, 3 }, { s.n, i.n, v.n })
		assert.truthy(Z.stats.hits >= 3)
	end)

	it("never memoizes a loading record", function()
		local s = counting("cstatic", "static", 300, false)
		A.Put(0, 7, Fixtures.UNLOADED, 1)
		at(7)
		at(7)
		assert.equal(2, s.n)
	end)

	it("drops every memo when any category changes", function()
		local s = counting("cstatic", "static", 300, false)
		at(1)
		C.AddToList("c_junk", Fixtures.JUNK)
		at(1)
		assert.equal(2, s.n)
	end)

	it("keeps at most MAX_MEMO entries, dropping the oldest first", function()
		local s = counting("cstatic", "static", 300, false)
		Z.MAX_MEMO = 3
		for slot = 1, 6 do -- six different itemIDs
			at(slot)
		end
		assert.equal(3, Z.memoCount)
		assert.equal(6, s.n)
		at(6)
		assert.equal(6, s.n, "newest is still cached")
		at(1)
		assert.equal(7, s.n, "oldest was dropped")
	end)

	it("is deterministic: shuffled input gives the same groups", function()
		local records = {}
		for slot = 1, 6 do
			records[slot] = SB.Items.Describe(0, slot)
		end
		local function shape(groups)
			local out = {}
			for id, list in pairs(groups) do
				out[id] = {}
				for i, r in ipairs(list) do
					out[id][i] = r.slot
				end
			end
			return out
		end
		local a = shape((Z.AssignAll(records)))
		local shuffled = { records[4], records[1], records[6], records[2], records[5], records[3] }
		Z.Invalidate()
		assert.same(a, shape((Z.AssignAll(shuffled))))
		assert.same({ 1, 2 }, a.c_consumables)
	end)

	it("puts reagent-bag items in Reagents only while it is shown separately (AC1.4)", function()
		A.SetBagSize(5, 36)
		A.Put(5, 1, Fixtures.HERB, 12)
		assert.equal("c_herbs", at(1, 5))
		SB.Config.Set("bags.reagentSeparate", true)
		C.Load()
		assert.equal("c_reagents", at(1, 5))
	end)

	it("categorizes the 1,290-slot fixture well inside the first-open budget", function()
		local m = SB.Adapter
		m.slots, m.sizes = {}, {}
		Big.Install(m)
		local records = {}
		for _, b in ipairs(Big.BAGS) do
			for slot = 1, b[2] do
				local r = SB.Items.Describe(b[1], slot)
				if r then
					records[#records + 1] = r
				end
			end
		end
		assert.equal(1032, #records)
		local t0 = os.clock()
		Z.AssignAll(records)
		local cold = (os.clock() - t0) * 1000
		t0 = os.clock()
		Z.AssignAll(records)
		local warm = (os.clock() - t0) * 1000
		assert.truthy(cold < 20, ("cold %.2f ms"):format(cold))
		assert.truthy(warm < 10, ("warm %.2f ms"):format(warm))
	end)

	it("a keyword that throws on every item is recorded once across many items and passes", function()
		local calls = 0
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function()
			calls = calls + 1
			error("kaboom")
		end })
		SB.Config.db.categories.u_boom = { name = "Boom", query = "boom", priority = 200 }
		C.Load()
		local before = #SB.ErrorTrap.Recent()
		local records = {}
		for slot = 1, 6 do
			records[slot] = SB.Items.Describe(0, slot)
		end
		for _ = 1, 50 do
			Z.AssignAll(records)
		end
		assert.equal(before + 1, #SB.ErrorTrap.Recent())
		assert.equal(1, calls, "a failed category is skipped, not re-run")
		assert.truthy(C.Get("u_boom").runtimeError)
		assert.truthy(SB.ErrorTrap.Recent()[before + 1].stack ~= nil)
		assert.equal("c_consumables", at(1))
		assert.equal("c_boe", at(3))
		assert.equal("c_junk", at(6))
		for _, r in ipairs(records) do
			assert.truthy(Z.Assign(r) ~= "u_boom")
		end
	end)

	it("a static memo hit does not re-evaluate and an instance memo hit does not either", function()
		local s = counting("cstatic", "static", 300, false)
		local i = counting("cinst", "instance", 299, false)
		for _ = 1, 5 do
			at(1)
		end
		assert.same({ 1, 1 }, { s.n, i.n })
	end)

	it("never exceeds the real 4000-entry cap", function()
		local s = counting("cstatic", "static", 300, false)
		for n = 1, 4200 do
			A.AddItem(400000 + n, { classID = A.ITEM_CLASS.Armor, subclassID = 0, quality = 1, ilvl = 1, name = "x" .. n,
				maxStack = 1, bind = "none", equipLoc = "INVTYPE_CHEST" })
			A.Put(0, 7, 400000 + n, 1)
			at(7)
			assert.truthy(Z.memoCount <= 4000)
		end
		assert.equal(4000, Z.memoCount)
		assert.truthy(Z.stats.evictions > 0)
		assert.equal(4200, s.n)
	end)

	it("assigns identically whatever order user categories were defined in", function()
		local defs = { { "u_a", "junk" }, { "u_b", "junk" }, { "u_c", "junk" } }
		local function run(order)
			SB.Config.db.categories = {}
			for _, k in ipairs(order) do
				local d = defs[k]
				SB.Config.db.categories[d[1]] = { name = d[1], query = d[2], priority = 150 }
			end
			C.Load()
			Z.Invalidate()
			return at(6)
		end
		local first = run({ 1, 2, 3 })
		assert.equal("u_a", first)
		assert.equal(first, run({ 3, 1, 2 }))
		assert.equal(first, run({ 2, 3, 1 }))
	end)

	it("resolves manual includes written straight into the saved data: priority, then lower id", function()
		local item = Fixtures.HEALING_POTION
		SB.Config.db.categories = {
			u_b = { name = "B", query = "", priority = 100, itemList = { include = { [item] = true } } },
			u_a = { name = "A", query = "", priority = 100, itemList = { include = { [item] = true } } },
			u_hi = { name = "Hi", query = "", priority = 120 },
		}
		C.Load()
		assert.equal("u_a", at(1), "equal priority: lower id")
		SB.Config.db.categories.u_b.priority = 110
		C.Load()
		assert.equal("u_b", at(1), "higher priority wins")
	end)

	it("never memoizes a nil from a loaded record", function()
		local s = counting("cnil", "static", 300, nil)
		assert.same({ nil, "pending" }, { Z.Assign(SB.Items.Describe(0, 1)) })
		assert.same({ nil, "pending" }, { Z.Assign(SB.Items.Describe(0, 1)) })
		assert.equal(2, s.n)
	end)

	it("records a failure once even across Categories.Load, and re-arms when the query is edited", function()
		local calls = 0
		SB.Query.RegisterKeyword({ name = "boom", class = "volatile", eval = function()
			calls = calls + 1
			error("kaboom")
		end })
		SB.Config.db.categories.u_boom = { name = "Boom", query = "boom", priority = 200 }
		C.Load()
		local before = #SB.ErrorTrap.Recent()
		at(1)
		C.AddToList("c_junk", Fixtures.JUNK) -- unrelated change: Load runs
		at(1)
		at(1)
		assert.equal(before + 1, #SB.ErrorTrap.Recent())
		assert.equal(1, calls)
		SB.Config.db.categories.u_boom.query = "boom | boom"
		C.Load()
		at(1)
		assert.equal(2, calls, "an edited query is re-armed")
		assert.equal(before + 2, #SB.ErrorTrap.Recent())
	end)

	it("Keystone & Crests files the keystone and crest items (spec 7.6)", function()
		Loader.LoadFile(SB, "SwagBag/Engine/Crests.lua")
		A.AddItem(500001, { name = "Weathered Harbinger Crest", classID = A.ITEM_CLASS.Miscellaneous, subclassID = 0,
			quality = 2, maxStack = 99, bind = "pickup" })
		A.Put(0, 7, 500001, 12)
		C.Load()
		assert.equal("c_keystone", at(5))
		assert.equal("c_keystone", at(7))
	end)
end)
