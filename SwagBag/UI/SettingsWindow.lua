-- SwagBag settings window (spec F15, 10.5): SwagBag's own frame, opened by a bare /swagbag or
-- /swagbag settings [page]. No Blizzard Settings-panel integration (the spec does not ask for
-- one); only plain Frames, Buttons and FontStrings, so it opens in combat and never touches a
-- secure frame or an item button.
-- Each page is a list of rows, laid out top to bottom, label above its buttons:
--   { kind = "choice", label, choices = { { value, text } }, get() -> value, apply(value) -> feedback }
--       the opinionated default is the first choice, the alternative right next to it (P1);
--       the button whose value get() returns is shown selected (highlight locked)
--   { kind = "actions", label, actions = { { text, run() -> feedback } } }
--   { kind = "drop", label, text, onDrop() -> feedback }   a button that takes the item on the
--       cursor (dragged onto it, or clicked while holding it)
--   { kind = "note", label }
--   { kind = "input", label, get() -> text, set(text), commit(text) -> feedback, button, maxLetters, boxWidth }
--       a one-line text box (week 11, the category editor): every keystroke goes to set (no answer, no redraw, so
--       nothing typed is lost when another button is clicked); Enter or the button after the box (button, default
--       L.SET_APPLY) runs commit, which answers in the status line like any click
-- An action may carry selected = true: its button is shown selected, as a choice's (week 11).
-- Any row may carry tip: a plain-words explanation shown when the mouse rests on one of its buttons,
-- under the row's label; a choice or action may carry its own tip, shown after the row's (week 6).
-- A button is as wide as its text (plus TEXT_PAD), never narrower than the row's width (or
-- BUTTON); a button that no longer fits the line starts the next one, and the rows below move down.
-- Pages register with SW.AddPage{ id, title, rows = function() -> list }, in TOC order, and are
-- rebuilt after every click, so a page can change its rows (the focus mode being edited).
-- Every click answers in the status line at the bottom (P2): the feedback text, which for a
-- read-only setting is L.SETTINGS_READONLY. An error is recorded (window "none": a settings
-- glitch never takes the bags away) and the status line says so.
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local SW = { pages = {}, byId = {}, current = nil, labels = {}, buttons = {}, inputs = {},
	used = { labels = 0, buttons = 0, inputs = 0 },
	selected = {}, tips = {}, WIDTH = 640, HEIGHT = 470, NAV = 140, BUTTON = 120, ROW = 20, GAP = 8, LINE_GAP = 4, TEXT_PAD = 24 }
SB.SettingsWindow = SW

-- "BackdropTemplate" is a plain (non-secure) template, so this window still opens in combat.
local frame = CreateFrame("Frame", "SwagBagSettings", UIParent, "BackdropTemplate")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
frame:SetSize(SW.WIDTH, SW.HEIGHT)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
frame:Hide()
SW.frame = frame
table.insert(UISpecialFrames, "SwagBagSettings")

frame:SetScript("OnDragStart", Guard("settings.dragStart", function()
	frame:StartMoving()
end, "none"))
frame:SetScript("OnDragStop", Guard("settings.dragStop", function()
	frame:StopMovingOrSizing()
end, "none"))

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("TOPLEFT", 12, -10)
frame.title:SetText(L.SET_TITLE)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.status:SetPoint("BOTTOMLEFT", SW.NAV + 12, 10)
frame.status:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
frame.status:SetJustifyH("LEFT")
frame.status:SetWordWrap(true)
frame.status:SetText(L.SET_SAVED_NOTE)
if SB.Theme then -- the look (UI/Theme.lua); the Blizzard theme keeps exactly the values above (AC14.1)
	SB.Theme.Window(frame, "dialog")
	SB.Theme.Text(frame.title, "titleLarge")
	SB.Theme.Text(frame.status, "small")
end

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", SW.NAV + 8, -40)
scroll:SetPoint("BOTTOMRIGHT", -8, 44)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(SW.WIDTH - SW.NAV - 16, 100)
scroll:SetScrollChild(child)
SW.scroll, SW.child = scroll, child
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", Guard("settings.wheel", function(_, delta)
	local max = math.max(0, (child:GetHeight() or 0) - (scroll:GetHeight() or 0))
	scroll:SetVerticalScroll(math.max(0, math.min(max, scroll:GetVerticalScroll() - delta * 40)))
end, "none"))

-- The status line: feedback (string, list of strings, or nil = "Done.").
function SW.Say(feedback)
	if type(feedback) == "table" then
		feedback = table.concat(feedback, " ")
	end
	if feedback == nil or feedback == "" then
		feedback = L.CMD_DONE
	end
	SW.lastStatus = feedback
	frame.status:SetText(feedback)
end

-- The tooltip of a row's button (week 6): the row's label, its tip, then the button's own tip.
-- SW.tips[button] = { title, text, extra } for the buttons of the page as drawn.
function SW.ShowTip(b)
	local tip = SW.tips[b]
	if not (GameTooltip and tip and (tip.text or tip.extra)) then
		return
	end
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	GameTooltip:SetText(tip.title or "")
	if tip.text then
		GameTooltip:AddLine(tip.text, 1, 1, 1, true)
	end
	if tip.extra then
		GameTooltip:AddLine(tip.extra, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

-- Run fn (a click) inside ErrorTrap; its return value is the feedback. Then redraw the page.
local function act(label, fn, ...)
	local ok, feedback = SB.ErrorTrap.Run(label, "none", fn, ...)
	SW.Say(ok and feedback or L.SETTINGS_FAILED)
	SW.Render()
end

---------------------------------------------------------------------------
-- Widget pools (plain FontStrings and Buttons inside the scroll child)
---------------------------------------------------------------------------
local function label()
	SW.used.labels = SW.used.labels + 1
	local fs = SW.labels[SW.used.labels]
	if not fs then
		fs = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetJustifyH("LEFT")
		if SB.Theme then
			SB.Theme.Text(fs, "label")
		end
		SW.labels[SW.used.labels] = fs
	end
	fs:Show()
	return fs
end

local function button()
	SW.used.buttons = SW.used.buttons + 1
	local b = SW.buttons[SW.used.buttons]
	if not b then
		b = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
		b:SetHeight(SW.ROW)
		b:SetScript("OnClick", Guard("settings.click", function(self)
			if self.onClick then
				self.onClick()
			end
		end, "none"))
		b:SetScript("OnReceiveDrag", Guard("settings.drop", function(self)
			if self.onDrop then
				self.onDrop()
			end
		end, "none"))
		b:SetScript("OnEnter", Guard("settings.tip", function(self)
			SW.ShowTip(self)
		end, "none"))
		b:SetScript("OnLeave", Guard("settings.tipHide", function(self)
			if GameTooltip and (not GameTooltip.IsOwned or GameTooltip:IsOwned(self)) then
				GameTooltip:Hide()
			end
		end, "none"))
		if SB.Theme then
			SB.Theme.Button(b)
		end
		SW.buttons[SW.used.buttons] = b
	end
	b.onClick, b.onDrop, SW.tips[b] = nil, nil, nil
	b:Show()
	return b
end

-- A one-line text box (week 11): InputBoxTemplate is a plain, non-secure template.
local function input()
	SW.used.inputs = SW.used.inputs + 1
	local e = SW.inputs[SW.used.inputs]
	if not e then
		e = SB.TextBox(CreateFrame("EditBox", nil, child, "InputBoxTemplate")) -- lets the keyboard go in combat
		e:SetHeight(SW.ROW)
		e:SetAutoFocus(false)
		e:SetScript("OnEnterPressed", Guard("settings.inputEnter", function(self)
			self:ClearFocus()
			if self.onCommit then
				self.onCommit()
			end
		end, "none"))
		e:SetScript("OnEscapePressed", Guard("settings.inputEscape", function(self)
			self:ClearFocus()
		end, "none"))
		e:SetScript("OnTextChanged", Guard("settings.inputText", function(self, userInput)
			if userInput and self.onChange then
				self.onChange(self:GetText() or "")
			end
		end, "none"))
		SW.inputs[SW.used.inputs] = e
	end
	e.onCommit, e.onChange = nil, nil
	e:Show()
	return e
end

-- The full width of a button's text (0 when the client cannot say).
local function textWidth(b)
	local w = b.GetTextWidth and b:GetTextWidth()
	return type(w) == "number" and w or 0
end

local function setSelected(b, on)
	SW.selected[b] = on and true or nil
	if on then
		b:LockHighlight()
	else
		b:UnlockHighlight()
	end
end

local function place(region, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", child, "TOPLEFT", x, y)
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
SW.nav = {}

function SW.AddPage(page)
	SW.pages[#SW.pages + 1] = page
	SW.byId[page.id] = page
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(SW.NAV - 16, 22)
	b:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40 - (#SW.pages - 1) * 26)
	b:SetText(page.title)
	b:SetScript("OnClick", Guard("settings.page", function()
		SW.Show(page.id)
	end, "none"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
	SW.nav[page.id] = b
	return page
end

-- Lay the current page out again (after every click, and on open).
function SW.Render()
	for i = 1, SW.used.labels do
		SW.labels[i]:Hide()
	end
	for i = 1, SW.used.buttons do
		local b = SW.buttons[i]
		setSelected(b, false)
		b:Hide()
	end
	for i = 1, SW.used.inputs do
		SW.inputs[i]:ClearFocus() -- a hidden or re-used box never keeps the keyboard
		SW.inputs[i]:Hide()
	end
	SW.used.labels, SW.used.buttons, SW.used.inputs = 0, 0, 0
	local page = SW.byId[SW.current]
	if not page then
		return
	end
	for id, b in pairs(SW.nav) do
		setSelected(b, id == SW.current)
	end
	local y, x0 = -4, nil
	for _, row in ipairs(page.rows()) do
		local fs = label()
		fs:SetText(row.label)
		place(fs, 4, y)
		if row.kind == "note" then
			-- A note can be long: wrap it to the page width and move on by its real height.
			fs:SetWidth((child:GetWidth() or SW.WIDTH) - 8)
			fs:SetWordWrap(true)
			local h = fs.GetStringHeight and fs:GetStringHeight()
			y = y - math.max(18, (type(h) == "number" and h or 0) + 6)
		else
			fs:SetWidth(0)
			fs:SetWordWrap(false)
			y = y - 18
		end
		local items = row.choices or row.actions
		if row.kind == "drop" then
			items = { { text = row.text } }
		elseif row.kind == "input" then
			local e, width = input(), (child:GetWidth() or SW.WIDTH) - 4 - 12 - SW.BUTTON - 8
			e:SetMaxLetters(row.maxLetters or 255)
			e:SetText(row.get() or "")
			e:SetWidth(row.boxWidth or width)
			place(e, 18, y) -- InputBoxTemplate draws its frame a little left of the box
			e.onChange = row.set
			local function commit()
				act("settings.input", row.commit, e:GetText() or "")
			end
			e.onCommit = commit
			x0 = 18 + (row.boxWidth or width) + 8
			items = { { text = row.button or L.SET_APPLY, commit = commit } }
		end
		if items then
			local current = row.get and row.get()
			local x, room = x0 or 12, (child:GetWidth() or SW.WIDTH) - 4
			x0 = nil
			for _, item in ipairs(items) do
				local b = button()
				b:SetText(item.text)
				-- as wide as its text, never narrower than the row's width; out of room: the next line
				local w = math.min(room - 12, math.max(item.width or row.width or SW.BUTTON, textWidth(b) + SW.TEXT_PAD))
				if x > 12 and x + w > room then
					x, y = 12, y - SW.ROW - SW.LINE_GAP
				end
				b:SetWidth(w)
				place(b, x, y)
				x = x + w + 4
				if row.tip or item.tip then
					SW.tips[b] = { title = row.label, text = row.tip, extra = item.tip }
				end
				if row.kind == "choice" then
					setSelected(b, current == item.value)
					b.onClick = function()
						act("settings.choice", row.apply, item.value)
					end
				elseif row.kind == "actions" then
					setSelected(b, item.selected)
					b.onClick = function()
						act("settings.action", item.run)
					end
				elseif row.kind == "input" then
					b.onClick = item.commit
				else
					b.onClick = function()
						act("settings.drop", row.onDrop)
					end
					b.onDrop = b.onClick
				end
			end
			y = y - SW.ROW - SW.GAP
		end
	end
	child:SetHeight(-y)
end

-- A page may carry onLeave: what it forgets when the window closes or another page opens (an armed "sure?", a draft
-- name). The next click after coming back must ask again, never act on a question from before.
local function leave(page)
	if page and page.onLeave then
		page.onLeave()
	end
end

-- Show the window at a page (default: the last one shown, else the first).
function SW.Show(pageId)
	local before = SW.current
	SW.current = (pageId and SW.byId[pageId] and pageId) or SW.current or (SW.pages[1] and SW.pages[1].id)
	if before and SW.current ~= before then
		leave(SW.byId[before]) -- a page left behind forgets its "sure?" questions
	end
	if not (frame:IsShown() and SW.current == before) then -- re-showing the open page keeps its scroll
		scroll:SetVerticalScroll(0)
	end
	frame:Show()
	SW.Render()
	return true
end

frame:HookScript("OnHide", Guard("settings.pagesLeave", function()
	for _, page in ipairs(SW.pages) do
		leave(page)
	end
end, "none"))

frame:HookScript("OnHide", Guard("settings.inputsHide", function()
	for i = 1, SW.used.inputs do
		SW.inputs[i]:ClearFocus()
	end
end, "none"))

function SW.Hide()
	frame:Hide()
end

function SW.IsOpen()
	return frame:IsShown()
end

-- Something changed outside the window (a typed command, the bags window's own buttons, a pause,
-- a focus mode): redraw so the selected buttons are never stale. Only while the window is open.
local function refresh()
	if frame:IsShown() then
		SW.Render()
	end
end
SB.On("SB_CONFIG_CHANGED", refresh, "none")
SB.On("SB_FOCUS_CHANGED", refresh, "none")

-- /swagbag and /swagbag settings [page] (spec 10.5).
local function open(arg)
	arg = (arg or ""):lower()
	if arg ~= "" and not SW.byId[arg] then
		local ids = {}
		for i, p in ipairs(SW.pages) do
			ids[i] = p.id
		end
		return L.SET_USAGE:format(table.concat(ids, ", "))
	end
	SW.Show(arg ~= "" and arg or nil)
	return L.SET_OPENED
end

SB.Slash.Register("settings", L.HELP_SETTINGS, open)
SB.Slash.onEmpty = function()
	return open("")
end
