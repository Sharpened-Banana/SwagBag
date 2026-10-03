-- SwagBag section actions (week 7, user pick 6): Shift+right-click a section header in the bags window
-- for a small menu of what can be done with the whole section here and now:
--   at a bank     "Send all to bank (N)" and "Send all to warband bank (N)": each item goes into that bank
--                 (Adapter.MoveToBank gives the bank type to the call, so Blizzard's selected tab is
--                 never changed); items the warband bank does not take are left out
--   at a vendor   "Sell all (N)", after a confirmation: items a vendor pays for, never what SwagBag protects
--                 (Vendor.Protected: locked, in an equipment set, to open or learn, worth more at auction) or
--                 what the client holds; within the visit's 12 (Blizzard's buyback keeps 12; the auto-sell and
--                 /swagbag sell junk share them, ruling R1). The question names the Auction House value when
--                 it is higher (R19), and past the 12 it says the earlier sales leave the Buyback tab.
-- Nowhere else (and in Free) there is nothing to do, and one chat line says where it works. Mail is left
-- out: attaching items to a letter is not a single safe call. Moves go through the mover
-- (Engine/Mover.lua): one item each 0.2 s, out of combat only, never while an item is on the cursor or the
-- item's button is under the mouse (P5); right before each move the vendor or bank is checked again
-- (rulings R2, R20). A moved item leaves a placeholder (spec 4.3), so nothing else in the bags moves. Each
-- action answers once (P2): one chat line when it ends.
-- Why Shift+right-click: a left-click collapses (AC3.2), a right-click pins in the collapse style (AC8.3)
-- and collapses in the front style (week 6), so both are taken; Shift+right-click is free, needs no new
-- frame on every header, and a header's tooltip names it whenever an action is available.
--   SA.Entries(id) -> { { text, run } }   SA.Open(id, header)   SA.Hint(id, header)
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local SA = { WIDTH = 210, ROW = 22 }
SB.SectionActions = SA

local function atVendor()
	return SB.Vendor ~= nil and SB.Vendor.open == true
end

function SA.Available()
	return SB.AtBank() or atVendor()
end

local function item(bag, slot, r)
	local info = SB.Adapter.GetItemInfo(r.itemID)
	return { bag = bag, slot = slot, itemID = r.itemID, link = r.link, count = r.count or 1,
		price = info and info.sellPrice or 0 }
end

-- The section's items a vendor pays for and SwagBag may sell. value: what one is worth to SwagBag
-- (Auctionator's price, else the vendor's; Engine/Prices.lua), for the question's Auction House sentence.
function SA.Sellable(id)
	local P, out = SB.Prices, {}
	for _, c in ipairs(SB.BagsWindow.SectionSlots(id)) do
		local r = c.record
		local it = item(c.bag, c.slot, r)
		if not r.pending and not r.hasNoValue and not r.isLocked and it.price > 0 and not SB.Vendor.Protected(r) then
			it.value = P and P.Value(r.link, r.itemID, P.Bound(r)) or it.price
			out[#out + 1] = it
		end
	end
	return out
end

-- The section's items that bank kind takes (an unknown answer counts as yes: the mover stops if refused).
function SA.Bankable(id, kind)
	local A, out = SB.Adapter, {}
	for _, c in ipairs(SB.BagsWindow.SectionSlots(id)) do
		if not c.record.isLocked and A.AllowedInBank(c.bag, c.slot, kind) ~= false then
			out[#out + 1] = item(c.bag, c.slot, c.record)
		end
	end
	return out
end

local KIND_NAME = { bank = "SECTION_BANK", warband = "SECTION_WARBAND" }

-- Right before each move (R20): the bank is still open. A lock never stops banking (it is about selling).
local function bankReady()
	return SB.AtBank() or "closed"
end

local function send(id, kind, list)
	local name, where = SB.Categories.Name(id), L[KIND_NAME[kind]]
	local ok, why = SB.Mover.Start({ items = list, act = function(bag, slot)
		return SB.Adapter.MoveToBank(bag, slot, kind)
	end, ready = bankReady, still = SB.AtBank, done = function(result)
		local n = #result.moved
		local line = n == 1 and L.SECTION_SENT_ONE:format(name, where) or L.SECTION_SENT:format(n, name, where)
		-- result.left: what stayed (never 0 on a stop, never an item used by hand meanwhile; ruling R8)
		if result.why == "stuck" or result.why == "error" then
			line = line .. " " .. L.SECTION_FULL:format(where, result.left)
		elseif result.why == "closed" then
			line = line .. " " .. L.SECTION_CLOSED:format(result.left)
		elseif result.why == "combat" then
			line = line .. " " .. L.VENDOR_STOP_COMBAT:format(result.left)
		elseif result.kept > 0 then
			line = line .. " " .. L.VENDOR_KEPT_MOUSE:format(result.kept)
		end
		SB.Print(line)
	end })
	if not ok then
		SB.Print(why == "combat" and L.SECTION_COMBAT or L.MOVER_BUSY)
	end
end

-- Sell all asks first (StaticPopup), naming how many, from where, and roughly for how much; the Auction
-- House value too when it is higher (R19). Within the visit's room it sells what fits; with no room left
-- (R1) it sells up to 12 more only after this question, which then says the earlier sales leave the
-- Buyback tab: that Yes is the explicit second confirmation.
SA.pending = nil
function SA.ConfirmSell(id, list)
	if SB.Adapter.InCombat() then -- nothing would sell: say so now rather than after a question
		SB.Print(L.SECTION_COMBAT)
		return
	end
	local V = SB.Vendor
	local past = V.Room() == 0
	local copper, worth, n = 0, 0, math.min(#list, past and V.BUYBACK or V.Room())
	for i = 1, n do
		copper = copper + list[i].price * list[i].count
		worth = worth + (list[i].value or list[i].price) * list[i].count
	end
	SA.pending = { id = id, list = list, past = past }
	local text = L.SECTION_SELL_CONFIRM:format(n, SB.Categories.Name(id), V.Money(copper))
	if worth > copper then
		text = text .. " " .. L.SECTION_SELL_AH:format(V.Money(worth))
	end
	if past then
		text = text .. " " .. L.SECTION_SELL_PAST
	end
	if StaticPopupDialogs and StaticPopup_Show then
		StaticPopupDialogs.SWAGBAG_SELL_ALL.text = text .. " " .. L.SECTION_SELL_KEEPS
		StaticPopup_Show("SWAGBAG_SELL_ALL")
	end
end

function SA.SellConfirmed()
	local p = SA.pending
	SA.pending = nil
	if not p then
		return
	end
	if not atVendor() then
		SB.Print(L.VENDOR_NOT_OPEN)
		return
	end
	local ok, why = SB.Vendor.Sell(p.list, "section", nil, p.past)
	if not ok then
		SB.Print(why == "combat" and L.SECTION_COMBAT or L.MOVER_BUSY)
	end
end

if StaticPopupDialogs then
	StaticPopupDialogs.SWAGBAG_SELL_ALL = {
		text = "",
		button1 = YES,
		button2 = NO,
		OnAccept = Guard("sections.sellAll", SA.SellConfirmed, "bags"),
		OnCancel = function()
			SA.pending = nil
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
end

function SA.Entries(id)
	local out = {}
	if id == SB.Categories.FREE then
		return out
	end
	if atVendor() then
		local list = SA.Sellable(id)
		if #list > 0 then
			out[#out + 1] = { text = L.SECTION_SELL_ALL:format(#list), run = function()
				SA.ConfirmSell(id, list)
			end }
		end
	end
	if SB.AtBank() then
		for _, kind in ipairs({ "bank", "warband" }) do
			local list = SA.Bankable(id, kind)
			if #list > 0 then
				out[#out + 1] = { text = L.SECTION_SEND_ALL:format(L[KIND_NAME[kind]], #list), run = function()
					send(id, kind, list)
				end }
			end
		end
	end
	return out
end

-- The menu: a plain frame (allowed in combat) with one button per entry and Cancel, beside the header.
local function menuFrame()
	if SA.menu then
		return SA.menu
	end
	local f = CreateFrame("Frame", "SwagBagSectionMenu", UIParent, "BackdropTemplate")
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	f:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
	f:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
	f:Hide()
	f.buttons = {}
	if SB.Theme then
		SB.Theme.Window(f, "dialog") -- themes restyle it like every SwagBag window (ruling R14)
	end
	table.insert(UISpecialFrames, "SwagBagSectionMenu")
	SA.menu = f
	return f
end

local function menuButton(f, i)
	local b = f.buttons[i]
	if not b then
		b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(SA.WIDTH - 12, SA.ROW - 2)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6 - (i - 1) * SA.ROW)
		b:SetScript("OnClick", Guard("sections.menu", function(self)
			f:Hide()
			if self.run then
				self.run()
			end
		end, "bags"))
		if SB.Theme then
			SB.Theme.Button(b)
		end
		f.buttons[i] = b
	end
	b:Show()
	return b
end

function SA.Open(id, header)
	local entries = SA.Entries(id)
	if #entries == 0 then
		SB.Print(SA.Available() and L.SECTION_NOTHING:format(SB.Categories.Name(id)) or L.SECTION_WHERE)
		return false
	end
	local f = menuFrame()
	for i, e in ipairs(entries) do
		local b = menuButton(f, i)
		b:SetText(e.text)
		b.run = e.run
	end
	local cancel = menuButton(f, #entries + 1)
	cancel:SetText(L.SECTION_CANCEL)
	cancel.run = nil
	for i = #entries + 2, #f.buttons do
		f.buttons[i]:Hide()
	end
	f:SetSize(SA.WIDTH, 12 + (#entries + 1) * SA.ROW)
	f:ClearAllPoints()
	if header then
		f:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 24, 0)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	f:Show()
	return true
end

-- A header's tooltip names the gesture while an action is available (P1: easy to find).
function SA.Hint(id, header)
	if not (GameTooltip and SA.Available()) or id == SB.Categories.FREE then
		return
	end
	GameTooltip:SetOwner(header, "ANCHOR_TOP")
	GameTooltip:SetText(SB.Categories.Name(id))
	GameTooltip:AddLine(atVendor() and L.SECTION_HINT_VENDOR or L.SECTION_HINT_BANK, 1, 1, 1, true)
	GameTooltip:Show()
end

local function hideMenu()
	if SA.menu then
		SA.menu:Hide()
	end
end
SB.On("SB_BAGS_CLOSED", hideMenu, "bags")
SB.On("MERCHANT_CLOSED", hideMenu, "bags")
SB.On("BANKFRAME_CLOSED", hideMenu, "bags")
