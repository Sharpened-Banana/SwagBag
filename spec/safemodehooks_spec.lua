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
	local SB, A, hooks, toggles, closes, windowOpen
	before_each(function()
		SB = Loader.New(FILES)
		A = SB.Adapter
		hooks, toggles, closes = {}, 0, 0
		hooksecurefunc = function(name, fn) hooks[name] = fn end
		NUM_CONTAINER_FRAMES = 2
		ContainerFrame1, ContainerFrame2 = fakeBlizzardFrame(), fakeBlizzardFrame()
		ContainerFrameCombinedBags = fakeBlizzardFrame()
		ToggleBag = function() end
		SB.Buttons = { created = true, KindOf = function(id) return id <= 5 and "bags" or "bank" end }
		windowOpen = false
		SB.BagsWindow = {
			IsOpen = function() return windowOpen end,
			Toggle = function() toggles = toggles + 1 end,
			Open = function()
				windowOpen = true
				return true
			end,
			Close = function()
				windowOpen = false
				closes = closes + 1
			end,
		}
		Loader.LoadFile(SB, "SwagBag/UI/SafeModeHooks.lua")
		SB.Emit("SB_LOGIN")
	end)

	after_each(function()
		hooksecurefunc, NUM_CONTAINER_FRAMES, ToggleBag = nil, nil, nil
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
	local function named(name)
		return { GetName = function() return name end }
	end

	it("a window the user opened stays open when a vendor frame closes (CloseAllBags(frame))", function()
		windowOpen = true -- opened with B before talking to the vendor
		hooks.OpenAllBags(named("MerchantFrame"))
		hooks.CloseAllBags(named("MerchantFrame"))
		assert.truthy(windowOpen)
		assert.equal(0, closes)
	end)

	it("a window the game opened for a frame closes with that frame", function()
		hooks.OpenAllBags(named("MerchantFrame"))
		assert.truthy(windowOpen)
		hooks.CloseAllBags(named("MerchantFrame"))
		assert.falsy(windowOpen)
	end)

	it("a window opened for one frame is not closed by another frame", function()
		hooks.OpenAllBags(named("MerchantFrame"))
		hooks.CloseAllBags(named("MailFrame"))
		assert.truthy(windowOpen)
	end)

	it("CloseAllBags() with no frame always closes", function()
		windowOpen = true
		hooks.CloseAllBags()
		assert.falsy(windowOpen)
	end)

	it("pressing the bag key forgets that the game opened the window", function()
		hooks.OpenAllBags(named("MerchantFrame"))
		hooks.ToggleAllBags()
		hooks.CloseAllBags(named("MerchantFrame"))
		assert.truthy(windowOpen)
	end)

	it("clicking a bag-bar icon (ToggleBag of a bag id) toggles once", function()
		hooks.ToggleBag(1)
		assert.equal(1, toggles)
	end)

	it("ToggleBag of a bank or warband id does nothing", function()
		hooks.ToggleBag(6)
		hooks.ToggleBag(12)
		assert.equal(0, toggles)
	end)

	it("ToggleBag and ToggleBackpack in the same frame toggle once", function()
		hooks.ToggleBag(1)
		hooks.ToggleBackpack()
		assert.equal(1, toggles)
	end)

	-- A Toggle that really opens and closes the fake window.
	local function realToggle()
		SB.BagsWindow.Toggle = function()
			toggles = toggles + 1
			windowOpen = not windowOpen
		end
	end

	it("ToggleBag ignores anything that is not a bag number 0-5 (no toggle, no Safe Mode)", function()
		hooks.ToggleBag(nil)
		hooks.ToggleBag("1")
		hooks.ToggleBag(-1)
		hooks.ToggleBag(6)
		assert.equal(0, toggles)
		assert.falsy(SB.SafeMode.IsOn("bags"))
	end)

	it("an OpenAllBags that toggles the backpack inside still counts as the game's open", function()
		realToggle()
		hooks.ToggleBackpack() -- inner call, same frame
		hooks.OpenAllBags(named("MerchantFrame"))
		assert.equal("MerchantFrame", SB.SafeModeHooks.autoOpenedBy)
		hooks.CloseAllBags(named("MerchantFrame"))
		assert.falsy(windowOpen)
	end)

	it("an OpenAllBags whose inner toggle closed a user-opened window opens it again, still the user's", function()
		realToggle()
		windowOpen = true -- opened with B earlier
		A.Advance(1)
		hooks.ToggleBackpack() -- inner call closes it
		hooks.OpenAllBags(named("MerchantFrame"))
		assert.truthy(windowOpen)
		assert.is_nil(SB.SafeModeHooks.autoOpenedBy)
		hooks.CloseAllBags(named("MerchantFrame"))
		assert.truthy(windowOpen)
	end)

	it("a bag key whose ToggleAllBags opens through OpenAllBags is the user's window", function()
		realToggle()
		hooks.OpenAllBags() -- inner call, same frame
		hooks.ToggleAllBags()
		assert.truthy(windowOpen)
		assert.equal(0, toggles)
		assert.is_nil(SB.SafeModeHooks.autoOpenedBy)
	end)

	it("a bag key whose ToggleAllBags runs OpenAllBags inside, with the window open, still closes it", function()
		realToggle()
		windowOpen = true
		A.Advance(1)
		hooks.OpenAllBags() -- inner call finds the window open and does nothing
		hooks.ToggleAllBags()
		assert.falsy(windowOpen)
		assert.equal(1, toggles)
	end)

	it("a bag key whose ToggleAllBags closes through CloseAllBags() does not reopen", function()
		realToggle()
		windowOpen = true
		A.Advance(1)
		hooks.CloseAllBags() -- inner call, same frame
		hooks.ToggleAllBags()
		assert.falsy(windowOpen)
		assert.equal(0, toggles)
	end)

	it("closing the window with Esc or X forgets that the game opened it", function()
		hooks.OpenAllBags(named("MerchantFrame"))
		assert.equal("MerchantFrame", SB.SafeModeHooks.autoOpenedBy)
		SB.Emit("SB_BAGS_CLOSED")
		assert.is_nil(SB.SafeModeHooks.autoOpenedBy)
	end)
end)
