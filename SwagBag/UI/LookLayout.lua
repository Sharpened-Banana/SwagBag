-- SwagBag look layout (0.18, user request: "I want the swagbag to look like EllesmereUI's bags ... and do all the
-- layout ones too"). The "Like EllesmereUI" look (UI/Themes.lua) also changes the bags window's layout, through
-- Theme.Layout; every other look keeps the window exactly as it was. Applied at once on SB_THEME_CHANGED, in or
-- out of combat (only SwagBag's own frames and textures; no item button is touched), and taken back the same way:
--   "portrait"      a round bag icon in a bronze ring over the window's top-left corner
--   "centredTitle"  the title centred (BagsWindow.BoundTitle), "used / total Slots" at the top right; a search
--                   error or warning takes the title row while it says something (SearchBox onMessage)
--   "iconButtons"   Sort, Pause, Reflow, View and Lock become round icon buttons at the right end of the search
--                   row (their tooltips name them), and the search box stretches to them; the bank's "Bank still
--                   open" button moves to the title row's left
--   "padSlots"      (BagsWindow: Layout.Position pads each section's last row, the first square a "+" drop tile)
--   "insideSidebar" (BagsWindow and UI/CategorySidebar.lua: the category list inside the window's left edge)
-- The last two need a layout: an open window lays out again (BagsWindow.RequestLayout, held while the mouse is
-- over the items). Nothing of EllesmereUI's is read or copied: the look is matched by eye from a screenshot.
--   LookLayout.Apply()        apply or take back, for the current look
--   LookLayout.SlotText() -> "72 / 86 Slots"   pure over the bags as laid out
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local LL = { applied = false, BUTTON = 24, GAP = 4, PORTRAIT = 44, ICON = 38,
	MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask", BAG_ICON = "Interface\\Icons\\INV_Misc_Bag_08",
	BRONZE = { 0.55, 0.44, 0.24, 1 } }
SB.LookLayout = LL

local W = SB.BagsWindow
if not (W and W.frame) then
	return
end
local frame = W.frame

local function on(key)
	return SB.Theme ~= nil and SB.Theme.Layout(key)
end

-- A round texture: the circle mask where the client has masks (every current client), else square.
local function round(tex)
	if tex.SetMask then
		tex:SetMask(LL.MASK)
	end
end

---------------------------------------------------------------------------
-- Portrait
---------------------------------------------------------------------------
local portrait
local function showPortrait(shown)
	if not portrait and shown then
		portrait = CreateFrame("Frame", nil, frame)
		portrait:SetSize(LL.PORTRAIT, LL.PORTRAIT)
		portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", -12, 12)
		portrait:SetFrameLevel(frame:GetFrameLevel() + 5)
		portrait.ring = portrait:CreateTexture(nil, "BACKGROUND")
		portrait.ring:SetAllPoints(portrait)
		portrait.ring:SetColorTexture(LL.BRONZE[1], LL.BRONZE[2], LL.BRONZE[3], LL.BRONZE[4])
		round(portrait.ring)
		portrait.icon = portrait:CreateTexture(nil, "ARTWORK")
		portrait.icon:SetSize(LL.ICON, LL.ICON)
		portrait.icon:SetPoint("CENTER", portrait, "CENTER", 0, 0)
		portrait.icon:SetTexture(LL.BAG_ICON)
		round(portrait.icon)
		LL.portrait = portrait
	end
	if portrait then
		portrait:SetShown(shown)
	end
end

---------------------------------------------------------------------------
-- Slot count and the title row
---------------------------------------------------------------------------
local slots = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
slots:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -9)
slots:SetJustifyH("RIGHT")
slots:Hide()
LL.slots = slots

-- "used / total Slots" over the bags as laid out (W.sizes) and the live model.
function LL.SlotText()
	local total, used = 0, 0
	for _, size in pairs(W.sizes or {}) do
		total = total + size
	end
	for _, _, snap in SB.Inventory.Iterate("bags") do
		if snap then
			used = used + 1
		end
	end
	return L.LOOK_SLOTS:format(math.min(used, total), total)
end

local message = "" -- the search box's error or warning, while it says something

local function refreshTitleRow()
	local centred = on("centredTitle")
	local busy = centred and message ~= ""
	frame.title:SetShown(not busy)
	slots:SetShown(centred and not busy)
	if centred and not busy then
		slots:SetText(LL.SlotText())
	end
end

local function refreshSlots()
	if LL.applied and frame:IsShown() then
		refreshTitleRow()
	end
end
SB.On("SB_BAGS_LAYOUT", refreshSlots, "bags")
SB.On("SB_BAGS_UPDATED", refreshSlots, "bags")

---------------------------------------------------------------------------
-- Icon buttons on the search row
---------------------------------------------------------------------------
-- Right to left, as they sit at the search row's right end; each with its icon and the anchors it has otherwise.
local function buttonList()
	local LB = SB.LockButton
	return {
		{ b = LB and LB.button, icon = "Interface\\Icons\\INV_Misc_Key_03", w = LB and LB.WIDTH or 50,
			home = { "TOPRIGHT", frame, "TOPRIGHT", -8, -31 } },
		{ b = W.viewButton, icon = "Interface\\Icons\\INV_Misc_Book_09", w = 72,
			home = { "TOPRIGHT", frame, "TOPRIGHT", -26, -5 } },
		{ b = W.reflowButton, icon = "Interface\\Icons\\Spell_Holy_BorrowedTime", w = 60,
			home = { "RIGHT", W.viewButton, "LEFT", -4, 0 } },
		{ b = W.modeButton, icon = "Interface\\Icons\\Spell_Nature_TimeStop", w = 64,
			home = { "RIGHT", W.reflowButton, "LEFT", -4, 0 } },
		{ b = W.sortButton, icon = "Interface\\Icons\\INV_Pet_Broom", w = 52,
			home = { "RIGHT", W.modeButton, "LEFT", -4, 0 } },
	}
end

local TEMPLATE_PARTS = { "Left", "Middle", "Right" }
local icons = setmetatable({}, { __mode = "k" }) -- [button] = { ring, icon }, made the first time it is an icon
LL.icons = icons

local function iconButton(e, shown)
	local b = e.b
	if not b then
		return
	end
	local made = icons[b]
	if shown and not made then
		made = { ring = b:CreateTexture(nil, "BACKGROUND"), icon = b:CreateTexture(nil, "ARTWORK") }
		icons[b] = made
		made.ring:SetAllPoints(b)
		made.ring:SetColorTexture(LL.BRONZE[1], LL.BRONZE[2], LL.BRONZE[3], LL.BRONZE[4])
		round(made.ring)
		made.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
		made.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
		made.icon:SetTexture(e.icon)
		round(made.icon)
		-- the buttons with no tooltip of their own say what they are while they are icons
		if not b:GetScript("OnEnter") then
			b:HookScript("OnEnter", Guard("bags.iconTip", function(self)
				if LL.applied and on("iconButtons") then
					GameTooltip:SetOwner(self, "ANCHOR_TOP")
					GameTooltip:SetText(self:GetText() or "")
					GameTooltip:Show()
				end
			end, "bags"))
			b:HookScript("OnLeave", Guard("bags.iconTipHide", function()
				GameTooltip:Hide()
			end, "bags"))
		end
	end
	if made then
		made.icon:SetShown(shown)
		made.ring:SetShown(shown)
	end
	for _, key in ipairs(TEMPLATE_PARTS) do
		local part = b[key]
		if type(part) == "table" and part.SetShown then
			part:SetShown(not shown)
		end
	end
	local text = b.GetFontString and b:GetFontString()
	if text then
		text:SetAlpha(shown and 0 or 1)
	end
	if shown then
		b:SetSize(LL.BUTTON, LL.BUTTON)
	else
		b:SetSize(e.w, 18)
		if SB.Theme then
			SB.Theme.Button(b) -- the look's own button style again
		end
	end
end

local function placeButtons(shown)
	local list = buttonList()
	local prev
	for _, e in ipairs(list) do
		iconButton(e, shown)
		if e.b then
			e.b:ClearAllPoints()
			if shown then
				if prev then
					e.b:SetPoint("RIGHT", prev, "LEFT", -LL.GAP, 0)
				else
					e.b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -28)
				end
				prev = e.b
			else
				e.b:SetPoint(e.home[1], e.home[2], e.home[3], e.home[4], e.home[5])
			end
		end
	end
	local box = SB.SearchBox and SB.SearchBox.editBox
	if box then
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -30)
		if shown and prev then
			box:SetPoint("RIGHT", prev, "LEFT", -8, 0)
		else
			box:SetSize(200, 20)
		end
	end
	local BW = SB.BankWindow
	local still = BW and BW.stillOpenButton
	if still then
		still:ClearAllPoints()
		if shown then
			still:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -5)
		else
			still:SetPoint("RIGHT", W.sortButton, "LEFT", -4, 0)
		end
	end
end

-- The search box's message line: in the title row while the title is centred, else beside the box as always.
local function placeMessage(centred)
	local Box = SB.SearchBox
	local line = Box and Box.errorLine
	if not line then
		return
	end
	line:ClearAllPoints()
	if centred then
		line:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -4)
		line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -4)
		line:SetJustifyH("CENTER")
	else
		line:SetPoint("TOPLEFT", Box.editBox, "TOPRIGHT", 8, 4)
		line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -62, -26)
		line:SetJustifyH("LEFT")
	end
end

if SB.SearchBox then
	SB.SearchBox.onMessage = function(text)
		message = text or ""
		if LL.applied then
			refreshTitleRow()
		end
	end
end

---------------------------------------------------------------------------
-- Apply / take back
---------------------------------------------------------------------------
function LL.Apply()
	local want = on("portrait") or on("centredTitle") or on("iconButtons") or on("padSlots") or on("insideSidebar")
	if not want and not LL.applied then
		return -- never applied: every frame is as it was made
	end
	LL.applied = want
	showPortrait(on("portrait"))
	W.BoundTitle(W.titleLeftmost)
	placeMessage(on("centredTitle"))
	refreshTitleRow()
	placeButtons(on("iconButtons"))
	if W.sidebar and not on("insideSidebar") then
		W.sidebar.Place() -- back beside the window, with its own panel
	end
	W.RequestLayout("look") -- the pads and the inside sidebar come with a layout (held under the mouse)
end

SB.On("SB_THEME_CHANGED", Guard("bags.look", LL.Apply, "bags"), "bags")
