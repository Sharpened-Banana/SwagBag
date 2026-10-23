-- luacheck: globals WOW_PROJECT_ID WOW_PROJECT_MAINLINE WOW_PROJECT_CAMELOT WOW_PROJECT_FOREVER C_Bank
-- Forever Stage A, Task 1: client flavor detection and the capability table (A.Flavor, A.FEATURES, A.Has,
-- A.Allows), with the REAL Adapter and stubbed project constants; then the mock's Forever mode.
local Loader = dofile("spec/helpers/loader.lua")

local SURFACES = { overlay = true, footer = true, mode = true, trigger = true, style = true, setting = true }

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
		assert.equal(6, features)
		assert.equal(13, pairsSeen)
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
