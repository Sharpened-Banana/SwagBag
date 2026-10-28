-- The bank window's "..." menu (week 13). The title row keeps Sort, "..." and close; every other
-- bank action is one row here, in this order: the four views (the current one marked; 0.17: Bags, one
-- section per bank tab), Sort either bank, Regroup now, Show/Hide Blizzard's bank, Deposit all warbound
-- items, Deposit gold and Withdraw gold (0.14.2, while the Warband bank moves gold), Bank settings.
-- Plain frames only (a menu may open in combat); every row calls the same BankWindow function its old
-- title button called, so each click is answered once, by that function (P2). The rows are rebuilt at
-- every open, so the view mark and the Blizzard words are current. It closes with the bank window.
--   BankMenu.Entries() -> { { text, tip, run } }   BankMenu.Toggle(anchor) -> shown   BankMenu.Hide()
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local BW = SB.BankWindow
local BM = {
	ROW = 22,
	WIDTH = 260,
}
SB.BankMenu = BM

local VIEWS = {
	{ id = "sections", name = L.BANK_MENU_VIEW_SECTIONS },
	{ id = "list", name = L.BANK_MENU_VIEW_LIST },
	{ id = "grid", name = L.BANK_MENU_VIEW_GRID },
	{ id = "bags", name = L.BANK_MENU_VIEW_BAGS },
}

function BM.Entries()
	local list, now = {}, BW.View()
	for _, v in ipairs(VIEWS) do
		local name = v.name
		if v.id == now then
			name = L.BANK_MENU_NOW:format(name)
		end
		list[#list + 1] = { text = L.BANK_MENU_VIEW:format(name), tip = L.TIP_MENU_VIEW, run = function()
			BW.SetView(v.id)
		end }
	end
	for _, kind in ipairs({ "bank", "warband" }) do
		list[#list + 1] = { text = L.BANK_MENU_SORT:format(BW.GroupName(kind)), tip = L.TIP_MENU_SORT, run = function()
			BW.Sort(kind)
		end }
	end
	list[#list + 1] = { text = L.BANK_MENU_REGROUP, tip = L.TIP_MENU_REGROUP, run = function()
		BW.Reflow("reflow")
	end }
	list[#list + 1] = { text = BW.VisitMode() == "tiny" and L.BANK_MENU_SHOW_BLIZZARD or L.BANK_MENU_HIDE_BLIZZARD,
		tip = L.TIP_MENU_BLIZZARD, run = function()
			BW.ToggleVisit()
		end }
	list[#list + 1] = { text = L.BANK_MENU_DEPOSIT, tip = L.TIP_MENU_DEPOSIT, run = function()
		BW.DepositWarband()
	end }
	-- Warband gold (0.14.2): the gold row's two actions, only while the Warband bank moves gold at all
	local canDeposit, canWithdraw, supported = SB.Adapter.WarbandMoneyState()
	if supported then
		list[#list + 1] = { text = L.BANK_MENU_GOLD_DEPOSIT, tip = canDeposit and L.TIP_GOLD_DEPOSIT or L.TIP_GOLD_UNAVAILABLE,
			run = function()
				BW.MoveGold("deposit")
			end }
		list[#list + 1] = { text = L.BANK_MENU_GOLD_WITHDRAW,
			tip = canWithdraw and L.TIP_GOLD_WITHDRAW or L.TIP_GOLD_UNAVAILABLE, run = function()
				BW.MoveGold("withdraw")
			end }
	end
	list[#list + 1] = { text = L.BANK_MENU_SETTINGS, tip = L.TIP_MENU_SETTINGS, run = function()
		SB.SettingsWindow.Show("bank")
	end }
	return list
end

local menu = CreateFrame("Frame", "SwagBagBankMenu", BW.frame, "BackdropTemplate")
menu:EnableMouse(true)
menu:SetFrameStrata("DIALOG")
menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
menu:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
menu:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
menu:Hide()
if SB.Theme then
	SB.Theme.Window(menu, "dialog")
end
BM.frame = menu
BM.rows = {}
table.insert(UISpecialFrames, "SwagBagBankMenu")

local function hideTip()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

local function row(i)
	local b = BM.rows[i]
	if not b then
		b = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
		b:SetSize(BM.WIDTH, BM.ROW)
		b:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * (BM.ROW + 2))
		b:SetScript("OnClick", Guard("bank.menuEntry", function(self)
			menu:Hide()
			self.entry.run()
		end, "bank"))
		b:SetScript("OnEnter", Guard("bank.menu", function(self)
			if not GameTooltip then
				return
			end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.entry.text)
			GameTooltip:AddLine(self.entry.tip, 1, 1, 1, true)
			GameTooltip:Show()
		end, "bank"))
		b:SetScript("OnLeave", hideTip)
		if SB.Theme then
			SB.Theme.Button(b)
		end
		BM.rows[i] = b
	end
	return b
end

function BM.Hide()
	hideTip()
	menu:Hide()
end

-- Open under the "..." button (anchor), or close. Returns whether the menu is shown after the call.
function BM.Toggle(anchor)
	if menu:IsShown() then
		BM.Hide()
		return false
	end
	local entries = BM.Entries()
	for i, e in ipairs(entries) do
		local b = row(i)
		b.entry = e
		b:SetText(e.text)
		b:Show()
	end
	for i = #entries + 1, #BM.rows do
		BM.rows[i]:Hide()
	end
	menu:SetSize(BM.WIDTH + 8, 8 + #entries * (BM.ROW + 2) - 2)
	menu:ClearAllPoints()
	menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
	menu:Show()
	return true
end
