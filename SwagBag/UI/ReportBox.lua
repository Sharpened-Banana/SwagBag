-- SwagBag report box: one read-only, copyable, multi-line EditBox (spec 10.4).
-- Text is selected on show and on focus; typing restores it; Esc closes.
local _, SB = ...

local Box = {}
SB.ReportBox = Box

local function build()
	local Guard = SB.ErrorTrap.Guard
	local f = CreateFrame("Frame", "SwagBagReportFrame", UIParent, "BackdropTemplate")
	f:SetSize(640, 420)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	f:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
	f:SetBackdropBorderColor(0.3, 0.8, 0.6, 1)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", Guard("report.dragStart", function(self)
		self:StartMoving()
	end, "none"))
	f:SetScript("OnDragStop", Guard("report.dragStop", function(self)
		self:StopMovingOrSizing()
	end, "none"))

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 10, -8)
	title:SetText(SB.L.REPORT_TITLE)

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -30)
	scroll:SetPoint("BOTTOMRIGHT", -30, 10)

	local edit = SB.TextBox(CreateFrame("EditBox", nil, scroll)) -- lets the keyboard go in combat (week 11)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(590)
	edit:SetScript("OnEscapePressed", Guard("report.escape", function()
		f:Hide()
	end, "none"))
	edit:SetScript("OnTextChanged", Guard("report.textChanged", function(self, userInput)
		if userInput then
			self:SetText(Box.text or "")
			self:HighlightText()
		end
	end, "none"))
	edit:SetScript("OnEditFocusGained", Guard("report.focus", function(self)
		self:HighlightText()
	end, "none"))
	scroll:SetScrollChild(edit)
	f.edit = edit

	table.insert(UISpecialFrames, "SwagBagReportFrame")
	f:Hide()
	return f
end

function Box.Show(text)
	Box.frame = Box.frame or build()
	Box.text = text
	Box.frame.edit:SetText(text)
	Box.frame:Show()
	Box.frame.edit:SetFocus()
	Box.frame.edit:HighlightText()
end
