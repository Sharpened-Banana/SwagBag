-- SwagBag's looks beyond the Blizzard default (UI/Theme.lua holds the registry and that default),
-- the /swagbag theme command and the Settings > Look page. A change applies at once, in or out of
-- combat, with no /reload, and is saved (settings.theme.name).
--   "flat"   Modern flat: dark flat panels, a black edge, white text, flat slots and buttons.
--   "classic" Classic (0.14.5, user request): the original game's dialog windows, a dark stone background
--            with the gold-trimmed border, gold title and header text, the old empty bag-slot squares.
--            Only Blizzard's own textures; nothing of Blizzard's frames is restyled.
--   "elvui"  Matches ElvUI: ElvUI's font, flat texture and colours, read from ElvUI itself through
--            Adapter.ElvUIMedia each time it is applied. Only while ElvUI is loaded; otherwise the
--            choice is refused with the reason, and a saved "elvui" shows the Blizzard look.
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

Theme.Register({
	id = "classic",
	name = L.THEME_CLASSIC,
	available = function()
		return true
	end,
	palette = function()
		return {
			window = { 1, 1, 1, 1 }, dialog = { 1, 1, 1, 1 }, border = { 1, 1, 1, 1 },
			header = { 1, 0.82, 0, 0.1 }, row = { 1, 0.82, 0, 0.04 },
			backdrop = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = 32,
			edge = { file = "Interface\\DialogFrame\\UI-DialogBox-Border", size = 16, inset = 4 },
			slotTexture = "Interface\\PaperDoll\\UI-Backpack-EmptySlot",
			fonts = { titleLarge = "GameFontNormalLarge", title = "GameFontNormal", header = "GameFontNormal",
				label = "GameFontNormal", body = "GameFontHighlightSmall", small = "GameFontHighlightSmall",
				row = "GameFontHighlightSmall" },
		}
	end,
})

Theme.Register({
	id = "elvui",
	name = L.THEME_ELVUI,
	unavailable = L.THEME_NO_ELVUI,
	available = function()
		return SB.Adapter.ElvUIMedia() ~= nil
	end,
	palette = function()
		local m = SB.Adapter.ElvUIMedia()
		if not m then
			return nil
		end
		local f, d = m.fade, m.backdrop
		return {
			window = { f[1], f[2], f[3], f[4] }, dialog = { f[1], f[2], f[3], math.max(f[4], 0.9) }, border = m.border,
			header = { d[1], d[2], d[3], 0.6 }, row = { d[1], d[2], d[3], 0.25 }, slot = { d[1], d[2], d[3], 1 },
			backdrop = m.blank, fonts = { file = m.font, size = m.size, flags = "OUTLINE" },
			button = { bg = { d[1], d[2], d[3], 1 } },
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
