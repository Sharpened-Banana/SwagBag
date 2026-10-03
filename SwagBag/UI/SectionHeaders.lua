-- SwagBag section headers (spec 4.1: "Section header: plain Button, pooled").
-- A header reads "- Consumables (12)" ("+" while collapsed); New adds "+N more below"
-- when arrivals overflowed into Free (spec 4.3). Plain Buttons, so creating one in
-- combat is allowed (ruling P9). The window supplies the actions:
--   Headers.onClick(sectionId, mouseButton, header)  left- or right-click ("LeftButton" | "RightButton"):
--                               collapse/expand, peek or pin (focus modes), drop the cursor item, or
--                               (Shift+right-click, week 7) the section actions menu beside `header`
--   Headers.onEnter(sectionId, header) / Headers.onLeave(sectionId, header)   optional: a hint tooltip
--   Headers.onDrop(sectionId)   an item dragged onto the header (AC4.3)
-- Those two are the bags window's. Another window passes its own { onClick, onDrop, window } as the
-- owner of the headers it acquires, and releases only the headers inside its own frame.
local _, SB = ...

local L = SB.L
local H = { pool = {}, inUse = {}, HEIGHT = 18 }
SB.SectionHeaders = H

-- [header] = the frame it was acquired in / its owner's { onClick, onDrop, window }. Kept beside the
-- frames, not on them, so a field name can never clash with a frame method.
local parents, owners, labels, tinted = {}, {}, {}, {}

-- The header background: the theme's (UI/Theme.lua), else the look SwagBag always had.
local function headerColor()
	if SB.Theme then
		return SB.Theme.HeaderColor()
	end
	return 1, 1, 1, 0.06
end

-- Pure: the header text. value (copper, optional) is the section's total value (spec F10),
-- shown when above 0; vendor = the value is the vendor price (no Auctionator).
function H.Label(name, count, collapsed, overflow, value, vendor)
	local text = L.HEADER_LABEL:format(collapsed and "+" or "-", name, count)
	if value and value > 0 then
		text = text .. (vendor and L.HEADER_VALUE_VENDOR or L.HEADER_VALUE):format(SB.Prices.Money(value))
	end
	if overflow and overflow > 0 then
		text = text .. L.HEADER_OVERFLOW:format(overflow)
	end
	return text
end

-- Section totals for a layout state, or nil when header totals are switched off.
-- recordOf(bag, slot) -> item record.
function H.Totals(state, recordOf)
	if not (state and SB.Prices and SB.Config.Get("prices.headerTotals")) then
		return nil
	end
	return SB.Prices.SectionTotals(state, recordOf)
end

function H.IsVendor()
	return SB.Prices ~= nil and SB.Prices.Source() == "Vendor"
end

local function create(parent)
	local h = CreateFrame("Button", nil, parent)
	h:SetHeight(H.HEIGHT)
	h:EnableMouse(true)
	h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	h.bg = h:CreateTexture(nil, "BACKGROUND")
	h.bg:SetAllPoints(h)
	h.bg:SetColorTexture(headerColor())
	h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	h.text:SetPoint("LEFT", h, "LEFT", 4, 0)
	h.text:SetJustifyH("LEFT")
	if SB.Theme then
		SB.Theme.Text(h.text, "header")
	end
	-- The ErrorTrap window is the owner's (W3-22, spec P6): an error in a bank header puts the
	-- bank window, not the bags window, in Safe Mode. No owner window: the bags window.
	h:SetScript("OnClick", function(self, mouseButton)
		local o = owners[self]
		SB.ErrorTrap.Run("header.click", o and o.window or "bags", function()
			o = o or H
			if o.onClick then
				o.onClick(self.sectionId, mouseButton, self)
			end
		end)
	end)
	h:SetScript("OnEnter", function(self)
		local o = owners[self]
		SB.ErrorTrap.Run("header.enter", o and o.window or "bags", function()
			o = o or H
			if o.onEnter then
				o.onEnter(self.sectionId, self)
			end
		end)
	end)
	h:SetScript("OnLeave", function(self)
		local o = owners[self]
		SB.ErrorTrap.Run("header.leave", o and o.window or "bags", function()
			o = o or H
			if o.onLeave then
				o.onLeave(self.sectionId, self)
			end
		end)
	end)
	h:SetScript("OnReceiveDrag", function(self)
		local o = owners[self]
		SB.ErrorTrap.Run("header.drop", o and o.window or "bags", function()
			o = o or H
			if o.onDrop then
				o.onDrop(self.sectionId)
			end
		end)
	end)
	return h
end

-- A shown header for sectionId at (x, y) inside parent. owner: optional { onClick, onDrop,
-- window } (window: the ErrorTrap window of its scripts, default "bags").
function H.Acquire(parent, sectionId, label, x, y, width, owner)
	local h = table.remove(H.pool) or create(parent)
	h:SetParent(parent)
	parents[h], owners[h] = parent, owner
	h.sectionId = sectionId
	tinted[h] = nil
	h.bg:SetColorTexture(headerColor())
	h.text:SetText(label)
	labels[h] = label
	h:SetWidth(width)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	h:Show()
	H.inUse[#H.inUse + 1] = h
	return h
end

-- A header with its own colour (the bank group that receives deposits): kept through theme changes
-- until the header is acquired again.
function H.Tint(h, r, g, b, a)
	tinted[h] = true
	h.bg:SetColorTexture(r, g, b, a)
end

-- A new look (UI/Theme.lua): every header that is not tinted takes the theme's background.
SB.On("SB_THEME_CHANGED", function()
	for _, list in ipairs({ H.inUse, H.pool }) do
		for _, h in ipairs(list) do
			if not tinted[h] then
				h.bg:SetColorTexture(headerColor())
			end
		end
	end
end, "none")

-- Change the text of the header (parent, sectionId) in place, only when it differs. Group headers
-- (ids starting with "#") are never touched. Nothing is released or acquired.
function H.SetLabel(parent, sectionId, text)
	if sectionId:sub(1, 1) == "#" then
		return false
	end
	for _, h in ipairs(H.inUse) do
		if parents[h] == parent and h.sectionId == sectionId then
			if labels[h] ~= text then
				labels[h] = text
				h.text:SetText(text)
				return true
			end
			return false
		end
	end
	return false
end

-- Release the headers inside parent; every header when parent is nil.
function H.ReleaseAll(parent)
	for i = #H.inUse, 1, -1 do
		local h = H.inUse[i]
		if parent == nil or parents[h] == parent then
			h:Hide()
			h.sectionId, parents[h], owners[h], labels[h] = nil, nil, nil, nil
			table.remove(H.inUse, i)
			H.pool[#H.pool + 1] = h
		end
	end
end
