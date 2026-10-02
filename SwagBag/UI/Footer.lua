-- SwagBag footer (ruling W4-14): a bar along the bottom of the bags window. Entries, left to right
-- in the user's order (setting bags.footer.entries; /swagbag footer; Settings > Footer):
--   gold        the character's gold
--   currencies  the currencies ticked "Show on backpack" in Blizzard's Currency tab
--   crests      every crest currency the character owns (none owned: nothing shows)
--   keystone    the keystone in the bags: dungeon short name and level ("AKCE +12")
--   free        free bag slots, the number on the free tile ("10 free (+2 reagent)")
-- A currency shows once, under the first entry that has it. Entries that do not fit the window's
-- width wrap to another row and never overlap. The bar's height is part of the window (BagsWindow's
-- sizeFrame asks Footer.Layout), so it never covers an item. Hovering an entry shows the standard
-- tooltip; nothing is clickable. Plain frames only, so it is built and redrawn in combat too. No
-- polling: money, currency, bag and keystone events refresh it, debounced, and only while the bags
-- window is open (it is re-read when the window next lays out).
--   Footer.IDS                          entry ids in the default order
--   Footer.Name(id) -> text             the entry's name
--   Footer.Entries() -> { { id, on } }  the user's order; unknown ids dropped, missing ones added, on
--   Footer.SetEntry(id, on) -> ok, why  why: "unknown" | "readonly"
--   Footer.Move(id, delta) -> ok, why   delta -1 = left, +1 = right; why: "unknown" | "edge" | "readonly"
--   Footer.Position(id) -> n            the entry's place in the order
--   Footer.Items() -> { { entry, text, icon, tip } }  what to draw, in order (reads the game)
--   Footer.Flow(widths, maxWidth) -> places, rows      pure: places[i] = { x, row }
--   Footer.Layout(width) -> height      place the items for a window this wide (0: nothing to show)
--   Footer.Refresh()                    re-read, re-place, and resize the window if the height changed
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local F = { IDS = { "gold", "currencies", "crests", "keystone", "free" }, items = {}, widgets = {}, used = 0,
	height = 0, places = {}, widths = {}, dirty = true,
	ROW = 16, ROW_GAP = 2, GAP = 12, ICON = 14, PAD = 2, INSET = 4, DELAY = 0.1 }
SB.Footer = F

local PATH = "bags.footer.entries"
local NAMES = { gold = L.FOOTER_NAME_GOLD, currencies = L.FOOTER_NAME_CURRENCIES, crests = L.FOOTER_NAME_CRESTS,
	keystone = L.FOOTER_NAME_KEYSTONE, free = L.FOOTER_NAME_FREE }
local KNOWN = {}
for _, id in ipairs(F.IDS) do
	KNOWN[id] = true
end

function F.Name(id)
	return NAMES[id] or id
end

---------------------------------------------------------------------------
-- The user's entries (comma-separated text: a per-character override copies a value, D16)
---------------------------------------------------------------------------
function F.Entries()
	local out, seen = {}, {}
	for part in tostring(SB.Config.Get(PATH) or ""):gmatch("[^,]+") do
		local off, id = part:match("^%s*(%-?)(%a+)%s*$")
		if id and KNOWN[id] and not seen[id] then
			seen[id] = true
			out[#out + 1] = { id = id, on = off ~= "-" }
		end
	end
	for _, id in ipairs(F.IDS) do
		if not seen[id] then
			out[#out + 1] = { id = id, on = true }
		end
	end
	return out
end

-- False (nothing written) while the settings are read-only.
local function save(list)
	local parts = {}
	for i, e in ipairs(list) do
		parts[i] = (e.on and "" or "-") .. e.id
	end
	return SB.Config.Set(PATH, table.concat(parts, ","))
end

function F.SetEntry(id, on)
	if not KNOWN[id] then
		return false, "unknown"
	end
	local list = F.Entries()
	for _, e in ipairs(list) do
		if e.id == id then
			e.on = on
		end
	end
	if not save(list) then
		return false, "readonly"
	end
	F.dirty = true
	F.Refresh()
	return true
end

function F.Move(id, delta)
	if not KNOWN[id] then
		return false, "unknown"
	end
	local list, i = F.Entries(), nil
	for n, e in ipairs(list) do
		if e.id == id then
			i = n
		end
	end
	local j = i + delta
	if j < 1 or j > #list then
		return false, "edge"
	end
	list[i], list[j] = list[j], list[i]
	if not save(list) then
		return false, "readonly"
	end
	F.dirty = true
	F.Refresh()
	return true
end

function F.Position(id)
	for n, e in ipairs(F.Entries()) do
		if e.id == id then
			return n
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- What to draw
---------------------------------------------------------------------------
local function crestName(name)
	local lower = type(name) == "string" and name:lower() or ""
	for _, w in ipairs(SB.Crests.words) do
		if lower:find(w, 1, true) then
			return true
		end
	end
	return false
end

-- Crest currencies the character owns: the season's confirmed IDs (Engine/Crests.lua) when there
-- are any, else every currency in Blizzard's list whose name has a crest word.
function F.Crests()
	local A, out = SB.Adapter, {}
	local ids = SB.Crests.currencies or {}
	if #ids > 0 then
		for _, id in ipairs(ids) do
			local c = A.CurrencyInfo(id)
			if c and c.quantity > 0 then
				out[#out + 1] = c
			end
		end
	else
		for _, c in ipairs(A.CurrencyList()) do
			if c.quantity > 0 and crestName(c.name) then
				out[#out + 1] = c
			end
		end
	end
	return out
end

-- The keystone in the bags, read like its overlay (OverlayData.For): { link, itemID, level, dungeon }.
function F.Keystone()
	for _, _, snap in SB.Inventory.Iterate("bags") do
		if snap and type(snap.link) == "string" and snap.link:find("|Hkeystone:", 1, true) then
			local d = SB.OverlayData.For({ isKeystone = true, link = snap.link }, { dungeonName = SB.Adapter.DungeonName })
			if d.keystone then
				return { link = snap.link, itemID = snap.itemID, level = d.keystone.level, dungeon = d.keystone.dungeon }
			end
		end
	end
	return nil
end

-- Empty bag slots by family, as the free tiles count them: any (the main tile), reagent (the
-- reagent bag's tile), other (profession bags).
function F.FreeCounts()
	local A, n, family = SB.Adapter, { any = 0, reagent = 0, other = 0 }, {}
	for bag, _, snap in SB.Inventory.Iterate("bags") do
		if snap == nil then
			family[bag] = family[bag] or A.BagFamily(bag)
			local f = family[bag]
			local k = (f == "any" or f == "reagent") and f or "other"
			n[k] = n[k] + 1
		end
	end
	return n
end

function F.Items()
	local A, out, shown = SB.Adapter, {}, {}
	local function add(entry, text, icon, tip)
		out[#out + 1] = { entry = entry, text = text, icon = icon, tip = tip }
	end
	local function currencies(entry, list)
		for _, c in ipairs(list) do
			if not shown[c.id] then
				shown[c.id] = true
				add(entry, tostring(c.quantity), c.icon, { kind = "currency", id = c.id })
			end
		end
	end
	for _, e in ipairs(F.Entries()) do
		if e.on and e.id == "gold" then
			add("gold", A.MoneyText(A.Money()), nil, { kind = "money" })
		elseif e.on and e.id == "currencies" then
			currencies("currencies", A.BackpackCurrencies())
		elseif e.on and e.id == "crests" then
			currencies("crests", F.Crests())
		elseif e.on and e.id == "keystone" then
			local k = F.Keystone()
			if k then
				local text = k.dungeon and L.FOOTER_KEYSTONE:format(k.dungeon, k.level) or L.FOOTER_KEYSTONE_LEVEL:format(k.level)
				add("keystone", text, (A.GetItemInstant(k.itemID) or {}).icon, { kind = "link", link = k.link })
			end
		elseif e.on and e.id == "free" then
			local n = F.FreeCounts()
			local text = n.reagent > 0 and L.FOOTER_FREE_REAGENT:format(n.any, n.reagent) or L.FOOTER_FREE:format(n.any)
			add("free", text, nil, { kind = "free", counts = n })
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Layout: rows that wrap, never overlap
---------------------------------------------------------------------------
-- Left to right; an item that would cross maxWidth starts the next row (an item alone on a row
-- may be as wide as maxWidth; Layout cuts its text to that).
function F.Flow(widths, maxWidth)
	local places, x, row = {}, 0, 1
	for i, w in ipairs(widths) do
		if x > 0 and x + w > maxWidth then
			row, x = row + 1, 0
		end
		places[i] = { x = x, row = row }
		x = x + w + F.GAP
	end
	return places, #widths > 0 and row or 0
end

-- A font string's full text width (GetUnboundedStringWidth ignores a width the region was cut to).
function F.TextWidth(fs)
	local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
	return tonumber(w) or 0
end

local function barFrame()
	if not F.bar then
		local W = SB.BagsWindow
		local bar = CreateFrame("Frame", nil, W.frame)
		bar:SetPoint("BOTTOMLEFT", W.frame, "BOTTOMLEFT", F.INSET, W.FOOTER)
		bar:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", -F.INSET, W.FOOTER)
		F.bar = bar
	end
	return F.bar
end

-- Standard tooltips (P2: hovering answers). Plain GameTooltip calls, nothing secure.
function F.Tooltip(owner, item)
	local T = GameTooltip
	if not (T and item) then
		return
	end
	T:SetOwner(owner, "ANCHOR_TOP")
	local tip = item.tip
	if tip.kind == "currency" then
		if not pcall(T.SetCurrencyByID, T, tip.id) then
			T:SetText(item.text)
		end
	elseif tip.kind == "link" then
		if not pcall(T.SetHyperlink, T, tip.link) then
			T:SetText(item.text)
		end
	elseif tip.kind == "money" then
		T:SetText(L.FOOTER_GOLD)
		T:AddLine(item.text, 1, 1, 1)
	else
		T:SetText(L.FOOTER_FREE_TITLE)
		T:AddLine(L.FOOTER_FREE_BAGS:format(tip.counts.any), 1, 1, 1)
		if tip.counts.reagent > 0 then
			T:AddLine(L.FOOTER_FREE_REAGENT_LINE:format(tip.counts.reagent), 1, 1, 1)
		end
		if tip.counts.other > 0 then
			T:AddLine(L.FOOTER_FREE_OTHER_LINE:format(tip.counts.other), 1, 1, 1)
		end
	end
	T:Show()
end

-- Pooled item widgets: a plain Frame with an icon and a text, hover only.
local function widget(i)
	local w = F.widgets[i]
	if not w then
		w = CreateFrame("Frame", nil, barFrame())
		w:EnableMouse(true)
		w.icon = w:CreateTexture(nil, "ARTWORK")
		w.icon:SetSize(F.ICON, F.ICON)
		w.icon:SetPoint("LEFT", w, "LEFT", 0, 0)
		w.text = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		w.text:SetJustifyH("LEFT")
		w.text:SetWordWrap(false)
		w:SetScript("OnEnter", Guard("footer.tip", function(self)
			F.Tooltip(self, self.item)
		end, "bags"))
		w:SetScript("OnLeave", Guard("footer.tipHide", function()
			if GameTooltip then
				GameTooltip:Hide()
			end
		end, "bags"))
		F.widgets[i] = w
	end
	w:Show()
	return w
end

-- width: the bags window's frame width. Returns the bar's height (0 when nothing shows).
function F.Layout(width)
	if F.dirty then
		F.items, F.dirty = F.Items(), false
	end
	local bar = barFrame()
	local inner = width - 2 * F.INSET
	local widths = {}
	for i, item in ipairs(F.items) do
		local w = widget(i)
		w.item = item
		local iconW = item.icon and (F.ICON + F.PAD) or 0
		if item.icon then
			w.icon:SetTexture(item.icon)
			w.icon:Show()
		else
			w.icon:Hide()
		end
		w.text:SetText(item.text)
		w.text:ClearAllPoints()
		w.text:SetPoint("LEFT", w, "LEFT", iconW, 0)
		widths[i] = math.min(inner, iconW + F.TextWidth(w.text))
		w.text:SetWidth(math.max(0, widths[i] - iconW)) -- a text wider than the bar is cut at its edge
	end
	for i = #F.items + 1, F.used do
		F.widgets[i]:Hide()
	end
	F.used = #F.items
	local places, rows = F.Flow(widths, inner)
	for i, p in ipairs(places) do
		local w = F.widgets[i]
		w:SetSize(widths[i], F.ROW)
		w:ClearAllPoints()
		w:SetPoint("TOPLEFT", bar, "TOPLEFT", p.x, -(p.row - 1) * (F.ROW + F.ROW_GAP))
	end
	local h = rows > 0 and (rows * F.ROW + (rows - 1) * F.ROW_GAP + F.PAD) or 0
	bar:SetHeight(math.max(h, 1))
	if rows > 0 then
		bar:Show()
	else
		bar:Hide()
	end
	F.places, F.widths, F.height = places, widths, h
	return h
end

-- Re-read the game and re-place; a new height resizes the window (its top-left corner stays put).
-- While the bags are closed nothing is read: the next layout of the window reads it.
function F.Refresh()
	local W = SB.BagsWindow
	if not (W and W.IsOpen and W.IsOpen()) then
		F.dirty = true
		return
	end
	F.items, F.dirty = F.Items(), false
	local old = F.height
	F.Layout(W.size[1] + 2 * F.INSET)
	if F.height ~= old then
		W.Resize()
	end
end

local function soon()
	SB.Debounce("footer.refresh", F.DELAY, function()
		F.Refresh()
	end, "bags")
end

SB.On("PLAYER_MONEY", soon, "bags")
SB.On("CURRENCY_DISPLAY_UPDATE", soon, "bags")
SB.On("CHALLENGE_MODE_COMPLETED", soon, "bags") -- the keystone's level changes after a run
SB.On("SB_CONFIG_CHANGED", function(_, path)
	if path == nil or path == PATH then
		soon()
	end
end, "bags")
SB.Inventory.OnChanged(soon) -- bag changes, a keystone's new link (listeners run in ErrorTrap "bags")

---------------------------------------------------------------------------
-- /swagbag footer and Settings > Footer
---------------------------------------------------------------------------
local function state(on)
	return on and L.OVERLAY_ON or L.OVERLAY_OFF
end

-- /swagbag footer                          list the entries, left to right, each on or off
-- /swagbag footer <entry> on|off|up|down   switch one, or move it left (up) or right (down)
SB.Slash.Register("footer", L.HELP_FOOTER, function(arg)
	local id, what = (arg or ""):lower():match("^(%S*)%s*(%S*)$")
	if id == "" then
		local parts = {}
		for i, e in ipairs(F.Entries()) do
			parts[i] = L.FOOTER_ENTRY_STATE:format(F.Name(e.id), state(e.on))
		end
		return L.FOOTER_STATE:format(table.concat(parts, ", "))
	end
	if not KNOWN[id] or not (what == "on" or what == "off" or what == "up" or what == "down") then
		return L.FOOTER_USAGE
	end
	local ok, why
	if what == "on" or what == "off" then
		ok, why = F.SetEntry(id, what == "on")
	else
		ok, why = F.Move(id, what == "up" and -1 or 1)
	end
	if why == "readonly" then
		return L.SETTINGS_READONLY
	elseif why == "edge" then
		return L.FOOTER_EDGE:format(F.Name(id))
	elseif not ok then
		return L.FOOTER_USAGE
	end
	if what == "on" or what == "off" then
		return L.FOOTER_SET:format(F.Name(id), state(what == "on"))
	end
	return L.FOOTER_MOVED:format(F.Name(id), F.Position(id))
end, "bags")

-- Settings > Footer: one row per entry in the user's order. Show (the default) first, Hide next to
-- it (P1); Move up / Move down are never highlighted. Every click runs /swagbag footer (D17).
if SB.SettingsWindow then
	local function footerRows()
		local rows = {}
		for i, e in ipairs(F.Entries()) do
			local id = e.id
			rows[#rows + 1] = { kind = "choice", label = L.FOOTER_ROW:format(i, F.Name(id)), width = 90,
				get = function()
					for _, x in ipairs(F.Entries()) do
						if x.id == id then
							return x.on
						end
					end
				end,
				choices = { { value = true, text = L.SET_SHOW }, { value = false, text = L.SET_HIDE },
					{ value = "up", text = L.FOOTER_UP }, { value = "down", text = L.FOOTER_DOWN } },
				apply = function(v)
					local word = (v == true and "on") or (v == false and "off") or v
					local line = "footer " .. id .. " " .. word
					if SB.SettingsWindow.RunCommand then -- UI/SettingsPages.lua: a failure says so
						return SB.SettingsWindow.RunCommand(line)
					end
					local _, feedback = SB.Slash.Run(line)
					return feedback
				end }
		end
		rows[#rows + 1] = { kind = "note", label = L.FOOTER_NOTE }
		return rows
	end
	SB.SettingsWindow.AddPage({ id = "footer", title = L.SET_PAGE_FOOTER, rows = footerRows })
end
