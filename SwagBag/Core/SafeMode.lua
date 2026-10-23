-- SwagBag Safe Mode state: one flag per window ("bags", "bank").
-- When a window's flag is on, SwagBag leaves that window to Blizzard.
-- The WoW hooks that act on these flags live in UI/SafeModeHooks.lua.
local _, SB = ...

local SM = {}
SB.SafeMode = SM

SM.WINDOWS = { "bags", "bank" }
SM.state = { bags = { on = false }, bank = { on = false } }

local function emit(window, on, reason)
	if SB.Emit then
		SB.Emit("SB_SAFEMODE_CHANGED", window, on, reason)
	end
end

function SM.IsOn(window)
	local s = SM.state[window]
	return s ~= nil and s.on
end

-- The reason a window is in Safe Mode, or nil while it is off.
function SM.Reason(window)
	local s = SM.state[window]
	if s and s.on then
		return s.reason
	end
	return nil
end

-- WoW Forever (Forever Stage A): the bank and guild bank are Blizzard's (reason "forever", Core/Boot.lua). The first
-- bank or guild-bank visit of the session says so in one chat line; never at login. True if it printed.
function SM.ForeverNotice()
	if SM.foreverTold or SM.Reason("bank") ~= "forever" then
		return false
	end
	SM.foreverTold = true
	SB.Print(SB.L.FOREVER_BANK_OFF)
	return true
end

-- reason: "manual" | "auto" | "check" | "schema" | "forever". Returns true if it changed.
function SM.Enable(window, reason)
	local s = SM.state[window]
	if not s or s.on then
		return false
	end
	s.on = true
	s.reason = reason or "manual"
	s.since = SB.Adapter.Date("%H:%M")
	s.offAt = nil
	emit(window, true, s.reason)
	return true
end

function SM.Disable(window)
	local s = SM.state[window]
	if not s or not s.on then
		return false
	end
	s.on = false
	s.reason = nil
	s.since = nil
	s.offAt = SB.Adapter.Now()
	emit(window, false, nil)
	return true
end

-- True if the window was switched off within the last `seconds`.
function SM.RecentlyDisabled(window, seconds)
	local s = SM.state[window]
	return s ~= nil and s.offAt ~= nil and (SB.Adapter.Now() - s.offAt) <= seconds
end

-- "off" or "on (auto, 21:01)" for /swagbag report and /swagbag safe.
function SM.Describe(window)
	local s = SM.state[window]
	local L = SB.L
	if not s.on then
		return L.SAFE_STATE_OFF
	end
	return L.SAFE_STATE_ON:format(L["SAFE_REASON_" .. s.reason:upper()], s.since)
end
