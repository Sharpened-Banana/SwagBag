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
-- Contents (UI/GroupView.lua): every viewable tab is a group, top to bottom, with its daily
-- withdrawals left in the header (AC16.2) and its own category sections, list (week 8: one row per
-- slot, the bags window's columns and order, each tab's empty slots as one free row) or grid; the window
-- has its own search box (AC16.1). Tab contents load on demand (QueryGuildBankTab, one tab
-- after another) and are kept for the session, so a reopen shows them at once; a snapshot is
-- saved per guild (AC16.4). Guild slot keys use bag 100 + tab.
-- Queries go out one at a time: a GUILDBANKBAGSLOTS_CHANGED that arrives while tab T is being
-- queried is T's answer if T then reads at least one item (ruling W3-30). An empty read is
-- only believed once T's own retry reads empty too ("known empty"); until then T stays
-- unanswered and its timeout moves the queue on. Only tabs that answered during this visit
-- are read, so a tab whose answer is still on its way never looks empty, and an unconfirmed
-- empty read never replaces a tab that had items (W3-31). A tab that gets no answer in
-- QUERY_GAP is asked once more at the end of the queue.
-- The cache belongs to one guild (GuildKey, W3-32). Slot actions wait until their tab has
-- answered this visit, and a withdraw first re-reads the slot (W3-33). The snapshot holds
-- only tabs answered this visit that are still viewable (W3-34).
-- Hiding SwagBag's window (Esc, the X) while the vault is open makes Blizzard's guild bank
-- visible again; nothing re-shrinks it until the next visit.
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
	cache = {}, -- [tab][slot] = Adapter.GuildSlot result, kept for the session (one guild)
	cacheKey = nil, -- the Adapter.GuildKey() the cache belongs to (ruling W3-32)
	queue = {}, -- tabs still to query this visit
	answered = {}, -- [tab] = true once its answer arrived this visit
	retried = {}, -- [tab] = true once re-queued after a query got no answer
	emptySeen = {}, -- [tab] = true once a read during its first query found no item (W3-30)
	confirmedEmpty = {}, -- [tab] = true: its retry read empty too, an empty read may replace the cache
	querying = nil,
	BAG_BASE = 100, -- guild tab N is bag 100 + N in layout keys
	QUERY_GAP = 0.3, -- seconds between two tab queries (and the wait if no answer comes)
	SNAPSHOT_DELAY = 1,
	HEADER = 80,
	COLUMNS_H = 18, -- the list's column bar under the deposit line (week 8), shown while a list is drawn
	scaleWarned = false, -- the list's F6 fallback was said this opening
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
frame.deposit:SetPoint("TOPLEFT", 14, -58)
frame.deposit:SetJustifyH("LEFT")
if SB.Theme then -- the look (UI/Theme.lua); the Blizzard theme keeps exactly the values above (AC14.1)
	SB.Theme.Window(frame, "main")
	SB.Theme.Text(frame.title, "title")
	SB.Theme.Text(frame.deposit, "small")
end

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

local function clampScroll()
	scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll(), child:GetHeight(), scroll:GetHeight()))
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("guild.wheel", function(_, delta)
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (SB.GroupView.SLOT + SB.GroupView.GAP) * 3)
	clampScroll()
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
	if old ~= GW.target and GW.view and GW.view.IsOpen() then
		GW.view.Relabel()
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

local function titleButton(text, label, onClick, width)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(width or 72, 18)
	b:SetText(text)
	b:SetScript("OnClick", Guard(label, onClick, "bank"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
	return b
end

GW.blizzardButton = titleButton(L.BTN_BLIZZARD_GUILD, "guild.blizzardButton", function()
	GW.ToggleVisit()
end, 140)
GW.blizzardButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)

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

-- Read every slot of a tab. Returns the new list (the cache is the caller's to update).
local function readTab(tab)
	local A, list = SB.Adapter, {}
	for slot = 1, A.GUILD_SLOTS do
		list[slot] = A.GuildSlot(tab, slot)
	end
	return list
end

local function hasItem(list)
	return type(list) == "table" and next(list) ~= nil
end

-- Query the selected tab first, then the others, one at a time: the next query goes out when
-- the previous answer arrives (GUILDBANKBAGSLOTS_CHANGED) or QUERY_GAP later.
local function timedOut()
	local tab = GW.querying
	if tab and not GW.answered[tab] and not GW.retried[tab] then
		GW.retried[tab] = true
		GW.queue[#GW.queue + 1] = tab
	end
	GW.QueryNext()
end

-- Ruling W3-30: a GUILDBANKBAGSLOTS_CHANGED while tab is being queried. It is tab's answer
-- only if tab now reads at least one item, or if this is tab's retry and its first query read
-- empty too (known empty). Otherwise the tab stays unanswered and timedOut moves on.
function GW.OnQueryEvent(tab)
	if GW.answered[tab] then
		return
	end
	if hasItem(readTab(tab)) then
		GW.answered[tab] = true
	elseif GW.retried[tab] and GW.emptySeen[tab] then
		GW.answered[tab] = true
		GW.confirmedEmpty[tab] = true
	else
		if not GW.retried[tab] then
			GW.emptySeen[tab] = true
		end
		return
	end
	SB.Debounce("guild.queryNext", 0.05, GW.QueryNext, "bank")
end

-- Ask a tab again (it answered, but now reads empty while the cache has items: W3-31). It
-- goes to the end of the queue even while it is the tab being queried: its answer already
-- came, and the queue moves past it 0.05 s later (fix round 2). Never queued twice.
function GW.Requery(tab)
	GW.answered[tab], GW.retried[tab], GW.emptySeen[tab], GW.confirmedEmpty[tab] = nil, nil, nil, nil
	for _, t in ipairs(GW.queue) do
		if t == tab then
			return
		end
	end
	GW.queue[#GW.queue + 1] = tab
	if not GW.querying then
		GW.QueryNext()
	end
end

function GW.QueryNext()
	local tab = table.remove(GW.queue, 1)
	GW.querying = tab
	if not tab then
		return
	end
	SB.Adapter.GuildQuery(tab)
	SB.Debounce("guild.queryNext", GW.QUERY_GAP, timedOut, "bank")
end

function GW.QueryAll()
	GW.queue, GW.answered, GW.retried, GW.emptySeen, GW.confirmedEmpty = {}, {}, {}, {}, {}
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

-- The per-guild snapshot (AC16.4): only tabs that answered this visit and are still viewable
-- (ruling W3-34), saved under the guild the cache belongs to (W3-32). A tab left out keeps
-- its saved snapshot.
function GW.SaveSnapshot()
	local tabs, any = {}, false
	for _, tab in ipairs(GW.order) do
		if GW.answered[tab] and GW.cache[tab] then
			tabs[tab] = { name = tabName(tab), slots = GW.cache[tab] }
			any = true
		end
	end
	if not (any and GW.cacheKey) then
		return false
	end
	return SB.Snapshots.SaveGuild(GW.cacheKey, tabs)
end

-- Forget the cached contents (another guild, or a guild change: ruling W3-32).
function GW.ClearCache(key)
	GW.cache, GW.cacheKey = {}, key
end

---------------------------------------------------------------------------
-- Contents: one group per viewable tab
---------------------------------------------------------------------------
local function withdrawText(t)
	if not t or t.withdrawals < 0 then
		return L.GUILD_WITHDRAW_UNLIMITED
	elseif t.withdrawals == 0 then
		return L.GUILD_WITHDRAW_NONE
	end
	return L.GUILD_WITHDRAW_LEFT:format(t.withdrawals)
end
GW.WithdrawText = withdrawText

local function tabOf(bag)
	return bag - GW.BAG_BASE
end

function GW.TabLabel(tab, collapsed, count)
	local text = L.GUILD_TAB_LABEL:format(collapsed and "+" or "-", tabName(tab), count or 0, withdrawText(GW.tabs[tab]))
	if not GW.cache[tab] then
		text = text .. L.GUILD_TAB_LOADING
	end
	if tab == GW.target then
		text = text .. L.GUILD_DEPOSITS_HERE
	end
	return text
end

-- The view button's order, as in the bags and bank windows: each click shows the next one.
local VIEW_NEXT, VIEW_BUTTON = SB.GroupView.VIEW_NEXT, SB.GroupView.VIEW_BUTTON
local VIEW_FLASH = { sections = L.GUILD_VIEW_SECTIONS, list = L.GUILD_VIEW_LIST, grid = L.GUILD_VIEW_GRID }

function GW.View()
	local v = SB.Config.Get("guildBank.view")
	if v == "grid" or v == "list" then
		return v
	end
	return "sections"
end

-- The title, search and deposit rows, plus the column bar while a list is drawn (the drawn view, W4-1).
function GW.HeaderHeight()
	return GW.HEADER + ((GW.view and GW.view.drawn == "list") and GW.COLUMNS_H or 0)
end

-- The list's rows (week 8). Guild slots are not bag slots: a row's tooltip is the guild slot's, and its
-- texts say what the guild bank's icons do.
GW.rows = SB.ListRows and SB.ListRows.New(child, "bank", function(text)
	GW.Flash(text)
end, { click = L.LIST_GUILD_ROW_CLICK, emptyTip = L.LIST_GUILD_EMPTY_TIP, gone = L.LIST_GUILD_GONE, goneTip = L.LIST_GUILD_GONE_TIP,
	tip = function(row, bag, slot)
		SB.Adapter.GuildTooltip(row, tabOf(bag), slot)
	end }) or nil

local function sizeFrame(width, height)
	local header = GW.HeaderHeight()
	if GW.columnsBar then -- the bar shows above a drawn list only (an F6 fallback draws none)
		GW.columnsBar.frame:SetShown(GW.view.drawn == "list")
		GW.columnsBar.Refresh()
	end
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -header)
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * GW.MAX_HEIGHT_FRACTION / frame:GetScale()
	frame:SetSize(width + 8, math.min(height, maxHeight - header - GW.FOOTER) + header + GW.FOOTER)
	clampScroll()
end

local function describe(bag, slot)
	local tab = tabOf(bag)
	local info = GW.cache[tab] and GW.cache[tab][slot]
	local button = SB.GuildButtons.Get(tab, slot)
	if button then
		SB.GuildButtons.Paint(button, info)
	end
	local record = info and SB.Items.DescribeLink(info, bag, slot, tab) or nil
	if SB.Overlays then
		SB.Overlays.Apply(button, record, bag)
	end
	return record
end

local searchBox

GW.view = SB.GroupView.New({
	key = "guild",
	window = "bank",
	child = child,
	scroll = scroll,
	button = function(bag, slot)
		return SB.GuildButtons.Get(tabOf(bag), slot)
	end,
	describe = describe,
	groups = function()
		local out = {}
		for _, tab in ipairs(GW.order) do
			out[#out + 1] = { id = "tab" .. tab, bags = { { bag = GW.BAG_BASE + tab, size = SB.Adapter.GUILD_SLOTS } } }
		end
		return out
	end,
	groupLabel = function(id, collapsed, count)
		return GW.TabLabel(tonumber(id:sub(4)), collapsed, count)
	end,
	groupTint = function(id)
		return GW.target ~= nil and id == "tab" .. GW.target
	end,
	view = GW.View,
	columns = function()
		return SB.Config.Get("guildBank.columns")
	end,
	newRows = function()
		return SB.Config.Get("bags.newRows")
	end,
	-- The list shows each tab's empty slots as one free row (a 98-slot tab would be 98 rows); categories
	-- and the grid show every empty slot, as before. Guild tabs have no bag family.
	freeTile = function(view)
		return view == "list"
	end,
	family = function()
		return "any"
	end,
	onResize = sizeFrame,
	onUpdated = function()
		searchBox.Apply()
	end,
	rows = GW.rows,
	goneTip = L.LIST_GUILD_GONE_TIP, -- a placeholder's tooltip (the rows' ghosts say it through GW.rows)
	onListFailed = function() -- F6: said once per opening; the guild bank shows categories
		if not GW.scaleWarned then
			GW.scaleWarned = true
			SB.Print(L.LIST_SCALE_FALLBACK_GUILD)
		end
	end,
})

-- The list's column bar, as the bank window's: a click sorts every list (one shared order).
if SB.ListRows then
	local GV = SB.GroupView
	GW.columnsBar = SB.ListRows.ColumnBar(frame, GW.view.RowWidth(), GW.COLUMNS_H, function(id)
		GW.SortList(id)
	end, "bank", "guild.listColumn")
	GW.columnsBar.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 4 + GV.PAD + GV.LIST_ROW + GV.ROW_TEXT_GAP, -GW.HEADER)
end

searchBox = SB.SearchBox.New({
	parent = frame,
	name = "SwagBagGuildSearchBox",
	search = SB.SearchState.New(),
	window = "bank",
	debounceKey = "search.guild",
	isOpen = function()
		return GW.IsOpen()
	end,
	forEachSlot = function(fn)
		return GW.view.ForEachSlot(fn)
	end,
	setDimmed = function(button, dimmed) -- the button, and in the list its row
		return GW.view.SetDimmed(button, dimmed)
	end,
})
GW.searchBox = searchBox

function GW.Layout(reason)
	GW.view.Layout(reason)
	searchBox.Apply()
end

function GW.Reflow(reason)
	if not frame:IsShown() then
		return false
	end
	local done = GW.view.RequestLayout(reason or "reflow") -- onUpdated applies the search when it lands
	GW.Flash(done and L.REFLOW_DONE or L.REFLOW_WAITING)
	return done
end

-- Categories -> list -> grid -> categories, like the bags and bank windows.
function GW.ToggleView()
	local view = VIEW_NEXT[GW.View()]
	if not SB.Config.Set("guildBank.view", view) then -- read-only settings: nothing changes
		GW.Flash(L.SETTINGS_READONLY)
		return
	end
	GW.viewButton:SetText(VIEW_BUTTON[VIEW_NEXT[view]])
	GW.Flash(VIEW_FLASH[view])
	GW.view.RequestLayout("view")
end

-- A click on a column of the list: sort every list by it, answered in the title (P2). The drawn lists
-- regroup through SB_LIST_SORTED (below), held while the mouse is over the items.
function GW.SortList(by)
	return SB.GroupView.SortList(by, GW.Flash)
end

GW.viewButton = titleButton(L.VIEW_TO_LIST, "guild.viewButton", function()
	GW.ToggleView()
end)
GW.viewButton:SetPoint("RIGHT", GW.blizzardButton, "LEFT", -4, 0)
GW.reflowButton = titleButton(L.BTN_REFLOW, "guild.reflowButton", function()
	GW.Reflow("reflow")
end, 60)
GW.reflowButton:SetPoint("RIGHT", GW.viewButton, "LEFT", -4, 0)
-- W3-26 parity: the title (and its flashes) ends left of the leftmost title button, on one line.
frame.title:SetPoint("RIGHT", GW.reflowButton, "LEFT", -6, 0)
frame.title:SetJustifyH("LEFT")
frame.title:SetWordWrap(false)

-- Re-read the tabs that answered this visit (a query answer, or an item that moved). A tab
-- read for the first time this session is laid out in full (held back while a button that
-- would move is under the mouse, W3-38); otherwise slots whose item changed go through GroupView.Changes (spec
-- 4.3) and the rest only repaint.
function GW.Refresh()
	local A, B = SB.Adapter, SB.GuildButtons
	local first = false
	local byTab = {}
	for _, tab in ipairs(GW.order) do
		local new = GW.answered[tab] and readTab(tab)
		if new and not hasItem(new) and hasItem(GW.cache[tab]) and not GW.confirmedEmpty[tab] then
			GW.Requery(tab) -- an unconfirmed empty read never replaces a tab with items (W3-31)
			new = nil
		end
		if new then
			GW.confirmedEmpty[tab] = nil
			first = first or GW.cache[tab] == nil
			local old = GW.cache[tab] or {}
			GW.cache[tab] = new
			local bag = GW.BAG_BASE + tab
			for slot = 1, A.GUILD_SLOTS do
				local a, b = old[slot], new[slot]
				if a ~= nil or b ~= nil then
					local button = B.Get(tab, slot)
					if button then
						B.Paint(button, b)
					end
					if GW.view.IsOpen() then
						local record = b and SB.Items.DescribeLink(b, bag, slot, tab) or nil
						GW.view.SetRecord(bag, slot, record)
						if SB.Overlays then
							SB.Overlays.Apply(button, record, bag)
						end
					end
					if (a and a.itemID) ~= (b and b.itemID) then
						byTab[tab] = byTab[tab] or {}
						table.insert(byTab[tab], { bag = bag, slot = slot, kind = b and "arrived" or "left", icon = a and a.icon })
					end
				end
			end
		end
	end
	SB.Debounce("guild.snapshot", GW.SNAPSHOT_DELAY, GW.SaveSnapshot, "none")
	if not GW.view.IsOpen() then
		return
	end
	if first then
		GW.view.RequestLayout("load")
		return
	end
	for _, tab in ipairs(GW.order) do
		if byTab[tab] then
			GW.view.Changes("tab" .. tab, byTab[tab])
		end
	end
	GW.view.Relabel()
	searchBox.Apply()
end

---------------------------------------------------------------------------
-- Slot actions (called by UI/GuildButtons.lua). Feedback in chat for every refusal (P2).
---------------------------------------------------------------------------
local function slotInfo(tab, slot)
	return GW.cache[tab] and GW.cache[tab][slot]
end

-- Ruling W3-33: no action on a tab whose answer has not arrived this visit.
local function loading(tab)
	if GW.answered[tab] then
		return false
	end
	SB.Print(L.GUILD_TAB_STILL_LOADING:format(tabName(tab)))
	return true
end

local function sameItem(a, b)
	return a ~= nil and b ~= nil and a.itemID == b.itemID and a.link == b.link
end

-- Returns what happened: "link" | "view" | "loading" | "empty" | "limit" | "tab" | "changed"
-- | "withdraw" | "pickup".
function GW.ClickSlot(tab, slot, mouseButton)
	local A, info = SB.Adapter, slotInfo(tab, slot)
	if info and A.ModifiedClick(info.link) then
		return "link"
	end
	if GW.VisitMode() == "view" then
		SB.Print(L.GUILD_VIEW_ONLY)
		return "view"
	end
	if loading(tab) then
		return "loading"
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
	if not sameItem(info, A.GuildSlot(tab, slot)) then -- W3-33: the slot changed under us
		GW.Refresh()
		SB.Print(L.GUILD_SLOT_CHANGED)
		return "changed"
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
	if loading(tab) then
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
	local key = SB.Adapter.GuildKey()
	if key ~= GW.cacheKey then -- another guild's contents are never shown (W3-32)
		GW.ClearCache(key)
	end
	GW.viewButton:SetText(VIEW_BUTTON[VIEW_NEXT[GW.View()]])
	frame:Show()
	GW.ApplyMode()
	GW.Layout("open")
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
	GW.queue, GW.querying, GW.scaleWarned = {}, nil, false
	if GW.interaction then -- the vault is still open: make Blizzard's guild bank visible again
		host.Restore()
	end
	GW.view.Clear()
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
	GW.SaveSnapshot()
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

-- Auctionator reported new prices: the section totals and the list's Value column follow, in place.
SB.On("SB_PRICES_CHANGED", function()
	if GW.view.IsOpen() then
		GW.view.RefreshTotals()
		GW.view.RefreshRows()
	end
end, "bank")

-- The list's order changed (a column click in any window, /swagbag list): the bar's marker follows
-- and a drawn list regroups, held while the mouse is over the items (P5).
SB.On("SB_LIST_SORTED", function()
	if GW.columnsBar then
		GW.columnsBar.Refresh()
	end
	if frame:IsShown() and GW.view.IsOpen() and GW.view.drawn == "list" then
		GW.view.RequestLayout("listsort")
	end
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

-- A queried tab's contents arrived, or an item moved: query the next tab and re-read the
-- tabs that answered. The tabs' withdrawals left are re-read too: a withdrawal changes a
-- slot first (ruling W3-5).
SB.On("GUILDBANKBAGSLOTS_CHANGED", function()
	if not GW.interaction then
		return
	end
	GW.ReadTabs()
	SB.GuildButtons.Ensure(GW.order) -- a tab that became viewable; missing buttons are skipped
	if GW.querying then
		GW.OnQueryEvent(GW.querying)
	end
	GW.Refresh()
	GW.RefreshTarget()
end, "bank")

SB.On("GUILDBANK_UPDATE_TABS", function()
	if not GW.interaction then
		return
	end
	GW.ReadTabs()
	if frame:IsShown() and SB.GuildButtons.Ensure(GW.order) then
		GW.view.RequestLayout("tabs")
	end
end, "bank")

SB.On("GUILDBANK_ITEM_LOCK_CHANGED", function()
	if GW.interaction then
		GW.Refresh()
	end
end, "bank")

SB.On("PLAYER_LOGOUT", function()
	host.Restore()
end, "bank")

-- The player joined, left or changed guild: forget the cached contents (ruling W3-32). The
-- event also fires for other guild updates: during an open visit the cache is dropped only
-- if the guild is no longer the one it belongs to, and the visit then queries again.
SB.On("PLAYER_GUILD_UPDATE", function()
	if not (GW.interaction and frame:IsShown()) then
		GW.ClearCache(nil)
		GW.answered = {}
		return
	end
	local key = SB.Adapter.GuildKey()
	if key ~= GW.cacheKey then
		GW.ClearCache(key)
		GW.answered = {}
		GW.view.RequestLayout("guild")
		GW.QueryAll()
	end
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
