-- =====================================================================
-- THROWAWAY SPIKE CODE  -  SwagBagSpikes / Core.lua
-- Not SwagBag product code. Feasibility tests only; delete after use.
-- Shared plumbing: results DB, logging, error + taint capture, events,
-- slash commands, use-attempt tracking, small UI helpers.
-- =====================================================================
local ADDON, ns = ...

ns.ADDON = ADDON
ns.VERSION = "0.1-spike"

local MAX_RUNS, MAX_EVENTS, MAX_ERRORS, MAX_BLOCKED, MAX_USES = 5, 800, 80, 150, 120

local run -- current run table (lives inside SwagBagSpikesDB.runs)

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function isSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) or false
end
ns.IsSecret = isSecret

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[SBS]|r " .. tostring(msg))
end

function ns.Now() return debugprofilestop() end

-- Make any value safe to store in SavedVariables (no secrets/frames/functions).
function ns.Safe(v, depth)
	if isSecret(v) then return "<secret>" end
	local t = type(v)
	if t == "nil" or t == "boolean" then return v end
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return tostring(v) end
		return v
	end
	if t == "string" then
		if #v > 400 then return v:sub(1, 400) .. "..." end
		return v
	end
	if t == "table" then
		depth = depth or 0
		if depth > 5 then return "<table too deep>" end
		local okFrame, isFrame = pcall(function() return type(v.GetObjectType) == "function" end)
		if okFrame and isFrame then
			local ok, name = pcall(function() return v:GetName() end)
			return "<frame " .. tostring(ok and name or "?") .. ">"
		end
		local out, n = {}, 0
		local ok = pcall(function()
			for k, val in pairs(v) do
				n = n + 1
				if n > 300 then out._truncated = true break end
				local key = k
				if isSecret(k) or (type(k) ~= "number" and type(k) ~= "string") then key = tostring(k) end
				out[key] = ns.Safe(val, depth + 1)
			end
		end)
		if not ok then return "<unreadable table>" end
		return out
	end
	return "<" .. t .. ">"
end

-- Resolve "C_Container.SortBags" style paths without erroring.
function ns.Resolve(path)
	local cur = _G
	for part in path:gmatch("[^%.]+") do
		local ok, nxt = pcall(function() return cur[part] end)
		if not ok or nxt == nil then return nil end
		cur = nxt
	end
	return cur
end

function ns.InCombat() return InCombatLockdown() and true or false end

function ns.NumSlots(bag)
	local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
	if ok and type(n) == "number" and not isSecret(n) then return n end
	return 0
end

---------------------------------------------------------------------------
-- Results DB
---------------------------------------------------------------------------
ns.spikeOrder, ns.spikeInfo = {}, {}

function ns.RegisterSpike(id, title, critique, decides)
	if not ns.spikeInfo[id] then table.insert(ns.spikeOrder, id) end
	ns.spikeInfo[id] = { title = title, critique = critique, decides = decides }
end

function ns.Run() return run end

local function InitDB()
	if type(SwagBagSpikesDB) ~= "table" then SwagBagSpikesDB = {} end
	local db = SwagBagSpikesDB
	db.schema = 1
	db.README = "THROWAWAY SPIKE RESULTS for SwagBag. Newest run = runs[lastRunIndex]. Each spike has status, summary, checks{}, data{}."
	db.runs = db.runs or {}
	run = {
		startedAt = date("%Y-%m-%d %H:%M:%S"),
		addonVersion = ns.VERSION,
		spikes = {}, events = {}, errors = {}, blocked = {}, uses = {}, guide = {}, counters = {},
	}
	local ok, version, build, bdate, toc = pcall(GetBuildInfo)
	run.build = ok and { version = version, build = build, date = bdate, toc = toc } or "unknown"
	table.insert(db.runs, run)
	while #db.runs > MAX_RUNS do table.remove(db.runs, 1) end
	db.lastRunIndex = #db.runs
end

function ns.Spike(id)
	if not run then return { checks = {}, data = {} } end -- before DB is ready: throwaway sink
	local s = run.spikes[id]
	if not s then
		local info = ns.spikeInfo[id] or {}
		s = { title = info.title, critique = info.critique, decides = info.decides, status = "NOT RUN", checks = {}, data = {} }
		run.spikes[id] = s
	end
	return s
end

-- Record one check. pass = true / false / nil (nil = informational / not decided)
function ns.Check(id, name, pass, detail)
	local s = ns.Spike(id)
	local prev = s.checks[name]
	s.checks[name] = { pass = pass, detail = ns.Safe(detail), at = date("%H:%M:%S"), combat = ns.InCombat() or nil }
	-- recompute spike status
	local anyPass, anyFail = false, false
	for _, c in pairs(s.checks) do
		if c.pass == true then anyPass = true elseif c.pass == false then anyFail = true end
	end
	if anyFail and anyPass then s.status = "MIXED"
	elseif anyFail then s.status = "FAIL"
	elseif anyPass then s.status = "PASS"
	else s.status = "INFO" end
	local changed = not prev or prev.pass ~= pass
	if changed and pass ~= nil then
		local col = pass and "|cff44ff44PASS|r" or "|cffff4444FAIL|r"
		ns.Print(("%s %s: %s"):format(id, name, col))
	end
	if ns.GuideRefresh then ns.GuideRefresh() end
end

function ns.Data(id, key, value)
	ns.Spike(id).data[key] = ns.Safe(value)
end

function ns.Summary(id, text)
	ns.Spike(id).summary = text
end

---------------------------------------------------------------------------
-- Event log, marks, errors
---------------------------------------------------------------------------
function ns.Log(kind, data)
	if not run then return end
	local e = type(data) == "table" and ns.Safe(data) or { value = ns.Safe(data) }
	e.kind = kind
	e.t = GetTime()
	e.ms = debugprofilestop()
	e.combat = ns.InCombat() or nil
	local ev = run.events
	ev[#ev + 1] = e
	if #ev > MAX_EVENTS then table.remove(ev, 1) end
end

ns.lastOp, ns.lastOpAt = nil, 0
function ns.Mark(label)
	ns.lastOp, ns.lastOpAt = label, GetTime()
	ns.Log("mark", { label = label })
end

function ns.RecordError(msg, where)
	if not run then return end
	local text = isSecret(msg) and "<secret>" or tostring(msg)
	local mine = text:find(ADDON, 1, true) ~= nil or (where ~= nil and where ~= "errorhandler")
	run.counters.errors = (run.counters.errors or 0) + 1
	if mine then run.counters.errorsMine = (run.counters.errorsMine or 0) + 1 end
	if #run.errors < MAX_ERRORS then
		table.insert(run.errors, {
			t = GetTime(), where = where, msg = text:sub(1, 900), mine = mine,
			combat = ns.InCombat() or nil, lastOp = ns.lastOp,
		})
	end
end

-- Wrap the global error handler (keeps BugSack etc. working).
do
	local prev = geterrorhandler()
	seterrorhandler(function(msg, ...)
		pcall(ns.RecordError, msg, "errorhandler")
		if prev then return prev(msg, ...) end
	end)
end

-- Run fn safely; never lets a spike error cascade.
function ns.Try(label, fn, ...)
	local args = { n = select("#", ...), ... }
	local prevOp = ns.currentOp
	ns.currentOp = label
	local res = { xpcall(function() return fn(unpack(args, 1, args.n)) end, function(err)
		local s = isSecret(err) and "<secret>" or tostring(err)
		return s .. "\n" .. (debugstack(2, 8, 0) or "")
	end) }
	ns.currentOp = prevOp
	if not res[1] then
		ns.RecordError(res[2], label)
		ns.Print("|cffff8800error in " .. label .. "|r (recorded)")
	end
	return unpack(res, 1, table.maxn(res))
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local evf = CreateFrame("Frame")
local handlers = {}
ns.unknownEvents = {}

function ns.On(event, fn, unit)
	if not handlers[event] then
		local ok = pcall(function()
			if unit then evf:RegisterUnitEvent(event, unit) else evf:RegisterEvent(event) end
		end)
		if not ok then
			ns.unknownEvents[event] = true
			return false
		end
		handlers[event] = {}
	end
	table.insert(handlers[event], fn)
	return true
end

evf:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do ns.Try("event:" .. event, list[i], event, ...) end
end)

ns.loginHooks = {}
function ns.OnLogin(fn) table.insert(ns.loginHooks, fn) end

ns.On("ADDON_LOADED", function(_, name)
	if name == ADDON then InitDB() end
end)

ns.On("PLAYER_LOGIN", function()
	if not run then InitDB() end
	local okN, name = pcall(UnitName, "player")
	local okR, realm = pcall(GetRealmName)
	run.char = tostring(okN and name or "?") .. "-" .. tostring(okR and realm or "?")
	run.unknownEvents = ns.unknownEvents
	for _, fn in ipairs(ns.loginHooks) do ns.Try("login", fn) end
	ns.Print("loaded. THROWAWAY test kit. Type |cffffff00/sbs|r to open the guide.")
end)

---------------------------------------------------------------------------
-- Taint / blocked-action capture
---------------------------------------------------------------------------
ns.blockedListeners = {}
local function OnBlocked(event, addon, func)
	if not run then return end
	local rec = {
		t = GetTime(), event = event, addon = ns.Safe(addon), func = ns.Safe(func),
		mine = (addon == ADDON), op = ns.currentOp, lastOp = ns.lastOp,
		lastOpAgo = ns.lastOpAt and (GetTime() - ns.lastOpAt) or nil,
		combat = ns.InCombat(), focus = ns.FocusLabel(),
	}
	if #run.blocked < MAX_BLOCKED then table.insert(run.blocked, rec) end
	if rec.mine then
		run.counters.blockedMine = (run.counters.blockedMine or 0) + 1
		ns.Print("|cffff4444BLOCKED|r " .. tostring(rec.func) .. " (last action: " .. tostring(ns.lastOp) .. ") - recorded, this is a test result")
	else
		run.counters.blockedOther = (run.counters.blockedOther or 0) + 1
	end
	for _, cb in ipairs(ns.blockedListeners) do pcall(cb, rec) end
end
ns.On("ADDON_ACTION_BLOCKED", OnBlocked)
ns.On("ADDON_ACTION_FORBIDDEN", OnBlocked)

function ns.BlockedMineSince(t)
	if not run then return 0 end
	local n = 0
	for _, b in ipairs(run.blocked) do
		if b.mine and b.t >= t then n = n + 1 end
	end
	return n
end

---------------------------------------------------------------------------
-- Mouse focus + item-use attempt tracking (shared by spikes A, S, B)
---------------------------------------------------------------------------
function ns.FocusFrame()
	if not GetMouseFoci then return nil end
	local ok, foci = pcall(GetMouseFoci)
	if ok and type(foci) == "table" then return foci[1] end
	return nil
end

function ns.FocusLabel()
	local f = ns.FocusFrame()
	if not f then return nil end
	local ok, lbl = pcall(function()
		return f.sbsLabel or (f.GetName and f:GetName()) or "<unnamed>"
	end)
	if ok and not isSecret(lbl) then return lbl end
	return "?"
end

-- variant of an item button under the mouse: pool / attr / blizzard / nil
local function FocusVariant()
	local f = ns.FocusFrame()
	if not f then return nil end
	local ok, kind, _, _, name = pcall(function()
		return f.sbsKind, f.sbsBag, f.sbsSlot, f.GetName and f:GetName()
	end)
	if not ok then return nil end
	if kind then return kind, f end
	if type(name) == "string" and not isSecret(name) and (name:find("^ContainerFrame") ) then
		return "blizzard", f
	end
	return nil
end

local function ItemOfFrame(f)
	local ok, bag, slot = pcall(function()
		local b = f.GetBagID and f:GetBagID()
		return b, f:GetID()
	end)
	if not ok or not bag then return nil end
	local okI, itemID = pcall(C_Container.GetContainerItemID, bag, slot)
	if okI and not isSecret(itemID) then return itemID, bag, slot end
	return nil
end

-- Context flags that other spikes set so we can see "use after X" effects.
ns.context = {}

local function RecordUse(evt, extra)
	if not run then return end
	local variant, f = FocusVariant()
	if not variant then return end
	local itemID, bag, slot = ItemOfFrame(f)
	local rec = {
		t = GetTime(), evt = evt, variant = variant, combat = ns.InCombat(),
		itemID = itemID, bag = bag, slot = slot, lastOp = ns.lastOp,
		ctx = ns.Safe(ns.context),
	}
	if extra then for k, v in pairs(extra) do rec[k] = ns.Safe(v) end end
	if #run.uses < MAX_USES then table.insert(run.uses, rec) end
	if ns.useListeners then for _, cb in ipairs(ns.useListeners) do pcall(cb, rec) end end
end
ns.useListeners = {}

ns.On("UNIT_SPELLCAST_SENT", function(_, unit, _, _, spellID)
	-- Only count it when the spell is the item's own Use spell (filters out keybind casts).
	local variant, f = FocusVariant()
	if not variant then return end
	local itemID = ItemOfFrame(f)
	local itemSpellID
	if itemID and C_Item and C_Item.GetItemSpell then
		local ok, _, sid = pcall(C_Item.GetItemSpell, itemID)
		if ok then itemSpellID = sid end
	end
	local match = (itemSpellID ~= nil and not isSecret(spellID) and spellID == itemSpellID)
	if match then RecordUse("SPELLCAST_SENT", { spellID = spellID, strong = true }) end
end, "player")

ns.On("UI_ERROR_MESSAGE", function(_, errType, msg)
	RecordUse("UI_ERROR_MESSAGE", { errType = errType, msg = msg, strong = false })
end)

table.insert(ns.blockedListeners, function(rec)
	if rec.mine then
		RecordUse("ADDON_ACTION_BLOCKED", { func = rec.func, blocked = true, addon = rec.addon })
	end
end)

-- Summarise uses for (variant, combat, optional filter).
-- Returns strongAttempts (item's own spell was sent), blocked, weak (UI error only).
function ns.UseStats(variant, combat, filter)
	local attempted, blocked, weak = 0, 0, 0
	if not run then return 0, 0, 0 end
	for _, u in ipairs(run.uses) do
		if u.variant == variant and (combat == nil or u.combat == combat) and (not filter or filter(u)) then
			if u.blocked then blocked = blocked + 1
			elseif u.strong then attempted = attempted + 1
			else weak = weak + 1 end
		end
	end
	return attempted, blocked, weak
end

---------------------------------------------------------------------------
-- Combat start/stop fan-out
---------------------------------------------------------------------------
ns.combatStart, ns.combatEnd = {}, {}
ns.On("PLAYER_REGEN_DISABLED", function()
	ns.Log("combat", { state = "start" })
	for _, fn in ipairs(ns.combatStart) do ns.Try("combatStart", fn) end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
	ns.Log("combat", { state = "end" })
	for _, fn in ipairs(ns.combatEnd) do ns.Try("combatEnd", fn) end
end)

-- run fn now if out of combat, else when combat ends
local oocQueue = {}
function ns.OutOfCombat(label, fn)
	if not ns.InCombat() then return ns.Try(label, fn) end
	table.insert(oocQueue, { label, fn })
end
table.insert(ns.combatEnd, function()
	local q = oocQueue
	oocQueue = {}
	for _, item in ipairs(q) do ns.Try(item[1], item[2]) end
end)

---------------------------------------------------------------------------
-- Bag ID helpers
---------------------------------------------------------------------------
local BI = Enum and Enum.BagIndex or {}
ns.BAGS = { BI.Backpack or 0, BI.Bag_1 or 1, BI.Bag_2 or 2, BI.Bag_3 or 3, BI.Bag_4 or 4, BI.ReagentBag or 5 }
ns.CHAR_TABS_ALL = {}
for i = 1, 6 do ns.CHAR_TABS_ALL[i] = BI["CharacterBankTab_" .. i] or (5 + i) end
ns.ACCT_TABS_ALL = {}
for i = 1, 5 do ns.ACCT_TABS_ALL[i] = BI["AccountBankTab_" .. i] or (11 + i) end

function ns.PurchasedTabs(kind) -- kind = "Character" | "Account"
	local bt = Enum and Enum.BankType and Enum.BankType[kind]
	if bt and C_Bank and C_Bank.FetchPurchasedBankTabIDs then
		local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, bt)
		if ok and type(ids) == "table" then return ids end
	end
	return kind == "Character" and ns.CHAR_TABS_ALL or ns.ACCT_TABS_ALL
end

function ns.BagKind(bag)
	if bag >= 0 and bag <= 5 then return "Bags" end
	if bag >= 6 and bag <= 11 then return "Character" end
	if bag >= 12 and bag <= 16 then return "Account" end
	return "Other"
end

function ns.BankTypeName(bt)
	if bt == nil then return "nil" end
	if isSecret(bt) then return "<secret>" end
	if Enum and Enum.BankType then
		for k, v in pairs(Enum.BankType) do if v == bt then return k end end
	end
	return tostring(bt)
end

---------------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------------
function ns.MakeWindow(name, title, w, h)
	local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	f:SetSize(w, h)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	f:SetBackdropColor(0.05, 0.05, 0.08, 0.94)
	f:SetBackdropBorderColor(0.3, 0.8, 0.6, 1)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetPoint("TOPLEFT", 8, -7)
	f.title:SetText(title)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	f.closeButton = close
	f:Hide()
	return f
end

function ns.MakeButton(parent, text, w, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w or 120, 22)
	b:SetText(text)
	b:SetScript("OnClick", function(self, ...)
		local label = self:GetText() or text or "?"
		ns.Mark("click:" .. label)
		ns.Try("button:" .. label, onClick, self, ...)
	end)
	return b
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
ns.commands, ns.commandOrder = {}, {}
function ns.Command(name, help, fn)
	name = name:lower()
	if not ns.commands[name] then table.insert(ns.commandOrder, name) end
	ns.commands[name] = { help = help, fn = fn }
end

SLASH_SWAGBAGSPIKES1 = "/sbs"
SLASH_SWAGBAGSPIKES2 = "/swagbagspikes"
SlashCmdList.SWAGBAGSPIKES = function(msg)
	msg = msg or ""
	local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	if cmd == "" then cmd = "guide" end
	local c = ns.commands[cmd]
	if not c then
		ns.Print("Unknown command '" .. cmd .. "'. Type /sbs help")
		return
	end
	ns.Mark("slash:" .. cmd)
	ns.Try("slash:" .. cmd, c.fn, rest)
end

ns.Command("help", "list commands", function()
	for _, name in ipairs(ns.commandOrder) do
		ns.Print("/sbs " .. name .. " - " .. ns.commands[name].help)
	end
end)

ns.Command("status", "print a one-line result per spike", function()
	if not run then return end
	for _, id in ipairs(ns.spikeOrder) do
		local s = run.spikes[id]
		local st = s and s.status or "NOT RUN"
		local col = (st == "PASS" and "|cff44ff44") or (st == "FAIL" and "|cffff4444") or (st == "MIXED" and "|cffffaa00") or "|cffaaaaaa"
		ns.Print(("%s %s%s|r - %s"):format(id, col, st, ns.spikeInfo[id].title or ""))
	end
	ns.Print(("errors: %d (mine %d), blocked actions by this addon: %d"):format(
		run.counters.errors or 0, run.counters.errorsMine or 0, run.counters.blockedMine or 0))
	ns.Print("Results are saved when you /reload or log out.")
end)

ns.Command("reset", "delete ALL saved spike results (asks no questions)", function()
	SwagBagSpikesDB = nil
	InitDB()
	ns.Print("results cleared; a fresh run started.")
end)
