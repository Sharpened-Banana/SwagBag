-- =====================================================================
-- THROWAWAY SPIKE CODE  -  SwagBagSpikes / SpikePool.lua
-- Spike A: secure item-button pool.
--  * Creates ~1,300 ContainerFrameItemButtonTemplate buttons at login,
--    one per possible (bag, slot), parented to per-bag frames (SetID(bag))
--    that live inside ONE scroll child. Times it per 100 + memory.
--  * Shows them in a "spike bag" window (grid view; Spike D adds sections).
--  * "A2 strip": up to 12 extra buttons that use SetBagID() (attribute
--    path) instead of a per-bag parent, to see if that is also taint-free.
--  * Combat battery: on entering combat, tries SetPoint/Show/Hide/SetAlpha/
--    SetParent/SetID/CreateFrame on pool buttons and records any block.
--  * Item-use results are evaluated from Core's use tracker.
-- =====================================================================
local ADDON, ns = ...

ns.RegisterSpike("A_POOL", "Create ~1,300 slot buttons at login (time + memory)", "A",
	"Pre-create all buttons at login vs time-slice vs create on first bank open")
ns.RegisterSpike("A_USE", "Use items from addon buttons, in and out of combat", "A",
	"Whether the secure-template path (per-bag parent and/or SetBagID) lets SwagBag buttons use items without taint")
ns.RegisterSpike("A_COMBAT", "Move/show/hide/create pool buttons during combat", "A",
	"Whether layout can change in combat (Incoming strip) or must freeze")

local Pool = { buttons = {}, bagFrames = {}, headers = {}, all = {}, attr = {}, mode = "grid", onHideCallbacks = {} }
ns.Pool = Pool

local COLS, SIZE, GAP = 12, 37, 4
Pool.COLS, Pool.SIZE, Pool.GAP = COLS, SIZE, GAP

-- capacity per bag: max(actual, assumed max). Bank tab size assumed 98 (checked at bank).
local ASSUMED = { [0] = 20, [1] = 38, [2] = 38, [3] = 38, [4] = 38, [5] = 38 }
local BANK_TAB_ASSUMED = 98

local function AllPoolBags()
	local list = {}
	for _, b in ipairs(ns.BAGS) do list[#list + 1] = b end
	for _, b in ipairs(ns.CHAR_TABS_ALL) do list[#list + 1] = b end
	for _, b in ipairs(ns.ACCT_TABS_ALL) do list[#list + 1] = b end
	return list
end

local function Capacity(bag)
	local n = ns.NumSlots(bag)
	local assumed = ASSUMED[bag] or BANK_TAB_ASSUMED
	return math.max(n, assumed)
end

function Pool.BagLabel(bag)
	if bag == 0 then return "Backpack (0)" end
	if bag >= 1 and bag <= 4 then return "Bag " .. bag end
	if bag == 5 then return "Reagent bag (5)" end
	if bag >= 6 and bag <= 11 then return "Character bank tab " .. (bag - 5) .. "  [bag " .. bag .. "]" end
	if bag >= 12 and bag <= 16 then return "Warband bank tab " .. (bag - 11) .. "  [bag " .. bag .. "]" end
	return "bag " .. bag
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local win = ns.MakeWindow("SwagBagSpikesPoolWindow", "SBS spike bag  (Spike A + D)", 4 + COLS * (SIZE + GAP) + 24, 520)
win:SetPoint("CENTER", 260, 0)
Pool.win = win

win.status = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
win.status:SetPoint("TOPLEFT", 8, -24)
win.status:SetJustifyH("LEFT")

win.scroll = CreateFrame("ScrollFrame", nil, win)
win.scroll:SetPoint("TOPLEFT", 6, -64)
win.scroll:SetPoint("BOTTOMRIGHT", -6, 6)
win.child = CreateFrame("Frame", nil, win.scroll)
win.child:SetSize(COLS * (SIZE + GAP) + 8, 400)
win.scroll:SetScrollChild(win.child)
win.scroll:EnableMouseWheel(true)
win.scroll:SetScript("OnMouseWheel", function(self, delta)
	local cur, max = self:GetVerticalScroll(), self:GetVerticalScrollRange()
	self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 60)))
end)
Pool.child = win.child

function Pool.SetStatus(text) win.status:SetText(text or "") end

-- A plain ScrollFrame doesn't clamp its offset when the child shrinks (e.g. bank
-- closes: 702 -> 212 buttons), leaving the view scrolled past the end = "empty bag".
function Pool.ClampScroll()
	local max = math.max(0, win.child:GetHeight() - win.scroll:GetHeight())
	if win.scroll:GetVerticalScroll() > max then win.scroll:SetVerticalScroll(max) end
end

---------------------------------------------------------------------------
-- Button creation
---------------------------------------------------------------------------
local function BagFrame(bag)
	local f = Pool.bagFrames[bag]
	if f then return f end
	f = CreateFrame("Frame", nil, win.child)
	f:SetID(bag)
	f:SetAllPoints(win.child)
	-- Blizzard's Initialize() asks the parent this; we never call Initialize, but be safe.
	f.IsCombinedBagContainer = function() return false end
	Pool.bagFrames[bag] = f
	Pool.buttons[bag] = Pool.buttons[bag] or {}
	return f
end

local function CreateSlotButton(bag, slot)
	local parent = BagFrame(bag)
	local b = CreateFrame("ItemButton", nil, parent, "ContainerFrameItemButtonTemplate")
	b:SetID(slot)
	b.sbsKind, b.sbsBag, b.sbsSlot = "pool", bag, slot
	b.sbsLabel = "pool:" .. bag .. ":" .. slot
	Pool.buttons[bag][slot] = b
	Pool.all[#Pool.all + 1] = b
	return b
end

local function AddBackground(b)
	if b.sbsBG then return end
	local bg = b:CreateTexture(nil, "BACKGROUND", nil, -7)
	bg:SetAllPoints(b)
	local ok = pcall(bg.SetAtlas, bg, "bags-item-slot64")
	if not ok then bg:SetColorTexture(0.15, 0.15, 0.15, 0.8) end
	b.sbsBG = bg
end

function Pool.EnsureCapacity(bag, n)
	local list = Pool.buttons[bag] or {}
	if #list >= n then return 0 end
	local made = 0
	for slot = #list + 1, n do
		local b = CreateSlotButton(bag, slot)
		AddBackground(b)
		made = made + 1
	end
	ns.Log("poolGrow", { bag = bag, made = made, n = n })
	return made
end

local function MemKB()
	local ok = pcall(UpdateAddOnMemoryUsage)
	local okM, kb = pcall(GetAddOnMemoryUsage, ADDON)
	return (ok and okM) and kb or nil
end

function Pool.CreateAll()
	if Pool.created then return end
	if ns.InCombat() then
		ns.Data("A_POOL", "deferredBecauseCombat", true)
		ns.OutOfCombat("Pool.CreateAll", Pool.CreateAll)
		return
	end
	collectgarbage("collect")
	local memBefore, luaBefore = MemKB(), collectgarbage("count")
	local bags = AllPoolBags()
	local per100, n = {}, 0
	local t0 = debugprofilestop()
	local tChunk = t0
	local perBag = {}
	for _, bag in ipairs(bags) do
		local cap = Capacity(bag)
		perBag[bag] = cap
		BagFrame(bag)
		for slot = 1, cap do
			CreateSlotButton(bag, slot)
			n = n + 1
			if n % 100 == 0 then
				local t = debugprofilestop()
				per100[#per100 + 1] = math.floor((t - tChunk) * 100) / 100
				tChunk = t
			end
		end
	end
	local createMs = debugprofilestop() - t0
	local t1 = debugprofilestop()
	for _, b in ipairs(Pool.all) do AddBackground(b); b:Hide() end
	local bgMs = debugprofilestop() - t1
	local memAfter, luaAfter = MemKB(), collectgarbage("count")
	Pool.created = true

	-- A2 strip buttons (SetBagID path), parented to a plain frame without an ID
	Pool.CreateAttrStrip()

	-- sanity: does GetBagID resolve through the parent?
	local sample = Pool.buttons[0] and Pool.buttons[0][1]
	local okBag, bagFromParent = pcall(function() return sample:GetBagID() end)
	local okProt, isProt, explicit = pcall(function() return sample:IsProtected() end)

	local maxChunk = 0
	for _, v in ipairs(per100) do if v > maxChunk then maxChunk = v end end
	local d = {
		buttons = n, perBagCapacity = perBag, createMs = createMs, backgroundsMs = bgMs,
		per100ms = per100, maxPer100ms = maxChunk,
		addonMemKB_before = memBefore, addonMemKB_after = memAfter,
		luaHeapKB_delta = luaAfter - luaBefore,
		memKBPerButton = (memAfter and memBefore) and ((memAfter - memBefore) / math.max(n, 1)) or nil,
		getBagIDFromParent = okBag and bagFromParent or "error",
		isProtected = (not okProt and "error") or isProt, isProtectedExplicit = okProt and explicit or nil,
		note = "GetAddOnMemoryUsage counts Lua heap only; frame/texture C memory is not included",
	}
	for k, v in pairs(d) do ns.Data("A_POOL", k, v) end
	ns.Check("A_POOL", "created", n > 1000, ("%d buttons in %.1f ms (+%.1f ms backgrounds)"):format(n, createMs, bgMs))
	ns.Check("A_POOL", "getBagIDResolvesFromParent", okBag and bagFromParent == 0, bagFromParent)
	-- Go threshold: whole pool in <= 250 ms at login (hidden by loading screen); else time-slice.
	ns.Check("A_POOL", "createUnder250ms", createMs + bgMs <= 250, ("total %.1f ms, worst 100 = %.1f ms"):format(createMs + bgMs, maxChunk))
	ns.Summary("A_POOL", ("%d buttons, %.0f ms create + %.0f ms bg, Lua +%.0f KB"):format(n, createMs, bgMs, luaAfter - luaBefore))
	ns.Print(("A_POOL: %d buttons in %.0f ms (worst 100: %.1f ms), +%.0f KB Lua"):format(n, createMs + bgMs, maxChunk, luaAfter - luaBefore))
end

---------------------------------------------------------------------------
-- Button visuals
---------------------------------------------------------------------------
function Pool.UpdateButton(b)
	local bag, slot = b.sbsBag, b:GetID()
	if b.sbsKind == "attr" then bag = b:GetBagID() end
	local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
	if not ok then info = nil end
	SetItemButtonTexture(b, info and info.iconFileID or nil)
	SetItemButtonCount(b, info and info.stackCount or 0)
	SetItemButtonQuality(b, info and info.quality or nil, info and info.hyperlink or nil)
	SetItemButtonDesaturated(b, info and info.isLocked or false)
	if b.UpdateCooldown then pcall(b.UpdateCooldown, b, info ~= nil) end
	b.sbsItemID = info and info.itemID or nil
	return info
end

local function TagButton(b, text, r, g, bl)
	if not b.sbsTag then
		b.sbsTag = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
		b.sbsTag:SetPoint("TOPLEFT", 1, -1)
	end
	b.sbsTag:SetText(text or "")
	b.sbsTag:SetTextColor(r or 1, g or 0.9, bl or 0)
	b.sbsTag:SetShown(text ~= nil and text ~= "")
end
Pool.TagButton = TagButton

---------------------------------------------------------------------------
-- Grid layout (bags + bank tabs when the bank is open)
---------------------------------------------------------------------------
local function Header(key)
	local h = Pool.headers[key]
	if not h then
		h = win.child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		Pool.headers[key] = h
	end
	return h
end
Pool.Header = Header

function Pool.HideAllHeaders()
	for _, h in pairs(Pool.headers) do h:Hide() end
end

function Pool.VisibleBags()
	local list = {}
	for _, bag in ipairs(ns.BAGS) do
		if ns.NumSlots(bag) > 0 then list[#list + 1] = bag end
	end
	if ns.bankOpen then
		for _, kind in ipairs({ "Character", "Account" }) do
			for _, bag in ipairs(ns.PurchasedTabs(kind)) do
				if ns.NumSlots(bag) > 0 then list[#list + 1] = bag end
			end
		end
	end
	return list
end

function Pool.PlaceAt(b, x, y)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", win.child, "TOPLEFT", x, y)
end

function Pool.LayoutGrid(reason)
	if not Pool.created then return end
	local t0 = debugprofilestop()
	if ns.Layout then ns.Layout.HidePlaceholders() end
	Pool.HideAllHeaders()
	local shown = Pool.VisibleBags()
	local shownSet = {}
	for _, bag in ipairs(shown) do shownSet[bag] = true end
	for bag, f in pairs(Pool.bagFrames) do f:SetShown(shownSet[bag] or false) end
	local y, nButtons = -4, 0
	for _, bag in ipairs(shown) do
		local h = Header("bag" .. bag)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", win.child, "TOPLEFT", 4, y)
		h:SetText(Pool.BagLabel(bag))
		h:Show()
		y = y - 14
		local n = ns.NumSlots(bag)
		if n > #(Pool.buttons[bag] or {}) then
			if ns.InCombat() then
				ns.Log("poolCapacityShortInCombat", { bag = bag, need = n })
			else
				Pool.EnsureCapacity(bag, n)
			end
		end
		local list = Pool.buttons[bag]
		for slot = 1, #list do
			local b = list[slot]
			if slot <= n then
				local i = slot - 1
				Pool.PlaceAt(b, 4 + (i % COLS) * (SIZE + GAP), y - math.floor(i / COLS) * (SIZE + GAP))
				b:Show()
				Pool.UpdateButton(b)
				nButtons = nButtons + 1
			else
				b:Hide()
			end
		end
		y = y - math.ceil(n / COLS) * (SIZE + GAP) - 6
	end
	win.child:SetHeight(math.max(-y + 10, 50))
	Pool.ClampScroll()
	Pool.mode = "grid"
	local ms = debugprofilestop() - t0
	ns.Log("layoutGrid", { ms = ms, buttons = nButtons, reason = reason, bank = ns.bankOpen })
	local s = ns.Spike("A_POOL").data
	if ns.bankOpen and not s.firstBankGridMs then
		ns.Data("A_POOL", "firstBankGridMs", ms)
		ns.Data("A_POOL", "firstBankGridButtons", nButtons)
	elseif not s.firstGridMs then
		ns.Data("A_POOL", "firstGridMs", ms)
		ns.Data("A_POOL", "firstGridButtons", nButtons)
	end
	s.maxGridMs = math.max(s.maxGridMs or 0, ms)
	if reason == "user" then
		local key = ns.InCombat() and "toggleViewInCombat" or "toggleViewOutOfCombat"
		local start = GetTime()
		C_Timer.After(1, function()
			local blocked = ns.BlockedMineSince(start)
			ns.Check("D_LAYOUT", key, blocked == 0, { toGrid = true, ms = ms, blocked = blocked })
		end)
	end
	Pool.SetStatus(("Grid view: %d slots, layout %.1f ms%s"):format(nButtons, ms, ns.InCombat() and " (in combat)" or ""))
	return ms
end

function Pool.RefreshVisible()
	if not win:IsShown() then return end
	if Pool.mode == "sections" and ns.Layout then
		ns.Layout.Incremental()
		return
	end
	-- grid: re-layout if any visible bag size changed, else repaint
	local sizesChanged = false
	Pool.lastSizes = Pool.lastSizes or {}
	for _, bag in ipairs(Pool.VisibleBags()) do
		local n = ns.NumSlots(bag)
		if Pool.lastSizes[bag] ~= n then sizesChanged = true end
		Pool.lastSizes[bag] = n
	end
	if sizesChanged then
		Pool.LayoutGrid("sizes changed")
	else
		local t0 = debugprofilestop()
		for _, bag in ipairs(Pool.VisibleBags()) do
			for slot = 1, ns.NumSlots(bag) do
				local b = Pool.buttons[bag] and Pool.buttons[bag][slot]
				if b then Pool.UpdateButton(b) end
			end
		end
		local s = ns.Spike("A_POOL").data
		s.maxRepaintMs = math.max(s.maxRepaintMs or 0, debugprofilestop() - t0)
	end
end

function Pool.Show()
	if not Pool.created then Pool.CreateAll() end
	if not win:IsShown() then
		local t0 = debugprofilestop()
		win:Show()
		if Pool.mode == "sections" and ns.Layout then ns.Layout.Full("open") else Pool.LayoutGrid("open") end
		ns.Log("poolShow", { ms = debugprofilestop() - t0 })
	end
end

function Pool.Hide() win:Hide() end

function Pool.Toggle()
	if win:IsShown() then Pool.Hide() else Pool.Show() end
end

win:HookScript("OnHide", function()
	ns.Log("poolHide", { ms = debugprofilestop(), suppressed = Pool.suppressOnHide or nil })
	if Pool.suppressOnHide then return end
	for _, cb in ipairs(Pool.onHideCallbacks) do ns.Try("Pool.onHide", cb) end
end)

---------------------------------------------------------------------------
-- Header buttons on the window
---------------------------------------------------------------------------
local bGrid = ns.MakeButton(win, "Grid view", 90, function() Pool.LayoutGrid("user") end)
bGrid:SetPoint("TOPLEFT", 6, -38)
local bSections = ns.MakeButton(win, "Sections view", 100, function() if ns.Layout then ns.Layout.Full("user") end end)
bSections:SetPoint("LEFT", bGrid, "RIGHT", 4, 0)
local bReflow = ns.MakeButton(win, "Reflow", 70, function() if ns.Layout then ns.Layout.Reflow() end end)
bReflow:SetPoint("LEFT", bSections, "RIGHT", 4, 0)
local bA2 = ns.MakeButton(win, "A2 strip", 80, function() Pool.ToggleAttrStrip() end)
bA2:SetPoint("LEFT", bReflow, "RIGHT", 4, 0)

---------------------------------------------------------------------------
-- A2 strip: buttons that rely on SetBagID (attribute) instead of parent ID
---------------------------------------------------------------------------
local strip = ns.MakeWindow("SwagBagSpikesA2Strip", "A2 strip: same items, SetBagID() buttons", 12 * (SIZE + GAP) + 12, 72)
strip:SetPoint("BOTTOM", win, "TOP", 0, 6)
Pool.strip = strip

function Pool.CreateAttrStrip()
	if #Pool.attr > 0 then return end
	local holder = CreateFrame("Frame", nil, strip) -- no SetID: parent ID would be 0
	holder:SetAllPoints(strip)
	for i = 1, 12 do
		local b = CreateFrame("ItemButton", nil, holder, "ContainerFrameItemButtonTemplate")
		b.sbsKind = "attr"
		b.sbsLabel = "attr:" .. i
		-- explicit size + anchor to the holder: without it the strip rendered smeared/overlapping
		b:SetSize(SIZE, SIZE)
		b:SetPoint("TOPLEFT", holder, "TOPLEFT", 6 + (i - 1) * (SIZE + GAP), -26)
		AddBackground(b)
		b:Hide()
		Pool.attr[i] = b
	end
	local mixinSetBagID = ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.SetBagID
	ns.Data("A_USE", "attrButtonUsesContainerMixinSetBagID", Pool.attr[1].SetBagID == mixinSetBagID)
end

local function HasUseSpell(itemID)
	if not itemID then return false end
	local ok, name, spellID = pcall(C_Item.GetItemSpell, itemID)
	return ok and (name ~= nil or spellID ~= nil)
end

function Pool.FillAttrStrip()
	if ns.InCombat() then ns.Print("A2 strip can only be (re)filled out of combat") return end
	local i = 0
	for _, bag in ipairs(ns.BAGS) do
		for slot = 1, ns.NumSlots(bag) do
			local id = C_Container.GetContainerItemID(bag, slot)
			if i < 12 and HasUseSpell(id) then
				i = i + 1
				local b = Pool.attr[i]
				b:SetBagID(bag)
				b:SetID(slot)
				b.sbsBag, b.sbsSlot = bag, slot
				b:Show()
				Pool.UpdateButton(b)
			end
		end
	end
	for j = i + 1, 12 do Pool.attr[j]:Hide() end
	local b1 = Pool.attr[1]
	local okAttr, attrVal = pcall(b1.GetAttribute, b1, "bagid")
	ns.Data("A_USE", "attrStripFilled", i)
	ns.Data("A_USE", "attrBagidAttribute", okAttr and attrVal or "error")
	ns.Data("A_USE", "attrGetBagID", b1.GetBagID and b1:GetBagID() or "nil")
	strip.title:SetText(("A2 strip: %d usable items via SetBagID()"):format(i))
end

function Pool.ToggleAttrStrip()
	if strip:IsShown() then strip:Hide() return end
	if not Pool.created then Pool.CreateAll() end
	Pool.FillAttrStrip()
	strip:Show()
end

---------------------------------------------------------------------------
-- Item-use evaluation (from Core's tracker)
---------------------------------------------------------------------------
local function EvaluateUse()
	for _, variant in ipairs({ "pool", "attr", "blizzard" }) do
		for _, combat in ipairs({ false, true }) do
			local att, blk, weak = ns.UseStats(variant, combat)
			local name = ("use_%s_%s"):format(variant, combat and "inCombat" or "outOfCombat")
			if blk > 0 then
				ns.Check("A_USE", name, false, { attempts = att, blocked = blk, weak = weak })
			elseif att > 0 then
				ns.Check("A_USE", name, true, { attempts = att, blocked = 0, weak = weak })
			elseif weak > 0 then
				ns.Check("A_USE", name, nil, { attempts = 0, blocked = 0, weak = weak, note = "only UI error messages seen (item may not be usable now)" })
			end
		end
	end
end
table.insert(ns.useListeners, function() C_Timer.After(0.2, function() ns.Try("EvaluateUse", EvaluateUse) end) end)

---------------------------------------------------------------------------
-- Combat battery (automatic, first 3 combats)
---------------------------------------------------------------------------
local batteries = 0
local function Battery()
	if not Pool.created or not ns.InCombat() then return end
	batteries = batteries + 1
	if batteries > 3 then return end
	local start = GetTime()
	local spare = Pool.buttons[16] and Pool.buttons[16][#Pool.buttons[16]] or Pool.all[#Pool.all]
	local visible
	if win:IsShown() then
		for _, b in ipairs(Pool.all) do if b:IsVisible() then visible = b break end end
	end
	local results = {}
	local function op(name, fn)
		local t0 = debugprofilestop()
		local ok, err = pcall(fn)
		results[#results + 1] = { op = name, ok = ok, err = (not ok) and ns.Safe(tostring(err)) or nil, ms = debugprofilestop() - t0 }
		ns.Log("combatOp", { op = name, ok = ok })
	end
	ns.Mark("combatBattery#" .. batteries)
	local okP, prot = pcall(spare.IsProtected, spare)
	results[#results + 1] = { op = "IsProtected", ok = okP, value = prot }
	op("spare:ClearAllPoints+SetPoint", function() spare:ClearAllPoints(); spare:SetPoint("TOPLEFT", win.child, "TOPLEFT", 0, 0) end)
	op("spare:Show", function() spare:Show() end)
	op("spare:SetAlpha", function() spare:SetAlpha(0.5); spare:SetAlpha(1) end)
	op("spare:Hide", function() spare:Hide() end)
	op("spare:SetID(same)", function() spare:SetID(spare:GetID()) end)
	op("spare:SetParent(other bag frame)+back", function()
		local orig = spare:GetParent()
		spare:SetParent(Pool.bagFrames[15] or orig)
		spare:SetParent(orig)
	end)
	op("bagFrame:Hide+Show", function()
		local f = Pool.bagFrames[16]
		local was = f:IsShown()
		f:Hide(); f:SetShown(was)
	end)
	op("CreateFrame(ContainerFrameItemButtonTemplate)", function()
		local nb = CreateFrame("ItemButton", nil, Pool.bagFrames[16], "ContainerFrameItemButtonTemplate")
		nb:Hide()
	end)
	if visible then
		op("visible:re-anchor same spot", function()
			local p, rel, rp, x, y = visible:GetPoint(1)
			visible:ClearAllPoints()
			visible:SetPoint(p, rel, rp, x, y)
		end)
		op("visible:Hide+Show", function() visible:Hide(); visible:Show() end)
		op("window:Hide+Show", function()
			Pool.suppressOnHide = true
			win:Hide(); win:Show()
			Pool.suppressOnHide = false
		end)
	end
	C_Timer.After(1.5, function()
		local blocked = ns.BlockedMineSince(start)
		local allOk = true
		for _, r in ipairs(results) do if r.ok == false then allOk = false end end
		ns.Data("A_COMBAT", "battery" .. batteries, { results = results, blockedMine = blocked, visibleTested = visible ~= nil })
		ns.Check("A_COMBAT", "battery_noErrors", allOk, ("battery #%d"):format(batteries))
		ns.Check("A_COMBAT", "battery_noBlockedActions", blocked == 0, { blocked = blocked })
		if visible then ns.Check("A_COMBAT", "visibleButtonsMovableInCombat", allOk and blocked == 0, "re-anchor/hide/show a visible button + window") end
		ns.Summary("A_COMBAT", ("battery #%d: %s, blocked %d"):format(batteries, allOk and "all ops ok" or "some ops errored", blocked))
	end)
end
table.insert(ns.combatStart, function() C_Timer.After(0.5, function() ns.Try("Battery", Battery) end) end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local pending = false
ns.On("BAG_UPDATE_DELAYED", function()
	if pending then return end
	pending = true
	C_Timer.After(0.05, function()
		pending = false
		ns.Try("Pool.RefreshVisible", Pool.RefreshVisible)
		if strip:IsShown() then for _, b in ipairs(Pool.attr) do if b:IsShown() then Pool.UpdateButton(b) end end end
	end)
end)
ns.On("ITEM_LOCK_CHANGED", function(_, bag, slot)
	if bag and slot and not ns.IsSecret(bag) and Pool.buttons[bag] and Pool.buttons[bag][slot] and Pool.buttons[bag][slot]:IsVisible() then
		Pool.UpdateButton(Pool.buttons[bag][slot])
	end
end)
ns.On("BAG_UPDATE_COOLDOWN", function()
	if not win:IsShown() then return end
	for _, b in ipairs(Pool.all) do
		if b:IsVisible() and b.sbsItemID and b.UpdateCooldown then pcall(b.UpdateCooldown, b, true) end
	end
end)

ns.OnLogin(function() ns.Try("Pool.CreateAll", Pool.CreateAll) end)

ns.Command("pool", "show/hide the spike bag window (spike A)", function() Pool.Toggle() end)
ns.commands.a = ns.commands.pool
ns.Command("a2", "show/hide the A2 SetBagID strip", function() Pool.ToggleAttrStrip() end)
