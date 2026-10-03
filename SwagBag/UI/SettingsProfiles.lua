-- SwagBag settings: the Profiles page (week 7, user pick 12). Save the current settings as a profile,
-- load or delete one, undo the last load or import, go back to the defaults, and share: a copyable
-- string (with or without the categories) and an import that previews first. Every click runs
-- /swagbag profile, so the window and the command never disagree (P2: the status line answers).
local _, SB = ...

local L = SB.L

local function nextName()
	local taken = {}
	for _, name in ipairs(SB.Profiles.List()) do
		taken[name] = true
	end
	local n = 1
	while taken[L.PROFILE_AUTO_NAME:format(n)] do
		n = n + 1
	end
	return L.PROFILE_AUTO_NAME:format(n)
end

local function rows()
	local run = SB.SettingsWindow.RunCommand
	local out = {
		{ kind = "note", label = L.SET_PROFILES_NOTE },
		{ kind = "actions", label = L.SET_PROFILES_SAVE, actions = {
			{ text = L.SET_PROFILES_SAVE_BUTTON, width = 160, run = function()
				return run("profile save " .. nextName())
			end },
		} },
	}
	for _, name in ipairs(SB.Profiles.List()) do
		local current = SB.Config.db.profile == name
		out[#out + 1] = { kind = "actions", label = current and L.SET_PROFILE_CURRENT:format(name) or name, actions = {
			{ text = L.SET_PROFILE_LOAD, width = 80, run = function()
				return run("profile load " .. name)
			end },
			{ text = L.SET_PROFILE_DELETE, width = 80, run = function()
				return run("profile delete " .. name)
			end },
		} }
	end
	out[#out + 1] = { kind = "actions", label = L.SET_PROFILES_SHARE, actions = {
		{ text = L.SET_SHARE_EXPORT, run = function()
			return run("profile export")
		end },
		{ text = L.SET_SHARE_EXPORT_CATS, width = 160, run = function()
			return run("profile export categories")
		end },
		{ text = L.SET_SHARE_IMPORT, run = function()
			return run("profile import")
		end },
	} }
	out[#out + 1] = { kind = "actions", label = L.SET_PROFILES_BACK, actions = {
		{ text = L.SET_PROFILES_UNDO, width = 160, run = function()
			return run("profile undo")
		end },
		{ text = L.SET_PROFILES_DEFAULTS, run = function()
			return run("profile reset")
		end },
	} }
	return out
end

SB.SettingsWindow.AddPage({ id = "profiles", title = L.SET_PAGE_PROFILES, rows = rows })
