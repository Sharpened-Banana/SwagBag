-- SwagBag Safe Mode hooks (spec 10.1, proven in spike S).
-- While SwagBag is active for bags (Safe Mode off and the button pool exists):
--   * B / ToggleAllBags / ToggleBackpack / ToggleBag(0-5) toggle SwagBag's window,
--   * OpenAllBags / CloseAllBags (vendor, mailbox, ...) open/close it,
--   * ContainerFrame1..N and ContainerFrameCombinedBags hide themselves on show.
-- The hooks only check a flag, so flipping Safe Mode is the whole toggle - legal
-- in and out of combat. We never CALL any Blizzard bag-opening function.
--
-- One frame, one action: a Blizzard bag function may call another one inside it
-- (OpenAllBags -> ToggleBackpack, ToggleAllBags -> OpenAllBags/CloseAllBags), and the
-- inner hook runs BEFORE the outer one. So every hook notes what it did in this frame
-- (lastAt = GetTime(), lastKind), and a second hook in the same frame only corrects
-- the bookkeeping instead of toggling again.
local _, SB = ...

-- autoOpenedBy: set when the game's OpenAllBags (vendor, mailbox, ...) opened our window,
-- so only the matching CloseAllBags(frame) closes it again; a window the user opened stays.
-- lastKind: "toggle" (a bag key toggled), "auto" (OpenAllBags opened it), "closed"
-- (CloseAllBags closed it), "none" (OpenAllBags found it already open).
local Hooks = { installed = false, lastAt = -1, lastKind = nil, toggleOpened = false, autoOpenedBy = nil }
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

local function frameName(frame)
	return (frame and frame.GetName and frame:GetName()) or true
end

-- B / backpack / bag-bar icon.
local function onBagKey()
	if not Hooks.IsActive() then
		Hooks.autoOpenedBy = nil
		return
	end
	local now = SB.Adapter.Now()
	if now == Hooks.lastAt then
		-- An inner OpenAllBags already opened the window for this key press: it is the
		-- user's window, not the game's. An inner OpenAllBags that found the window open
		-- ("none") did nothing, so this key press still toggles. Anything else already acted.
		if Hooks.lastKind == "auto" then
			Hooks.autoOpenedBy = nil
			Hooks.lastKind = "toggle"
			return
		elseif Hooks.lastKind ~= "none" then
			return
		end
	end
	Hooks.autoOpenedBy = nil
	local W = SB.BagsWindow
	local wasOpen = W.IsOpen()
	W.Toggle()
	Hooks.lastAt, Hooks.lastKind = now, "toggle"
	Hooks.toggleOpened = not wasOpen and W.IsOpen()
end

-- OpenAllBags hook (arg: the frame that wants the bags, e.g. MerchantFrame).
local function onOpenAll(frame)
	if not Hooks.IsActive() then
		return
	end
	local W = SB.BagsWindow
	local now = SB.Adapter.Now()
	if now == Hooks.lastAt and Hooks.lastKind ~= "closed" then
		-- A toggle hook ran inside this OpenAllBags. If it opened the window, the game
		-- opened it; if it closed a window the user had open, open it again.
		if Hooks.lastKind == "toggle" then
			if Hooks.toggleOpened then
				Hooks.autoOpenedBy = frameName(frame)
			elseif not W.IsOpen() then
				W.Open()
			end
		end
		return
	end
	Hooks.lastAt = now
	if W.IsOpen() then
		Hooks.lastKind = "none"
		return
	end
	if W.Open() then
		Hooks.autoOpenedBy = frameName(frame)
		Hooks.lastKind = "auto"
	end
end

-- CloseAllBags(frame): close only a window the game opened for that frame
-- (CloseAllBags() with no frame always closes).
local function onCloseAll(frame)
	if not Hooks.IsActive() then
		return
	end
	local by = Hooks.autoOpenedBy
	if frame == nil or (by and (by == true or (frame.GetName and frame:GetName() == by))) then
		local wasOpen = SB.BagsWindow.IsOpen()
		SB.BagsWindow.Close()
		Hooks.autoOpenedBy = nil
		if wasOpen then
			Hooks.lastAt, Hooks.lastKind = SB.Adapter.Now(), "closed"
		end
	end
end

function Hooks.Install()
	if Hooks.installed then
		return
	end
	Hooks.installed = true
	local Guard = SB.ErrorTrap.Guard
	hooksecurefunc("ToggleAllBags", Guard("hook:ToggleAllBags", onBagKey, "bags"))
	hooksecurefunc("ToggleBackpack", Guard("hook:ToggleBackpack", onBagKey, "bags"))
	if ToggleBag then
		-- Only the bag-bar IDs 0-5; never bank tabs, nil or other values.
		hooksecurefunc("ToggleBag", Guard("hook:ToggleBag", function(id)
			if type(id) == "number" and id >= 0 and id <= 5 then
				onBagKey()
			end
		end, "bags"))
	end
	hooksecurefunc("OpenAllBags", Guard("hook:OpenAllBags", onOpenAll, "bags"))
	hooksecurefunc("CloseAllBags", Guard("hook:CloseAllBags", onCloseAll, "bags"))
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

-- The window was hidden (Esc, X, or any close): the game no longer owns it.
SB.On("SB_BAGS_CLOSED", function()
	Hooks.autoOpenedBy = nil
end, "bags")

-- Pool created late (login or /reload in combat): SwagBag takes over from here on.
SB.On("SB_BUTTONS_READY", function()
	if Hooks.installed and Hooks.IsActive() then
		Hooks.HideBlizzardBags()
	end
end, "bags")

SB.On("SB_LOGIN", function()
	Hooks.Install()
end, "bags")
