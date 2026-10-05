-- SwagBag setup wizard (spec F7: AC7.1, AC7.2, AC7.4; week 12, from the week-4 quick setup). Shown once, a few
-- seconds after the first login, on any character (settings are account-wide); a user who finished or skipped the
-- quick setup before (setup.done) never sees it again unless they type /swagbag setup (AC7.4), which shows it filled
-- in with the settings as they are. Four short steps, one screen each:
--   1 What do you play?   M+, Raid, Gold-making, Casual, Collector: pick any, or none
--   2 What that turns on  every focus mode and what the picked styles switch (AC9.2), each a click to switch
--   3 Layout              slots per row, the bags' size, the look
--   4 Gold                where prices come from (found or not), the gold glow at the bank, selling junk
-- Back, Next and Skip on every step, Finish on the last. Nothing is written before Finish (Engine/Setup.lua keeps the
-- draft): Skip keeps SwagBag's defaults (or the settings as they are) and says so (AC7.2); Esc or the X is "later",
-- nothing saved. When combat starts the wizard steps aside and comes back where it was when combat ends.
-- All writes refuse while the settings are read-only (a newer schema), with that reason.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local Setup = SB.Setup
local QS = { step = 1, STEPS = 4, styleButtons = {}, columnButtons = {}, scaleButtons = {}, lookButtons = {},
	worthButtons = {}, sellButtons = {}, switchButtons = {}, MAX_SWITCHES = 18, DELAY = 3 }
SB.QuickSetup = QS

QS.STYLES = Setup.STYLES
QS.COLUMNS = { 10, 12, 14, 16 }
QS.SCALES = { 0.8, 0.9, 1.0, 1.1, 1.25 }
QS.WORTH = { "off", 50, 100, 500, 1000, "top" } -- "top" is shown only while it is the setting now

---------------------------------------------------------------------------
-- The screen (plain frames only; it can open in combat)
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "SwagBagQuickSetup", UIParent, "BackdropTemplate")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:SetSize(580, 400)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
frame:Hide()
QS.frame = frame
table.insert(UISpecialFrames, "SwagBagQuickSetup")

frame:SetScript("OnDragStart", Guard("setup.dragStart", function()
	frame:StartMoving()
end, "none"))
frame:SetScript("OnDragStop", Guard("setup.dragStop", function()
	frame:StopMovingOrSizing()
end, "none"))

local function text(parent, template, x, y, width)
	local fs = parent:CreateFontString(nil, "OVERLAY", template)
	fs:SetPoint("TOPLEFT", x, y)
	if width then
		fs:SetWidth(width)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(true)
	end
	return fs
end

frame.title = text(frame, "GameFontNormalLarge", 14, -12)
frame.title:SetText(L.QS_TITLE)
frame.stepLabel = text(frame, "GameFontNormal", 14, -38)
frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.status:SetPoint("BOTTOMLEFT", 14, 44)
frame.status:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
frame.status:SetJustifyH("LEFT")
frame.status:SetText(L.WIZ_HINT)

-- One panel per step, under the step's name; only the current one is shown.
frame.steps = {}
for i = 1, QS.STEPS do
	local p = CreateFrame("Frame", nil, frame)
	p:SetPoint("TOPLEFT", 0, -60)
	p:SetPoint("BOTTOMRIGHT", 0, 64)
	p:Hide()
	frame.steps[i] = p
end
local step1, step2, step3, step4 = frame.steps[1], frame.steps[2], frame.steps[3], frame.steps[4]

frame.intro = text(step1, "GameFontHighlight", 14, -4, 552)
frame.intro:SetText(L.QS_INTRO)
-- Week 6 (D18): what the Pause button on the bags is for, before the user meets it.
frame.pauseNote = text(step1, "GameFontHighlightSmall", 14, -90, 552)
frame.pauseNote:SetText(L.QS_PAUSE_NOTE)
frame.switchNote = text(step2, "GameFontHighlight", 14, -4, 552)
frame.switchNote:SetText(L.WIZ_SWITCH_NOTE)
frame.columnsLabel = text(step3, "GameFontNormal", 14, -4)
frame.columnsLabel:SetText(L.SET_COLUMNS)
frame.scaleLabel = text(step3, "GameFontNormal", 14, -60)
frame.scaleLabel:SetText(L.SET_SCALE)
frame.lookLabel = text(step3, "GameFontNormal", 14, -116)
frame.lookLabel:SetText(L.SET_LOOK)
frame.prices = text(step4, "GameFontHighlight", 14, -4, 552)
frame.worthLabel = text(step4, "GameFontNormal", 14, -52)
frame.worthLabel:SetText(L.SET_WORTH)
frame.sellLabel = text(step4, "GameFontNormal", 14, -108)
frame.sellLabel:SetText(L.SET_VENDOR_SELL)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

-- A wizard button: fn() runs under ErrorTrap "none", then the screen is drawn again.
local function button(parent, width, x, y, label, fn)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	if x then
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	end
	if label then
		b:SetText(label)
	end
	b:SetScript("OnClick", Guard("setup.click", function()
		fn()
		QS.Paint()
	end, "none"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
	return b
end

-- QS.lit[button]: drawn selected (a picked style, the choice in force).
QS.lit = {}
local function highlight(b, on)
	QS.lit[b] = on or nil
	if on then
		b:LockHighlight()
	else
		b:UnlockHighlight()
	end
end

local function value(key)
	return Setup.Value(QS.draft, key)
end

-- Step 1: the styles.
for i, s in ipairs(QS.STYLES) do
	QS.styleButtons[s.id] = button(step1, 100, 14 + (i - 1) * 106, -40, nil, function()
		Setup.Toggle(QS.draft, s.id)
	end)
end

-- Step 2: one button per switch, in two columns; the text says the switch and its state, a click switches it.
for i = 1, QS.MAX_SWITCHES do
	local b
	b = button(step2, 270, 14 + ((i - 1) % 2) * 280, -44 - math.floor((i - 1) / 2) * 24, nil, function()
		if b.key then
			Setup.Set(QS.draft, b.key, not value(b.key))
		end
	end)
	QS.switchButtons[i] = b
end

-- Step 3: slots per row, size, look.
for i, n in ipairs(QS.COLUMNS) do
	QS.columnButtons[n] = button(step3, 56, 14 + (i - 1) * 60, -22, tostring(n), function()
		Setup.Set(QS.draft, "bags.columns", n)
	end)
end
for i, n in ipairs(QS.SCALES) do
	QS.scaleButtons[n] = button(step3, 56, 14 + (i - 1) * 60, -78, L.SET_PERCENT:format(math.floor(n * 100 + 0.5)), function()
		Setup.Set(QS.draft, "bags.scale", n)
	end)
end

-- The looks there are (UI/Theme.lua), each made the first time it is drawn: a look whose addon is not loaded is left
-- out, unless it is the one set now.
local function lookButton(id, i)
	local b = QS.lookButtons[id]
	if not b then
		b = button(step3, 120, nil, nil, SB.Theme.Name(id), function()
			Setup.Set(QS.draft, "theme.name", id)
		end)
		QS.lookButtons[id] = b
	end
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", step3, "TOPLEFT", 14 + (i - 1) * 126, -134)
	return b
end

-- Step 4: the gold glow and selling junk.
local function worthText(v)
	if v == "off" then
		return L.SET_OFF
	elseif v == "top" then
		return L.SET_WORTH_TOP:format(SB.Config.Get("prices.worthTop"))
	end
	return L.WIZ_WORTH_GOLD:format(v)
end
for i, v in ipairs(QS.WORTH) do
	QS.worthButtons[v] = button(step4, 84, 14 + (i - 1) * 88, -70, nil, function()
		if v == "off" or v == "top" then
			Setup.Set(QS.draft, "prices.worth", v)
		else
			Setup.Set(QS.draft, "prices.worth", "fixed")
			Setup.Set(QS.draft, "prices.worthGold", v)
		end
	end)
end
for i, v in ipairs({ true, false }) do
	QS.sellButtons[v] = button(step4, 84, 14 + (i - 1) * 88, -126, v and L.SET_ON or L.SET_OFF, function()
		Setup.Set(QS.draft, "vendor.autoSell", v)
	end)
end

-- Where prices come from: the auction addon SwagBag found, or what a vendor pays.
local function pricesLine()
	local P = SB.Prices
	local source = P and P.Source()
	if source and source ~= "Vendor" then
		return L.WIZ_PRICES_FROM:format(P.SourceText())
	end
	return L.WIZ_PRICES_VENDOR
end

local function paintStep2()
	local keys = Setup.Switches(QS.draft)
	for i, b in ipairs(QS.switchButtons) do
		local key = keys[i]
		b.key = key
		if key then
			local on = value(key) == true
			b:SetText(L.WIZ_SWITCH:format(Setup.Label(key), on and L.SET_ON or L.SET_OFF))
			highlight(b, on)
			b:Show()
		else
			b:Hide()
		end
	end
end

local function paintStep3()
	for n, b in pairs(QS.columnButtons) do
		highlight(b, value("bags.columns") == n)
	end
	for n, b in pairs(QS.scaleButtons) do
		highlight(b, value("bags.scale") == n)
	end
	local T, shown, i = SB.Theme, {}, 0
	if T and T.order then
		for _, id in ipairs(T.order) do
			if T.Available(id) or id == value("theme.name") then
				i = i + 1
				local b = lookButton(id, i)
				highlight(b, value("theme.name") == id)
				b:Show()
				shown[id] = true
			end
		end
	end
	for id, b in pairs(QS.lookButtons) do
		if not shown[id] then
			b:Hide()
		end
	end
	frame.lookLabel:SetShown(i > 0)
end

local function paintStep4()
	frame.prices:SetText(pricesLine())
	local mode, gold = value("prices.worth"), value("prices.worthGold")
	for v, b in pairs(QS.worthButtons) do
		b:SetText(worthText(v))
		if v == "off" or v == "top" then
			highlight(b, mode == v)
		else
			highlight(b, mode == "fixed" and gold == v)
		end
	end
	QS.worthButtons.top:SetShown(SB.Config.Get("prices.worth") == "top")
	for v, b in pairs(QS.sellButtons) do
		highlight(b, value("vendor.autoSell") == v)
	end
end

local STEP_NAMES = { "WIZ_STEP1", "WIZ_STEP2", "WIZ_STEP3", "WIZ_STEP4" }

function QS.Paint()
	local d = QS.draft
	if not d then
		return
	end
	frame.stepLabel:SetText(L.WIZ_STEP:format(QS.step, QS.STEPS, L[STEP_NAMES[QS.step]]))
	for i, p in ipairs(frame.steps) do
		p:SetShown(i == QS.step)
	end
	for _, s in ipairs(QS.STYLES) do
		local b = QS.styleButtons[s.id]
		local on = d.styles[s.id] == true
		b:SetText(on and L.QS_STYLE_ON:format(L[s.name]) or L[s.name])
		highlight(b, on)
	end
	if QS.step == 2 then
		paintStep2()
	elseif QS.step == 3 then
		paintStep3()
	elseif QS.step == 4 then
		paintStep4()
	end
	QS.skipButton:SetText(SB.Config.Get("setup.done") and L.QS_SKIP_KEPT or L.QS_SKIP)
	QS.backButton:SetShown(QS.step > 1)
	QS.nextButton:SetShown(QS.step < QS.STEPS)
	QS.finishButton:SetShown(QS.step == QS.STEPS)
end

-- Finish / Skip answer in chat (P2); a refusal also shows on the screen, which stays open. An error runs under "none"
-- (a settings glitch never takes the bags away): the status line and chat say it failed, and the error is recorded
-- for /swagbag report.
local function finish(fn)
	local ok, feedback = SB.ErrorTrap.Run("setup.finish", "none", fn, QS.draft)
	if not ok then
		feedback = L.SETTINGS_FAILED
	end
	SB.Print(feedback)
	frame.status:SetText(feedback)
	if ok and not SB.Config.readOnly then
		QS.Close("done")
	end
end

function QS.Hint()
	return SB.Config.Get("setup.done") and L.WIZ_HINT_KEPT or L.WIZ_HINT
end

local function go(step)
	QS.step = math.max(1, math.min(QS.STEPS, step))
	frame.status:SetText(QS.Hint())
end

QS.finishButton = button(frame, 120, nil, nil, L.WIZ_FINISH, function()
	finish(Setup.Finish)
end)
QS.finishButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
QS.nextButton = button(frame, 120, nil, nil, L.WIZ_NEXT, function()
	go(QS.step + 1)
end)
QS.nextButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
QS.backButton = button(frame, 90, nil, nil, L.WIZ_BACK, function()
	go(QS.step - 1)
end)
QS.backButton:SetPoint("RIGHT", QS.nextButton, "LEFT", -8, 0)
QS.skipButton = button(frame, 160, nil, nil, L.QS_SKIP, function()
	finish(Setup.Skip)
end)
QS.skipButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
if SB.Theme then -- the look (UI/Theme.lua); the Blizzard theme keeps exactly the values above (AC14.1)
	SB.Theme.Window(frame, "dialog")
	SB.Theme.Text(frame.title, "titleLarge")
	for _, fs in ipairs({ frame.intro, frame.switchNote, frame.prices }) do
		SB.Theme.Text(fs, "body")
	end
	for _, fs in ipairs({ frame.stepLabel, frame.columnsLabel, frame.scaleLabel, frame.lookLabel, frame.worthLabel,
		frame.sellLabel }) do
		SB.Theme.Text(fs, "label")
	end
	SB.Theme.Text(frame.pauseNote, "small")
	SB.Theme.Text(frame.status, "small")
end

-- Closing without Finish or Skip (Esc, the X) is "later": it says when the screen comes back. Stepping aside for
-- combat says its own line. The OnHide guard comes first (Alt+Z hides UIParent while this frame stays shown).
frame:SetScript("OnHide", Guard("setup.hide", function(self)
	if self:IsShown() then
		return
	end
	if not QS.closing then
		-- Once setup is done it never comes back by itself, so do not promise it will.
		SB.Print(SB.Config.Get("setup.done") and L.QS_LATER_KEPT or L.QS_LATER)
	end
	QS.closing = nil
end, "none"))

function QS.Close(how)
	QS.closing = how
	frame:Hide()
end

-- A fresh draft from the settings as they are (a re-run starts from the styles picked last time), at step 1.
function QS.Show()
	QS.draft, QS.step, QS.combatHidden = Setup.New(), 1, false
	frame.status:SetText(QS.Hint())
	QS.Paint()
	frame:Show()
end

function QS.IsOpen()
	return frame:IsShown()
end

-- First login with this build: show it a few seconds after the loading screen, unless the settings are read-only, the
-- bags are in Safe Mode (then the bags are Blizzard's anyway), or setup is done (a user of the quick setup).
SB.On("SB_LOGIN", function()
	if SB.Config.Get("setup.done") or SB.Config.readOnly then
		return
	end
	SB.Debounce("setup.show", QS.DELAY, QS.TryShow, "none")
end, "none")

-- Not in combat and not inside an instance (a popup there would cover the fight or the run): wait, and try again when
-- combat ends or the zone changes. /swagbag setup opens at once.
function QS.TryShow()
	if SB.SafeMode.IsOn("bags") or SB.Config.readOnly or SB.Config.Get("setup.done") then
		QS.waiting = false
		return
	end
	if SB.Adapter.InCombat() or SB.Adapter.InstanceInfo().instanceType then
		QS.waiting = true
		return
	end
	QS.waiting = false
	QS.Show()
end

local function inInstance()
	return SB.Adapter.InstanceInfo().instanceType ~= nil
end

-- Combat starts while the wizard is open: it steps aside (it never covers a fight) and comes back where it was, with
-- everything picked, when combat ends. Nothing is saved meanwhile. Inside an instance (a run, a raid, a delve) it
-- does not come back when combat ends: it keeps the draft and returns when the player leaves the instance, or
-- when they type /swagbag setup (which resumes the kept draft).
SB.On("PLAYER_REGEN_DISABLED", function()
	if frame:IsShown() then
		QS.combatHidden = true
		QS.Close("combat")
		SB.Print(inInstance() and L.WIZ_COMBAT_HIDDEN_RUN or L.WIZ_COMBAT_HIDDEN)
	end
end, "none")

-- Show the draft kept while the wizard stepped aside, at the step it was.
function QS.Resume()
	QS.combatHidden = false
	QS.Paint()
	frame:Show()
end

SB.On("PLAYER_REGEN_ENABLED", function()
	if QS.combatHidden then
		if not inInstance() then
			QS.Resume()
		end
	elseif QS.waiting then
		QS.TryShow()
	end
end, "none")
SB.On("PLAYER_ENTERING_WORLD", function()
	if QS.combatHidden then
		if not inInstance() and not SB.Adapter.InCombat() then
			QS.Resume()
		end
	elseif QS.waiting then
		QS.TryShow()
	end
end, "none")

SB.Slash.Register("setup", L.HELP_SETUP, function()
	if QS.combatHidden then
		QS.Resume()
	else
		QS.Show()
	end
	return L.QS_OPENED
end)

SB.Slash.Register("tour", L.HELP_TOUR, function()
	return L.TOUR_LATER
end)
