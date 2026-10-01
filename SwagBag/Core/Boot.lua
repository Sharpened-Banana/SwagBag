-- SwagBag start-up. ADDON_LOADED: settings + saved error ring.
-- PLAYER_LOGIN: feature checks, Safe Mode decisions, then SB_LOGIN for modules.
local ADDON, SB = ...

local L = SB.L

SB.On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then
		return
	end
	local status = SB.Config.Init(SwagBagDB, SwagBagCharDB)
	if status == "newer" then
		return -- never touch a newer schema; Safe Mode is switched on at login
	end
	SwagBagDB, SwagBagCharDB = SB.Config.db, SB.Config.charDB
	SB.ErrorTrap.Attach(SwagBagDB.errors)
	if status == "reset" then
		SB.ErrorTrap.OnError("Config.migrate", "none", tostring(SB.Config.lastError), "")
	end
end, "none")

SB.On("PLAYER_LOGIN", function()
	local Config, SM = SB.Config, SB.SafeMode
	SB.Checks.Apply(SB.Checks.Run())
	if Config.status == "newer" then
		SM.Enable("bags", "schema")
		SM.Enable("bank", "schema")
		SB.Print(L.NEWER_SCHEMA)
	elseif Config.status == "reset" then
		SB.Print(L.MIGRATION_FAILED)
	end
	for _, window in ipairs(SM.WINDOWS) do
		if Config.Get("safeMode." .. window) then
			SM.Enable(window, "manual")
		end
	end
	SB.Print(L.LOADED:format(SB.VERSION))
	SB.Emit("SB_LOGIN")
end)
