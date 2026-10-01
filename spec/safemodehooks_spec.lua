local Loader = dofile("spec/helpers/loader.lua")

local FILES = { "SwagBag/Core/SafeMode.lua", "SwagBag/Core/ErrorTrap.lua", "SwagBag/Core/Events.lua" }

-- A Blizzard bag frame stand-in: remembers OnShow hooks and its shown state.
local function fakeBlizzardFrame()
	local f = { shown = false, hooks = {} }
	function f:HookScript(_, fn) self.hooks[#self.hooks + 1] = fn end
	function f:IsShown() return self.shown end
	function f:Hide() self.shown = false end
	function f:Show()
		self.shown = true
		for _, fn in ipairs(self.hooks) do fn(self) end
	end
	return f
end

describe("SafeModeHooks", function()
	local SB, A, hooks, toggles, closes
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		hooks, toggles, closes = {}, 0, 0
		hooksecurefunc = function(name, fn) hooks[name] = fn end
		NUM_CONTAINER_FRAMES = 2
		ContainerFrame1, ContainerFrame2 = fakeBlizzardFrame(), fakeBlizzardFrame()
		ContainerFrameCombinedBags = fakeBlizzardFrame()
		SB.Buttons = { created = true }
		SB.BagsWindow = {
			Toggle = function() toggles = toggles + 1 end,
			Open = function() end,
			Close = function() closes = closes + 1 end,
		}
		Loader.LoadFile(SB, "SwagBag/UI/SafeModeHooks.lua")
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		hooksecurefunc, NUM_CONTAINER_FRAMES = nil, nil
		ContainerFrame1, ContainerFrame2, ContainerFrameCombinedBags = nil, nil, nil
	end)

	it("the bag key toggles SwagBag once per frame even when two bag functions fire", function()
		hooks.ToggleAllBags()
		hooks.ToggleBackpack()
		assert.equal(1, toggles)
		A.Advance(0.1)
		hooks.ToggleBackpack()
		assert.equal(2, toggles)
	end)

	it("Blizzard bag frames hide themselves while SwagBag is active", function()
		ContainerFrameCombinedBags:Show()
		assert.falsy(ContainerFrameCombinedBags:IsShown())
	end)

	it("in Safe Mode the hooks step aside: no toggle, Blizzard frames stay open", function()
		SB.SafeMode.Enable("bags", "manual")
		hooks.ToggleAllBags()
		assert.equal(0, toggles)
		ContainerFrame1:Show()
		assert.truthy(ContainerFrame1:IsShown())
	end)

	it("turning Safe Mode on closes SwagBag's window; turning it off hides Blizzard's", function()
		SB.SafeMode.Enable("bags", "auto")
		assert.equal(1, closes)
		ContainerFrame2:Show()
		SB.SafeMode.Disable("bags")
		assert.falsy(ContainerFrame2:IsShown())
	end)

	it("stays inactive until the button pool exists (login or /reload in combat)", function()
		SB.Buttons.created = false
		assert.falsy(SB.SafeModeHooks.IsActive())
		hooks.ToggleAllBags()
		assert.equal(0, toggles)
		ContainerFrame1:Show()
		assert.truthy(ContainerFrame1:IsShown(), "Blizzard bags must keep working meanwhile")
	end)

	it("when the pool becomes ready later, open Blizzard bags close so SwagBag takes over", function()
		SB.Buttons.created = false
		ContainerFrame1:Show()
		SB.Buttons.created = true
		SB.Emit("SB_BUTTONS_READY")
		assert.falsy(ContainerFrame1:IsShown())
	end)

	it("an error inside a hook flips bags to Safe Mode instead of breaking the bag key", function()
		SB.BagsWindow.Toggle = function() error("toggle broke") end
		hooks.ToggleAllBags()
		assert.truthy(SB.SafeMode.IsOn("bags"))
		assert.equal("hook:ToggleAllBags", SB.ErrorTrap.Recent()[1].label)
	end)
end)
