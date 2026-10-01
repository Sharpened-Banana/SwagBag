-- SwagBag week-1 slash commands: safe, report, check, reset, debug.
-- (help lives in Core/Slash.lua; search is registered by UI/SearchBox.lua.)
local _, SB = ...

local L = SB.L
local Slash = SB.Slash
local Commands = {}
SB.Commands = Commands

local function windowName(window)
	return window == "bank" and L.WINDOW_BANK or L.WINDOW_BAGS
end

-- Switch one window's Safe Mode and remember the choice. Returns the feedback line.
function Commands.SetSafe(window, on)
	local SM = SB.SafeMode
	local changed
	if on then
		changed = SM.Enable(window, "manual")
	else
		changed = SM.Disable(window)
	end
	SB.Config.Set("safeMode." .. window, on)
	if changed then
		return (on and L.SAFE_NOW_ON or L.SAFE_NOW_OFF):format(windowName(window))
	end
	return (on and L.SAFE_ALREADY_ON or L.SAFE_ALREADY_OFF):format(windowName(window))
end

Slash.Register("safe", L.HELP_SAFE, function(arg)
	local SM = SB.SafeMode
	arg = arg:lower()
	if arg == "" then
		return L.SAFE_STATUS:format(SM.Describe("bags"), SM.Describe("bank"))
	elseif arg == "on" or arg == "off" then
		return { Commands.SetSafe("bags", arg == "on"), Commands.SetSafe("bank", arg == "on") }
	elseif arg == "bags" or arg == "bank" then
		return Commands.SetSafe(arg, not SM.IsOn(arg))
	end
	return L.SAFE_USAGE
end)

Slash.Register("report", L.HELP_REPORT, function()
	SB.ReportBox.Show(SB.Report.Build())
	return L.REPORT_OPENED
end)

Slash.Register("check", L.HELP_CHECK, function()
	return SB.Checks.Lines(SB.Checks.Run())
end)

-- Called by the confirmation dialog. Swaps in fresh SavedVariables tables.
function Commands.DoReset()
	SwagBagDB, SwagBagCharDB = SB.Config.Reset()
	SB.ErrorTrap.Attach(SwagBagDB.errors)
	if SB.Categories then
		SB.Categories.Load()
	end
	if SB.BagsWindow and SB.BagsWindow.Close then
		SB.BagsWindow.Close()
	end
	SB.Print(L.RESET_DONE)
end

if StaticPopupDialogs then
	StaticPopupDialogs.SWAGBAG_RESET = {
		text = L.RESET_CONFIRM,
		button1 = YES,
		button2 = NO,
		OnAccept = SB.ErrorTrap.Guard("reset", Commands.DoReset, "none"),
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
end

Slash.Register("reset", L.HELP_RESET, function()
	StaticPopup_Show("SWAGBAG_RESET")
	return L.RESET_ASKED
end)

Slash.Register("debug", L.HELP_DEBUG, function(arg)
	local what, window = arg:lower():match("^(%S*)%s*(%S*)")
	if what == "v1" and SB.DebugV1 then
		return SB.DebugV1.Toggle()
	end
	if what ~= "error" then
		return L.DEBUG_USAGE
	end
	window = window == "bank" and "bank" or "bags"
	SB.ErrorTrap.Run("debug:error", window, function()
		error(L.DEBUG_ERROR_TEXT, 0)
	end)
	return L.DEBUG_ERROR_DONE:format(windowName(window))
end)
