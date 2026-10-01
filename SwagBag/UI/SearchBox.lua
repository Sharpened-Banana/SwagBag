-- SwagBag search box on the bags window (spec F5). Typing re-applies the search
-- 150 ms after the last keystroke. A parse error shows a red message and a red
-- underline under the offending characters; the previous valid search stays.
-- The dimming is re-applied whenever the window lays out (including reopen) and
-- whenever slot data changes (including LOADED for a pending item).
local _, SB = ...

local L = SB.L
local Box = {}
SB.SearchBox = Box

local W = SB.BagsWindow
local Guard = SB.ErrorTrap.Guard

local box = CreateFrame("EditBox", "SwagBagBagsSearchBox", W.frame, "SearchBoxTemplate")
box:SetSize(200, 20)
box:SetPoint("TOPLEFT", 14, -30)
box:SetAutoFocus(false)
Box.editBox = box

local errorLine = W.frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
-- Two lines at most, between the box and the window's right edge, top-aligned with
-- the box. Anchored TOPRIGHT (not RIGHT) so it never stretches down over the items.
errorLine:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 4)
errorLine:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", -8, -26)
errorLine:SetJustifyH("LEFT")
errorLine:SetJustifyV("TOP")
errorLine:SetWordWrap(true)
if errorLine.SetMaxLines then
	errorLine:SetMaxLines(2)
end

local underline = box:CreateTexture(nil, "OVERLAY")
underline:SetColorTexture(1, 0.25, 0.25, 1)
underline:SetHeight(2)
underline:Hide()

local measure = box:CreateFontString(nil, "OVERLAY")
measure:SetFontObject(box:GetFontObject())
measure:Hide()

local function textWidth(text)
	measure:SetText(text)
	return measure:GetStringWidth()
end

-- No error: show the applied search's soft warning (unknown #keyword), if any.
function Box.ClearError()
	errorLine:SetTextColor(1, 0.82, 0) -- soft yellow: a warning is not an error
	errorLine:SetText(SB.Search.lastWarning or "")
	underline:Hide()
end

-- Underline the offending characters (byte range from Search.ErrorSpan; for a
-- trailing operator that is the token before the end of the text).
function Box.ShowError(text, err)
	errorLine:SetTextColor(1, 0.1, 0.1) -- red, as GameFontRedSmall
	errorLine:SetText(SB.Query.FormatError(err))
	local first, last = SB.Search.ErrorSpan(text, err)
	if last < first then
		underline:Hide()
		return
	end
	local left = box:GetTextInsets()
	underline:ClearAllPoints()
	underline:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", (left or 0) + textWidth(text:sub(1, first - 1)), 1)
	underline:SetWidth(math.max(6, textWidth(text:sub(first, last))))
	underline:Show()
end

-- Re-applies the current search to every slot. Does nothing while the window is closed.
function Box.Apply()
	if not W.IsOpen() then
		return 0, 0, 0
	end
	local matches, total, ms = SB.Search.Apply(W.ForEachSlot, SB.Buttons.SetDimmed)
	if matches == nil then
		errorLine:SetTextColor(1, 0.1, 0.1)
		errorLine:SetText(L.SEARCH_EVAL_FAILED)
		underline:Hide()
	elseif SB.Search.lastError == nil then
		Box.ClearError()
	end
	return matches, total, ms
end

function Box.Run()
	local text = box:GetText()
	if SB.Search.SetText(text) then
		Box.ClearError()
	else
		Box.ShowError(text, SB.Search.lastError)
	end
	return Box.Apply()
end

-- Any text change (typing, or the box's own clear button) schedules one debounced run.
box:HookScript("OnTextChanged", Guard("search.textChanged", function()
	SB.Debounce("search.bags", 0.15, Box.Run, "bags")
end, "bags"))

SB.On("SB_BAGS_LAYOUT", function()
	Box.Apply()
end, "bags")

SB.On("SB_BAGS_UPDATED", function()
	Box.Apply()
end, "bags")

SB.Slash.Register("search", L.HELP_SEARCH, function(arg)
	if not W.IsOpen() then
		return L.SEARCH_OPEN_FIRST
	end
	box:SetText(arg)
	if not SB.Search.SetText(arg) then
		Box.ShowError(arg, SB.Search.lastError)
		return L.SEARCH_ERROR:format(SB.Query.FormatError(SB.Search.lastError))
	end
	Box.ClearError()
	local matches, total, ms = Box.Apply()
	if matches == nil then
		return L.SEARCH_EVAL_FAILED
	end
	if not SB.Search.IsActive() then
		return L.SEARCH_CLEARED
	end
	local result = L.SEARCH_RESULT:format(arg, matches, total, ms)
	if SB.Search.lastWarning then
		return { result, SB.Search.lastWarning }
	end
	return result
end, "bags")
