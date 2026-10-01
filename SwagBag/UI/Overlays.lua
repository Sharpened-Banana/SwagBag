-- SwagBag overlays (spec F9). Draws Engine/OverlayData.lua's result on an item button:
--   top left      item level, or "+12" on a keystone          (overlays.ilvl / .keystone)
--   bottom left   upgrade track "H3/6", or the keystone's dungeon (overlays.track / .keystone)
--   left          "BoE" / "WuE" until the item is bound          (overlays.bind)
--   top right     green upgrade arrow (AC9.3)                     (overlays.upgrade)
--   top left      junk coin on gray items a vendor pays for       (overlays.junk)
-- The stack count is Blizzard's own (SetItemButtonCount). overlays.usePawn hands the arrow
-- to Pawn's PawnIsContainerItemAnUpgrade for bag and bank items.
-- An empty reagent-bag slot gets a faint green tint, so in Free it is clear which empty slots
-- take reagents only (the week-2 "reagent-bag empties in Free" cue).
-- Regions are font strings and textures on the button itself (no frames: allowed in combat),
-- made the first time a button needs one, in its OVERLAY layer, so dimming the button dims
-- them too. What the character wears is read once and kept until PLAYER_EQUIPMENT_CHANGED,
-- which re-draws the open windows (spec AC9.3).
-- /swagbag overlays also switches the item level in the bags window's title (bags.showIlvl).
--   Overlays.Apply(button, record, bag)   record nil = empty slot
--   Overlays.RefreshAll()                 re-draw every open window's buttons
local _, SB = ...

local L = SB.L
local Ov = { context = nil, NAMES = { "ilvl", "track", "upgrade", "keystone", "junk", "bind" } }
SB.Overlays = Ov

local regions = setmetatable({}, { __mode = "k" }) -- [button] = its overlay regions
Ov.regions = regions

local function text(button, point, x, y)
	local fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	fs:SetPoint(point, button, point, x, y)
	return fs
end

-- A texture with an atlas, or a plain colour when the atlas is missing.
local function texture(button, sublevel, atlas, r, g, b, a)
	local t = button:CreateTexture(nil, "OVERLAY", nil, sublevel)
	local ok, set = pcall(t.SetAtlas, t, atlas)
	if not (ok and set ~= false) then
		t:SetColorTexture(r, g, b, a)
	end
	t:Hide()
	return t
end

local function regionsFor(button)
	local r = regions[button]
	if not r then
		r = {
			topLeft = text(button, "TOPLEFT", 2, -2),
			bottomLeft = text(button, "BOTTOMLEFT", 2, 2),
			bind = text(button, "LEFT", 2, 0),
			arrow = texture(button, 7, "bags-greenarrow", 0.2, 1, 0.2, 0.9),
			junk = texture(button, 7, "bags-junkcoin", 1, 0.85, 0.1, 0.9),
			reagent = button:CreateTexture(nil, "OVERLAY", nil, 6),
		}
		r.arrow:SetSize(14, 14)
		r.arrow:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
		r.junk:SetSize(12, 12)
		r.junk:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		r.reagent:SetColorTexture(0.2, 0.75, 0.35, 0.18) -- a plain tint: no atlas to go missing
		r.reagent:Hide()
		r.reagent:SetAllPoints(button)
		regions[button] = r
	end
	return r
end

local MAX_UNKNOWN_RETRIES = 10
local unknownRetries = 0
local retryPending = false

local function anyUnknown(equipped)
	for _, e in pairs(equipped) do
		if e.unknown then
			return true
		end
	end
	return false
end

-- What the character wears and can use; kept until the equipment changes. A context with a
-- worn item whose level is unreadable (unknown) is kept for the pass in hand, and one retry
-- (1 s later, clearing it and re-drawing) is scheduled if none is pending: at most 10 retries
-- per episode, the count reset by a clean read (W3-19).
function Ov.Context()
	if not Ov.context then
		local A = SB.Adapter
		local ctx = { equipped = A.EquippedItems(), canUse = A.CanUse, dungeonName = A.DungeonName }
		if SB.Config.Get("overlays.usePawn") then
			ctx.pawn = function(record)
				if record.bag and A.BagKind(record.bag) then -- bag and bank slots; not the guild bank
					return A.PawnUpgrade(record.bag, record.slot)
				end
				return nil
			end
		end
		if not anyUnknown(ctx.equipped) then
			unknownRetries = 0
		elseif not retryPending and unknownRetries < MAX_UNKNOWN_RETRIES then
			retryPending = true
			SB.Debounce("overlays.unknown", 1, function()
				retryPending = false
				unknownRetries = unknownRetries + 1
				Ov.context = nil
				Ov.RefreshAll()
			end, "none")
		end
		Ov.context = ctx
	end
	return Ov.context
end

local function on(name)
	return SB.Config.Get("overlays." .. name) == true
end

local function show(region, yes)
	if yes then
		region:Show()
	else
		region:Hide()
	end
end

function Ov.Apply(button, record, bag)
	if not button then
		return
	end
	local reagentEmpty = record == nil and bag ~= nil and SB.Adapter.BagKind(bag) == "reagentbag"
	if not regions[button] and record == nil and not reagentEmpty then
		return -- an empty slot that never showed anything: no regions needed
	end
	local r = regionsFor(button)
	local d = SB.OverlayData.For(record, Ov.Context())
	local top = (on("ilvl") and d.ilvl and tostring(d.ilvl))
		or (on("keystone") and d.keystone and L.OVERLAY_KEYSTONE:format(d.keystone.level)) or ""
	local bottom = (on("track") and d.track) or (on("keystone") and d.keystone and d.keystone.dungeon) or ""
	r.topLeft:SetText(top)
	r.bottomLeft:SetText(bottom)
	r.bind:SetText(on("bind") and d.bind or "")
	show(r.arrow, on("upgrade") and d.upgrade)
	show(r.junk, on("junk") and d.junk and top == "")
	show(r.reagent, reagentEmpty)
end

-- Re-draw the buttons of every open window (equipment or settings changed).
function Ov.RefreshAll()
	local function each(fn)
		fn(function(button, record, bag)
			Ov.Apply(button, record, bag)
		end)
	end
	local bags, bank, guild = SB.BagsWindow, SB.BankWindow, SB.GuildBankWindow
	if bags and bags.IsOpen() then
		each(bags.ForEachSlot)
	end
	if bank and bank.IsOpen() then
		each(bank.view.ForEachSlot)
	end
	if guild and guild.IsOpen() then
		each(guild.view.ForEachSlot)
	end
end

-- A gear swap fires one event per slot: re-draw once, after the last one.
SB.On("PLAYER_EQUIPMENT_CHANGED", function()
	Ov.context = nil
	SB.Debounce("overlays.equipment", 0.1, Ov.RefreshAll, "none")
end, "none")

-- The setting behind each name /swagbag overlays knows (plain names are overlays.<name>).
local SETTING = { pawn = "overlays.usePawn", title = "bags.showIlvl" }

local function path(name)
	return SETTING[name] or ("overlays." .. name)
end

local function state(name)
	return SB.Config.Get(path(name)) and L.OVERLAY_ON or L.OVERLAY_OFF
end

-- /swagbag overlays              list every overlay and whether it is on
-- /swagbag overlays <name> on|off  switch one (pawn: let Pawn decide the arrow;
--                                  title: the item level in the bags window's title)
SB.Slash.Register("overlays", L.HELP_OVERLAYS, function(arg)
	local name, value = (arg or ""):lower():match("^(%S*)%s*(%S*)$")
	local names = { unpack(Ov.NAMES) }
	names[#names + 1] = "pawn"
	names[#names + 1] = "title"
	if name == "" then
		local parts = {}
		for _, n in ipairs(names) do
			parts[#parts + 1] = n .. " " .. state(n)
		end
		return L.OVERLAYS_STATE:format(table.concat(parts, ", "))
	end
	local known = false
	for _, n in ipairs(names) do
		known = known or n == name
	end
	if not known or (value ~= "on" and value ~= "off") then
		return L.OVERLAYS_USAGE
	end
	if not SB.Config.Set(path(name), value == "on") then
		return L.SETTINGS_READONLY
	end
	Ov.context = nil
	Ov.RefreshAll()
	if SB.BagsWindow then
		SB.BagsWindow.RefreshTitle()
	end
	local line = L.OVERLAYS_SET:format(name, state(name))
	if name == "pawn" and value == "on" and not SB.Adapter.HasPawn() then
		return { line, L.OVERLAYS_NO_PAWN }
	end
	return line
end)
