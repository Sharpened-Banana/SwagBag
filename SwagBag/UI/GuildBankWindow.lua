-- SwagBag guild bank window (spec F16). Opens when the guild vault opens. Blizzard's guild
-- bank frame stays open the whole time (hiding it would end the visit):
--   "full" (default)  Blizzard's frame is shown but invisible (UI/TinyHost.lua); its real tab
--                     buttons sit on the right edge of SwagBag's window. A right-click
--                     withdraws to the bags, a drag picks up or drops, a right-click on a bag
--                     item deposits into the tab Blizzard has selected (Blizzard's own code).
--   "view"            Blizzard's frame is left as Blizzard shows it and SwagBag's window is
--                     read-only beside it (the fallback if check G1 fails; spec AC16.6).
-- The "Blizzard guild bank" button switches to "view" for this visit (gold, log,
-- permissions, tab purchase stay in Blizzard's frame; spec AC16.5). Setting:
-- guildBank.mode (/swagbag guild full|view). SwagBag never selects a tab and never writes
-- Blizzard's guild bank frame state (spec AC16.7): it reads the selected tab only.
-- Every viewable tab is listed top to bottom with its daily withdrawals left (AC16.2).
-- Tab contents load on demand (QueryGuildBankTab, one tab after another) and are kept for
-- the session, so a reopen shows them at once (AC16.4). Hiding SwagBag's window (Esc, the X)
-- while the vault is open makes Blizzard's guild bank visible again; nothing re-shrinks it
-- until the next visit.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local GW = {
	interaction = false, -- the vault is open
	visit = nil, -- "full" | "view" for this visit (the Blizzard guild bank button), nil = setting
	target = nil, -- the tab Blizzard has selected, last read
	lastVisit = nil,
	tabs = {}, -- [tab] = Adapter.GuildTabs entry (only tabs the guild owns)
	order = {}, -- viewable tab numbers, ascending
	cache = {}, -- [tab][slot] = Adapter.GuildSlot result, kept for the session
	loaded = {}, -- [tab] = true once its contents arrived this session
	queue = {}, -- tabs still to query this visit
	asked = {}, -- [tab] = true once queried this visit
	querying = nil,
	QUERY_GAP = 0.3, -- seconds between two tab queries (and the wait if no answer comes)
	SLOT = 37,
	GAP = 4,
	PAD = 4,
	COLUMNS = 14,
	TAB_HEADER = 20,
	TAB_GAP = 8,
	HEADER = 58,
	FOOTER = 6,
	MAX_HEIGHT_FRACTION = 0.75,
}
SB.GuildBankWindow = GW

local host = SB.TinyHost.New("guild", "bank")
GW.host = host

local frame = CreateFrame("Frame", "SwagBagGuildBankWindow", UIParent, "BackdropTemplate")
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:SetSize(600, 200)
frame:Hide()
if frame.SetDontSavePosition then
	frame:SetDontSavePosition(true)
end
GW.frame = frame
table.insert(UISpecialFrames, "SwagBagGuildBankWindow")

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", 10, -8)
frame.title:SetText(L.GUILD_TITLE)

frame.deposit = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.deposit:SetPoint("TOPLEFT", 10, -24)
frame.deposit:SetJustifyH("LEFT")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", 4, -GW.HEADER)
scroll:SetPoint("BOTTOMRIGHT", -4, GW.FOOTER)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(100, 100)
scroll:SetScrollChild(child)
GW.scroll, GW.child = scroll, child
SB.GuildButtons.SetParent(child)

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("guild.wheel", function(_, delta)
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (GW.SLOT + GW.GAP) * 3)
	scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll(), child:GetHeight(), scroll:GetHeight()))
end, "bank"))

local function blizzardGuildBank()
	return SB.Adapter.Frame("GuildBankFrame")
end

---------------------------------------------------------------------------
-- Title feedback and position
---------------------------------------------------------------------------
local titleToken = 0
function GW.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("guild.flash", function()
		if token == titleToken then
			frame.title:SetText(L.GUILD_TITLE)
		end
	end, "bank"))
end

function GW.RestorePosition()
	local p = SB.Config.UI().positions.guild
	frame:ClearAllPoints()
	if type(p) == "table" and p[1] then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -120)
	end
end

frame:SetScript("OnDragStart", Guard("guild.dragStart", function()
	frame:StartMoving()
end, "bank"))
frame:SetScript("OnDragStop", Guard("guild.dragStop", function()
	frame:StopMovingOrSizing()
	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top and GW.VisitMode() == "full" then
		SB.Config.UI().positions.guild = { "TOPLEFT", "BOTTOMLEFT", left, top }
	end
end, "bank"))

---------------------------------------------------------------------------
-- Full / view
---------------------------------------------------------------------------
function GW.Mode()
	return SB.Config.Get("guildBank.mode") == "view" and "view" or "full"
end

function GW.VisitMode()
	return GW.visit or GW.Mode()
end

local function tabName(tab)
	local t = GW.tabs[tab]
	return (t and t.name and t.name ~= "") and t.name or L.GUILD_TAB_N:format(tab)
end
GW.TabName = tabName

-- Read the tab Blizzard has selected (never written) and show where deposits go.
function GW.RefreshTarget()
	local old = GW.target
	GW.target = SB.Adapter.GuildCurrentTab()
	frame.deposit:SetText(GW.target and L.GUILD_DEPOSITS_TO:format(tabName(GW.target)) or "")
	if old ~= GW.target and frame:IsShown() then
		GW.Render()
	end
end

-- Blizzard's tab buttons run Blizzard's code; SwagBag reads the result on the next frame.
local hookedTabs = setmetatable({}, { __mode = "k" })
local function hookTabs(tabFrames)
	for _, t in ipairs(tabFrames) do
		local b = t.Button or t
		if not hookedTabs[b] and b.HookScript then
			hookedTabs[b] = true
			b:HookScript("OnClick", Guard("guild.tabClick", function()
				SB.Adapter.After(0, Guard("guild.tabRead", GW.RefreshTarget, "bank"))
			end, "bank"))
		end
	end
end

local function rehostTabs(tabFrames)
	for i, t in ipairs(tabFrames) do
		host.Rehost(t, frame, function(f)
			if i == 1 then
				f:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -16)
			else
				f:SetPoint("TOPLEFT", tabFrames[i - 1], "BOTTOMLEFT", 0, -6)
			end
		end)
	end
end

local function anchorBeside(gf)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", gf, "TOPRIGHT", 8, 0)
end

-- Put Blizzard's guild bank and SwagBag's window in the visit's mode. Blizzard's frame is
-- load-on-demand: until it exists (or while it is hidden) there is nothing to move yet, and
-- its OnShow hook calls this again. In combat parents cannot change: the visit stays "view".
-- Ruling W3-1: re-applied while Blizzard's guild bank is already tiny (its second OnShow,
-- GUILDBANKFRAME_OPENED, /swagbag guild, a reopen inside one fight), the visit stays full and
-- only our own position is restored; it never flips to "view" (that would anchor us to the
-- invisible frame). Out of combat a "view" request still hands Blizzard's frame back below.
-- Fix round 1: only while SwagBag's window is shown and the bank is not in Safe Mode. A
-- signal for a visit SwagBag is not showing (Safe Mode, or our window hidden) never shrinks
-- Blizzard's guild bank: that would leave an invisible vault that takes bag right-clicks.
function GW.ApplyMode()
	local gf = blizzardGuildBank()
	if not (gf and gf:IsShown()) or not frame:IsShown() or SB.SafeMode.IsOn("bank") then
		return
	end
	local tabFrames = SB.Adapter.GuildTabFrames()
	hookTabs(tabFrames)
	if host.IsActive() and (GW.VisitMode() == "full" or SB.Adapter.InCombat()) then
		host.Keep()
		if GW.VisitMode() ~= "full" then
			GW.visit = "full"
			GW.Flash(L.BANK_NOT_IN_COMBAT)
		end
		GW.RestorePosition()
	elseif GW.VisitMode() == "full" then
		if host.Shrink(gf) then
			rehostTabs(tabFrames)
			GW.RestorePosition()
		else
			GW.visit = "view"
			anchorBeside(gf)
			GW.Flash(L.GUILD_COMBAT_VIEW)
		end
	else
		host.Restore()
		anchorBeside(gf)
	end
	GW.lastVisit = GW.VisitMode()
	GW.RefreshTarget()
end

function GW.ToggleVisit()
	if SB.Adapter.InCombat() then
		GW.Flash(L.BANK_NOT_IN_COMBAT)
		return false
	end
	GW.visit = GW.VisitMode() == "full" and "view" or "full"
	GW.ApplyMode()
	GW.Flash(GW.visit == "view" and L.GUILD_SHOWING_BLIZZARD or L.GUILD_HIDING_BLIZZARD)
	return true
end

GW.blizzardButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
GW.blizzardButton:SetSize(140, 18)
GW.blizzardButton:SetText(L.BTN_BLIZZARD_GUILD)
GW.blizzardButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)
GW.blizzardButton:SetScript("OnClick", Guard("guild.blizzardButton", function()
	GW.ToggleVisit()
end, "bank"))

---------------------------------------------------------------------------
-- Tabs, queries and the session cache
---------------------------------------------------------------------------
function GW.ReadTabs()
	GW.tabs, GW.order = {}, {}
	for _, t in ipairs(SB.Adapter.GuildTabs()) do
		GW.tabs[t.tab] = t
		if t.viewable then
			GW.order[#GW.order + 1] = t.tab
		end
	end
	table.sort(GW.order)
end

-- Re-read every slot of a loaded tab into the cache.
function GW.ReadTab(tab)
	local A, list = SB.Adapter, {}
	for slot = 1, A.GUILD_SLOTS do
		list[slot] = A.GuildSlot(tab, slot)
	end
	GW.cache[tab] = list
end

-- Query the selected tab first, then the others, one at a time: the next query goes out when
-- the previous answer arrives (GUILDBANKBAGSLOTS_CHANGED) or QUERY_GAP later.
function GW.QueryNext()
	local tab = table.remove(GW.queue, 1)
	GW.querying = tab
	if not tab then
		return
	end
	GW.asked[tab] = true
	SB.Adapter.GuildQuery(tab)
	SB.Debounce("guild.queryNext", GW.QUERY_GAP, GW.QueryNext, "bank")
end

function GW.QueryAll()
	GW.queue, GW.asked = {}, {}
	local first = SB.Adapter.GuildCurrentTab()
	if first and GW.tabs[first] and GW.tabs[first].viewable then
		GW.queue[1] = first
	end
	for _, tab in ipairs(GW.order) do
		if tab ~= first then
			GW.queue[#GW.queue + 1] = tab
		end
	end
	GW.QueryNext()
end

---------------------------------------------------------------------------
-- Contents: each viewable tab as a header line and a grid of its 98 slots
---------------------------------------------------------------------------
GW.labels = {}

local function withdrawText(t)
	if not t or t.withdrawals < 0 then
		return L.GUILD_WITHDRAW_UNLIMITED
	elseif t.withdrawals == 0 then
		return L.GUILD_WITHDRAW_NONE
	end
	return L.GUILD_WITHDRAW_LEFT:format(t.withdrawals)
end
GW.WithdrawText = withdrawText

function GW.TabLabel(tab)
	local text = L.GUILD_TAB_HEADER:format(tabName(tab), withdrawText(GW.tabs[tab]))
	if not GW.loaded[tab] then
		text = text .. L.GUILD_TAB_LOADING
	end
	if tab == GW.target then
		text = text .. L.GUILD_DEPOSITS_HERE
	end
	return text
end

local function label(tab)
	local fs = GW.labels[tab]
	if not fs then
		fs = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetJustifyH("LEFT")
		GW.labels[tab] = fs
	end
	return fs
end

function GW.Render()
	local B, cols = SB.GuildButtons, GW.COLUMNS
	local step = GW.SLOT + GW.GAP
	local y = GW.PAD
	local shown = {}
	for _, tab in ipairs(GW.order) do
		shown[tab] = true
		local fs = label(tab)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", child, "TOPLEFT", GW.PAD, -y)
		fs:SetText(GW.TabLabel(tab))
		if tab == GW.target then
			fs:SetTextColor(0.3, 1, 0.3)
		else
			fs:SetTextColor(1, 0.82, 0)
		end
		fs:Show()
		y = y + GW.TAB_HEADER
		local cached = GW.cache[tab] or {}
		for slot = 1, SB.Adapter.GUILD_SLOTS do
			local b = B.Get(tab, slot)
			if b then
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", child, "TOPLEFT", GW.PAD + ((slot - 1) % cols) * step,
					-(y + math.floor((slot - 1) / cols) * step))
				B.Paint(b, cached[slot])
				b:Show()
			end
		end
		y = y + math.ceil(SB.Adapter.GUILD_SLOTS / cols) * step + GW.TAB_GAP
	end
	for tab, fs in pairs(GW.labels) do
		if not shown[tab] then
			fs:Hide()
			for slot = 1, SB.Adapter.GUILD_SLOTS do
				local b = B.Get(tab, slot)
				if b then
					b:Hide()
				end
			end
		end
	end
	local width = GW.PAD * 2 + cols * GW.SLOT + (cols - 1) * GW.GAP
	child:SetSize(width, y + GW.PAD)
	local maxHeight = UIParent:GetHeight() * GW.MAX_HEIGHT_FRACTION
	frame:SetSize(width + 8, math.min(y + GW.PAD, maxHeight - GW.HEADER - GW.FOOTER) + GW.HEADER + GW.FOOTER)
end

---------------------------------------------------------------------------
-- Slot actions (called by UI/GuildButtons.lua). Feedback in chat for every refusal (P2).
---------------------------------------------------------------------------
local function slotInfo(tab, slot)
	return GW.cache[tab] and GW.cache[tab][slot]
end

-- Returns what happened: "link" | "view" | "empty" | "limit" | "tab" | "withdraw" | "pickup".
function GW.ClickSlot(tab, slot, mouseButton)
	local A, info = SB.Adapter, slotInfo(tab, slot)
	if info and A.ModifiedClick(info.link) then
		return "link"
	end
	if GW.VisitMode() == "view" then
		SB.Print(L.GUILD_VIEW_ONLY)
		return "view"
	end
	if mouseButton ~= "RightButton" then
		if not A.GuildPickup(tab, slot) then
			SB.Print(L.GUILD_ACTION_FAILED)
		end
		return "pickup"
	end
	if not info then
		return "empty"
	end
	local t = GW.tabs[tab]
	if t and t.withdrawals == 0 then
		SB.Print(L.GUILD_NO_WITHDRAWALS:format(tabName(tab)))
		return "limit"
	end
	if not SB.Config.Get("guildBank.withdrawAnyTab") and tab ~= A.GuildCurrentTab() then
		SB.Print(L.GUILD_SELECT_TAB_FIRST:format(tabName(tab)))
		return "tab"
	end
	if not A.GuildWithdraw(tab, slot) then
		SB.Print(L.GUILD_ACTION_FAILED)
	end
	return "withdraw"
end

function GW.DragSlot(tab, slot)
	if GW.VisitMode() == "view" then
		SB.Print(L.GUILD_VIEW_ONLY)
		return false
	end
	if not SB.Adapter.GuildPickup(tab, slot) then
		SB.Print(L.GUILD_ACTION_FAILED)
	end
	return true
end

function GW.DropSlot(tab, slot)
	return GW.DragSlot(tab, slot)
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
function GW.IsOpen()
	return frame:IsShown()
end

function GW.Open()
	if SB.SafeMode.IsOn("bank") or not GW.interaction then
		return false
	end
	if frame:IsShown() then
		return true
	end
	GW.ReadTabs()
	if not SB.GuildButtons.Ensure(GW.order) then
		SB.Print(L.GUILD_COMBAT_WAIT)
		return false
	end
	frame:Show()
	GW.ApplyMode()
	GW.Render()
	GW.QueryAll()
	return true
end

function GW.Close()
	frame:Hide()
end

frame:SetScript("OnHide", Guard("guild.hide", function(self)
	if self:IsShown() then
		return
	end
	GW.queue, GW.querying = {}, nil
	if GW.interaction then -- the vault is still open: make Blizzard's guild bank visible again
		host.Restore()
	end
	SB.Emit("SB_GUILD_CLOSED")
end, "bank"))

function GW.OnOpened()
	if GW.interaction then
		GW.ApplyMode() -- a second signal for the same visit (event and OnShow): just re-apply
		return
	end
	GW.interaction, GW.visit = true, nil
	GW.Open()
end

function GW.OnClosed()
	if not GW.interaction then
		return
	end
	GW.interaction, GW.visit = false, nil
	frame:Hide()
	host.Restore()
end

-- Blizzard's guild bank UI loads on demand; hook its OnShow once it exists.
local frameHooked = false
function GW.HookFrame()
	local gf = blizzardGuildBank()
	if frameHooked or not gf then
		return
	end
	frameHooked = true
	gf:HookScript("OnShow", Guard("guild.blizzardShown", function()
		GW.OnOpened()
	end, "bank"))
end

SB.On("ADDON_LOADED", function(_, name)
	if name == "Blizzard_GuildBankUI" then
		GW.HookFrame()
	end
end, "bank")

SB.On("SB_LOGIN", function()
	GW.HookFrame()
end, "bank")

SB.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, interactionType)
	if SB.Adapter.IsGuildBanker(interactionType) then
		GW.HookFrame()
		GW.OnOpened()
	end
end, "bank")

SB.On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, interactionType)
	if SB.Adapter.IsGuildBanker(interactionType) then
		GW.OnClosed()
	end
end, "bank")

-- Older clients name the visit with these events; registration fails silently without them.
SB.On("GUILDBANKFRAME_OPENED", function()
	GW.HookFrame()
	GW.OnOpened()
end, "bank")

SB.On("GUILDBANKFRAME_CLOSED", function()
	GW.OnClosed()
end, "bank")

-- A queried tab's contents arrived, or an item moved: re-read every tab asked for this visit
-- (an answer may come late, after the next query went out) and query the next tab. The tabs'
-- withdrawals left are re-read too: a withdrawal changes a slot first (ruling W3-5).
SB.On("GUILDBANKBAGSLOTS_CHANGED", function()
	if not GW.interaction then
		return
	end
	GW.ReadTabs()
	SB.GuildButtons.Ensure(GW.order) -- a tab that became viewable; Render skips missing buttons
	for tab in pairs(GW.asked) do
		GW.loaded[tab] = true
	end
	if GW.querying then
		SB.Debounce("guild.queryNext", 0.05, GW.QueryNext, "bank")
	end
	for _, tab in ipairs(GW.order) do
		if GW.loaded[tab] then
			GW.ReadTab(tab)
		end
	end
	GW.RefreshTarget()
	if frame:IsShown() then
		GW.Render()
	end
end, "bank")

SB.On("GUILDBANK_UPDATE_TABS", function()
	if not GW.interaction then
		return
	end
	GW.ReadTabs()
	if frame:IsShown() and SB.GuildButtons.Ensure(GW.order) then
		GW.Render()
	end
end, "bank")

SB.On("GUILDBANK_ITEM_LOCK_CHANGED", function()
	if GW.interaction and frame:IsShown() then
		for _, tab in ipairs(GW.order) do
			if GW.loaded[tab] then
				GW.ReadTab(tab)
			end
		end
		GW.Render()
	end
end, "bank")

SB.On("PLAYER_LOGOUT", function()
	host.Restore()
end, "bank")

SB.On("SB_SAFEMODE_CHANGED", function(_, window, on)
	if window ~= "bank" then
		return
	end
	if on then
		frame:Hide()
		host.Restore()
	elseif GW.interaction then
		GW.Open()
	end
end, "none")

SB.Slash.Register("guild", L.HELP_GUILD, function(arg)
	arg = (arg or ""):lower()
	local anyTab = arg:match("^anytab%s*(.*)$")
	if anyTab then -- ruling W3-10: off until check G1 proves the client honours the tab
		if anyTab ~= "on" and anyTab ~= "off" then
			return L.GUILD_ANYTAB_USAGE:format(SB.Config.Get("guildBank.withdrawAnyTab") and "on" or "off")
		end
		if not SB.Config.Set("guildBank.withdrawAnyTab", anyTab == "on") then
			return L.SETTINGS_READONLY
		end
		return anyTab == "on" and L.GUILD_ANYTAB_ON or L.GUILD_ANYTAB_OFF
	end
	if arg ~= "full" and arg ~= "view" then
		return L.GUILD_USAGE:format(GW.Mode())
	end
	if not SB.Config.Set("guildBank.mode", arg) then
		return L.SETTINGS_READONLY
	end
	GW.visit = nil
	if frame:IsShown() then
		GW.ApplyMode()
	end
	if SB.Adapter.InCombat() then -- this visit may not follow it (ruling W3-1)
		return L.GUILD_MODE_SAVED_NEXT
	end
	return arg == "full" and L.GUILD_MODE_FULL or L.GUILD_MODE_VIEW
end, "bank")
