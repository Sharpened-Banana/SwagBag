-- SwagBag guided tour (spec F7, AC7.3; week 12). /swagbag tour, any time, shows the bag window's parts one at a time,
-- each with a small note next to it and a thin gold frame around it: the section headers, collapsing a section, focus
-- modes and peeking, the search box, the mode title and Pause, Sort, and Safe Mode. Back, Next and End on the note.
-- It only points: it never clicks, moves, sorts or lays out anything (P5). It never covers a fight: it ends when
-- combat starts, and when the bags close, with one chat line either way. A part that is not drawn (the grid view has
-- no section headers) gets its note beside the bag window, with the same words. Plain frames only.
--   Tour.Start() -> feedback        opens the bags if they are closed; refuses in combat, while the bags are
--                                   Blizzard's (Safe Mode), or when they can't open
--   Tour.Next() / Tour.Back()       the next or previous note; Next on the last one ends the tour (said once)
--   Tour.End(reason) -> bool        "done" | "ended" | "closed" | "combat": the note goes and one line says so;
--                                   false when no tour runs
--   Tour.step, Tour.target          the note shown (nil: no tour) and what it points at
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local Tour = { step = nil, target = nil }
SB.Tour = Tour

-- The bags window's first section header (the bank's and the guild bank's headers have other parents); show() checks
-- that it is drawn.
local function firstHeader()
	local W, H = SB.BagsWindow, SB.SectionHeaders
	if not (W and W.child and H and H.inUse) then
		return nil
	end
	for _, h in ipairs(H.inUse) do
		if h:GetParent() == W.child then
			return h
		end
	end
	return nil
end

local function bagsPart(name)
	return function()
		return SB.BagsWindow and SB.BagsWindow[name]
	end
end

-- The notes, in order. target() -> the frame the note points at, or nil (the note sits beside the window).
Tour.STEPS = {
	{ id = "headers", text = "TOUR_HEADERS", target = firstHeader },
	{ id = "collapse", text = "TOUR_COLLAPSE", target = firstHeader },
	{ id = "peek", text = "TOUR_PEEK", target = firstHeader },
	{ id = "search", text = "TOUR_SEARCH", target = function()
		return SB.SearchBox and SB.SearchBox.editBox
	end },
	{ id = "modes", text = "TOUR_MODES", target = bagsPart("modeButton") },
	{ id = "sort", text = "TOUR_SORT", target = bagsPart("sortButton") },
	{ id = "safe", text = "TOUR_SAFE" },
}

local frame = CreateFrame("Frame", "SwagBagTour", UIParent, "BackdropTemplate")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
frame:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
frame:SetBackdropBorderColor(1, 0.82, 0, 1)
frame:SetSize(300, 150)
frame:Hide()
Tour.frame = frame
table.insert(UISpecialFrames, "SwagBagTour") -- Esc ends the tour

frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.count:SetPoint("TOPLEFT", 10, -8)
frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.text:SetPoint("TOPLEFT", 10, -26)
frame.text:SetWidth(280)
frame.text:SetJustifyH("LEFT")
frame.text:SetWordWrap(true)

-- The thin gold frame around what the note points at. It takes no mouse: everything under it works as usual.
local ring = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
ring:SetFrameStrata("DIALOG")
ring:EnableMouse(false)
ring:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
ring:SetBackdropBorderColor(1, 0.82, 0, 1)
ring:Hide()
Tour.ring = ring

local function button(label, x, fn, name)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(80, 22)
	b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 10)
	b:SetText(label)
	b:SetScript("OnClick", Guard(name, fn, "none"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
	return b
end
Tour.backButton = button(L.TOUR_BACK, 10, function()
	Tour.Back()
end, "tour.back")
Tour.nextButton = button(L.TOUR_NEXT, 110, function()
	Tour.Next()
end, "tour.next")
Tour.endButton = button(L.TOUR_END, 210, function()
	Tour.End("ended")
end, "tour.end")
if SB.Theme then
	SB.Theme.Window(frame, "dialog")
	SB.Theme.Text(frame.count, "small")
	SB.Theme.Text(frame.text, "body")
end

-- Draw the note of the current step, next to its part (or beside the window when the part is not drawn).
local function show()
	local s = Tour.STEPS[Tour.step]
	local target = s.target and s.target() or nil
	if not (target and target:IsShown()) then
		target = nil
	end
	frame.count:SetText(L.TOUR_COUNT:format(Tour.step, #Tour.STEPS))
	frame.text:SetText(L[s.text])
	frame:ClearAllPoints()
	ring:ClearAllPoints()
	if target then
		frame:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, 10)
		ring:SetPoint("TOPLEFT", target, "TOPLEFT", -3, 3)
		ring:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 3, -3)
		ring:Show()
	else
		frame:SetPoint("TOPRIGHT", SB.BagsWindow.frame, "TOPLEFT", -10, 0)
		ring:Hide()
	end
	Tour.target = target or SB.BagsWindow.frame
	Tour.backButton:SetShown(Tour.step > 1)
	Tour.nextButton:SetText(Tour.step == #Tour.STEPS and L.TOUR_DONE or L.TOUR_NEXT)
	frame:Show()
end

function Tour.Start()
	local W = SB.BagsWindow
	if SB.Adapter.InCombat() then
		return L.TOUR_COMBAT
	elseif not W or SB.SafeMode.IsOn("bags") then
		return L.TOUR_SAFE_MODE
	elseif not W.IsOpen() and not W.Open() then
		return L.TOUR_NO_BAGS
	end
	if SB.QuickSetup and SB.QuickSetup.AnswerOffer then
		SB.QuickSetup.AnswerOffer() -- started by the command while the offer shows: the offer is answered
	end
	Tour.step = 1
	show()
	return L.TOUR_STARTED
end

function Tour.Next()
	if not Tour.step then
		return
	end
	if Tour.step >= #Tour.STEPS then
		Tour.End("done")
		return
	end
	Tour.step = Tour.step + 1
	show()
end

function Tour.Back()
	if Tour.step and Tour.step > 1 then
		Tour.step = Tour.step - 1
		show()
	end
end

local ENDS = { done = "TOUR_FINISHED", ended = "TOUR_ENDED", closed = "TOUR_ENDED_CLOSED", combat = "TOUR_ENDED_COMBAT" }

function Tour.End(reason)
	if not Tour.step then
		return false
	end
	Tour.step, Tour.target = nil, nil
	ring:Hide()
	frame:Hide()
	SB.Print(L[ENDS[reason] or ENDS.ended])
	return true
end

-- Esc (or anything else hiding the note) ends the tour, once. The guard first: Alt+Z hides UIParent, not the note.
frame:SetScript("OnHide", Guard("tour.hide", function(self)
	if not self:IsShown() and Tour.step then
		Tour.End("ended")
	end
end, "none"))

SB.On("SB_BAGS_CLOSED", function()
	Tour.End("closed")
end, "none")

-- Combat starts: the note goes at once (it never covers a fight). Hiding a plain frame is allowed in combat.
SB.On("PLAYER_REGEN_DISABLED", function()
	Tour.End("combat")
end, "none")

-- The bags were laid out again (a view change, Reflow): the parts may be other frames now, so point again.
SB.On("SB_BAGS_LAYOUT", function()
	if Tour.step then
		show()
	end
end, "none")

SB.Slash.Register("tour", L.HELP_TOUR, function()
	return Tour.Start()
end)
