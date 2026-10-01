-- SwagBag blocked-action log: every ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN
-- that names SwagBag is kept (last 20) and shown in /swagbag report, so in-game
-- checks V1, V3 and V9 can be confirmed from the report instead of from memory.
local ADDON, SB = ...

local Blocked = { list = {}, MAX = 20 }
SB.Blocked = Blocked

local function onBlocked(event, addon, func)
	if addon ~= ADDON then
		return
	end
	local A = SB.Adapter
	local list = Blocked.list
	list[#list + 1] = { time = A.Date("%H:%M:%S"), event = event, func = tostring(func), combat = A.InCombat() }
	while #list > Blocked.MAX do
		table.remove(list, 1)
	end
end

SB.On("ADDON_ACTION_BLOCKED", onBlocked, "none")
SB.On("ADDON_ACTION_FORBIDDEN", onBlocked, "none")
