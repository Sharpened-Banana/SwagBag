-- SwagBag guild bank slot buttons (spec F16). Guild bank items are not container items, so
-- these are SwagBag's own plain ItemButtons (no secure template), one per (tab, slot),
-- created out of combat when the guild bank first opens and kept for the session. What a
-- click does is decided by the guild bank window (SB.GuildBankWindow.ClickSlot / DragSlot /
-- DropSlot), which calls Blizzard's own guild bank functions through the Adapter.
--   GuildButtons.SetParent(frame)  the guild window's scroll child (set once at load)
--   GuildButtons.Ensure(tabs) -> true when every button exists (false: waits for combat to end)
--   GuildButtons.Get(tab, slot) -> button | nil;  button.tab, button.slot
--   GuildButtons.Paint(button, info)   info: Adapter.GuildSlot result or nil
local _, SB = ...

local GB = { buttons = {}, count = 0, parent = nil }
SB.GuildButtons = GB

function GB.SetParent(frame)
	GB.parent = frame
end

local function window()
	return SB.GuildBankWindow
end

local function create(tab, slot)
	local Guard = SB.ErrorTrap.Guard
	local b = CreateFrame("ItemButton", nil, GB.parent)
	b.tab, b.slot = tab, slot
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnClick", Guard("guild.click", function(self, mouseButton)
		window().ClickSlot(self.tab, self.slot, mouseButton)
	end, "bank"))
	b:SetScript("OnDragStart", Guard("guild.drag", function(self)
		window().DragSlot(self.tab, self.slot)
	end, "bank"))
	b:SetScript("OnReceiveDrag", Guard("guild.drop", function(self)
		window().DropSlot(self.tab, self.slot)
	end, "bank"))
	b:SetScript("OnEnter", Guard("guild.enter", function(self)
		SB.Adapter.GuildTooltip(self, self.tab, self.slot)
	end, "bank"))
	b:SetScript("OnLeave", Guard("guild.leave", function()
		SB.Adapter.HideTooltip()
	end, "bank"))
	b:Hide()
	if SB.Skins then -- week 9: Masque's skin, when it is loaded
		SB.Skins.Add("guild", b)
	end
	GB.buttons[tab][slot] = b
	GB.count = GB.count + 1
	return b
end

local function complete(tabs)
	for _, tab in ipairs(tabs) do
		if #(GB.buttons[tab] or {}) < SB.Adapter.GUILD_SLOTS then
			return false
		end
	end
	return true
end

-- Only creating a button waits for combat to end: buttons made on an earlier visit are reused.
function GB.Ensure(tabs)
	if complete(tabs) then
		return true
	end
	if SB.Adapter.InCombat() then
		SB.OutOfCombat(function()
			GB.Ensure(tabs)
		end, "guildButtons.ensure", "bank")
		return false
	end
	for _, tab in ipairs(tabs) do
		GB.buttons[tab] = GB.buttons[tab] or {}
		for slot = #GB.buttons[tab] + 1, SB.Adapter.GUILD_SLOTS do
			create(tab, slot)
		end
	end
	return true
end

function GB.Get(tab, slot)
	local list = GB.buttons[tab]
	return list and list[slot]
end

function GB.Paint(button, info)
	SetItemButtonTexture(button, info and info.icon or nil)
	SetItemButtonCount(button, info and info.count or 0)
	SetItemButtonQuality(button, info and info.quality or nil, info and info.link or nil)
	SetItemButtonDesaturated(button, info ~= nil and info.isLocked)
end
