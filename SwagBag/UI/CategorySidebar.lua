-- SwagBag category sidebar (0.17, user request: "a sidebar that goes over all of the categories (and amount in
-- each). Once clicked it brings up that category and that's it"). A slim column beside the bags window and the
-- bank window, as tall as the window: one line per section as drawn, "Consumables (12)" (the header's count),
-- "+ Consumables (12)" while folded; the bank adds a heading per bank. The window decides what a click does
-- (unfold the section if folded, then scroll its header to the top); the sidebar only lists and reports clicks.
-- Left of the window, or right when the left has no room or something of Blizzard's is there; the side is chosen
-- only when the window opens (sb.Place). A handle at the window side of its top edge shrinks it to a thin strip
-- (saved per character and window: ui.sidebarShrunk[key]); a click on the strip brings it back. P5: counts and
-- "+" change in place on the same lines; a change to the list itself waits while the mouse is over the sidebar
-- and retries every 300 ms. Plain frames and buttons only, so it works in combat. One setting for both windows:
-- bags.sidebar (on by default), /swagbag sidebar on|off.
--   S.Label(name, count, folded) -> text           pure
--   S.Side(left, width, blocked) -> "LEFT" | "RIGHT"  pure: left = the window's left edge (nil: not known yet)
--   S.On() -> bool                                  the setting
--   S.New(cfg) -> sb   cfg = { key = "bags" | "bank", parent = the window frame, window = ErrorTrap window,
--                      onClick(entry) (trapped as cfg.window), blocked() optional -> true while the window's
--                      left side is taken (the bank's "shown" mode) }
--   sb.Update(entries)  entries = { { text, id, group, heading, indent } } top to bottom (the window's own
--                       fields ride along to onClick); {} (another view) hides the sidebar
--   sb.Place()          at open: pick the side and anchor to the window
--   sb.IsMouseOver()    the window's own "under the pointer" tests count the sidebar
--   sb.frame, sb.rows, sb.handle
local _, SB = ...

local L = SB.L
local S = { WIDTH = 150, SHRUNK = 14, ROW = 16, HANDLE = 14, PAD = 4, INDENT = 10, RETRY = 0.3, instances = {} }
SB.CategorySidebar = S

function S.Label(name, count, folded)
	return L.SIDEBAR_LINE:format(folded and "+ " or "", name, count)
end

function S.Side(left, width, blocked)
	if blocked or (type(left) == "number" and left < width) then
		return "RIGHT"
	end
	return "LEFT"
end

function S.On()
	return SB.Config.Get("bags.sidebar") ~= false
end

local function shrunkSet()
	local ui = SB.Config.UI()
	ui.sidebarShrunk = type(ui.sidebarShrunk) == "table" and ui.sidebarShrunk or {}
	return ui.sidebarShrunk
end

local function keyOf(e)
	return tostring(e.group or "") .. ":" .. tostring(e.id or "")
end

local function sameKeys(drawn, entries)
	if #drawn ~= #entries then
		return false
	end
	for i, e in ipairs(entries) do
		if drawn[i] ~= keyOf(e) then
			return false
		end
	end
	return true
end

function S.New(cfg)
	local sb = { rows = {}, wanted = {}, side = "LEFT" }
	local parent = cfg.parent
	local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	frame:SetWidth(S.WIDTH)
	frame:EnableMouse(true) -- the strip under the lines is the sidebar's, never a click through to the world
	if SB.Theme then
		SB.Theme.Window(frame, "main")
	end
	frame:Hide()
	sb.frame = frame

	local scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", S.PAD, -(S.HANDLE + S.PAD))
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S.PAD, S.PAD)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(S.WIDTH - 2 * S.PAD, S.ROW)
	scroll:SetScrollChild(child)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", SB.ErrorTrap.Guard("sidebar.wheel", function(_, delta)
		scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll() - delta * S.ROW * 3,
			child:GetHeight(), scroll:GetHeight()))
	end, cfg.window))
	sb.scroll, sb.child = scroll, child

	local handle = CreateFrame("Button", nil, frame)
	handle.text = handle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	handle.text:SetPoint("CENTER", handle, "CENTER", 0, 0)
	handle:SetScript("OnClick", function()
		SB.ErrorTrap.Run("sidebar.handle", cfg.window, function()
			local set = shrunkSet()
			set[cfg.key] = (not set[cfg.key]) or nil
			sb.Place()
			sb.Draw()
		end)
	end)
	sb.handle = handle

	local function newRow(i)
		local row = CreateFrame("Button", nil, child)
		row:SetHeight(S.ROW)
		row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * S.ROW)
		row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -(i - 1) * S.ROW)
		row:RegisterForClicks("LeftButtonUp")
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(false)
		local hl = row:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints(row)
		hl:SetColorTexture(1, 1, 1, 0.1)
		row:SetScript("OnClick", function(self)
			if self.entry and cfg.onClick then
				SB.ErrorTrap.Run("sidebar.click", cfg.window, cfg.onClick, self.entry)
			end
		end)
		sb.rows[i] = row
		return row
	end

	local function shrunk()
		return shrunkSet()[cfg.key] == true
	end

	-- The handle sits at the top corner next to the window, so shrinking never moves it; shrunk, it is the
	-- whole strip.
	local function placeHandle()
		handle:ClearAllPoints()
		local left = sb.side == "LEFT"
		if shrunk() then
			handle:SetAllPoints(frame)
			handle.text:SetText(left and "<" or ">")
		else
			handle:SetSize(S.HANDLE, S.HANDLE)
			handle:SetPoint(left and "TOPRIGHT" or "TOPLEFT", frame, left and "TOPRIGHT" or "TOPLEFT", 0, 0)
			handle.text:SetText(left and ">" or "<")
		end
	end

	-- Draw sb.wanted: the same line objects at the same places, only their texts change.
	function sb.Draw()
		local entries = sb.wanted
		if not (S.On() and #entries > 0) then
			sb.drawn = nil
			frame:Hide()
			return
		end
		local small = shrunk()
		frame:SetWidth(small and S.SHRUNK or S.WIDTH)
		for i, e in ipairs(entries) do
			local row = sb.rows[i] or newRow(i)
			row.entry = e
			row.text:SetFontObject(e.heading and "GameFontNormalSmall" or "GameFontHighlightSmall")
			row.text:ClearAllPoints()
			row.text:SetPoint("LEFT", row, "LEFT", e.indent and S.INDENT or 0, 0)
			row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
			row.text:SetText(e.text)
			row:SetShown(not small)
		end
		for i = #entries + 1, #sb.rows do
			sb.rows[i].entry = nil
			sb.rows[i]:Hide()
		end
		scroll:SetShown(not small)
		child:SetHeight(#entries * S.ROW)
		scroll:SetVerticalScroll(SB.GridLayout.ClampOffset(scroll:GetVerticalScroll(), child:GetHeight(),
			scroll:GetHeight()))
		sb.drawn = {}
		for i, e in ipairs(entries) do
			sb.drawn[i] = keyOf(e)
		end
		placeHandle()
		frame:Show()
	end

	function sb.Update(entries)
		sb.wanted = entries or {}
		if frame:IsShown() and sb.drawn and #sb.wanted > 0 and S.On() and not sameKeys(sb.drawn, sb.wanted)
			and frame:IsMouseOver() then
			SB.Debounce("sidebar." .. cfg.key, S.RETRY, function()
				sb.Update(sb.wanted)
			end, cfg.window)
			return
		end
		sb.Draw()
	end

	function sb.Place()
		sb.side = S.Side(parent:GetLeft(), S.WIDTH, cfg.blocked and cfg.blocked() or false)
		frame:ClearAllPoints()
		if sb.side == "LEFT" then
			frame:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, 0)
			frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", 0, 0)
		else
			frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
			frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 0, 0)
		end
		placeHandle()
	end

	function sb.IsMouseOver()
		return frame:IsShown() and frame:IsMouseOver()
	end

	S.instances[#S.instances + 1] = sb
	return sb
end

-- /swagbag sidebar [on|off]: the one setting for the bags and bank windows; an open window shows or hides its
-- sidebar at once (adding or removing a column beside the window moves nothing inside it).
SB.Slash.Register("sidebar", L.HELP_SIDEBAR, function(arg)
	arg = (arg or ""):lower()
	if arg ~= "on" and arg ~= "off" then
		return L.SIDEBAR_STATE:format(S.On() and L.OVERLAY_ON or L.OVERLAY_OFF)
	end
	if not SB.Config.Set("bags.sidebar", arg == "on") then
		return L.SETTINGS_READONLY
	end
	for _, sb in ipairs(S.instances) do
		sb.Draw()
	end
	return arg == "on" and L.SIDEBAR_ON or L.SIDEBAR_OFF
end)
