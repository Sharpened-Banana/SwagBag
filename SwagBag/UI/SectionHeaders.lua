-- SwagBag section headers (spec 4.1: "Section header: plain Button, pooled").
-- A header reads "- Consumables (12)" ("+" while collapsed); New adds "+N more below"
-- when arrivals overflowed into Free (spec 4.3). Plain Buttons, so creating one in
-- combat is allowed (ruling P9). The window supplies the actions:
--   Headers.onClick(sectionId)  left-click (collapse/expand, or drop the cursor item)
--   Headers.onDrop(sectionId)   an item dragged onto the header (AC4.3)
local _, SB = ...

local L = SB.L
local H = { pool = {}, inUse = {}, HEIGHT = 18 }
SB.SectionHeaders = H

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
		if H.onClick then
			H.onClick(self.sectionId)
		end
	end, "bags"))
	h:SetScript("OnReceiveDrag", Guard("header.drop", function(self)
		if H.onDrop then
			H.onDrop(self.sectionId)
		end
	end, "bags"))
	return h
end

-- A shown header for sectionId at (x, y) inside parent.
function H.Acquire(parent, sectionId, label, x, y, width)
	local h = table.remove(H.pool) or create(parent)
	h:SetParent(parent)
	h.sectionId = sectionId
	h.text:SetText(label)
	h:SetWidth(width)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	h:Show()
	H.inUse[#H.inUse + 1] = h
	return h
end

function H.ReleaseAll()
	for i = #H.inUse, 1, -1 do
		local h = H.inUse[i]
		h:Hide()
		h.sectionId = nil
		H.inUse[i] = nil
		H.pool[#H.pool + 1] = h
	end
end
