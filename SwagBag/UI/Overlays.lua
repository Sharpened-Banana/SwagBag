-- SwagBag overlays (spec F9). Draws Engine/OverlayData.lua's result on an item button:
--   top left      item level, or "+12" on a keystone          (overlays.ilvl / .keystone)
--   bottom left   upgrade track "H3/6", or the keystone's dungeon (overlays.track / .keystone)
--   left          "BoE" / "WuE" until the item is bound          (overlays.bind)
--   top right     green upgrade arrow (AC9.3)                     (overlays.upgrade)
--   top left      junk coin on gray items a vendor pays for       (overlays.junk)
--                 (bottom left on gray gear, under its item level)
--   whole button  a soft green glow on an item to open or learn  (overlays.learn, week 7)
--   left middle   a small padlock on an item the user locked      (overlays.lock, week 7)
--   right middle  a purple star on gear whose look the account lacks, and on a toy, mount or pet not
--                 collected yet while the green glow is not drawn (off, or gold at the bank)  (overlays.uncollected)
--   whole button  a gold glow while the bank is open on items worth money (prices.worth, week 7;
--                 at the bank it wins over the green glow). /swagbag worth sets it.
-- The stack count is Blizzard's own (SetItemButtonCount); nothing is drawn bottom right (a grouped icon
-- draws the group total on that same Count font string: Buttons.SetStack). Sizes
-- are the constants below (W4-15: larger, thick outline), so a check in game can tune them.
-- overlays.usePawn hands the arrow to Pawn (Adapter.PawnUpgrade) for bag and bank items; where
-- Pawn has no opinion the item-level rule decides.
-- An empty reagent-bag slot gets a faint green tint, so in Free it is clear which empty slots
-- take reagents only (the week-2 "reagent-bag empties in Free" cue).
-- Regions are font strings and textures on the button itself (no frames: allowed in combat),
-- made the first time a button needs one, in its OVERLAY layer, so dimming the button dims
-- them too. What the character wears is read once and kept until PLAYER_EQUIPMENT_CHANGED,
-- which re-draws the open windows (spec AC9.3).
-- /swagbag overlays also switches the item level in the bags window's title (bags.showIlvl).
--   Overlays.Apply(button, record, bag)   record nil = empty slot
--   Overlays.RefreshAll()                 re-draw every open window's buttons (alt viewer too)
local _, SB = ...

local L = SB.L
local Ov = { context = nil, NAMES = { "ilvl", "track", "upgrade", "keystone", "junk", "bind", "learn", "lock",
	"uncollected" },
	-- Sizes in pixels on a 37 px button (W4-15, O1 steps 3-5 and 10). FONT is the fallback when the
	-- template font has no file; TEXT_WIDTH clips a text inside the button.
	FONT = "Fonts\\ARIALN.TTF", FONT_SIZE = 13, BIND_SIZE = 11, FONT_FLAGS = "THICKOUTLINE", TEXT_WIDTH = 33,
	ARROW_SIZE = 16, JUNK_SIZE = 16, JUNK_OUTLINE = 3, JUNK_TINT = { 1, 0.9, 0.35 },
	-- Week 7: the whole-button glow, Blizzard's white bag glow tinted (green: open or learn).
	GLOW_ATLAS = "bags-glow-white", LEARN_TINT = { 0.35, 1, 0.35 }, WORTH_TINT = { 1, 0.82, 0 }, WORTH_DELAY = 0.1,
	-- The lock mark (week 7): Blizzard's pet-battle padlock, a plain texture file.
	LOCK_TEXTURE = "Interface\\PetBattles\\PetBattle-LockIcon", LOCK_SIZE = 10,
	-- The uncollected mark (week 7): a text star, so no texture can go missing. It sits at the right edge in
	-- the gap between the upgrade arrow (bottom at 17 px) and the stack count (top at 24 px).
	STAR = "*", STAR_SIZE = 11, STAR_Y = -2, STAR_COLOR = { 0.85, 0.55, 1 } }
SB.Overlays = Ov

local regions = setmetatable({}, { __mode = "k" }) -- [button] = its overlay regions
Ov.regions = regions

-- Larger than the template, with a thick outline, so it reads on any icon; clipped inside the button.
local function text(button, point, x, y, size)
	local fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	fs:SetFont((fs:GetFont()) or Ov.FONT, size, Ov.FONT_FLAGS)
	fs:SetPoint(point, button, point, x, y)
	fs:SetWidth(Ov.TEXT_WIDTH)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
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
			topLeft = text(button, "TOPLEFT", 2, -2, Ov.FONT_SIZE),
			bottomLeft = text(button, "BOTTOMLEFT", 2, 2, Ov.FONT_SIZE),
			bind = text(button, "LEFT", 2, 0, Ov.BIND_SIZE),
			arrow = texture(button, 7, "bags-greenarrow", 0.2, 1, 0.2, 0.9),
			junkShadow = texture(button, 6, "bags-junkcoin", 0, 0, 0, 0.9),
			junk = texture(button, 7, "bags-junkcoin", 1, 0.85, 0.1, 0.9),
			reagent = button:CreateTexture(nil, "OVERLAY", nil, 6),
			glow = texture(button, 5, Ov.GLOW_ATLAS, 1, 1, 1, 0.25),
			lock = button:CreateTexture(nil, "OVERLAY", nil, 7),
			star = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"),
		}
		r.star:SetFont((r.star:GetFont()) or Ov.FONT, Ov.STAR_SIZE, Ov.FONT_FLAGS)
		r.star:SetPoint("RIGHT", button, "RIGHT", -2, Ov.STAR_Y)
		r.star:SetTextColor(unpack(Ov.STAR_COLOR))
		r.star:SetText(Ov.STAR)
		r.star:Hide()
		r.glow:SetAllPoints(button)
		r.lock:SetTexture(Ov.LOCK_TEXTURE)
		r.lock:SetSize(Ov.LOCK_SIZE, Ov.LOCK_SIZE)
		r.lock:SetPoint("LEFT", button, "LEFT", 1, 0) -- the one spot between the corner texts and the arrow
		r.lock:Hide()
		r.arrow:SetSize(Ov.ARROW_SIZE, Ov.ARROW_SIZE)
		r.arrow:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
		r.junk:SetSize(Ov.JUNK_SIZE, Ov.JUNK_SIZE)
		r.junk:SetVertexColor(unpack(Ov.JUNK_TINT))
		r.junk:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
		r.junkCorner = "TOPLEFT"
		-- A black copy of the coin, a little larger, behind it: an outline that reads on any icon.
		r.junkShadow:SetSize(Ov.JUNK_SIZE + Ov.JUNK_OUTLINE, Ov.JUNK_SIZE + Ov.JUNK_OUTLINE)
		r.junkShadow:SetVertexColor(0, 0, 0, 0.9)
		r.junkShadow:SetPoint("CENTER", r.junk, "CENTER", 0, 0)
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
		local ctx = { equipped = A.EquippedItems(), canUse = A.CanUse, dungeonName = A.DungeonName,
			learn = SB.Collections and SB.Collections.Learn, locked = SB.Locks and SB.Locks.Has,
			uncollected = SB.Collections and SB.Collections.Uncollected,
			protected = function(record) -- the vendor's own rule: a coin only where SwagBag could sell it
				return SB.Vendor ~= nil and SB.Vendor.Protected(record, true) == true -- cached looks (week 8)
			end }
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

-- An overlay this client leaves out (WoW Forever: track, keystone) is never drawn, whatever was saved.
local function on(name)
	return SB.Adapter.Allows("overlay", name) and SB.Config.Get("overlays." .. name) == true
end

-- The overlays this client offers, in NAMES order (on Retail, all of them).
function Ov.Names()
	local out = {}
	for _, n in ipairs(Ov.NAMES) do
		if SB.Adapter.Allows("overlay", n) then
			out[#out + 1] = n
		end
	end
	return out
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
	-- Item-level colors (0.17): only the item level takes a step's color; a keystone's "+12" and a pooled
	-- button's old color go back to white.
	local IC = SB.IlvlColors
	local cr, cg, cb
	if IC and d.ilvl and top == tostring(d.ilvl) then
		cr, cg, cb = IC.For(d.ilvl)
	end
	if cr then
		r.topLeft:SetTextColor(cr, cg, cb)
	else
		r.topLeft:SetTextColor(1, 1, 1)
	end
	r.bottomLeft:SetText(bottom)
	r.bind:SetText(on("bind") and d.bind or "")
	show(r.arrow, on("upgrade") and d.upgrade)
	-- The coin goes where no text is: top left, or bottom left under gray gear's item level (gear
	-- never stacks, so Blizzard's count is never there).
	local junk = on("junk") and d.junk and (top == "" or bottom == "")
	if junk then
		local corner = top == "" and "TOPLEFT" or "BOTTOMLEFT"
		if r.junkCorner ~= corner then
			r.junk:ClearAllPoints()
			r.junk:SetPoint(corner, button, corner, 2, corner == "TOPLEFT" and -2 or 2)
			r.junkCorner = corner
		end
	end
	show(r.junk, junk)
	show(r.junkShadow, junk)
	show(r.reagent, reagentEmpty)
	-- One glow per button (week 7): gold at the bank for an item worth money, else green for an item to
	-- open or learn.
	local worth = Ov.IsWorth(record)
	local glow = worth or (on("learn") and d.learn ~= nil)
	if glow then
		r.glow:SetVertexColor(unpack(worth and Ov.WORTH_TINT or Ov.LEARN_TINT))
	end
	show(r.glow, glow)
	show(r.lock, on("lock") and d.locked)
	-- One signal per item (D9): a toy, mount or pet the green glow already marks gets no star; gear's look,
	-- and a toy, mount or pet under the gold glow at the bank (green not drawn), get the star in their own
	-- corner (ruling R10).
	local green = glow and not worth
	local star = d.uncollected == "appearance" or (d.uncollected ~= nil and not green)
	show(r.star, on("uncollected") and star)
end

---------------------------------------------------------------------------
-- Worth money at the bank (week 7, user pick 7): Ov.worthMin is the stack value (copper) from which an
-- item glows gold; nil while the bank is closed or the glow is off. Worked out once when the bank opens
-- (and again when prices, the setting or the bags' layout change during the visit, and for "top" when the
-- bank's contents change, week 8), never per button.
-- A missing or secret price is no price (Engine/Prices.lua): such an item never glows.
---------------------------------------------------------------------------
local function stackValue(record)
	if not record or record.pending or record.offline then
		return 0
	end
	local P = SB.Prices
	local v = P and P.Value(record.link, record.itemID, P.Bound(record))
	return (v or 0) * (record.count or 1)
end

function Ov.IsWorth(record)
	if Ov.worthMin == nil then
		return false
	end
	local value = stackValue(record)
	return value > 0 and value >= Ov.worthMin
end

-- Work the threshold out over the bags and both banks, then re-draw. SB.AtBank: Core/Init.lua (one
-- definition for the section actions and this glow, ruling R12).
function Ov.RefreshWorth(onlyIfMoved)
	local before = Ov.worthMin
	Ov.worthMin = nil
	if SB.AtBank() and SB.Prices then
		local values = {}
		local function collect(forEach)
			forEach(function(_, record)
				values[#values + 1] = stackValue(record)
			end)
		end
		local bags, bank = SB.BagsWindow, SB.BankWindow
		if bags and bags.IsOpen() then
			collect(bags.ForEachSlot)
		end
		if bank and bank.IsOpen() then
			collect(bank.view.ForEachSlot)
		end
		local C = SB.Config
		Ov.worthMin = SB.Prices.WorthThreshold(values, C.Get("prices.worth"), C.Get("prices.worthGold"),
			C.Get("prices.worthTop"))
	end
	if onlyIfMoved and Ov.worthMin == before then
		return -- the bank's contents changed but the line did not move: nothing to re-draw
	end
	Ov.RefreshAll()
end

local function worthSoon()
	SB.Debounce("overlays.worth", Ov.WORTH_DELAY, Ov.RefreshWorth, "none")
end
SB.On("BANKFRAME_OPENED", worthSoon, "none")
SB.On("BANKFRAME_CLOSED", function()
	Ov.worthMin = nil
	Ov.RefreshAll()
end, "none")
SB.On("SB_PRICES_CHANGED", function()
	if SB.AtBank() then
		worthSoon()
	end
end, "none")
SB.On("SB_BAGS_LAYOUT", function()
	if SB.AtBank() then
		worthSoon()
	end
end, "none")
-- Week 8 (week-7 deferred): the bank's contents arrive or change while it is open. Only "your top X %"
-- depends on them (a fixed amount does not), so only that line is worked out again, once after the burst,
-- and the windows are re-drawn only when the line moved (own debounce key: it never replaces a full refresh).
SB.On("SB_BANK_CHANGED", function()
	if SB.AtBank() and SB.Config.Get("prices.worth") == "top" then
		SB.Debounce("overlays.worthBank", Ov.WORTH_DELAY, function()
			Ov.RefreshWorth(true)
		end, "none")
	end
end, "none")

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
	local offline = SB.OfflineWindow -- the alt viewer (its records are offline: never an arrow)
	if offline and offline.IsOpen() then
		each(offline.view.ForEachSlot)
	end
end

-- The colors or their steps changed (or every setting did): the icons and the list rows follow. The cache
-- in Engine/IlvlColors.lua is dropped by its own listener, which loads first.
SB.On("SB_CONFIG_CHANGED", function(_, path)
	if path ~= nil and path ~= "overlays.ilvlColors" and path ~= "overlays.ilvlSteps" then
		return
	end
	Ov.RefreshAll()
	local bags, bank = SB.BagsWindow, SB.BankWindow
	if bags and bags.IsOpen() and bags.RequestLayout then
		bags.RequestLayout("ilvlcolors")
	end
	if bank and bank.IsOpen() and bank.view and bank.view.RequestLayout then
		bank.view.RequestLayout("ilvlcolors")
	end
end, "none")

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
	local names = Ov.Names()
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
	for _, n in ipairs(Ov.NAMES) do
		if not known and n == name then
			return L.FOREVER_LEFT_OUT:format(name) -- known, but this client leaves it out: nothing is saved
		end
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

-- /swagbag ilvlcolors on|off       color item levels by the steps in Settings > Overlays; turning it on with no
--                                  steps yet fills them from the equipped item level
SB.Slash.Register("ilvlcolors", L.HELP_ILVLCOLORS, function(arg)
	local value = (arg or ""):lower():match("^%s*(%S*)%s*$")
	if value ~= "on" and value ~= "off" then
		return L.ILVLCOLORS_USAGE
	end
	local C, IC = SB.Config, SB.IlvlColors
	local byHand = false
	if value == "on" and C.Get("overlays.ilvlSteps") == "" then
		local steps = IC.Fill(SB.Adapter.EquippedItemLevel())
		if #steps == 0 then
			byHand = true
		elseif not C.Set("overlays.ilvlSteps", IC.Format(steps)) then
			return L.SETTINGS_READONLY
		end
	end
	if not C.Set("overlays.ilvlColors", value == "on") then
		return L.SETTINGS_READONLY
	end
	if value == "off" then
		return L.ILVLCOLORS_OFF
	end
	if byHand then
		return { L.ILVLCOLORS_ON, L.ILVLCOLORS_SET_BY_HAND }
	end
	return L.ILVLCOLORS_ON
end)

-- /swagbag worth                   what glows gold at the bank, and how to change it
-- /swagbag worth <gold>            items worth that much gold or more a stack (1 to 10,000,000)
-- /swagbag worth top <percent>     your most valuable percent of items (1 to 50)
-- /swagbag worth off               no gold glow
local function worthState()
	local C = SB.Config
	local mode = C.Get("prices.worth")
	if mode == "fixed" then
		return L.WORTH_FIXED:format(C.Get("prices.worthGold"))
	elseif mode == "top" then
		return L.WORTH_TOP:format(C.Get("prices.worthTop"))
	end
	return L.WORTH_OFF
end

SB.Slash.Register("worth", L.HELP_WORTH, function(arg)
	local a, b = (arg or ""):lower():match("^(%S*)%s*(%S*)$")
	local C = SB.Config
	if a == "" then
		return L.WORTH_STATE:format(worthState())
	end
	local ok
	if a == "off" and b == "" then
		ok = C.Set("prices.worth", "off")
	elseif a == "top" and tonumber(b) and tonumber(b) >= 1 and tonumber(b) <= 50 then
		local n = math.floor(tonumber(b))
		ok = C.Set("prices.worthTop", n) and C.Set("prices.worth", "top")
	elseif b == "" and tonumber(a) and tonumber(a) >= 1 and tonumber(a) <= 10000000 then
		local n = math.floor(tonumber(a))
		ok = C.Set("prices.worthGold", n) and C.Set("prices.worth", "fixed")
	else
		return L.WORTH_USAGE
	end
	if not ok then
		return L.SETTINGS_READONLY
	end
	if SB.AtBank() then
		Ov.RefreshWorth()
	end
	return L.WORTH_SET:format(worthState())
end)
