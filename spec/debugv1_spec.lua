-- luacheck: globals CreateFrame UIParent UISpecialFrames
local Loader = dofile("spec/helpers/loader.lua")
local Fixtures = dofile("spec/fixtures/items.lua")

local function newFake()
	local f = { shown = false, scripts = {}, calls = {} }
	return setmetatable(f, {
		__index = function(_, name)
			if name == "SetScript" then
				return function(s, n, fn) s.scripts[n] = fn end
			elseif name == "Show" then
				return function(s) s.shown = true end
			elseif name == "Hide" then
				return function(s) s.shown = false end
			elseif name == "IsShown" then
				return function(s) return s.shown end
			elseif name == "CreateFontString" then
				return function() return newFake() end
			elseif name == "SetBagID" or name == "SetID" then
				return function(s, v) s.calls[name] = v end
			end
			return function() end
		end,
	})
end

describe("DebugV1", function()
	local SB, V1, created, painted

	before_each(function()
		SB = Loader.New({
			"SwagBag/Core/Events.lua", "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua",
		})
		Fixtures.SmallBags(SB.Adapter)
		created = {}
		painted = 0
		CreateFrame = function(kind, name)
			local f = newFake()
			created[#created + 1] = { kind = kind, name = name, frame = f }
			return f
		end
		UIParent = newFake()
		UISpecialFrames = {}
		SB.Buttons = { Paint = function() painted = painted + 1 end }
		Loader.LoadFile(SB, "SwagBag/UI/DebugV1.lua")
		V1 = SB.DebugV1
	end)

	it("creates nothing at load: the probe is opt-in", function()
		assert.equal(0, #created)
	end)

	it("refuses in combat and creates no frames or buttons", function()
		SB.Adapter.combat = true
		assert.equal(SB.L.V1_COMBAT, V1.Toggle())
		assert.equal(0, #created)
	end)

	it("shows the strip out of combat, fills it, and hides it on the second call", function()
		local line = V1.Toggle()
		assert.truthy(line:find("^V1 strip shown with %d+ usable items"))
		assert.equal("SwagBagV1Strip", created[1].name)
		assert.truthy(created[1].frame.shown)
		assert.truthy(painted > 0)
		assert.equal(SB.L.V1_HIDDEN, V1.Toggle())
		assert.falsy(created[1].frame.shown)
	end)

	it("runs the drag scripts inside the error trap", function()
		V1.Toggle()
		local strip = created[1].frame
		strip.StartMoving = function() error("boom", 0) end
		strip.StopMovingOrSizing = function() error("boom", 0) end
		strip.scripts.OnDragStart(strip)
		strip.scripts.OnDragStop(strip)
		assert.equal(2, SB.ErrorTrap.count)
	end)
end)
