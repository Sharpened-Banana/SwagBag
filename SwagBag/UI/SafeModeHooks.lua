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
-- Who owns the window (week 6, D16): a window the user opened (B, a bag icon) closes only by the
-- user's own hand (B, Esc, the X). No CloseAllBags closes it, with a frame or without one, and a
-- bag toggle that runs inside a frame's CloseAllBags and closes it opens it again. A window the
-- game opened for a frame (its OpenAllBags named that frame) closes with that frame's CloseAllBags,
-- or with a CloseAllBags() that names no frame.
-- Hooks.TraceText() -> text: the last TRACE hook calls (hook, its argument, what SwagBag did, when),
-- oldest first, for /swagbag report ("Bag hooks (last 5): ...").
local _, SB = ...

-- autoOpenedBy: set when the game's OpenAllBags (vendor, mailbox, ...) opened our window,
-- so only the matching CloseAllBags(frame) closes it again; a window the user opened stays.
-- lastKind: "toggle" (a bag key toggled), "auto" (OpenAllBags opened it), "closed"
-- (CloseAllBags closed it), "none" (OpenAllBags found it already open).
-- toggleClosedUsers: the last toggle closed a window the user had opened (D16).
local Hooks = { installed = false, lastAt = -1, lastKind = nil, toggleOpened = false, toggleClosedUsers = false,
	autoOpenedBy = nil, trace = {}, TRACE = 5 }
SB.SafeModeHooks = Hooks

-- The trace (week 6): one entry per hook call, the newest last, at most TRACE of them.
local function note(kind, arg, did)
	local t = Hooks.trace
	t[#t + 1] = { kind = kind, arg = arg, did = did, at = SB.Adapter.Now() }
	if #t > Hooks.TRACE then
		table.remove(t, 1)
	end
end

local function argName(frame)
	if frame == nil then
		return "nil"
	end
	local name = frame.GetName and frame:GetName()
	return type(name) == "string" and name or "?"
end

local function didText(did)
	local L = SB.L
	return ({ opened = L.HOOK_OPENED, closed = L.HOOK_CLOSED, kept = L.HOOK_KEPT, reopened = L.HOOK_REOPENED,
		game = L.HOOK_GAME, user = L.HOOK_USER, nothing = L.HOOK_NOTHING, inactive = L.HOOK_INACTIVE })[did] or did
end

function Hooks.TraceText()
	local L, parts = SB.L, {}
	for i, e in ipairs(Hooks.trace) do
		parts[i] = L.REPORT_BAG_HOOK:format(e.kind, e.arg, didText(e.did), e.at)
	end
	return #parts > 0 and table.concat(parts, ", ") or L.REPORT_NONE
end

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

-- B / backpack / bag-bar icon. kind: the hook's name; arg: ToggleBag's bag number or "".
local function onBagKey(kind, arg)
	if not Hooks.IsActive() then
		Hooks.autoOpenedBy = nil
		note(kind, arg, "inactive")
		return
	end
	local now = SB.Adapter.Now()
	if now == Hooks.lastAt then
		-- An inner OpenAllBags already opened the window for this key press: it is the
		-- user's window, not the game's. An inner OpenAllBags that found the window open
		-- ("none") did nothing, so this key press still toggles. Anything else already acted.
		if Hooks.lastKind == "auto" then
			Hooks.autoOpenedBy = nil
			Hooks.toggleClosedUsers = false -- this press opened it: no earlier close is still pending
			Hooks.lastKind = "toggle"
			note(kind, arg, "user")
			return
		elseif Hooks.lastKind ~= "none" then
			note(kind, arg, "nothing")
			return
		end
	end
	local wasUsers = Hooks.autoOpenedBy == nil
	Hooks.autoOpenedBy = nil
	local W = SB.BagsWindow
	local wasOpen = W.IsOpen()
	W.Toggle()
	Hooks.lastAt, Hooks.lastKind = now, "toggle"
	Hooks.toggleOpened = not wasOpen and W.IsOpen()
	Hooks.toggleClosedUsers = wasOpen and wasUsers and not W.IsOpen()
	note(kind, arg, W.IsOpen() and "opened" or "closed")
end

-- OpenAllBags hook (arg: the frame that wants the bags, e.g. MerchantFrame).
local function onOpenAll(frame)
	local arg = argName(frame)
	if not Hooks.IsActive() then
		note("OpenAllBags", arg, "inactive")
		return
	end
	local W = SB.BagsWindow
	local now = SB.Adapter.Now()
	if now == Hooks.lastAt and Hooks.lastKind ~= "closed" then
		-- A toggle hook ran inside this OpenAllBags. If it opened the window, the game
		-- opened it; if it closed a window the user had open, open it again.
		local did = "nothing"
		if Hooks.lastKind == "toggle" then
			if Hooks.toggleOpened then
				Hooks.autoOpenedBy = frameName(frame)
				did = "game"
			elseif not W.IsOpen() then
				W.Open()
				did = "reopened"
			end
		end
		note("OpenAllBags", arg, did)
		return
	end
	Hooks.lastAt = now
	if W.IsOpen() then
		Hooks.lastKind = "none"
		note("OpenAllBags", arg, "nothing")
		return
	end
	if W.Open() then
		Hooks.autoOpenedBy = frameName(frame)
		Hooks.lastKind = "auto"
		note("OpenAllBags", arg, "opened")
	else
		note("OpenAllBags", arg, "nothing")
	end
end

-- CloseAllBags(frame) (D16): closes only a window the game opened, for that frame (any frame
-- when its OpenAllBags named none), or with no frame at all. A window the user opened stays,
-- with or without a frame: the vendor's walk-away close (FM1 step 8) leaves it open, as
-- Blizzard's own bags stay open after a vendor that did not open them.
local function onCloseAll(frame)
	local arg = argName(frame)
	if not Hooks.IsActive() then
		note("CloseAllBags", arg, "inactive")
		return
	end
	local W = SB.BagsWindow
	local now = SB.Adapter.Now()
	if frame ~= nil and now == Hooks.lastAt and Hooks.lastKind == "toggle" and Hooks.toggleClosedUsers then
		-- A bag toggle ran inside this frame's CloseAllBags and closed the user's window: open it
		-- again. Never for CloseAllBags() with no frame: that runs inside the bag key itself.
		Hooks.toggleClosedUsers = false
		W.Open()
		note("CloseAllBags", arg, "reopened")
		return
	end
	local by = Hooks.autoOpenedBy
	if by and (by == true or frame == nil or (frame.GetName and frame:GetName() == by)) then
		local wasOpen = W.IsOpen()
		W.Close()
		Hooks.autoOpenedBy = nil
		if wasOpen then
			Hooks.lastAt, Hooks.lastKind = now, "closed"
		end
		note("CloseAllBags", arg, wasOpen and "closed" or "nothing")
		return
	end
	note("CloseAllBags", arg, W.IsOpen() and "kept" or "nothing")
end

function Hooks.Install()
	if Hooks.installed then
		return
	end
	Hooks.installed = true
	local Guard = SB.ErrorTrap.Guard
	hooksecurefunc("ToggleAllBags", Guard("hook:ToggleAllBags", function()
		onBagKey("ToggleAllBags", "")
	end, "bags"))
	hooksecurefunc("ToggleBackpack", Guard("hook:ToggleBackpack", function()
		onBagKey("ToggleBackpack", "")
	end, "bags"))
	if ToggleBag then
		-- Only the bag-bar IDs from the Adapter's bag layout; never bank tabs, nil or other values.
		hooksecurefunc("ToggleBag", Guard("hook:ToggleBag", function(id)
			local k = type(id) == "number" and SB.Adapter.BagKind(id)
			if k == "backpack" or k == "bags" or k == "reagentbag" then
				onBagKey("ToggleBag", tostring(id))
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
