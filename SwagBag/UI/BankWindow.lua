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
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local BW = {
	interaction = false, -- the bank visit is open (between BANKFRAME_OPENED and _CLOSED)
	visit = nil, -- "tiny" | "beside" for this visit (the Blizzard bank button), nil = setting
	target = nil, -- "bank" | "warband" | nil: Blizzard's selected bank type, last read
	lastVisit = nil, -- "tiny" | "beside": the mode of the last visit (for /swagbag report)
	HEADER = 58,
	FOOTER = 6,
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
frame.deposit:SetPoint("TOPLEFT", 10, -24)
frame.deposit:SetJustifyH("LEFT")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local function blizzardBank()
	return SB.Adapter.Frame("BankFrame")
end

---------------------------------------------------------------------------
-- Title feedback and position
---------------------------------------------------------------------------
local titleToken = 0
function BW.Flash(text)
	titleToken = titleToken + 1
	local token = titleToken
	frame.title:SetText(text)
	SB.Adapter.After(1.5, Guard("bank.flash", function()
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
	BW.target = SB.Adapter.ActiveBankType()
	frame.deposit:SetText(BW.target and L.BANK_DEPOSITS_TO:format(groupName(BW.target)) or "")
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

-- The "Blizzard bank" button: show or hide Blizzard's bank for this visit.
function BW.ToggleVisit()
	if SB.Adapter.InCombat() then
		BW.Flash(L.BANK_NOT_IN_COMBAT)
		return false
	end
	BW.visit = BW.VisitMode() == "tiny" and "beside" or "tiny"
	BW.ApplyMode()
	BW.Flash(BW.visit == "beside" and L.BANK_SHOWING_BLIZZARD or L.BANK_HIDING_BLIZZARD)
	return true
end

local function titleButton(text, label, onClick, width)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(width or 72, 18)
	b:SetText(text)
	b:SetScript("OnClick", Guard(label, onClick, "bank"))
	return b
end
BW.TitleButton = titleButton

BW.blizzardButton = titleButton(L.BTN_BLIZZARD_BANK, "bank.blizzardButton", function()
	BW.ToggleVisit()
end, 104)
BW.blizzardButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -5)

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

function BW.RefreshStillOpen()
	BW.stillOpenButton:SetShown(BW.interaction and not frame:IsShown() and not SB.SafeMode.IsOn("bank"))
end

function BW.Open()
	if SB.SafeMode.IsOn("bank") or not BW.interaction then
		return false
	end
	if frame:IsShown() then
		return true
	end
	frame:Show()
	BW.ApplyMode()
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
