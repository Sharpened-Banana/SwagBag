-- SwagBag display buttons (the alt viewer, UI/OfflineWindow.lua): saved items are not in any bag
-- this character can reach, so these are SwagBag's own PLAIN ItemButtons (no template, nothing
-- secure), one per (bag, slot) of the saved data, made the first time a saved item needs one and
-- kept for the session. A click never uses or moves anything: a modified click links the item in
-- chat (Blizzard's own handler), any other click answers that the item cannot be used from here
-- (P2). Hovering shows the item's tooltip from its link. Plain frames, so they are made in combat
-- too (like placeholders and section headers).
--   DisplayButtons.SetParent(frame)          the alt viewer's scroll child (set once at load)
--   DisplayButtons.Get(bag, slot) -> button  made on first use; button.bag, button.slot
--   DisplayButtons.Paint(button, info)       info = { link, count, icon, quality } or nil
--   DisplayButtons.onClick(bag, slot, mouseButton), DisplayButtons.linkOf(bag, slot) -> link
--       set by the window that owns them
local _, SB = ...

local DB = { buttons = {}, count = 0, parent = nil, links = setmetatable({}, { __mode = "k" }) }
SB.DisplayButtons = DB

function DB.SetParent(frame)
	DB.parent = frame
end

local function create(bag, slot)
	local Guard = SB.ErrorTrap.Guard
	local b = CreateFrame("ItemButton", nil, DB.parent)
	b.bag, b.slot = bag, slot
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", Guard("offline.click", function(self, mouseButton)
		if DB.onClick then
			DB.onClick(self.bag, self.slot, mouseButton)
		end
	end, "none"))
	b:SetScript("OnEnter", Guard("offline.enter", function(self)
		local link = DB.links[self]
		if link then
			SB.Adapter.LinkTooltip(self, link)
		end
	end, "none"))
	b:SetScript("OnLeave", Guard("offline.leave", function()
		SB.Adapter.HideTooltip()
	end, "none"))
	b:Hide()
	if SB.Skins then -- week 9: Masque's skin, when it is loaded (made in combat: it joins after combat)
		SB.Skins.Add("alts", b)
	end
	DB.count = DB.count + 1
	return b
end

function DB.Get(bag, slot)
	DB.buttons[bag] = DB.buttons[bag] or {}
	local b = DB.buttons[bag][slot]
	if not b then
		b = create(bag, slot)
		DB.buttons[bag][slot] = b
	end
	return b
end

function DB.Paint(button, info)
	DB.links[button] = info and info.link or nil
	SetItemButtonTexture(button, info and info.icon or nil)
	SetItemButtonCount(button, info and info.count or 0)
	SetItemButtonQuality(button, info and info.quality or nil, info and info.link or nil)
	SetItemButtonDesaturated(button, false)
end
