-- SwagBag section headers (spec 4.1: "Section header: plain Button, pooled").
-- A header reads "- Consumables (12)" ("+" while collapsed); New adds "+N more below"
-- when arrivals overflowed into Free (spec 4.3). Plain Buttons, so creating one in
-- combat is allowed (ruling P9). The window supplies the actions:
--   Headers.onClick(sectionId)  left-click (collapse/expand, or drop the cursor item)
--   Headers.onDrop(sectionId)   an item dragged onto the header (AC4.3)
-- Those two are the bags window's. Another window passes its own { onClick, onDrop } as the
-- owner of the headers it acquires, and releases only the headers inside its own frame.
local _, SB = ...

local L = SB.L
local H = { pool = {}, inUse = {}, HEIGHT = 18 }
SB.SectionHeaders = H

-- [header] = the frame it was acquired in / its owner's { onClick, onDrop }. Kept beside the
-- frames, not on them, so a field name can never clash with a frame method.
local parents, owners = {}, {}

-- Pure: the header text.
function H.Label(name, count, collapsed, overflow)
	local text = L.HEADER_LABEL:format(collapsed and "+" or "-", name, count)
	if overflow and overflow > 0 then
		text = text .. L.HEADER_OVERFLOW:format(overflow)
	end
	return text
end

local function create(parent)
	local Guard = SB.ErrorTrap.Guard
	local h = CreateFrame("Button", nil, parent)
	h:SetHeight(H.HEIGHT)
	h:EnableMouse(true)
	h:RegisterForClicks("LeftButtonUp")
	h.bg = h:CreateTexture(nil, "BACKGROUND")
	h.bg:SetAllPoints(h)
	h.bg:SetColorTexture(1, 1, 1, 0.06)
	h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	h.text:SetPoint("LEFT", h, "LEFT", 4, 0)
	h.text:SetJustifyH("LEFT")
	h:SetScript("OnClick", Guard("header.click", function(self)
		local o = owners[self] or H
		if o.onClick then
			o.onClick(self.sectionId)
		end
	end, "bags"))
	h:SetScript("OnReceiveDrag", Guard("header.drop", function(self)
		local o = owners[self] or H
		if o.onDrop then
			o.onDrop(self.sectionId)
		end
	end, "bags"))
	return h
end

-- A shown header for sectionId at (x, y) inside parent. owner: optional { onClick, onDrop }.
function H.Acquire(parent, sectionId, label, x, y, width, owner)
	local h = table.remove(H.pool) or create(parent)
	h:SetParent(parent)
	parents[h], owners[h] = parent, owner
	h.sectionId = sectionId
	h.bg:SetColorTexture(1, 1, 1, 0.06)
	h.text:SetText(label)
	h:SetWidth(width)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	h:Show()
	H.inUse[#H.inUse + 1] = h
	return h
end

-- Release the headers inside parent; every header when parent is nil.
function H.ReleaseAll(parent)
	for i = #H.inUse, 1, -1 do
		local h = H.inUse[i]
		if parent == nil or parents[h] == parent then
			h:Hide()
			h.sectionId, parents[h], owners[h] = nil, nil, nil
			table.remove(H.inUse, i)
			H.pool[#H.pool + 1] = h
		end
	end
end
