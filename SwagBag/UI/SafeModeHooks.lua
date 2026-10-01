-- SwagBag Safe Mode hooks (spec 10.1, proven in spike S).
-- While SwagBag is active for bags (Safe Mode off and the button pool exists):
--   * B / ToggleAllBags / ToggleBackpack toggle SwagBag's window,
--   * OpenAllBags / CloseAllBags (vendor, mailbox, ...) open/close it,
--   * ContainerFrame1..N and ContainerFrameCombinedBags hide themselves on show.
-- The hooks only check a flag, so flipping Safe Mode is the whole toggle - legal
-- in and out of combat. We never CALL any Blizzard bag-opening function.
local _, SB = ...

local Hooks = { installed = false, lastToggle = -1 }
SB.SafeModeHooks = Hooks

function Hooks.IsActive()
	return SB.Buttons.created and not SB.SafeMode.IsOn("bags")
end

local function blizzardBagFrames()
	local list = {}
	for i = 1, (NUM_CONTAINER_FRAMES or 13) do
		local f = _G["ContainerFrame" .. i]
		if f then
			list[#list + 1] = f
		end
	end
	if ContainerFrameCombinedBags then
		list[#list + 1] = ContainerFrameCombinedBags
	end
	return list
end

function Hooks.HideBlizzardBags()
	for _, f in ipairs(blizzardBagFrames()) do
		if f:IsShown() then
			f:Hide()
		end
	end
end

-- One key press can run several hooked bag functions in the same frame; act once.
local function onBagKey()
	if not Hooks.IsActive() then
		return
	end
	local now = SB.Adapter.Now()
	if now == Hooks.lastToggle then
		return
	end
	Hooks.lastToggle = now
	SB.BagsWindow.Toggle()
end

function Hooks.Install()
	if Hooks.installed then
		return
	end
	Hooks.installed = true
	local Guard = SB.ErrorTrap.Guard
	hooksecurefunc("ToggleAllBags", Guard("hook:ToggleAllBags", onBagKey, "bags"))
	hooksecurefunc("ToggleBackpack", Guard("hook:ToggleBackpack", onBagKey, "bags"))
	hooksecurefunc("OpenAllBags", Guard("hook:OpenAllBags", function()
		if Hooks.IsActive() then
			SB.BagsWindow.Open()
		end
	end, "bags"))
	hooksecurefunc("CloseAllBags", Guard("hook:CloseAllBags", function()
		if Hooks.IsActive() then
			SB.BagsWindow.Close()
		end
	end, "bags"))
	for _, f in ipairs(blizzardBagFrames()) do
		f:HookScript("OnShow", Guard("hook:BlizzardBagOnShow", function(self)
			if Hooks.IsActive() then
				self:Hide()
			end
		end, "bags"))
	end
	if Hooks.IsActive() then
		Hooks.HideBlizzardBags()
	end
end

-- Safe Mode on: close our window (Blizzard's bags answer the next B press).
-- Safe Mode off: hide any open Blizzard bag frame (ours answers the next B press).
SB.On("SB_SAFEMODE_CHANGED", function(_, window, on)
	if window ~= "bags" then
		return
	end
	if on then
		SB.BagsWindow.Close()
	elseif Hooks.installed then
		Hooks.HideBlizzardBags()
	end
end, "none")

-- Pool created late (login or /reload in combat): SwagBag takes over from here on.
SB.On("SB_BUTTONS_READY", function()
	if Hooks.installed and Hooks.IsActive() then
		Hooks.HideBlizzardBags()
	end
end, "bags")

SB.On("SB_LOGIN", function()
	Hooks.Install()
end, "bags")
