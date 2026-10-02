-- SwagBag tooltip counts (spec AC13.3, F13): how many of an item the account has, and where, under
-- item tooltips ("SwagBag: 27 in all", then a line per character -- "Bags 5, Bank 20" -- the
-- warband bank and guild banks). Counts come from Engine/AltData.lua (Syndicator when it answers,
-- else SwagBag's own snapshots, with this character's bags live). Nothing is added when the only
-- place is this character's bags (the tooltip's own item says that already, D16).
-- Setting tooltip.counts: "auto" (default: shown unless Syndicator is loaded, which writes the same
-- lines itself; one set, not two, D17), "on", "off". /swagbag tooltip and Settings > Alt data.
-- The hook is a client call into SwagBag: taint-free (Adapter.HookItemTooltip, main and link
-- tooltips only, F20) and under ErrorTrap "none" (a tooltip glitch is recorded for /swagbag report
-- and never takes the bags away).
-- A tooltip refreshes about 5 times a second while it is hovered, so the lines are memoized by item
-- ID (F21) and dropped when anything they depend on changes: the bags (BAG_UPDATE_DELAYED and
-- Inventory's flush), a saved snapshot, Syndicator's data, a setting.
--   TooltipCounts.Lines(counts) -> { { left, right } }   pure
--   TooltipCounts.Add(tooltip, itemID)
local _, SB = ...

local L = SB.L
local TC = { MAX_CHARS = 8, MODES = { auto = true, on = true, off = true } }
SB.TooltipCounts = TC

function TC.Mode()
	local m = SB.Config.Get("tooltip.counts")
	return TC.MODES[m] and m or "auto"
end

function TC.Showing()
	local m = TC.Mode()
	if m == "off" then
		return false
	end
	return not (m == "auto" and SB.Adapter.AddOnState("Syndicator"))
end

local PARTS = { { "bags", L.TIP_BAGS }, { "bank", L.TIP_BANK }, { "mail", L.TIP_MAIL }, { "equipped", L.TIP_EQUIPPED },
	{ "auctions", L.TIP_AUCTIONS }, { "void", L.TIP_VOID } }

local function charTotal(c)
	local n = 0
	for _, p in ipairs(PARTS) do
		n = n + (c[p[1]] or 0)
	end
	return n
end

local function charLine(c)
	local parts = {}
	for _, p in ipairs(PARTS) do
		local v = c[p[1]] or 0
		if v > 0 then
			parts[#parts + 1] = p[2]:format(v)
		end
	end
	local name = c.current and L.TIP_THIS_CHAR:format(c.name) or c.name
	local colour = SB.Adapter.ClassColour(c.class)
	if colour then
		name = colour .. name .. "|r"
	end
	return { name, table.concat(parts, ", ") }
end

function TC.Lines(counts)
	if type(counts) ~= "table" then
		return {}
	end
	local total, elsewhere = 0, false
	for _, c in ipairs(counts.chars or {}) do
		local n = charTotal(c)
		total = total + n
		if n > (c.current and (c.bags or 0) or 0) then
			elsewhere = true
		end
	end
	local warband = counts.warband or 0
	total = total + warband
	elsewhere = elsewhere or warband > 0
	for _, g in ipairs(counts.guilds or {}) do
		total = total + (g.count or 0)
		elsewhere = true
	end
	if total == 0 or not elsewhere then
		return {}
	end
	local lines = { { L.TIP_TOTAL:format(total) } }
	for i, c in ipairs(counts.chars or {}) do
		if i > TC.MAX_CHARS then
			lines[#lines + 1] = { L.TIP_MORE:format(#counts.chars - TC.MAX_CHARS) }
			break
		end
		lines[#lines + 1] = charLine(c)
	end
	if warband > 0 then
		lines[#lines + 1] = { L.TIP_WARBAND, tostring(warband) }
	end
	for _, g in ipairs(counts.guilds or {}) do
		lines[#lines + 1] = { L.TIP_GUILD:format(g.name), tostring(g.count) }
	end
	return lines
end

-- itemID -> lines (an empty list is a memo too: "nothing to add" is also an answer).
local memo, memoSize = {}, 0
TC.MEMO_MAX = 500

function TC.Forget()
	memo, memoSize = {}, 0
end

function TC.Add(tooltip, itemID)
	if not TC.Showing() then
		return
	end
	local lines = memo[itemID]
	if not lines then
		lines = TC.Lines(SB.AltData.Counts(itemID))
		if memoSize >= TC.MEMO_MAX then
			TC.Forget()
		end
		memo[itemID] = lines
		memoSize = memoSize + 1
	end
	for _, line in ipairs(lines) do
		SB.Adapter.TooltipLine(tooltip, line[1], line[2])
	end
end

SB.On("BAG_UPDATE_DELAYED", TC.Forget, "none")
SB.On("SB_SNAPSHOT_SAVED", TC.Forget, "none")
SB.On("SB_ALTDATA_CHANGED", TC.Forget, "none")
SB.On("SB_CONFIG_CHANGED", TC.Forget, "none")
-- the flush, 50 ms after BAG_UPDATE_DELAYED: this character's live bags. A cooldown-only flush
-- changes no count, so the memo stays.
SB.Inventory.OnChanged(function(mask)
	if mask ~= SB.Inventory.R.COOLDOWN then
		TC.Forget()
	end
end)

-- No hook (the client lacks the tooltip data processor): recorded once under "none" and named in
-- /swagbag report; nothing else is affected.
SB.On("SB_LOGIN", function()
	if not SB.Adapter.HookItemTooltip(SB.ErrorTrap.Guard("tooltip.counts", TC.Add, "none")) then
		TC.hookFailed = true
		SB.ErrorTrap.OnError("tooltip.counts", "none", L.TIP_HOOK_UNAVAILABLE, SB.Adapter.Stack())
	end
end, "none")

local STATE = { auto = L.TIP_STATE_AUTO, on = L.TIP_STATE_ON, off = L.TIP_STATE_OFF }

-- /swagbag tooltip              the state and the choices
-- /swagbag tooltip auto|on|off  set it (saved)
SB.Slash.Register("tooltip", L.HELP_TOOLTIP, function(arg)
	arg = (arg or ""):lower()
	if not TC.MODES[arg] then
		return L.TIP_USAGE:format(STATE[TC.Mode()])
	end
	if not SB.Config.Set("tooltip.counts", arg) then
		return L.SETTINGS_READONLY
	end
	return L.TIP_SET:format(STATE[arg])
end)

-- Settings > Alt data: the tooltip choice (runs /swagbag tooltip, D17) and where the data comes from.
if SB.SettingsWindow then
	local function altsRows()
		local list, source = SB.AltData.Characters()
		local name = (source and source ~= "Own") and tostring(source) or L.ALTS_OWN
		return {
			{ kind = "choice", label = L.SET_TIP, get = TC.Mode, width = 190,
				choices = { { value = "auto", text = L.SET_TIP_AUTO }, { value = "on", text = L.SET_TIP_ON },
					{ value = "off", text = L.SET_TIP_OFF } },
				apply = function(v)
					return SB.SettingsWindow.RunCommand("tooltip " .. v)
				end },
			-- the alt viewer (UI/OfflineWindow.lua): runs /swagbag alts (D17)
			{ kind = "actions", label = L.SET_ALTS_VIEW, actions = { { text = L.SET_ALTS_OPEN, width = 160, run = function()
				return SB.SettingsWindow.RunCommand("alts")
			end } } },
			{ kind = "note", label = L.SET_ALTS_SOURCE:format(name, list and #list or 0, (SB.Snapshots.Count()),
				math.floor(SB.Snapshots.Bytes() / 1024 + 0.5)) },
		}
	end
	SB.SettingsWindow.AddPage({ id = "alts", title = L.SET_PAGE_ALTS, rows = altsRows })
end
