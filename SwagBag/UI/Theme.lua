-- SwagBag themes (spec 3.2 "Theme", AC14.1, 2.2 v1.3): how SwagBag's OWN frames look. A theme
-- is a palette; the frames register here once and are restyled whenever the theme changes, live,
-- in or out of combat (no /reload). What a theme touches, and nothing else:
--   Theme.Window(frame, kind)  a window's backdrop (kind "main": bags, bank, guild bank, alt viewer;
--                              "dialog": settings, quick setup). frame uses "BackdropTemplate"
--   Theme.Text(fs, role)       a font string's font (role "title" | "titleLarge" (settings, setup) |
--                              "header" | "label" | "body" | "small" | "row"); the Blizzard look puts back the font it was made with
--   Theme.Button(b)            SwagBag's own UIPanelButtonTemplate buttons (title buttons, settings):
--                              a flat look hides the template's Left/Middle/Right textures and shows a
--                              flat texture of SwagBag's own; never an item button or a secure frame
--   Theme.Slot(texture)        the slot background SwagBag adds under each item button (Buttons.lua):
--                              SwagBag's own texture region, as in week 3 (regions only, nothing of
--                              Blizzard's is restyled)
--   Theme.Row(row)             a list-view row's background (UI/ListRows.lua)
--   Theme.HeaderColor() -> r, g, b, a   section headers' background (UI/SectionHeaders.lua)
-- The "blizzard" theme (built in, the default) is exactly the look SwagBag had before themes
-- (AC14.1): the same backdrop colours, Blizzard's fonts and the bag-slot atlas. More themes come
-- from UI/Themes.lua. Theme.Register{ id, name, available() -> bool, unavailable (text), palette() }
--   palette = { window, dialog, border = { r, g, b, a }, header = { r, g, b, a }, row = colour | nil,
--     slot = colour | nil (nil: the bag-slot atlas), backdrop = texture path, fonts = nil | { [role] =
--     font object name } | { file, size, flags } (one font file, sizes by role), button = nil | { bg, border },
--     edge = nil | { file, size, inset } (a textured window border; nil: a 1 px line in the backdrop texture),
--     tile = nil | size (the backdrop texture repeats in squares of that size), slotTexture = nil | texture path
--     (drawn under each slot instead of the slot colour or atlas; 0.14.5, the Classic look) }
--   Theme.Apply(id, save) -> ok, why   why: "unknown" | "unavailable" | "readonly"; save writes
--     settings.theme.name. Emits SB_THEME_CHANGED(id).
-- The saved theme is applied at login; one that is not available then (ElvUI not loaded) shows the
-- Blizzard look for the session, says so once, and stays saved.
local _, SB = ...

local L = SB.L
local Theme = { themes = {}, order = {}, current = "blizzard" }
SB.Theme = Theme

local weak = { __mode = "k" }
local windows = setmetatable({}, weak) -- [frame] = kind
local texts = setmetatable({}, weak) -- [fs] = { role, original font object }
local buttons = setmetatable({}, weak) -- [button] = true
local flats = setmetatable({}, weak) -- [button] = SwagBag's flat texture on it
local slots = setmetatable({}, weak) -- [texture] = true
local rows = setmetatable({}, weak) -- [row] = true

Theme.SLOT_ATLAS = "bags-item-slot64"
Theme.BLANK = "Interface\\Buttons\\WHITE8x8"
local SIZES = { titleLarge = 3, title = 1, header = 0, label = 0, body = -1, small = -1, row = -1 } -- one-font themes: size offsets

function Theme.Register(def)
	if not Theme.themes[def.id] then
		Theme.order[#Theme.order + 1] = def.id
	end
	Theme.themes[def.id] = def
	return def
end

Theme.Register({
	id = "blizzard",
	name = L.THEME_BLIZZARD,
	available = function()
		return true
	end,
	palette = function()
		return { window = { 0.06, 0.06, 0.08, 0.95 }, dialog = { 0.06, 0.06, 0.08, 0.97 }, border = { 0.35, 0.35, 0.4, 1 },
			header = { 1, 1, 1, 0.06 }, backdrop = Theme.BLANK }
	end,
})

local BLIZZARD = Theme.themes.blizzard.palette()
local palette = BLIZZARD

-- A palette that cannot be used (W5-5): the four colour fields are tables of 4 numbers, the backdrop
-- a string. Optional keys (row, slot, fonts, button) that are not usable fall back to the Blizzard
-- look's value (none).
local function isColour(c)
	if type(c) ~= "table" then
		return false
	end
	for i = 1, 4 do
		if type(c[i]) ~= "number" then
			return false
		end
	end
	return true
end

local function validPalette(p)
	if type(p) ~= "table" then
		return nil
	end
	for _, key in ipairs({ "window", "dialog", "border", "header" }) do
		if not isColour(p[key]) then
			return nil
		end
	end
	if type(p.backdrop) ~= "string" then
		return nil
	end
	local out = {}
	for k, v in pairs(p) do
		out[k] = v
	end
	out.row = isColour(p.row) and p.row or BLIZZARD.row
	out.slot = isColour(p.slot) and p.slot or BLIZZARD.slot
	if p.fonts ~= nil and type(p.fonts) ~= "table" then
		out.fonts = BLIZZARD.fonts
	end
	if p.button ~= nil and not (type(p.button) == "table" and isColour(p.button.bg)) then
		out.button = BLIZZARD.button
	end
	local e = p.edge
	if e ~= nil and not (type(e) == "table" and type(e.file) == "string" and type(e.size) == "number"
			and type(e.inset) == "number") then
		out.edge = nil
	end
	if type(p.tile) ~= "number" then
		out.tile = nil
	end
	if type(p.slotTexture) ~= "string" then
		out.slotTexture = nil
	end
	return out
end

function Theme.Current()
	return Theme.current
end

function Theme.Name(id)
	local def = Theme.themes[id]
	return def and def.name or tostring(id)
end

function Theme.Available(id)
	local def = Theme.themes[id]
	if not def then
		return false
	end
	local ok, yes = SB.ErrorTrap.Run("theme.available", "none", def.available)
	return ok and yes == true
end

---------------------------------------------------------------------------
-- Styling one object with the current palette
---------------------------------------------------------------------------
local function styleWindow(frame, kind)
	local bg = palette[kind] or palette.window
	local e = palette.edge
	if e then
		local i = e.inset
		frame:SetBackdrop({ bgFile = palette.backdrop, edgeFile = e.file, edgeSize = e.size, tile = palette.tile ~= nil,
			tileSize = palette.tile, insets = { left = i, right = i, top = i, bottom = i } })
	else
		frame:SetBackdrop({ bgFile = palette.backdrop, edgeFile = palette.backdrop, edgeSize = 1 })
	end
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
	local b = palette.border
	frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4])
end

local function styleText(fs, t)
	local f = palette.fonts
	if f == nil then
		if t.original then
			fs:SetFontObject(t.original)
		end
	elseif f.file then
		-- SetFont's return value is ignored on purpose: a bad path keeps the previous font.
		fs:SetFont(f.file, f.size + (SIZES[t.role] or 0), f.flags)
	else
		local object = f[t.role] and SB.Adapter.FontObject(f[t.role])
		if object then
			fs:SetFontObject(object)
		elseif t.original then
			fs:SetFontObject(t.original)
		end
	end
end

local TEMPLATE_PARTS = { "Left", "Middle", "Right" }

local function styleButton(b)
	local look = palette.button
	for _, key in ipairs(TEMPLATE_PARTS) do
		local part = b[key]
		if type(part) == "table" and part.SetShown then
			part:SetShown(look == nil)
		end
	end
	local flat = flats[b]
	if look and not flat then
		flat = b:CreateTexture(nil, "BACKGROUND")
		flat:SetAllPoints(b)
		flats[b] = flat
	end
	if flat then
		if look then
			flat:SetColorTexture(look.bg[1], look.bg[2], look.bg[3], look.bg[4])
			flat:Show()
		else
			flat:Hide()
		end
	end
end

local function styleSlot(tex)
	local c = palette.slot
	if palette.slotTexture then
		tex:SetTexture(palette.slotTexture)
		tex:SetTexCoord(0, 1, 0, 1)
	elseif c then
		tex:SetColorTexture(c[1], c[2], c[3], c[4])
	elseif not pcall(tex.SetAtlas, tex, Theme.SLOT_ATLAS) then
		tex:SetColorTexture(0.15, 0.15, 0.15, 0.8)
	end
end

local function styleRow(row)
	local c = palette.row
	if not row.bg then
		return
	end
	if c then
		row.bg:SetColorTexture(c[1], c[2], c[3], c[4])
		row.bg:Show()
	else
		row.bg:Hide()
	end
end

function Theme.HeaderColor()
	local c = palette and palette.header
	if not isColour(c) then
		c = BLIZZARD.header
	end
	return c[1], c[2], c[3], c[4]
end

---------------------------------------------------------------------------
-- Registration: styled now, and again on every theme change
---------------------------------------------------------------------------
function Theme.Window(frame, kind)
	windows[frame] = kind or "main"
	styleWindow(frame, windows[frame])
end

function Theme.Text(fs, role)
	if not fs then
		return
	end
	local t = texts[fs]
	if not t then
		t = { role = role, original = fs.GetFontObject and fs:GetFontObject() or nil }
		texts[fs] = t
	end
	t.role = role
	styleText(fs, t)
end

function Theme.Button(b)
	buttons[b] = true
	styleButton(b)
end

function Theme.Slot(tex)
	slots[tex] = true
	styleSlot(tex)
end

function Theme.Row(row)
	rows[row] = true
	styleRow(row)
end

local function restyleAll()
	for frame, kind in pairs(windows) do
		styleWindow(frame, kind)
	end
	for fs, t in pairs(texts) do
		styleText(fs, t)
	end
	for b in pairs(buttons) do
		styleButton(b)
	end
	for tex in pairs(slots) do
		styleSlot(tex)
	end
	for row in pairs(rows) do
		styleRow(row)
	end
end

-- Switch the look. save: also write settings.theme.name (a choice in Settings, /swagbag theme).
function Theme.Apply(id, save)
	local def = Theme.themes[id]
	if not def then
		return false, "unknown"
	end
	if not Theme.Available(id) then
		return false, "unavailable"
	end
	-- Validate before anything is committed (W5-5): a palette that errors or is unusable changes nothing.
	local ok, raw = SB.ErrorTrap.Run("theme.palette", "none", def.palette)
	local p = ok and validPalette(raw)
	if not p then
		return false, "unavailable"
	end
	local oldPalette, oldCurrent = palette, Theme.current
	palette, Theme.current = p, id
	if not SB.ErrorTrap.Run("theme.restyle", "none", restyleAll) then
		palette, Theme.current = oldPalette, oldCurrent
		SB.ErrorTrap.Run("theme.restyle", "none", restyleAll)
		return false, "unavailable"
	end
	if save and not SB.Config.Set("theme.name", id) then
		palette, Theme.current = oldPalette, oldCurrent
		SB.ErrorTrap.Run("theme.restyle", "none", restyleAll)
		return false, "readonly"
	end
	SB.Emit("SB_THEME_CHANGED", id)
	return true
end

-- The saved look, at login. A theme that cannot be used now (its addon is not loaded) leaves the
-- Blizzard look for this session, with one line, and stays saved for when it can.
SB.On("SB_LOGIN", function()
	local id = SB.Config.Get("theme.name")
	if id == Theme.current then
		return
	end
	local ok = Theme.Apply(id, false)
	if not ok then
		Theme.Apply("blizzard", false)
		SB.Print(L.THEME_FALLBACK:format(Theme.Name(id)))
	end
end, "none")
