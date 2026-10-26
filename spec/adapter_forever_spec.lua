-- luacheck: globals WOW_PROJECT_ID WOW_PROJECT_MAINLINE WOW_PROJECT_CAMELOT WOW_PROJECT_FOREVER C_Bank Enum
-- luacheck: globals C_Item C_ChallengeMode C_PartyInfo C_HousingCatalog ItemLocation
-- Forever Stage A, Task 1: client flavor detection and the capability table (A.Flavor, A.FEATURES, A.Has,
-- A.Allows), with the REAL Adapter and stubbed project constants; then the mock's Forever mode.
local Loader = dofile("spec/helpers/loader.lua")

local SURFACES = { overlay = true, footer = true, mode = true, trigger = true, style = true, setting = true, keyword = true }

-- Literal Allows ids that no feature gates (none yet). An id listed here is known to be always allowed.
local UNGATED = {}

local function sourceFiles()
	local list = {}
	local p = io.popen("find SwagBag -name '*.lua' | sort")
	for line in p:lines() do
		list[#list + 1] = line
	end
	p:close()
	return list
end

local function clearGlobals()
	WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CAMELOT, WOW_PROJECT_FOREVER, C_Bank = nil, nil, nil, nil, nil
end

describe("Adapter flavor (real adapter, stubbed globals)", function()
	local A
	before_each(function()
		clearGlobals()
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(clearGlobals)

	local function onForever()
		WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 18, 18
	end

	it("no project constants and no Forever API is retail (tests, old clients)", function()
		assert.equal("retail", A.Flavor())
	end)

	it("WOW_PROJECT_ID == WOW_PROJECT_MAINLINE is retail", function()
		WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CAMELOT = 1, 1, 18
		assert.equal("retail", A.Flavor())
	end)

	-- Mutation: comparing id with mainline only, in rule 2.
	it("WOW_PROJECT_ID == WOW_PROJECT_CAMELOT (18) is forever", function()
		WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 18, 18
		assert.equal("forever", A.Flavor())
	end)

	it("a renamed constant, WOW_PROJECT_FOREVER, is still forever", function()
		WOW_PROJECT_ID, WOW_PROJECT_FOREVER = 18, 18
		assert.equal("forever", A.Flavor())
	end)

	-- Mutation: dropping rule 3.
	it("an unknown project that is not Retail takes the Forever profile", function()
		WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 99, 1
		assert.equal("forever", A.Flavor())
	end)

	-- Mutation: checking the API before the constants.
	it("Retail that gains C_Bank.ShouldUsePlayerBagsInBank stays retail", function()
		WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
		C_Bank = { ShouldUsePlayerBagsInBank = function() return true end }
		assert.equal("retail", A.Flavor())
	end)

	-- Mutation: applying the API fallback only when WOW_PROJECT_ID is nil.
	it("an ID with no MAINLINE constant and the Forever API is forever", function()
		WOW_PROJECT_ID = 1
		C_Bank = { ShouldUsePlayerBagsInBank = function() return true end }
		assert.equal("forever", A.Flavor())
		C_Bank = nil
		assert.equal("retail", A.Flavor(), "an ID alone, without the API, stays retail")
	end)

	it("no constants but C_Bank.ShouldUsePlayerBagsInBank is forever", function()
		C_Bank = { ShouldUsePlayerBagsInBank = function() return true end }
		assert.equal("forever", A.Flavor())
	end)

	-- Mutation: Has reading FEATURES[f].forever on both clients.
	it("on Retail every declared feature and surface is on", function()
		WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CAMELOT = 1, 1, 18
		local features, pairsSeen = 0, 0
		for name, feature in pairs(A.FEATURES) do
			features = features + 1
			assert.equal(true, A.Has(name), name)
			for surface, ids in pairs(feature.surfaces) do
				for _, id in ipairs(ids) do
					pairsSeen = pairsSeen + 1
					assert.equal(true, A.Allows(surface, id), surface .. " " .. id)
				end
			end
		end
		assert.equal(7, features)
		assert.equal(26, pairsSeen)
	end)

	-- Mutation: Allows returning Has of the first feature for every id.
	it("on Forever every Stage A feature is off and its surfaces are refused", function()
		onForever()
		for name in pairs(A.FEATURES) do
			assert.equal(false, A.Has(name), name)
		end
		assert.equal(false, A.Allows("overlay", "keystone"))
		assert.equal(false, A.Allows("footer", "crests"))
		assert.equal(false, A.Allows("mode", "delves"))
		assert.equal(false, A.Allows("trigger", "mplus"))
		assert.equal(false, A.Allows("style", "mplus"))
		assert.equal(false, A.Allows("setting", "overlays.track"))
		assert.equal(true, A.Allows("overlay", "ilvl"))
		assert.equal(true, A.Allows("footer", "gold"))
		-- 0.16.0: expansion keywords are hidden on Forever (Q6); other keywords stay
		assert.equal(false, A.Allows("keyword", "midnight"))
		assert.equal(false, A.Allows("keyword", "expansion"))
		assert.equal(true, A.Allows("keyword", "crit"))
	end)

	it("an undeclared feature is off on both clients", function()
		assert.equal(false, A.Has("nope"), "retail")
		onForever()
		assert.equal(false, A.Has("nope"), "forever")
	end)

	-- Mutation: a typo, Has("keystone"), in Task 3 (or Allows("overlay", "keystones")).
	it("every Has and Allows call in SwagBag/ names a declared feature or surface", function()
		local gated = {}
		for _, feature in pairs(A.FEATURES) do
			for surface, ids in pairs(feature.surfaces) do
				gated[surface] = gated[surface] or {}
				for _, id in ipairs(ids) do
					gated[surface][id] = true
				end
			end
		end
		local bad = {}
		for _, path in ipairs(sourceFiles()) do
			local f = assert(io.open(path, "r"))
			local text = f:read("*a")
			f:close()
			for name in text:gmatch('Has%("([%w]+)"%)') do
				if A.FEATURES[name] == nil then
					bad[#bad + 1] = path .. ": Has(\"" .. name .. "\")"
				end
			end
			for surface in text:gmatch('Allows%("(%a+)",') do
				if not SURFACES[surface] then
					bad[#bad + 1] = path .. ": Allows surface \"" .. surface .. "\""
				end
			end
			for surface, id in text:gmatch('Allows%("(%a+)",%s*"([^"]+)"%)') do
				if not ((gated[surface] and gated[surface][id]) or UNGATED[surface .. ":" .. id]) then
					bad[#bad + 1] = path .. ": Allows(\"" .. surface .. "\", \"" .. id .. "\")"
				end
			end
		end
		assert.same({}, bad)
	end)
end)

describe("Mock Forever mode", function()
	it("Loader.New with flavor forever runs the files under Forever", function()
		local SB = Loader.New({}, { flavor = "forever" })
		assert.equal("forever", SB.Adapter.Flavor())
		assert.equal(false, SB.Adapter.Has("keystones"))
		assert.equal(16001, SB.Adapter.BuildInfo().toc)
	end)

	it("the default mock stays retail", function()
		local SB = Loader.New({})
		assert.equal("retail", SB.Adapter.Flavor())
		assert.equal(true, SB.Adapter.Has("keystones"))
		assert.equal(120100, SB.Adapter.BuildInfo().toc)
	end)
end)

-- Forever Stage A, Task 2: bag IDs derived from Enum.BagIndex (real Adapter, stubbed Enum).
describe("Bag layout from Enum.BagIndex", function()
	local Mock = dofile("spec/mock_adapter.lua")
	local A
	before_each(function()
		Enum = nil
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		Enum = nil
	end)

	local function copy(t)
		local out = {}
		for k, v in pairs(t) do
			out[k] = v
		end
		return out
	end

	-- Mutation: an off-by-one in the consecutive scan.
	it("Retail's 12.1.5 BagIndex derives exactly today's literals", function()
		assert.same(Mock.RETAIL_BAG_INDEX, A.RETAIL_BAG_INDEX)
		local layout = A.LayoutFromBagIndex(Mock.RETAIL_BAG_INDEX)
		assert.same({ 0, 1, 2, 3, 4, 5 }, layout.bags)
		assert.equal(5, layout.reagent)
		assert.same({ first = 6, last = 11 }, layout.bank)
		assert.same({ first = 12, last = 16 }, layout.warband)
		local kind, tab = {}, {}
		kind[0] = "backpack"
		for id = 1, 4 do
			kind[id] = "bags"
		end
		kind[5] = "reagentbag"
		for id = 6, 11 do
			kind[id], tab[id] = "bank", id - 5
		end
		for id = 12, 16 do
			kind[id], tab[id] = "warband", id - 11
		end
		assert.same(kind, layout.kind)
		assert.same(tab, layout.tab)
		assert.same(A.RETAIL_LAYOUT.kind, layout.kind)
		assert.same(A.RETAIL_LAYOUT.tab, layout.tab)
	end)

	-- Mutation: a hardcoded last = first + 5.
	it("Forever's BagIndex gives bank 6-14 and warband 15-23", function()
		local layout = A.LayoutFromBagIndex(Mock.FOREVER_BAG_INDEX)
		assert.same({ 0, 1, 2, 3, 4, 5 }, layout.bags)
		assert.same({ first = 6, last = 14 }, layout.bank)
		assert.same({ first = 15, last = 23 }, layout.warband)
		assert.equal(9, layout.tab[14])
		assert.equal(9, layout.tab[23])
	end)

	it("Forever's extra names (-1, -2, -3) are never bags", function()
		local layout = A.LayoutFromBagIndex(Mock.FOREVER_BAG_INDEX)
		assert.is_nil(layout.kind[-1])
		assert.is_nil(layout.kind[-2])
		assert.is_nil(layout.kind[-3])
	end)

	-- Mutation: deriving a partial layout.
	it("an incomplete BagIndex gives nil, and BagLayout falls back to Retail", function()
		local bi = copy(Mock.FOREVER_BAG_INDEX)
		bi.AccountBankTab_1 = nil
		assert.is_nil(A.LayoutFromBagIndex(bi))
		Enum = { BagIndex = bi }
		assert.equal(A.RETAIL_LAYOUT, A.BagLayout())
	end)

	-- Mutation: ending a range at the gap instead of refusing the table (no gap scan).
	it("a gap in the bank tabs gives nil and falls back to Retail; overlapping ranges are refused", function()
		local gap = copy(Mock.RETAIL_BAG_INDEX)
		gap.CharacterBankTab_3 = nil
		assert.is_nil(A.LayoutFromBagIndex(gap))
		Enum = { BagIndex = gap }
		assert.equal(A.RETAIL_LAYOUT, A.BagLayout())
		local overlap = copy(Mock.RETAIL_BAG_INDEX)
		overlap.AccountBankTab_1 = 8
		assert.is_nil(A.LayoutFromBagIndex(overlap))
	end)

	-- Mutation: dropping both the Bag_1 == Backpack + 1 check and the bag gap scan (either one alone refuses it).
	it("Bag_1 that does not follow the backpack gives nil", function()
		local bi = copy(Mock.RETAIL_BAG_INDEX)
		bi.Bag_1 = 7
		assert.is_nil(A.LayoutFromBagIndex(bi))
		Enum = { BagIndex = bi }
		assert.equal(A.RETAIL_LAYOUT, A.BagLayout())
		local bare = copy(bi)
		bare.ReagentBag = nil
		assert.is_nil(A.LayoutFromBagIndex(bare), "no ReagentBag to catch it")
	end)

	-- Mutation: no gap scan after the bag run.
	it("a missing Bag_2 gives nil, not bags 0, 1, 5", function()
		local bi = copy(Mock.RETAIL_BAG_INDEX)
		bi.Bag_2 = nil
		assert.is_nil(A.LayoutFromBagIndex(bi))
		bi.ReagentBag = nil
		assert.is_nil(A.LayoutFromBagIndex(bi), "no ReagentBag to catch it: not bags 0, 1")
	end)

	-- Mutation: no gap scan after the bank run (Forever's bank 6-6, tabs 7-11 with no kind).
	it("a missing CharacterBankTab_2 on Forever gives nil", function()
		local bi = copy(Mock.FOREVER_BAG_INDEX)
		bi.CharacterBankTab_2 = nil
		assert.is_nil(A.LayoutFromBagIndex(bi))
		Enum = { BagIndex = bi }
		assert.equal(A.RETAIL_LAYOUT, A.BagLayout())
	end)

	-- Mutation: no gap scan after the warband run.
	it("a gap in the warband tabs gives nil", function()
		local bi = copy(Mock.FOREVER_BAG_INDEX)
		bi.AccountBankTab_4 = nil
		assert.is_nil(A.LayoutFromBagIndex(bi))
	end)

	-- Mutation: accepting a ReagentBag that does not follow the last bag.
	it("a ReagentBag that does not follow the last bag gives nil", function()
		local bi = copy(Mock.RETAIL_BAG_INDEX)
		bi.ReagentBag = 30
		assert.is_nil(A.LayoutFromBagIndex(bi))
		local early = copy(Mock.RETAIL_BAG_INDEX)
		early.Bag_4 = nil
		early.ReagentBag = 5
		assert.is_nil(A.LayoutFromBagIndex(early), "bags 0-3 then reagent 5 skips 4")
	end)

	it("no ReagentBag: the bags are 0-4", function()
		local bi = copy(Mock.RETAIL_BAG_INDEX)
		bi.ReagentBag = nil
		local layout = A.LayoutFromBagIndex(bi)
		assert.same({ 0, 1, 2, 3, 4 }, layout.bags)
		assert.is_nil(layout.reagent)
		assert.is_nil(layout.kind[5])
	end)

	-- Mutation: re-deriving on every call (no cache), or caching forever (ignoring a new table).
	it("BagLayout follows a new Enum.BagIndex table and caches the same one", function()
		local reads = 0
		local function proxy(real)
			return setmetatable({}, { __index = function(_, k)
				reads = reads + 1
				return real[k]
			end })
		end
		Enum = { BagIndex = proxy(Mock.FOREVER_BAG_INDEX) }
		local first = A.BagLayout()
		assert.same({ first = 6, last = 14 }, first.bank)
		local once = reads
		assert.truthy(once > 0)
		assert.equal(first, A.BagLayout())
		A.BagKind(12)
		A.GetBagIDs("bags")
		assert.equal(once, reads, "the same table is derived once")
		Enum.BagIndex = proxy(Mock.RETAIL_BAG_INDEX)
		local second = A.BagLayout()
		assert.truthy(reads > once, "a new table is derived again")
		assert.same({ first = 6, last = 11 }, second.bank)
	end)

	-- Mutation: restoring the literal ranges in BagKind.
	it("Forever bank tabs 7-9 (bags 12-14) are character bank, not warband", function()
		Enum = { BagIndex = Mock.FOREVER_BAG_INDEX }
		assert.same({ "bank", 7 }, { A.BagKind(12) })
		assert.same({ "bank", 9 }, { A.BagKind(14) })
		assert.same({ "warband", 1 }, { A.BagKind(15) })
		assert.same({ "warband", 9 }, { A.BagKind(23) })
		assert.same({}, { A.BagKind(24) })
	end)

	it("GetBagIDs('bags') comes from the layout", function()
		assert.same({ 0, 1, 2, 3, 4, 5 }, A.GetBagIDs("bags"), "no Enum: Retail")
		Enum = { BagIndex = Mock.RETAIL_BAG_INDEX }
		assert.same({ 0, 1, 2, 3, 4, 5 }, A.GetBagIDs("bags"), "Retail")
		Enum = { BagIndex = Mock.FOREVER_BAG_INDEX }
		assert.same({ 0, 1, 2, 3, 4, 5 }, A.GetBagIDs("bags"), "Forever")
		local bi = copy(Mock.RETAIL_BAG_INDEX)
		bi.ReagentBag = nil
		Enum = { BagIndex = bi }
		local ids = A.GetBagIDs("bags")
		assert.same({ 0, 1, 2, 3, 4 }, ids, "no reagent bag")
		ids[1] = 99
		assert.same({ 0, 1, 2, 3, 4 }, A.GetBagIDs("bags"), "a copy: the caller cannot change the layout")
	end)
end)

describe("Mock Forever bag layout", function()
	it("Mock.Forever gives the Forever layout and bag lists; the default mock keeps Retail's", function()
		local SB = Loader.New({}, { flavor = "forever" })
		assert.same({ first = 6, last = 14 }, SB.Adapter.BagLayout().bank)
		assert.same({ "bank", 7 }, { SB.Adapter.BagKind(12) })
		assert.same({ 0, 1, 2, 3, 4, 5 }, SB.Adapter.GetBagIDs("bags"))
		assert.same({}, SB.Adapter.GetBagIDs("warband"))
		local R = Loader.New({})
		assert.equal(R.Adapter.RETAIL_LAYOUT, R.Adapter.BagLayout())
		assert.same({ "warband", 1 }, { R.Adapter.BagKind(12) })
	end)
end)

-- Forever Stage A, Task 3: the gated reads give their "no data" answer on Forever before touching the game.
describe("Gated Adapter reads (real adapter, stubbed game)", function()
	local A, calls, saved
	local NAMES = { "C_Item", "C_ChallengeMode", "C_PartyInfo", "C_HousingCatalog", "ItemLocation" }

	local function counted(name, value)
		return function()
			calls[name] = (calls[name] or 0) + 1
			return value
		end
	end

	before_each(function()
		saved = {}
		for _, n in ipairs(NAMES) do
			saved[n] = _G[n]
		end
		clearGlobals()
		Enum = nil
		calls = {}
		C_Item = {
			GetItemUpgradeInfo = counted("upgrade", { trackString = "Hero", currentLevel = 3, maxLevel = 6 }),
			IsBoundToAccountUntilEquip = counted("wue", true),
		}
		C_ChallengeMode = {
			GetMapUIInfo = counted("dungeon", "Ara-Kara, City of Echoes"),
			IsChallengeModeActive = counted("challenge", true),
		}
		C_PartyInfo = { IsDelveInProgress = counted("delve", true) }
		C_HousingCatalog = { GetCatalogEntryInfoByItem = counted("decor", { totalNumPlaced = 1 }) }
		ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
		local SB = {}
		assert(loadfile("SwagBag/Core/Adapter.lua"))("SwagBag", SB)
		A = SB.Adapter
	end)

	after_each(function()
		clearGlobals()
		Enum = nil
		for _, n in ipairs(NAMES) do
			_G[n] = saved[n]
		end
	end)

	local function reads()
		local info, hasTrack = A.UpgradeInfo("item:1")
		return { info = info, hasTrack = hasTrack, dungeon = A.DungeonName(503), challenge = A.ChallengeModeActive(),
			delve = A.InDelve({ instanceType = "scenario", difficultyID = 208 }), decor = A.DecorKnown(1),
			wue = A.IsWarboundUntilEquip(0, 1) }
	end

	-- Mutation: gating after the API call (the answer is right, but the game is asked).
	it("on Forever the gated reads return no data and never call the game", function()
		WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 18, 18
		local r = reads()
		assert.is_nil(r.info)
		assert.equal(false, r.hasTrack)
		assert.is_nil(r.dungeon)
		assert.equal(false, r.challenge)
		assert.equal(false, r.delve)
		assert.is_nil(r.decor)
		assert.equal(false, r.wue)
		assert.same({}, calls)
	end)

	-- Mutation: no warband gate in GetBagIDs.
	it("on Forever GetBagIDs('warband') is empty even when C_Bank lists tabs", function()
		WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 18, 18
		Enum = { BankType = { Character = 0, Account = 2 } }
		C_Bank = { FetchPurchasedBankTabIDs = function(t)
			return t == 2 and { 15, 16 } or { 6, 7 }
		end }
		assert.same({}, A.GetBagIDs("warband"))
		assert.same({ 6, 7 }, A.GetBagIDs("bank"))
	end)

	-- Characterization (passes before and after). Mutation: a gate that answers no data on Retail too.
	it("on Retail the same reads still ask the game", function()
		local r = reads()
		assert.same({ track = "Hero", level = 3, max = 6 }, r.info)
		assert.equal(true, r.hasTrack)
		assert.equal("Ara-Kara, City of Echoes", r.dungeon)
		assert.equal(true, r.challenge)
		assert.equal(true, r.delve)
		assert.equal(true, r.decor)
		assert.equal(true, r.wue)
		assert.same({ upgrade = 1, dungeon = 1, challenge = 1, delve = 1, decor = 1, wue = 1 }, calls)
		Enum = { BankType = { Character = 0, Account = 2 } }
		C_Bank = { FetchPurchasedBankTabIDs = function(t)
			return t == 2 and { 12, 13 } or { 6, 7 }
		end }
		assert.same({ 12, 13 }, A.GetBagIDs("warband"))
	end)
end)
