-- SwagBag share box (week 7, user pick 12): one window for a profile's share string. Export: the string,
-- selected, ready for Ctrl+C. Import: paste a string, Preview says what would change (nothing changes
-- yet), Import applies it and keeps the old settings for /swagbag profile undo. A string is read with
-- patterns only (Engine/Profiles.lua): nothing in it ever runs. Plain frames only (opens in combat).
--   ShareBox.ShowExport(text)   ShareBox.ShowImport()   ShareBox.Preview() -> ok   ShareBox.Import() -> ok
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local SX = { MAX_LINES = 8 }
SB.ShareBox = SX

local ERRORS = { empty = "SHARE_ERR_EMPTY", notours = "SHARE_ERR_NOTOURS", newer = "SHARE_ERR_NEWER",
	toolong = "SHARE_ERR_TOOLONG", damaged = "SHARE_ERR_DAMAGED", type = "SHARE_ERR_TYPE" }

local function button(f, text, onClick)
	local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	b:SetSize(110, 22)
	b:SetText(text)
	b:SetScript("OnClick", Guard("share.click", onClick, "none"))
	if SB.Theme then
		SB.Theme.Button(b)
	end
	return b
end

local function build()
	local f = CreateFrame("Frame", "SwagBagShareBox", UIParent, "BackdropTemplate")
	f:SetSize(560, 380)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	f:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
	f:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
	f:EnableMouse(true)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetPoint("TOPLEFT", 10, -8)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -30)
	scroll:SetPoint("BOTTOMRIGHT", -30, 120)
	local edit = SB.TextBox(CreateFrame("EditBox", nil, scroll)) -- lets the keyboard go in combat (week 11)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(510)
	edit:SetScript("OnEscapePressed", Guard("share.escape", function()
		f:Hide()
	end, "none"))
	edit:SetScript("OnTextChanged", Guard("share.textChanged", function(self, userInput)
		if not userInput then
			return
		end
		if SX.mode == "export" then -- read-only: typing puts the string back
			self:SetText(SX.text or "")
			self:HighlightText()
		else
			SX.data = nil -- a changed string must be previewed again
		end
	end, "none"))
	scroll:SetScrollChild(edit)
	f.edit = edit
	f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.status:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 10, 112)
	f.status:SetPoint("RIGHT", f, "RIGHT", -10, 0)
	f.status:SetJustifyH("LEFT")
	f.status:SetJustifyV("TOP")
	f.status:SetWordWrap(true)
	f.preview = button(f, L.SHARE_PREVIEW, function()
		SX.Preview()
	end)
	f.preview:SetPoint("BOTTOMLEFT", 10, 10)
	f.import = button(f, L.SHARE_IMPORT, function()
		SX.Import()
	end)
	f.import:SetPoint("LEFT", f.preview, "RIGHT", 8, 0)
	if SB.Theme then
		SB.Theme.Window(f, "dialog")
		SB.Theme.Text(f.title, "title")
		SB.Theme.Text(f.status, "small")
	end
	table.insert(UISpecialFrames, "SwagBagShareBox")
	f:Hide()
	return f
end

local function frame()
	SX.frame = SX.frame or build()
	return SX.frame
end

function SX.ShowExport(text)
	local f = frame()
	SX.mode, SX.text, SX.data = "export", text, nil
	f.title:SetText(L.SHARE_EXPORT_TITLE)
	f.status:SetText(L.SHARE_EXPORT_HINT)
	f.preview:Hide()
	f.import:Hide()
	f.edit:SetText(text)
	f:Show()
	f.edit:SetFocus()
	f.edit:HighlightText()
end

function SX.ShowImport()
	local f = frame()
	SX.mode, SX.text, SX.data = "import", nil, nil
	f.title:SetText(L.SHARE_IMPORT_TITLE)
	f.status:SetText(L.SHARE_IMPORT_HINT)
	f.preview:Show()
	f.import:Show()
	f.edit:SetText("")
	f:Show()
	f.edit:SetFocus()
end

-- What the pasted string would change, in the status area; nothing changes yet.
function SX.Preview()
	local f = frame()
	local data, err, detail = SB.Profiles.Parse(f.edit:GetText())
	if not data then
		if err == "type" and detail then
			detail = SB.Profiles.Label(detail) -- a setting by its name in the settings window (ruling R18)
		end
		SX.data = nil
		f.status:SetText(L[ERRORS[err] or "SHARE_ERR_DAMAGED"]:format(tostring(detail or "")))
		return false
	end
	SX.data = data
	local lines, shown = SB.Profiles.Preview(data), {}
	for i = 1, math.min(#lines, SX.MAX_LINES) do
		shown[i] = lines[i]
	end
	if #lines > SX.MAX_LINES then
		shown[#shown + 1] = L.SHARE_MORE:format(#lines - SX.MAX_LINES)
	end
	f.status:SetText(L.SHARE_PREVIEW_HEAD .. "\n" .. table.concat(shown, "\n"))
	return true
end

-- Import only what was previewed; the chat line is the answer (P2).
function SX.Import()
	local f = frame()
	if not SX.data then
		f.status:SetText(L.SHARE_PREVIEW_FIRST)
		return false
	end
	local ok, n = SB.Profiles.Import(SX.data)
	if not ok then
		f.status:SetText(L.SETTINGS_READONLY)
		return false
	end
	SX.data = nil
	f:Hide()
	SB.Print(L.PROFILE_IMPORTED:format(n))
	return true
end
