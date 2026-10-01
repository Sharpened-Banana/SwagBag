-- SwagBag Adapter: the ONLY file allowed to name C_* namespaces or Enum
-- (scripts/check.sh fails the build otherwise). Everything else calls SB.Adapter.*.
-- Load-time code here must stay safe outside WoW: tests load this file and then
-- replace the WoW-calling functions with fakes (spec/mock_adapter.lua).
local _, SB = ...

local A = {}
SB.Adapter = A

local function isSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end
A.IsSecret = isSecret

---------------------------------------------------------------------------
-- Basics: chat, clock, timers, combat, diagnostics
---------------------------------------------------------------------------
function A.ChatPrint(text)
	DEFAULT_CHAT_FRAME:AddMessage(text)
end

function A.Now()
	return GetTime()
end

function A.ProfileMs()
	return debugprofilestop()
end

function A.After(seconds, fn)
	C_Timer.After(seconds, fn)
end

function A.InCombat()
	return InCombatLockdown() == true
end

function A.Stack()
	return debugstack(3, 8, 0) or ""
end

function A.Date(fmt)
	return date(fmt)
end

function A.BuildInfo()
	local version, build, _, toc = GetBuildInfo()
	return { version = version, build = build, toc = toc, locale = GetLocale() }
end

-- Resolve a dotted path such as "C_Container.SortBags" without erroring.
function A.Resolve(path)
	local cur = _G
	for part in path:gmatch("[^%.]+") do
		local ok, nxt = pcall(function()
			return cur[part]
		end)
		if not ok or nxt == nil then
			return nil
		end
		cur = nxt
	end
	return cur
end

-- Returns loaded (boolean), version (string or nil) for another addon.
function A.AddOnState(name)
	if not (C_AddOns and C_AddOns.IsAddOnLoaded) then
		return false, nil
	end
	local loaded = C_AddOns.IsAddOnLoaded(name) == true
	local version = C_AddOns.GetAddOnMetadata(name, "Version")
	return loaded, version
end
