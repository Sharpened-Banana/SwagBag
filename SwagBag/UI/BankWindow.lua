-- SwagBag bank window (spec F2, section 5). Opens on BANKFRAME_OPENED, closes on
-- BANKFRAME_CLOSED. Blizzard's bank frame stays open the whole time:
--   "tiny" (default)  Blizzard's bank is shown but invisible (UI/TinyHost.lua) and its real
--                     tab buttons (BankFrame.TabSystem) hang under SwagBag's window
--   "beside"          Blizzard's bank is left exactly as Blizzard shows it, and SwagBag's
--                     window sits to its right (spec 5.4; the fallback if check V2 fails)
-- The "Blizzard bank" button switches between the two for this visit only (tab purchase and
-- warband gold live in Blizzard's frame). The setting is bank.blizzardFrame
-- (/swagbag bank tiny|beside).
-- Read only (spec 5.2, 5.3): the deposit target is whatever bank type Blizzard has selected
-- (Adapter.ActiveBankType); SwagBag shows it and never sets it. Esc or the X hides SwagBag's
-- window (spec 5.6) and gives Blizzard's bank back its parent, so it is visible while the
-- visit lasts; the bags window shows "Bank still open", which shows this window again.
-- Contents (UI/GroupView.lua): the "Character bank" group on top, the "Warband bank" group
-- below, each with its own category sections (or grid), for the purchased tabs the client
-- reports. The receiving group is tinted and says "deposits go here". Items move only into
-- New or Free while the window is open (spec 4.3). Sort buttons call Blizzard's bank sort
-- and regroup after the bank settles; in combat they refuse with feedback and nothing runs
-- later (spec 5.5, ruling W11). The window has its own search box.
-- "Deposit warbound" (week 6, user request 3) runs the game's own warband deposit through the
-- Adapter, beside a "With reagents" box that is Blizzard's own include-reagents choice.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local BW = {
	interaction = false, -- the bank visit is open (between BANKFRAME_OPENED and _CLOSED)
	visit = nil, -- "tiny" | "beside" for this visit (the Blizzard bank button), nil = setting
	target = nil, -- "bank" | "warband" | nil: Blizzard's selected bank type, last read
	lastVisit = nil, -- "tiny" | "beside": the mode of the last visit (for /swagbag report)
	sortPending = false, -- a Sort was pressed and the bank updates are still settling
	sortSawUpdate = false,
	HEADER = 80, -- title row, search row, deposit line
	FOOTER = 6,
	MAX_HEIGHT_FRACTION = 0.75,
	SORT_SETTLE = 0.3,
	SORT_TIMEOUT = 1.5,
	FLASH = 1.5, -- seconds a title answer shows
	VISIT_FLASH = 3, -- the Blizzard bank button's answer: the window may jump beside Blizzard's (D17)
}
SB.BankWindow = BW

local host = SB.TinyHost.New("bank", "bank")
BW.host = host

local frame = CreateFrame("Frame", "SwagBagBankWindow", UIParent, "BackdropTemplate")
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:SetSize(540, 120)
frame:Hide()
if frame.SetDontSavePosition then
	frame:SetDontSavePosition(true)
end
BW.frame = frame
table.insert(UISpecialFrames, "SwagBagBankWindow")

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", 10, -8)
frame.title:SetText(L.BANK_TITLE)

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
scroll:SetPoint("TOPLEFT", 4, -BW.HEADER)
scroll:SetPoint("BOTTOMRIGHT", -4, BW.FOOTER)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(100, 100)
scroll:SetScrollChild(child)
BW.scroll, BW.child = scroll, child
-- The bank tabs' bag frames (and so their item buttons) live in this window.
SB.Buttons.SetParentFor("bank", child)
SB.Buttons.SetParentFor("warband", child)

local function clampScroll()
	scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll(), child:GetHeight(), scroll:GetHeight()))
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("bank.wheel", function(_, delta)
	scroll:SetVerticalScroll(scroll:GetVerticalScroll() - delta * (SB.GroupView.SLOT + SB.GroupView.GAP) * 3)
	clampScroll()
end, "bank"))

local function blizzardBank()
	return SB.Adapter.Frame("BankFrame")
end

---------------------------------------------------------------------------
-- Title feedback and position
---------------------------------------------------------------------------
local titleToken = 0
-- A flash cut short by the title's room (W3-26 bounds it) also goes to chat, so a long answer is
-- never lost (P2; the bags window's D27, week 5). seconds: how long it shows (default FLASH);
-- toChat: the line also goes to chat, once, whether or not it was cut short (week 6, D17).
function BW.Flash(text, seconds, toChat)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	if toChat or (frame.title.IsTruncated and frame.title:IsTruncated()) then
		SB.Print(text)
	end
	SB.Adapter.After(seconds or BW.FLASH, Guard("bank.flash", function()
		if token == titleToken then
			frame.title:SetText(L.BANK_TITLE)
		end
	end, "bank"))
end

function BW.RestorePosition()
	local p = SB.Config.UI().positions.bank
	frame:ClearAllPoints()
	if type(p) == "table" and p[1] then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -120)
	end
end

frame:SetScript("OnDragStart", Guard("bank.dragStart", function()
	frame:StartMoving()
end, "bank"))
frame:SetScript("OnDragStop", Guard("bank.dragStop", function()
	frame:StopMovingOrSizing()
	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top and BW.VisitMode() == "tiny" then -- beside follows Blizzard's frame instead
		SB.Config.UI().positions.bank = { "TOPLEFT", "BOTTOMLEFT", left, top }
	end
end, "bank"))

---------------------------------------------------------------------------
-- Tiny / beside
---------------------------------------------------------------------------
function BW.Mode()
	return SB.Config.Get("bank.blizzardFrame") == "beside" and "beside" or "tiny"
end

function BW.VisitMode()
	return BW.visit or BW.Mode()
end

local function groupName(kind)
	return kind == "warband" and L.BANK_GROUP_WARBAND or L.BANK_GROUP_BANK
end
BW.GroupName = groupName

-- Read Blizzard's selected bank type (never written) and show where deposits go.
function BW.RefreshTarget()
	local old = BW.target
	BW.target = SB.Adapter.ActiveBankType()
	frame.deposit:SetText(BW.target and L.BANK_DEPOSITS_TO:format(groupName(BW.target)) or "")
	if old ~= BW.target and BW.view and BW.view.IsOpen() then
		BW.view.Relabel() -- the tint and "deposits go here" move to the other group
	end
	SB.Emit("SB_BANK_TARGET", BW.target)
end

-- A click on one of Blizzard's tabs runs Blizzard's code first; SwagBag reads the result
-- on the next frame. Each tab is hooked once.
local hookedTabs = setmetatable({}, { __mode = "k" })
local function hookTabs(tabSystem)
	if not tabSystem or type(tabSystem.tabs) ~= "table" then
		return
	end
	for _, tab in ipairs(tabSystem.tabs) do
		if not hookedTabs[tab] and tab.HookScript then
			hookedTabs[tab] = true
			tab:HookScript("OnClick", Guard("bank.tabClick", function()
				SB.Adapter.After(0, Guard("bank.tabRead", BW.RefreshTarget, "bank"))
			end, "bank"))
		end
	end
end

local function placeTabs(tabSystem)
	tabSystem:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2)
end

local function anchorBeside(bf)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", bf, "TOPRIGHT", 8, 0)
end

-- Put Blizzard's bank and SwagBag's window in the visit's mode. In combat parents cannot
-- change, so a visit that starts in combat stays "beside".
-- Ruling W3-1: re-applied while Blizzard's bank is already tiny ("Bank still open", /swagbag
-- bank, a reopen inside one fight), the visit stays tiny and only our own position is
-- restored; it never flips to "beside" (that would anchor us to the invisible frame). Out
-- of combat a "beside" request still hands Blizzard's bank back below.
function BW.ApplyMode()
	local bf = blizzardBank()
	if not bf then
		return
	end
	hookTabs(bf.TabSystem)
	if host.IsActive() and (BW.VisitMode() == "tiny" or SB.Adapter.InCombat()) then
		host.Keep()
		if BW.VisitMode() ~= "tiny" then
			BW.visit = "tiny"
			BW.Flash(L.BANK_NOT_IN_COMBAT)
		end
		BW.RestorePosition()
	elseif BW.VisitMode() == "tiny" then
		if host.Shrink(bf) then
			if bf.TabSystem then
				host.Rehost(bf.TabSystem, frame, placeTabs)
			end
			BW.RestorePosition()
		else
			BW.visit = "beside"
			anchorBeside(bf)
			BW.Flash(L.BANK_COMBAT_BESIDE)
		end
	else
		host.Restore()
		anchorBeside(bf)
	end
	BW.lastVisit = BW.VisitMode()
	BW.RefreshTarget()
end

-- The "Blizzard bank" button: show or hide Blizzard's bank for this visit. The window jumps
-- beside Blizzard's bank (or back), so the answer shows longer and also goes to chat (D17).
function BW.ToggleVisit()
	if SB.Adapter.InCombat() then
		BW.Flash(L.BANK_NOT_IN_COMBAT)
		return false
	end
	BW.visit = BW.VisitMode() == "tiny" and "beside" or "tiny"
	BW.ApplyMode()
	BW.Flash(BW.visit == "beside" and L.BANK_SHOWING_BLIZZARD or L.BANK_HIDING_BLIZZARD, BW.VISIT_FLASH, true)
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
BW.TitleButton = titleButton

BW.blizzardButton = titleButton(L.BTN_BLIZZARD_BANK, "bank.blizzardButton", function()
	BW.ToggleVisit()
end, 104)
BW.blizzardButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)

---------------------------------------------------------------------------
-- Contents: two groups in one GroupView
---------------------------------------------------------------------------
function BW.View()
	return SB.Config.Get("bank.view") == "grid" and "grid" or "sections"
end

local searchBox -- the bank's search box, built below the view

local function bagsOf(kind)
	local A, B, list = SB.Adapter, SB.Buttons, {}
	for _, bag in ipairs(A.GetBagIDs(kind)) do
		local n = A.NumSlots(bag)
		if n > 0 then
			if B.Count(bag) < n then
				B.EnsureCapacity(bag, n)
				if A.InCombat() then
					-- Ruling W3-27: the growth waits for combat to end; then lay the bank out again
					-- (this layout creates any buttons still missing, so queue order does not matter).
					SB.OutOfCombat(function()
						if frame:IsShown() and BW.view.IsOpen() then
							BW.view.RequestLayout("grow") -- onUpdated applies the search when it lands
						end
					end, "bank.grownLayout", "bank")
				end
			end
			list[#list + 1] = { bag = bag, size = n }
		end
	end
	return list
end

-- Paint the slot's button and return its item record (nil for an empty slot). A pending item
-- has no slot icon yet; placeholders still need one.
local function describe(bag, slot)
	local A, B = SB.Adapter, SB.Buttons
	local button = B.Get(bag, slot)
	if button then
		B.Paint(button, A.GetSlot(bag, slot))
	end
	local record = SB.Items.Describe(bag, slot)
	if record and not record.icon then
		record.icon = (A.GetItemInstant(record.itemID) or {}).icon
	end
	if SB.Overlays then
		SB.Overlays.Apply(button, record, bag)
	end
	return record
end

-- Fit the window around the content; scroll when taller than 75 % of the screen. Every anchor
-- of this window is a top-left corner, so a resize never moves its top edge.
local function sizeFrame(width, height)
	child:SetSize(width, height)
	local maxHeight = UIParent:GetHeight() * BW.MAX_HEIGHT_FRACTION / frame:GetScale()
	frame:SetSize(width + 8, math.min(height, maxHeight - BW.HEADER - BW.FOOTER) + BW.HEADER + BW.FOOTER)
	clampScroll()
end


BW.view = SB.GroupView.New({
	key = "bank",
	window = "bank",
	child = child,
	scroll = scroll,
	button = function(bag, slot)
		return SB.Buttons.Get(bag, slot)
	end,
	describe = describe,
	groups = function()
		return { { id = "bank", bags = bagsOf("bank") }, { id = "warband", bags = bagsOf("warband") } }
	end,
	groupLabel = function(id, collapsed, count)
		local text = L.BANK_GROUP_LABEL:format(collapsed and "+" or "-", groupName(id), count)
		if id == BW.target then
			text = text .. L.BANK_GROUP_TARGET
		end
		return text
	end,
	groupTint = function(id)
		return id == BW.target
	end,
	view = BW.View,
	columns = function()
		return SB.Config.Get("bank.columns")
	end,
	newRows = function()
		return SB.Config.Get("bags.newRows")
	end,
	freeTile = function() -- one setting for the bags and the bank (plan D19, /swagbag free)
		return SB.Config.Get("bags.freeTile")
	end,
	onResize = sizeFrame,
	onUpdated = function()
		searchBox.Apply()
	end,
	onDrop = function(sectionId)
		SB.BagsWindow.DropOnSection(sectionId)
	end,
})

searchBox = SB.SearchBox.New({
	parent = frame,
	name = "SwagBagBankSearchBox",
	search = SB.SearchState.New(),
	window = "bank",
	debounceKey = "search.bank",
	isOpen = function()
		return BW.IsOpen()
	end,
	forEachSlot = function(fn)
		return BW.view.ForEachSlot(fn)
	end,
	setDimmed = function(button, dimmed)
		return SB.Buttons.SetDimmed(button, dimmed)
	end,
})
BW.searchBox = searchBox

-- Full layout of both groups, then the search dimming.
function BW.Layout(reason)
	BW.view.Layout(reason)
	searchBox.Apply()
end

-- Sort (spec 5.5): Blizzard's bank sort for one bank type, only from a click and never in
-- combat (nothing is queued; ruling W11). SORT_SETTLE after the last bank update the window
-- regroups (held back while the mouse is over the items); a sort that changes nothing stops
-- waiting after SORT_TIMEOUT.
function BW.Sort(kind)
	local A = SB.Adapter
	if A.InCombat() then
		BW.Flash(L.SORT_AFTER_COMBAT)
		return false
	end
	local ok, err = A.SortBank(kind)
	if not ok then
		if err ~= nil then
			SB.ErrorTrap.OnError("bank.sort", "none", tostring(err), A.Stack())
		end
		BW.Flash(L.SORT_UNAVAILABLE)
		return false
	end
	if not BW.sortPending then
		BW.sortSawUpdate = false
	end
	BW.sortPending = frame:IsShown()
	if BW.sortPending then
		SB.Debounce("bank.sortSettle", BW.SORT_TIMEOUT, function()
			local saw = BW.sortSawUpdate
			BW.sortPending, BW.sortSawUpdate = false, false
			if saw then
				BW.Reflow("sort")
			end
		end, "bank")
	end
	BW.Flash(L.SORT_STARTED)
	return true
end

function BW.Reflow(reason)
	if not frame:IsShown() then
		return false
	end
	local done = BW.view.RequestLayout(reason or "reflow") -- onUpdated applies the search when it lands
	BW.Flash(done and L.REFLOW_DONE or L.REFLOW_WAITING)
	return done
end

function BW.ToggleView()
	local view = BW.View() == "grid" and "sections" or "grid"
	if not SB.Config.Set("bank.view", view) then -- read-only settings: nothing changes
		BW.Flash(L.SETTINGS_READONLY)
		return
	end
	BW.viewButton:SetText(view == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	BW.Flash(view == "grid" and L.BANK_VIEW_GRID or L.BANK_VIEW_SECTIONS)
	BW.view.RequestLayout("view")
end

-- Config is not initialized while this file loads, so the view label is set in BW.Open().
BW.viewButton = titleButton(L.VIEW_TO_GRID, "bank.viewButton", function()
	BW.ToggleView()
end)
BW.viewButton:SetPoint("RIGHT", BW.blizzardButton, "LEFT", -4, 0)
BW.reflowButton = titleButton(L.BTN_REFLOW, "bank.reflowButton", function()
	BW.Reflow("reflow")
end, 60)
BW.reflowButton:SetPoint("RIGHT", BW.viewButton, "LEFT", -4, 0)
BW.sortWarbandButton = titleButton(L.BTN_SORT_WARBAND, "bank.sortWarband", function()
	BW.Sort("warband")
end, 96)
BW.sortWarbandButton:SetPoint("RIGHT", BW.reflowButton, "LEFT", -4, 0)
BW.sortBankButton = titleButton(L.BTN_SORT_BANK, "bank.sortBank", function()
	BW.Sort("bank")
end, 76)
BW.sortBankButton:SetPoint("RIGHT", BW.sortWarbandButton, "LEFT", -4, 0)
-- Ruling W3-26: the title (and its flashes) ends left of the leftmost title button; a long
-- flash is cut short on one line instead of running under the buttons.
frame.title:SetPoint("RIGHT", BW.sortBankButton, "LEFT", -6, 0)
frame.title:SetJustifyH("LEFT")
frame.title:SetWordWrap(false)

---------------------------------------------------------------------------
-- Deposit all warbound items (week 6, user request 3)
---------------------------------------------------------------------------
-- SwagBag's own plain button makes the game call Blizzard's "Deposit All Warbound Items" makes
-- (Adapter.DepositWarband, the warband bank by type: Blizzard's selected bank type is never read
-- for it nor set). It sits on this window under the title, so it shows in tiny and beside mode alike
-- and hides with the window: never invisible but clickable. Every click answers in the title (P2).
-- It refuses in combat (nothing is queued, like Sort), while the warband bank is locked, and when a
-- deposit would end an item's refund or that cannot be told: Blizzard's own button asks first, and
-- the "Blizzard bank" button shows it. SwagBag only reads the result: the items arrive in the
-- warband group's New like any deposit (spec 4.3).
local function carried()
	local A, list = SB.Adapter, {}
	for _, bag in ipairs(A.GetBagIDs("bags")) do
		local n = A.NumSlots(bag)
		if n > 0 then
			list[#list + 1] = { bag = bag, size = n }
		end
	end
	return list
end

function BW.DepositWarband()
	local A = SB.Adapter
	if A.InCombat() then
		BW.Flash(L.DEPOSIT_AFTER_COMBAT)
		return false
	end
	local usable, why = A.WarbandDepositState()
	if not usable then
		BW.Flash(why == "locked" and L.DEPOSIT_LOCKED or L.DEPOSIT_UNAVAILABLE)
		return false
	end
	local refundable = A.RefundableForWarband(carried())
	if refundable ~= false then -- true, or nil: it cannot be told
		BW.Flash(refundable and L.DEPOSIT_REFUNDABLE or L.DEPOSIT_UNSURE)
		return false
	end
	local ok, err = A.DepositWarband()
	if not ok then
		if err ~= nil then
			SB.ErrorTrap.OnError("bank.deposit", "none", tostring(err), A.Stack())
		end
		BW.Flash(L.DEPOSIT_UNAVAILABLE)
		return false
	end
	BW.Flash(A.DepositReagents() and L.DEPOSIT_STARTED_REAGENTS or L.DEPOSIT_STARTED)
	return true
end

BW.depositButton = titleButton(L.BTN_DEPOSIT_WARBAND, "bank.depositWarband", function()
	BW.DepositWarband()
end, 128)
BW.depositButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -54)

-- "With reagents": Blizzard's include-reagents choice for that deposit (its own setting, which its own
-- box writes too). Shown ticked as the game has it; hidden when the game cannot say.
BW.reagentsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
BW.reagentsLabel:SetPoint("RIGHT", BW.depositButton, "LEFT", -6, 0)
BW.reagentsLabel:SetText(L.DEPOSIT_REAGENTS_LABEL)
BW.reagentsBox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
BW.reagentsBox:SetSize(22, 22)
BW.reagentsBox:SetPoint("RIGHT", BW.reagentsLabel, "LEFT", -2, 0)
if SB.Theme then
	SB.Theme.Text(BW.reagentsLabel, "small")
end

function BW.RefreshReagents()
	local on = SB.Adapter.DepositReagents()
	BW.reagentsBox:SetShown(on ~= nil)
	BW.reagentsLabel:SetShown(on ~= nil)
	BW.reagentsBox:SetChecked(on == true)
end

BW.reagentsBox:SetScript("OnClick", Guard("bank.depositReagents", function()
	local want = SB.Adapter.DepositReagents() ~= true
	if SB.Adapter.SetDepositReagents(want) then
		BW.Flash(want and L.DEPOSIT_REAGENTS_ON or L.DEPOSIT_REAGENTS_OFF)
	else
		BW.Flash(L.DEPOSIT_REAGENTS_FAILED)
	end
	BW.RefreshReagents()
end, "bank"))

-- The deposit line ends left of the box, on one line.
frame.deposit:SetPoint("RIGHT", BW.reagentsBox, "LEFT", -6, 0)
frame.deposit:SetWordWrap(false)

-- Live updates while open (spec 4.3), for the bank tabs only: count, lock and loaded data
-- repaint in place; an emptied slot or a different item goes to GroupView.Changes; a tab
-- that appears or changes size lays the bank out again (held back like any full layout).
local BANK_REASONS
SB.Inventory.OnChanged(Guard("bank.inventory", function(mask, changes)
	if not (frame:IsShown() and BW.view.IsOpen()) then
		return
	end
	local Inv, B, A, v = SB.Inventory, SB.Buttons, SB.Adapter, BW.view
	BANK_REASONS = BANK_REASONS or { Inv.R.COUNT, Inv.R.ITEM, Inv.R.SIZE, Inv.R.LOCK, Inv.R.LOADED }
	local bankChange = false
	for _, c in ipairs(changes) do
		if B.KindOf(c.bag) ~= "bags" then
			bankChange = true
			break
		end
	end
	if BW.sortPending and bankChange then
		for _, r in ipairs(BANK_REASONS) do
			if Inv.Has(mask, r) then
				BW.sortSawUpdate = true
				SB.Debounce("bank.sortSettle", BW.SORT_SETTLE, function()
					BW.sortPending, BW.sortSawUpdate = false, false
					BW.Reflow("sort")
				end, "bank")
				break
			end
		end
	end
	if Inv.Has(mask, Inv.R.SIZE) and bankChange then
		B.EnsureBankTabs()
		BW.view.RequestLayout("size")
		return
	end
	local byGroup, touched = {}, false
	for _, c in ipairs(changes) do
		local gid = v.GroupOf(c.bag)
		local button = B.Get(c.bag, c.slot)
		if gid and button and c.slot <= (v.Size(c.bag) or 0) then
			local old = v.Record(c.bag, c.slot)
			touched = true
			if not Inv.Has(c.reasons, Inv.R.ITEM) then
				B.Paint(button, A.GetSlot(c.bag, c.slot))
				local fresh = SB.Items.Describe(c.bag, c.slot)
				if old and fresh and fresh.itemID == old.itemID then
					fresh.icon = fresh.icon or old.icon
					v.SetRecord(c.bag, c.slot, fresh)
					if SB.Overlays then
						SB.Overlays.Apply(button, fresh, c.bag)
					end
				end
			else
				local record = describe(c.bag, c.slot)
				v.SetRecord(c.bag, c.slot, record)
				-- Same itemID, new link (a keystone after a run): repaint in place (W12).
				local sameItem = old and record and old.itemID == record.itemID
				if not sameItem and (record or old) then
					byGroup[gid] = byGroup[gid] or {}
					table.insert(byGroup[gid], { bag = c.bag, slot = c.slot, kind = record and "arrived" or "left",
						icon = old and old.icon })
				end
			end
		end
	end
	for _, gid in ipairs({ "bank", "warband" }) do
		if byGroup[gid] then
			v.Changes(gid, byGroup[gid])
		end
	end
	if touched then
		v.RefreshTotals()
		searchBox.Apply()
	end
end, "bank"))

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
function BW.IsOpen()
	return frame:IsShown()
end

-- "Bank still open" on the bags window (spec 5.6): shown while the visit is open but
-- SwagBag's bank window is hidden. Its click only shows SwagBag's bank window again.
local bags = SB.BagsWindow
BW.stillOpenButton = CreateFrame("Button", nil, bags.frame, "UIPanelButtonTemplate")
BW.stillOpenButton:SetSize(110, 18)
BW.stillOpenButton:SetText(L.BANK_STILL_OPEN)
BW.stillOpenButton:SetPoint("RIGHT", bags.sortButton, "LEFT", -4, 0)
BW.stillOpenButton:SetScript("OnClick", Guard("bank.stillOpen", function()
	BW.Open()
end, "bank"))
BW.stillOpenButton:Hide()
if SB.Theme then
	SB.Theme.Button(BW.stillOpenButton)
end

-- The bags title ends left of the leftmost shown title button: this one while it shows.
function BW.RefreshStillOpen()
	local shown = (BW.interaction and not frame:IsShown() and not SB.SafeMode.IsOn("bank")) and true or false
	BW.stillOpenButton:SetShown(shown)
	bags.BoundTitle(shown and BW.stillOpenButton or nil)
end

function BW.Open()
	if SB.SafeMode.IsOn("bank") or not BW.interaction then
		return false
	end
	if frame:IsShown() then
		return true
	end
	BW.sortPending, BW.sortSawUpdate = false, false
	BW.viewButton:SetText(BW.View() == "grid" and L.VIEW_TO_SECTIONS or L.VIEW_TO_GRID)
	frame:Show()
	BW.ApplyMode()
	BW.RefreshReagents()
	BW.Layout("open")
	SB.Emit("SB_BANK_OPENED")
	BW.RefreshStillOpen()
	return true
end

function BW.Close()
	frame:Hide()
end

-- Esc, the X button and BW.Close() hide only SwagBag's window; during a visit Blizzard's bank is
-- then made visible again (no invisible bank taking bag right-clicks). The OnHide guard comes first:
-- Alt+Z hides UIParent, which fires OnHide while the frame itself is still shown.
frame:SetScript("OnHide", Guard("bank.hide", function(self)
	if self:IsShown() then
		return
	end
	if BW.interaction then -- the visit is still open: make Blizzard's bank visible again
		host.Restore()
	end
	BW.view.Clear()
	BW.sortPending, BW.sortSawUpdate = false, false
	SB.Emit("SB_BANK_CLOSED")
	BW.RefreshStillOpen()
end, "bank"))

function BW.OnBankOpened()
	BW.interaction, BW.visit = true, nil
	BW.Open()
	BW.RefreshStillOpen()
end

function BW.OnBankClosed()
	BW.interaction, BW.visit = false, nil
	frame:Hide()
	host.Restore()
	BW.RefreshStillOpen()
end

SB.On("BANKFRAME_OPENED", function()
	BW.OnBankOpened()
end, "bank")

SB.On("BANKFRAME_CLOSED", function()
	BW.OnBankClosed()
end, "bank")

-- A bank tab bought or changed during the visit (spec 9, 13.2 item 6; the event is
-- feature-detected: registration fails silently on a client without it).
SB.On("BANK_TAB_SETTINGS_UPDATED", function()
	if not (frame:IsShown() and BW.view.IsOpen()) then
		return
	end
	-- Ruling W3-25: a deposit still waiting on the 50 ms flush is notified (and marked new)
	-- first; the rescan below would otherwise absorb it as "already there".
	SB.Inventory.FlushKinds({ "bank", "warband" }, "tabs")
	SB.Inventory.ScanKind("bank")
	SB.Inventory.ScanKind("warband")
	SB.Buttons.EnsureBankTabs()
	BW.view.RequestLayout("tabs")
end, "bank")

-- /swagbag free tile|all (plan D19): the bank regroups too, held back like any full layout.
SB.On("SB_FREE_TILE_CHANGED", function()
	if frame:IsShown() then
		BW.view.RequestLayout("free")
	end
end, "bank")

-- Auctionator reported new prices: the section totals follow, in place.
SB.On("SB_PRICES_CHANGED", function()
	if frame:IsShown() then
		BW.view.RefreshTotals()
	end
end, "bank")

-- Disabling or reloading never leaves Blizzard's bank moved (spec 8.6).
SB.On("PLAYER_LOGOUT", function()
	host.Restore()
end, "bank")

-- Safe Mode for the bank: hand everything back to Blizzard; switching it off during a visit
-- takes over again.
SB.On("SB_SAFEMODE_CHANGED", function(_, window, on)
	if window ~= "bank" then
		return
	end
	if on then
		frame:Hide()
		host.Restore()
	elseif BW.interaction then
		BW.Open()
	end
	BW.RefreshStillOpen()
end, "none")

SB.Slash.Register("bank", L.HELP_BANK, function(arg)
	arg = (arg or ""):lower()
	if arg ~= "tiny" and arg ~= "beside" then
		return L.BANK_USAGE:format(BW.Mode())
	end
	if not SB.Config.Set("bank.blizzardFrame", arg) then
		return L.SETTINGS_READONLY
	end
	BW.visit = nil
	if frame:IsShown() then
		BW.ApplyMode()
	end
	if SB.Adapter.InCombat() then -- this visit may not follow it (ruling W3-1)
		return L.BANK_MODE_SAVED_NEXT
	end
	return arg == "tiny" and L.BANK_MODE_TINY or L.BANK_MODE_BESIDE
end, "bank")
