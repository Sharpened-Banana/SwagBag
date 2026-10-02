-- SwagBag list rows (spec 2.2 v1.3, the list view): the text part of each row, in four columns
-- -- the name in its quality colour, the count, the item level and the stack's value. The item
-- part of a row is the slot's own button (UI/Buttons.lua), which the window places at the row's
-- left edge: every click on the icon is Blizzard's own item click (use, sell, deposit, split,
-- drag), and a row itself takes no click. Contract with the window: a row starts to the right of
-- its button (never under it) and sits at the button's parent frame level, not above it, so the
-- row can never cover the secure button. A row itself takes no item click: a click on a row's text only flashes where to click
-- (P2, F24; with no flash callback it goes to chat). Hovering a row shows the item's tooltip and a line that says to click the icon (P2).
-- Every row script is cosmetic, so it traps as "none" (F3, the week-4 glow precedent): one glitch
-- there never flips Safe Mode and takes the bags away. Plain frames and font strings only, made the first time a
-- row is needed (allowed in combat, like the footer, ruling W4-24); one set of rows per window.
--   ListRows.New(parent, window, flash) -> rows  window: kept for the caller's signature (the rows'
--                                              scripts always trap as "none", F3); flash(text): the
--                                              window's title flash, called on a click on a row's text
--   rows.Place(button, x, y, width, height, shown)  the row of a slot button (made on first use)
--   rows.Paint(button, bag, slot, record, freeCount)  record nil: an empty slot ("Empty slot"),
--                                              or the free tile when freeCount is a number
--   rows.Ghosts(list, width, height)           rows for placeholders: { { x, y } }, drawn whole
--   rows.HideAll()                             another view, or a full layout starting
--   rows.SetDimmed(button, dimmed)             search: a row dims with its button (AC5.1)
--   rows.IsMouseOver(button) -> bool           P5: a row under the mouse holds its button
--   ListRows.Columns(width) -> { name, count, ilvl, value } = { x, width }   pure
--   ListRows.Texts(record, freeCount) -> { name, count, ilvl, value }         pure
local _, SB = ...

local L = SB.L
local TRAP = "none" -- F3: the window label of every row script
local LR = { COUNT = 36, ILVL = 36, VALUE = 86, GAP = 6, FONT = "GameFontHighlightSmall" }
SB.ListRows = LR

function LR.Columns(width)
	local nameW = math.max(40, width - LR.COUNT - LR.ILVL - LR.VALUE - 3 * LR.GAP)
	local x = nameW + LR.GAP
	local out = { name = { x = 0, width = nameW }, count = { x = x, width = LR.COUNT } }
	x = x + LR.COUNT + LR.GAP
	out.ilvl = { x = x, width = LR.ILVL }
	out.value = { x = x + LR.ILVL + LR.GAP, width = LR.VALUE }
	return out
end

local function hex(r, g, b)
	local function byte(v)
		return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5)
	end
	return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

-- The name in its quality colour (F5): record.quality through the Adapter first; else the quality
-- in a 12.x "|cnIQ4:" link tag, else the hex of an old "|cffa335ee" link; else plain.
local function coloured(record)
	local name = record.name
	if type(name) ~= "string" and type(record.link) == "string" then
		name = record.link:match("%[(.-)%]")
	end
	if type(name) ~= "string" then
		return L.LIST_LOADING
	end
	local link = type(record.link) == "string" and record.link or nil
	local quality = type(record.quality) == "number" and record.quality or nil
	if not quality and link then
		quality = tonumber(link:match("|cnIQ(%d+):"))
	end
	local r, g, b = SB.Adapter.QualityColor(quality)
	if r then
		return hex(r, g, b) .. name .. "|r"
	end
	local colour = link and link:match("|c(%x%x%x%x%x%x%x%x)")
	if colour then
		return "|c" .. colour .. name .. "|r"
	end
	return name
end

function LR.Texts(record, freeCount)
	if not record then
		local name = type(freeCount) == "number" and L.LIST_FREE:format(freeCount) or L.LIST_EMPTY
		return { name = name, count = "", ilvl = "", value = "" }
	end
	local count = record.count or 1
	local ilvl = SB.Sort.Ilvl(record)
	local value = SB.Sort.Value(record)
	return {
		name = coloured(record),
		count = count > 1 and tostring(count) or "",
		ilvl = ilvl and tostring(math.floor(ilvl)) or "",
		value = (value and value > 0) and SB.Prices.Money(value) or "",
	}
end

local function hideTip()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

function LR.New(parent, _window, flash)
	local Guard = SB.ErrorTrap.Guard
	local R = { rows = {}, ghosts = {}, used = 0 }
	-- [row] = { bag, slot, filled }; [button] = true while dimmed; [button] = its texts, kept until
	-- its row is first needed, so a hidden slot (a spare in Free) never gets a row
	local slotOf, dimmed, texts = {}, {}, {}

	local function text(row, justify)
		local fs = row:CreateFontString(nil, "OVERLAY", LR.FONT)
		fs:SetJustifyH(justify)
		fs:SetWordWrap(false)
		return fs
	end

	local function create(tip, click)
		local row = CreateFrame("Frame", nil, parent)
		row:SetFrameLevel(parent:GetFrameLevel()) -- not above the item buttons (see the header)
		row:EnableMouse(true)
		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints(row)
		row.bg:Hide()
		row.name, row.count, row.ilvl, row.value = text(row, "LEFT"), text(row, "RIGHT"), text(row, "RIGHT"),
			text(row, "RIGHT")
		row:SetScript("OnEnter", Guard("list.rowTip", tip, TRAP))
		row:SetScript("OnLeave", Guard("list.rowTipHide", hideTip, TRAP))
		if click then
			row:SetScript("OnMouseUp", Guard("list.rowClick", click, TRAP))
		end
		return row
	end

	local function itemTip(row)
		local s = slotOf[row]
		if s and s.filled then
			SB.Adapter.SlotTooltip(row, s.bag, s.slot, L.LIST_ROW_TIP)
		elseif GameTooltip then
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.LIST_EMPTY_TIP, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end

	-- P2 (F24): a click on a row's text says where to click; nothing secure is involved.
	local function answer(msg)
		if flash then
			flash(msg)
		else
			SB.Print(msg) -- never silent (P2), even without a window's title flash
		end
	end

	local function itemClick(row)
		local s = slotOf[row]
		answer((s and s.filled) and L.LIST_ROW_CLICK or L.LIST_EMPTY_CLICK)
	end

	local function ghostClick()
		answer(L.PLACEHOLDER_TIP)
	end

	local function ghostTip(row)
		if GameTooltip then
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.PLACEHOLDER_TIP, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end

	local function layoutTexts(row, width, height)
		local cols = LR.Columns(width)
		row:SetSize(width, height)
		for _, id in ipairs(SB.Sort.COLUMNS) do
			local fs = row[id]
			fs:ClearAllPoints()
			fs:SetPoint("LEFT", row, "LEFT", cols[id].x, 0)
			fs:SetWidth(cols[id].width)
		end
	end

	local function setTexts(row, t)
		row.name:SetText(t.name)
		row.count:SetText(t.count)
		row.ilvl:SetText(t.ilvl)
		row.value:SetText(t.value)
	end

	local function rowFor(button)
		local row = R.rows[button]
		if not row then
			row = create(itemTip, itemClick)
			R.rows[button] = row
			local t = texts[button]
			if t then
				slotOf[row] = t.slot
				setTexts(row, t)
			end
		end
		return row
	end

	function R.Place(button, x, y, width, height, shown)
		local row = R.rows[button]
		if not shown or not x then
			if row then
				row:Hide()
			end
			return
		end
		row = rowFor(button)
		layoutTexts(row, width, height)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
		row:SetAlpha(dimmed[button] and SB.Buttons.DIM_ALPHA or 1)
		row:Show()
	end

	function R.Paint(button, bag, slot, record, freeCount)
		local t = LR.Texts(record, freeCount)
		t.slot = { bag = bag, slot = slot, filled = record ~= nil }
		texts[button] = t
		local row = R.rows[button]
		if row then
			slotOf[row] = t.slot
			setTexts(row, t)
		end
	end

	function R.Ghosts(list, width, height)
		for i, p in ipairs(list) do
			local row = R.ghosts[i]
			if not row then
				row = create(ghostTip, ghostClick)
				R.ghosts[i] = row
			end
			layoutTexts(row, width, height)
			setTexts(row, { name = L.LIST_GONE, count = "", ilvl = "", value = "" })
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", parent, "TOPLEFT", p.x, p.y)
			row:SetAlpha(SB.Buttons.PLACEHOLDER_ALPHA)
			row:Show()
		end
		for i = #list + 1, R.used do
			R.ghosts[i]:Hide()
		end
		R.used = #list
	end

	function R.HideAll()
		for _, row in pairs(R.rows) do
			row:Hide()
		end
		R.Ghosts({}, 0, 0)
	end

	function R.SetDimmed(button, dim)
		dimmed[button] = dim and true or nil
		local row = R.rows[button]
		if row then
			row:SetAlpha(dim and SB.Buttons.DIM_ALPHA or 1)
		end
	end

	function R.IsMouseOver(button)
		local row = R.rows[button]
		return row ~= nil and row:IsShown() and row:IsMouseOver() == true
	end

	return R
end
