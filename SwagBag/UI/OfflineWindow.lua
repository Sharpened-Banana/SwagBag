-- SwagBag alt viewer (spec 3.2 Views.Offline, AC13.2): one saved character's items, read only --
-- its bags, its bank, the warband bank and its guild's bank, as groups of category sections
-- (UI/GroupView.lua), with a search box of its own (AC5.1). The data comes from
-- Engine/AltData.lua (Syndicator when it answers, else SwagBag's own snapshots); each group
-- header says how old it is ("2 days ago") or where it came from ("from Syndicator").
-- Items are SwagBag's own plain display buttons (UI/DisplayButtons.lua), never item buttons:
-- nothing here can be used, moved or sold. A click says so (P2); a modified click links the item.
-- The window shows what was saved when it opened (or when another character is picked); it does
-- not follow saves made while it is open. Every entry point traps as "none": a glitch here is
-- recorded for /swagbag report and never takes the bags or the bank away (there is no Blizzard
-- window to fall back to).
-- Items whose data the client has not loaded yet (after a patch the item cache is empty) are
-- described as pending and wait in New. While the window is open, item data arriving for one of
-- them lays the window out again (debounced, LOADED_DELAY) through GroupView's RequestLayout, held
-- like any full layout while a button that would move is under the mouse or an item is on the
-- cursor (P5), so they move into their categories (preflight F22). That layout keeps the data the
-- window opened with. Closing forgets what it was waiting on.
--   OfflineWindow.Open(key) -> bool   key: AltData.Canon("Name-Realm"), default this character
--   OfflineWindow.Close(), .IsOpen(), .Flash(text), .key
--   OfflineWindow.ToggleMenu()         the character picker: every saved character, a click shows it
--   /swagbag alts [name]               open (this character, or the one named)
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local OW = { HEADER = 80, FOOTER = 6, MAX_HEIGHT_FRACTION = 0.75, GUILD_BASE = 100, key = nil, slots = {}, groups = {},
	info = {}, KINDS = { "bags", "bank", "warband", "guild" }, LOADED_DELAY = 0.3, pending = {},
	menuButtons = {}, MENU_ROW = 20, MENU_MAX = 30 }
SB.OfflineWindow = OW

local frame = CreateFrame("Frame", "SwagBagOfflineWindow", UIParent, "BackdropTemplate")
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
OW.frame = frame
table.insert(UISpecialFrames, "SwagBagOfflineWindow")

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", 10, -8)
frame.title:SetPoint("RIGHT", frame, "RIGHT", -30, 0)
frame.title:SetJustifyH("LEFT")
frame.title:SetWordWrap(false)
frame.source = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.source:SetPoint("TOPLEFT", 14, -58)
frame.source:SetJustifyH("LEFT")
if SB.Theme then
	SB.Theme.Window(frame, "main")
	SB.Theme.Text(frame.title, "title")
	SB.Theme.Text(frame.source, "small")
end

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", 4, -OW.HEADER)
scroll:SetPoint("BOTTOMRIGHT", -4, OW.FOOTER)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(100, 100)
scroll:SetScrollChild(child)
OW.scroll, OW.child = scroll, child
SB.DisplayButtons.SetParent(child)

local function clampScroll()
	scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll(), child:GetHeight(), scroll:GetHeight()))
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("offline.wheel", function(_, delta)
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (SB.GroupView.SLOT + SB.GroupView.GAP) * 3)
	clampScroll()
end, "none"))

frame:SetScript("OnDragStart", Guard("offline.dragStart", function()
	frame:StartMoving()
end, "none"))
frame:SetScript("OnDragStop", Guard("offline.dragStop", function()
	frame:StopMovingOrSizing()
	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top then
		SB.Config.UI().positions.offline = { "TOPLEFT", "BOTTOMLEFT", left, top }
	end
end, "none"))

function OW.RestorePosition()
	local p = SB.Config.UI().positions.offline
	frame:ClearAllPoints()
	if type(p) == "table" and p[1] then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 80, -140)
	end
end

---------------------------------------------------------------------------
-- Title
---------------------------------------------------------------------------
local titleToken = 0

local function restingTitle()
	return L.OFFLINE_TITLE:format(OW.name or "")
end

function OW.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("offline.flash", function()
		if token == titleToken then
			frame.title:SetText(restingTitle())
		end
	end, "none"))
end

---------------------------------------------------------------------------
-- The saved data of one character
---------------------------------------------------------------------------
local GROUP_NAMES = { bags = L.OFFLINE_BAGS, bank = L.OFFLINE_BANK, warband = L.OFFLINE_WARBAND }

-- A saved slot { link, count } as the button and Items.DescribeLink want it, or nil (a link with no
-- item ID: never shown).
function OW.Info(s)
	local A = SB.Adapter
	local id = s and SB.AltData.ItemID(s.link)
	if not id then
		return nil
	end
	local data = A.GetItemInfo(id)
	return { itemID = id, link = s.link, count = s.count or 1, icon = (A.GetItemInstant(id) or {}).icon,
		quality = data and data.quality or nil }
end

-- The saved slot's location (the location keywords: backpack, bags, reagentbag, bank, warband,
-- guild) and its tab.
local function kindOf(bag)
	if bag >= OW.GUILD_BASE then
		return "guild", bag - OW.GUILD_BASE
	end
	local kind, tab = SB.Adapter.BagKind(bag)
	if kind == "bank" or kind == "warband" or kind == "backpack" or kind == "reagentbag" then
		return kind, tab
	end
	return "bags", nil
end

-- Read every kind of saved container for key into OW.slots (bag -> slot -> { link, count }) and
-- OW.groups (GroupView groups, in KINDS order, only kinds with something saved).
function OW.Load(key)
	OW.slots, OW.groups, OW.info, OW.pending = {}, {}, {}, {}
	for _, kind in ipairs(OW.KINDS) do
		local c, source = SB.AltData.Container(key, kind)
		if c then
			local bags = {}
			for id, cont in pairs(c.containers) do
				local bag = kind == "guild" and OW.GUILD_BASE + id or id
				local slots = {}
				for slot, s in pairs(cont.slots) do
					if OW.Info(s) then
						slots[slot] = s
					end
				end
				OW.slots[bag] = slots
				bags[#bags + 1] = { bag = bag, size = cont.size }
			end
			table.sort(bags, function(a, b)
				return a.bag < b.bag
			end)
			if #bags > 0 then
				OW.groups[#OW.groups + 1] = { id = kind, bags = bags }
				OW.info[kind] = { at = c.at, source = source, title = c.title }
			end
		end
	end
end

local function age(info)
	if info.at then
		return SB.Snapshots.Age(SB.Adapter.Time() - info.at)
	end
	return L.OFFLINE_FROM:format(tostring(info.source))
end

function OW.GroupLabel(id, collapsed, count)
	local info = OW.info[id] or {}
	local name = GROUP_NAMES[id] or L.OFFLINE_GUILD:format(info.title or "")
	return L.OFFLINE_GROUP:format(collapsed and "+" or "-", name, count or 0, age(info))
end

local function describe(bag, slot)
	local s = OW.slots[bag] and OW.slots[bag][slot]
	local info = OW.Info(s)
	local button = SB.DisplayButtons.Get(bag, slot)
	SB.DisplayButtons.Paint(button, info)
	if not info then
		return nil
	end
	local kind, tab = kindOf(bag)
	local record = SB.Items.DescribeLink(info, bag, slot, tab, kind)
	record.offline = true
	if record.pending then
		OW.pending[info.itemID] = true -- laid out again when its data arrives (F22)
	end
	if SB.Overlays then
		SB.Overlays.Apply(button, record, bag)
	end
	return record
end

local function sizeFrame(width, height)
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * OW.MAX_HEIGHT_FRACTION / frame:GetScale()
	frame:SetSize(width + 8, math.min(height, maxHeight - OW.HEADER - OW.FOOTER) + OW.HEADER + OW.FOOTER)
	clampScroll()
end

local searchBox

OW.view = SB.GroupView.New({
	key = "offline",
	window = "none",
	child = child,
	scroll = scroll,
	-- only saved items have a button in the layout: an empty saved slot is not drawn (no Free)
	button = function(bag, slot)
		if OW.slots[bag] and OW.slots[bag][slot] then
			return SB.DisplayButtons.Get(bag, slot)
		end
		return nil
	end,
	describe = describe,
	groups = function()
		return OW.groups
	end,
	groupLabel = OW.GroupLabel,
	view = function()
		return "sections"
	end,
	columns = function()
		return SB.Config.Get("bank.columns")
	end,
	newRows = function()
		return 1 -- only drawn while it holds an item still loading (hideEmptyNew, F22)
	end,
	hideEmptyNew = true,
	onResize = sizeFrame,
	onUpdated = function()
		searchBox.Apply()
	end,
})

searchBox = SB.SearchBox.New({
	parent = frame,
	name = "SwagBagOfflineSearchBox",
	search = SB.SearchState.New(),
	window = "none",
	debounceKey = "search.offline",
	isOpen = function()
		return OW.IsOpen()
	end,
	forEachSlot = function(fn)
		return OW.view.ForEachSlot(fn)
	end,
	setDimmed = function(button, dimmed)
		return SB.Buttons.SetDimmed(button, dimmed)
	end,
})
OW.searchBox = searchBox

---------------------------------------------------------------------------
-- Clicks (UI/DisplayButtons.lua): nothing is used; a modified click links the item
---------------------------------------------------------------------------
function OW.ClickSlot(bag, slot)
	local s = OW.slots[bag] and OW.slots[bag][slot]
	if s and SB.Adapter.ModifiedClick(s.link) then
		return "link"
	end
	OW.Flash(L.OFFLINE_READONLY)
	return "readonly"
end
SB.DisplayButtons.onClick = OW.ClickSlot

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
local function nameOf(key)
	for _, c in ipairs(SB.AltData.Characters() or {}) do
		if c.key == key then
			return c.name
		end
	end
	return key and key:match("^[^%-]+") or key
end

function OW.IsOpen()
	return frame:IsShown()
end

-- Reads the character's saved data again (open, another character). Item data arriving (F22)
-- does not come here: it lays out the data already read, so the window never follows saves made
-- while it is open.
function OW.Layout(reason)
	OW.view.Clear() -- the buttons of what was shown, before the new data replaces it
	OW.Load(OW.key)
	frame.title:SetText(restingTitle())
	OW.pickButton:SetText(L.OFFLINE_PICK:format(OW.name or ""))
	-- nothing of the character's own saved (the warband bank is the account's): say how to get it
	local _, source = SB.AltData.Characters()
	if OW.info.bags or OW.info.bank or OW.info.guild then
		frame.source:SetText(L.OFFLINE_SOURCE:format(source == "Own" and L.ALTS_OWN or tostring(source)))
	else
		frame.source:SetText(L.OFFLINE_NOTHING:format(OW.name or ""))
	end
	OW.view.Layout(reason)
	searchBox.Apply()
end

function OW.Open(key)
	OW.key = key or SB.AltData.Canon(SB.Adapter.CharKey())
	OW.name = nameOf(OW.key)
	if not frame:IsShown() then
		OW.RestorePosition()
		frame:Show()
	end
	OW.Layout("open")
	return true
end

function OW.Close()
	frame:Hide()
end

---------------------------------------------------------------------------
-- The character picker: a button on the source line (below the search box's error line, F23) and
-- a list of plain buttons under it
---------------------------------------------------------------------------
OW.pickButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
OW.pickButton:SetSize(180, 20)
OW.pickButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -56)
OW.pickButton:SetText(L.OFFLINE_PICK:format(""))
OW.pickButton:SetScript("OnClick", Guard("offline.pick", function()
	OW.ToggleMenu()
end, "none"))

local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
menu:SetPoint("TOPRIGHT", OW.pickButton, "BOTTOMRIGHT", 0, -2)
menu:SetFrameStrata("DIALOG")
menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
menu:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
menu:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
menu:Hide()
OW.menu = menu
if SB.Theme then
	SB.Theme.Button(OW.pickButton)
	SB.Theme.Window(menu, "dialog")
end

-- "Abby (Argent Dawn) - 2 days ago"; without a stamp (Syndicator) just the name and realm.
local function menuText(c)
	local text = c.realm and L.OFFLINE_MENU_REALM:format(c.name, c.realm) or c.name
	if c.lastSeen then
		text = L.OFFLINE_MENU_SEEN:format(text, SB.Snapshots.Age(SB.Adapter.Time() - c.lastSeen))
	end
	return text
end

local function classColoured(c, text)
	local colour = SB.Adapter.ClassColour(c.class)
	return colour and (colour .. text .. "|r") or text
end

local function menuButton(i)
	local b = OW.menuButtons[i]
	if not b then
		b = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
		b:SetSize(260, OW.MENU_ROW)
		b:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * (OW.MENU_ROW + 2))
		b:SetScript("OnClick", Guard("offline.menuPick", function(self)
			menu:Hide()
			OW.Open(self.key)
		end, "none"))
		if SB.Theme then
			SB.Theme.Button(b)
		end
		OW.menuButtons[i] = b
	end
	b:Show()
	return b
end

-- Open the list of saved characters (the one shown is highlighted), or close it. Up to MENU_MAX;
-- /swagbag alts <name> reaches any other.
function OW.ToggleMenu()
	if menu:IsShown() then
		menu:Hide()
		return false
	end
	local list = SB.AltData.Characters() or {}
	local n = math.min(#list, OW.MENU_MAX)
	for i = 1, n do
		local b = menuButton(i)
		b.key = list[i].key
		b:SetText(classColoured(list[i], menuText(list[i])))
		if list[i].key == OW.key then
			b:LockHighlight()
		else
			b:UnlockHighlight()
		end
	end
	for i = n + 1, #OW.menuButtons do
		OW.menuButtons[i]:Hide()
	end
	menu:SetSize(268, 8 + math.max(1, n) * (OW.MENU_ROW + 2))
	menu:Show()
	if n == 0 then
		OW.Flash(L.OFFLINE_NONE_SAVED)
	end
	return true
end

frame:SetScript("OnHide", Guard("offline.hide", function(self)
	if self:IsShown() then
		return
	end
	menu:Hide()
	OW.view.Clear()
	OW.pending = {} -- item data arriving while closed lays nothing out (onItemLoaded returns at once)
end, "none"))

---------------------------------------------------------------------------
-- Item data arriving (F22): pending items move into their categories
---------------------------------------------------------------------------
-- The data already read, laid out again: RequestLayout holds it (and retries every 300 ms) while
-- a button that would move is under the mouse or an item is on the cursor (P5).
local function relayoutLoaded()
	if not (OW.IsOpen() and OW.view.IsOpen()) then
		return
	end
	OW.view.RequestLayout("loaded") -- the search is applied by GroupView's onUpdated, whenever it lands
end

local function onItemLoaded(_, itemID, success)
	if success == false or not OW.pending[itemID] or not OW.IsOpen() then
		return
	end
	OW.pending[itemID] = nil
	SB.Debounce("offline.loaded", OW.LOADED_DELAY, relayoutLoaded, "none")
end

SB.On("ITEM_DATA_LOAD_RESULT", onItemLoaded, "none")
SB.On("GET_ITEM_INFO_RECEIVED", onItemLoaded, "none")

-- The saved character named text ("Name" or "Name-Realm", compared in AltData.Canon form), or
-- nil and either the saved names (none matches) or the matching keys (a name on several realms).
local function find(text)
	local canon = (SB.AltData.Canon(text) or text):lower()
	local names, matches = {}, {}
	for _, c in ipairs(SB.AltData.Characters() or {}) do
		names[#names + 1] = c.name
		if c.key:lower() == canon then
			return c
		end
		if (c.name or ""):lower() == canon then
			matches[#matches + 1] = c
		end
	end
	if #matches == 1 then
		return matches[1]
	elseif #matches > 1 then
		local keys = {}
		for _, c in ipairs(matches) do
			keys[#keys + 1] = c.key
		end
		return nil, nil, keys
	end
	return nil, names
end

-- /swagbag alts [name]
SB.Slash.Register("alts", L.HELP_ALTS, function(arg)
	arg = arg or ""
	if arg == "" then
		OW.Open()
		return L.OFFLINE_OPENED:format(OW.name)
	end
	local c, names, several = find(arg)
	if several then
		return L.OFFLINE_SEVERAL:format(arg, table.concat(several, ", "))
	end
	if not c then
		return L.OFFLINE_UNKNOWN:format(arg, #names > 0 and table.concat(names, ", ") or L.REPORT_NONE)
	end
	OW.Open(c.key)
	return L.OFFLINE_OPENED:format(OW.name)
end)
