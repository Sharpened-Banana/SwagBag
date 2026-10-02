-- SwagBag quick setup (spec 12.1: "a one-screen quick setup (playstyle -> preset)"; the full
-- four-step wizard and the tour are November, F7). Shown once, a few seconds after the first
-- login with this build, on any character (settings are account-wide). /swagbag setup shows it
-- again (AC7.4); /swagbag tour says when the tour arrives.
--   Pick any of M+, Raid, Gold-making, Casual, Collector, and the slots per row, then:
--   Apply  sets each picked style's preset and says what it did
--   Skip   keeps SwagBag's defaults and says so (AC7.2)
--   Esc / the X  "later": nothing is saved; it opens again at the next login, and says so
-- Presets only switch things ON for the chosen styles (every focus mode is on by default) and
-- move categories up; Casual (without M+ or Raid) is the one that switches two things off.
-- All writes refuse while the settings are read-only (a newer schema), with that reason.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local QS = { picked = {}, columns = 12, styleButtons = {}, columnButtons = {}, DELAY = 3 }
SB.QuickSetup = QS

QS.STYLES = {
	{ id = "mplus", name = "QS_MPLUS" }, { id = "raid", name = "QS_RAID" }, { id = "gold", name = "QS_GOLD" },
	{ id = "casual", name = "QS_CASUAL" }, { id = "collector", name = "QS_COLLECTOR" },
}
QS.COLUMNS = { 10, 12, 14 }

-- Categories a style moves up, right after Keystone & Crests (spec 7.6: "Gold promotes Trade
-- Goods and BoE gear").
local PROMOTE = { gold = { "c_tradegoods", "c_boe" }, collector = { "c_collect" } }

-- Pure: the settings each style sets, given everything picked. Returns { { path, value } }.
function QS.Preset(picked)
	local out = {}
	local function set(path, value)
		out[#out + 1] = { path, value }
	end
	if picked.mplus then
		set("focus.on.mplus", true)
		set("consumables.warn", true)
		set("overlays.keystone", true)
		set("overlays.track", true)
	end
	if picked.raid then
		set("focus.on.raid", true)
		set("consumables.warn", true)
		set("overlays.upgrade", true)
	end
	if picked.gold then
		set("prices.headerTotals", true)
	end
	if picked.casual and not picked.mplus and not picked.raid then
		set("consumables.warn", false)
		set("overlays.track", false)
	end
	return out
end

-- Pure: the category display order with the picked styles' categories moved up.
function QS.Order(display, picked)
	local up = {}
	for _, s in ipairs(QS.STYLES) do
		for _, id in ipairs(picked[s.id] and PROMOTE[s.id] or {}) do
			up[#up + 1] = id
		end
	end
	if #up == 0 then
		return nil
	end
	local moved, out = {}, {}
	for _, id in ipairs(up) do
		moved[id] = true
	end
	for _, id in ipairs(display) do
		if not moved[id] then
			out[#out + 1] = id
			if id == "c_keystone" then
				for _, u in ipairs(up) do
					out[#out + 1] = u
				end
			end
		end
	end
	return out
end

local function names(picked)
	local out = {}
	for _, s in ipairs(QS.STYLES) do
		if picked[s.id] then
			out[#out + 1] = L[s.name]
		end
	end
	return out
end

-- The open windows follow at once.
local function refresh()
	SB.Categories.Load()
	-- No Focus.Refresh here: the focus.* writes above went through Config.Set, whose
	-- SB_CONFIG_CHANGED Focus already listens to.
	SB.Emit("SB_PRICES_CHANGED")
	if SB.Overlays then
		SB.Overlays.context = nil
		SB.Overlays.RefreshAll()
	end
	local W = SB.BagsWindow
	if W and W.IsOpen() then
		W.RequestLayout("setup")
		W.RefreshTitle()
	end
end

-- Apply the picked styles. Returns the feedback line.
function QS.Apply()
	local C = SB.Config
	local list = names(QS.picked)
	if #list == 0 then
		return L.QS_PICK_FIRST
	end
	if C.readOnly then
		return L.SETTINGS_READONLY
	end
	for _, p in ipairs(QS.Preset(QS.picked)) do
		C.Set(p[1], p[2])
	end
	C.Set("bags.columns", QS.columns)
	local display = {}
	for _, c in ipairs(SB.Categories.display) do
		display[#display + 1] = c.id
	end
	local order = QS.Order(display, QS.picked)
	if order then
		C.db.categoryOrder = order
	end
	C.Set("setup.done", true)
	-- The settings are saved; a refresh error must not turn that into "failed".
	local refreshed = SB.ErrorTrap.Run("setup.refresh", "none", refresh)
	QS.Close("done")
	local line = L.QS_APPLIED:format(table.concat(list, ", "))
	if not refreshed then
		line = line .. " " .. L.QS_REFRESH_NOTE
	end
	return line
end

-- First run: "keeps its defaults". A re-run (/swagbag setup after earlier edits): "keeps your
-- current settings", since the defaults are no longer what is set.
function QS.Skip()
	local rerun = SB.Config.Get("setup.done") == true
	if not SB.Config.Set("setup.done", true) then
		return L.SETTINGS_READONLY
	end
	QS.Close("done")
	return rerun and L.QS_SKIPPED_KEPT or L.QS_SKIPPED
end

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
frame:SetSize(560, 250)
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

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("TOPLEFT", 14, -12)
frame.title:SetText(L.QS_TITLE)
frame.intro = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.intro:SetPoint("TOPLEFT", 14, -40)
frame.intro:SetText(L.QS_INTRO)
frame.columnsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.columnsLabel:SetPoint("TOPLEFT", 14, -110)
frame.columnsLabel:SetText(L.SET_COLUMNS)
frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.status:SetPoint("BOTTOMLEFT", 14, 44)
frame.status:SetText(L.QS_HINT)
if SB.Theme then -- the look (UI/Theme.lua); the Blizzard theme keeps exactly the values above (AC14.1)
	SB.Theme.Window(frame, "dialog")
	SB.Theme.Text(frame.title, "titleLarge")
	SB.Theme.Text(frame.intro, "body")
	SB.Theme.Text(frame.columnsLabel, "label")
	SB.Theme.Text(frame.status, "small")
end

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local function paint()
	for _, s in ipairs(QS.STYLES) do
		local b = QS.styleButtons[s.id]
		local on = QS.picked[s.id] == true
		b:SetText(on and L.QS_STYLE_ON:format(L[s.name]) or L[s.name])
		if on then
			b:LockHighlight()
		else
			b:UnlockHighlight()
		end
	end
	for n, b in pairs(QS.columnButtons) do
		if n == QS.columns then
			b:LockHighlight()
		else
			b:UnlockHighlight()
		end
	end
end
QS.Paint = paint

for i, s in ipairs(QS.STYLES) do
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(100, 24)
	b:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (i - 1) * 106, -70)
	b:SetScript("OnClick", Guard("setup.style", function()
		QS.picked[s.id] = not QS.picked[s.id] or nil
		paint()
	end, "none"))
	QS.styleButtons[s.id] = b
end

for i, n in ipairs(QS.COLUMNS) do
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(56, 22)
	b:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (i - 1) * 60, -130)
	b:SetText(tostring(n))
	b:SetScript("OnClick", Guard("setup.columns", function()
		QS.columns = n
		paint()
	end, "none"))
	QS.columnButtons[n] = b
end

-- Apply / Skip answer in chat (P2); a refusal also shows on the screen, which stays open. An
-- error runs under "none" (a settings glitch never takes the bags away): the status line and
-- chat say it failed, and the error is recorded for /swagbag report.
local function finish(fn)
	local ok, feedback = SB.ErrorTrap.Run("setup.finish", "none", fn)
	if not ok then
		feedback = L.SETTINGS_FAILED
	end
	SB.Print(feedback)
	frame.status:SetText(feedback)
end

QS.applyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
QS.applyButton:SetSize(120, 24)
QS.applyButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
QS.applyButton:SetText(L.QS_APPLY)
QS.applyButton:SetScript("OnClick", Guard("setup.apply", function()
	finish(QS.Apply)
end, "none"))
QS.skipButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
QS.skipButton:SetSize(160, 24)
QS.skipButton:SetPoint("RIGHT", QS.applyButton, "LEFT", -8, 0)
QS.skipButton:SetText(L.QS_SKIP)
QS.skipButton:SetScript("OnClick", Guard("setup.skip", function()
	finish(QS.Skip)
end, "none"))
if SB.Theme then
	for _, b in pairs(QS.styleButtons) do
		SB.Theme.Button(b)
	end
	for _, b in pairs(QS.columnButtons) do
		SB.Theme.Button(b)
	end
	SB.Theme.Button(QS.applyButton)
	SB.Theme.Button(QS.skipButton)
end

-- Closing without Apply or Skip (Esc, the X) is "later": it says when the screen comes back.
-- The OnHide guard comes first (Alt+Z hides UIParent while this frame stays shown).
frame:SetScript("OnHide", Guard("setup.hide", function(self)
	if self:IsShown() then
		return
	end
	if QS.closing ~= "done" then
		-- Once setup is done it never comes back by itself, so do not promise it will.
		SB.Print(SB.Config.Get("setup.done") and L.QS_LATER_KEPT or L.QS_LATER)
	end
	QS.closing = nil
end, "none"))

function QS.Close(how)
	QS.closing = how
	frame:Hide()
end

function QS.Show()
	QS.picked, QS.columns = {}, SB.Config.Get("bags.columns")
	frame.status:SetText(L.QS_HINT)
	paint()
	frame:Show()
end

function QS.IsOpen()
	return frame:IsShown()
end

-- First login with this build: show it a few seconds after the loading screen, unless the
-- settings are read-only or the bags are in Safe Mode (then the bags are Blizzard's anyway).
SB.On("SB_LOGIN", function()
	if SB.Config.Get("setup.done") or SB.Config.readOnly then
		return
	end
	SB.Debounce("setup.show", QS.DELAY, QS.TryShow, "none")
end, "none")

-- Not in combat and not inside an instance (a popup there would cover the fight or the run):
-- wait, and try again when combat ends or the zone changes. /swagbag setup opens at once.
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

local function retry()
	if QS.waiting then
		QS.TryShow()
	end
end
SB.On("PLAYER_REGEN_ENABLED", retry, "none")
SB.On("PLAYER_ENTERING_WORLD", retry, "none")

SB.Slash.Register("setup", L.HELP_SETUP, function()
	QS.Show()
	return L.QS_OPENED
end)

SB.Slash.Register("tour", L.HELP_TOUR, function()
	return L.TOUR_LATER
end)
