-- SwagBag's looks beyond the Blizzard default (UI/Theme.lua holds the registry and that default),
-- the /swagbag theme command and the Settings > Look page. A change applies at once, in or out of
-- combat, with no /reload, and is saved (settings.theme.name).
--   "flat"  Modern flat: dark flat panels, a black edge, white text, flat slots and buttons.
local _, SB = ...

local L = SB.L
local Theme = SB.Theme

Theme.Register({
	id = "flat",
	name = L.THEME_FLAT,
	available = function()
		return true
	end,
	palette = function()
		return {
			window = { 0.09, 0.09, 0.1, 0.92 }, dialog = { 0.09, 0.09, 0.1, 0.96 }, border = { 0, 0, 0, 1 },
			header = { 1, 1, 1, 0.03 }, row = { 1, 1, 1, 0.025 }, slot = { 0.14, 0.14, 0.15, 1 }, backdrop = Theme.BLANK,
			fonts = { titleLarge = "GameFontHighlightLarge", title = "GameFontHighlight", header = "GameFontHighlight", label = "GameFontHighlight",
				body = "GameFontHighlightSmall", small = "GameFontHighlightSmall", row = "GameFontHighlightSmall" },
			button = { bg = { 0.16, 0.16, 0.18, 1 } },
		}
	end,
})

local function list()
	local parts = {}
	for _, id in ipairs(Theme.order) do
		local name = Theme.Name(id)
		if not Theme.Available(id) then
			name = L.THEME_NOT_LOADED:format(name)
		end
		parts[#parts + 1] = L.THEME_ITEM:format(id, name)
	end
	return table.concat(parts, ", ")
end

-- /swagbag theme              the current look and every look there is
-- /swagbag theme <id>         switch (saved); a look that cannot be used now says why
SB.Slash.Register("theme", L.HELP_THEME, function(arg)
	local id = (arg or ""):lower():match("^(%S*)")
	if id == "" then
		return L.THEME_STATE:format(Theme.Name(Theme.Current()), list())
	end
	local ok, why = Theme.Apply(id, true)
	if ok then
		return L.THEME_SET:format(Theme.Name(id))
	elseif why == "readonly" then
		return L.SETTINGS_READONLY
	elseif why == "unavailable" then
		local def = Theme.themes[id]
		return (def.unavailable or L.THEME_UNAVAILABLE):format(Theme.Name(Theme.Current()))
	end
	return L.THEME_USAGE:format(list())
end, "none")

-- Settings > Look: one choice, the Blizzard look first (the default, P1). Runs /swagbag theme (D17).
if SB.SettingsWindow then
	local function lookRows()
		local choices = {}
		for _, id in ipairs(Theme.order) do
			choices[#choices + 1] = { value = id, text = Theme.Name(id) }
		end
		return {
			{ kind = "choice", label = L.SET_LOOK, get = Theme.Current, choices = choices,
				apply = function(v)
					return SB.SettingsWindow.RunCommand("theme " .. v)
				end },
			{ kind = "note", label = L.SET_LOOK_NOTE },
		}
	end
	SB.SettingsWindow.AddPage({ id = "look", title = L.SET_PAGE_LOOK, rows = lookRows })
end
