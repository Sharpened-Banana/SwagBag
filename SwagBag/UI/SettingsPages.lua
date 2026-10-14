-- SwagBag settings pages: Bags, Bank & guild bank, Overlays (spec F15, AC15.2). Every row shows
-- the opinionated default first and its alternative next to it (P1). A choice that has a chat
-- command runs that command (SB.Slash.Run), so the window and the command can never disagree;
-- the rest set their setting here. Every choice answers in the status line (P2), and refuses
-- with L.SETTINGS_READONLY while the settings are read-only (a newer schema).
local _, SB = ...

local L = SB.L
local SW = SB.SettingsWindow

-- Run a chat command and hand back its feedback.
local function run(line)
	local ok, feedback = SB.Slash.Run(line)
	if not ok then
		if not SB.Slash.commands[(line:match("^%s*(%S*)") or ""):lower()] then
			return feedback -- an unknown command: nothing was recorded, so say what it was
		end
		return L.SETTINGS_FAILED -- recorded under the command's own label; the status line says so (W4-7)
	end
	return feedback
end
SB.SettingsWindow.RunCommand = run

local function get(path)
	return function()
		return SB.Config.Get(path)
	end
end

local function onOff(label, path, command)
	return { kind = "choice", label = label, get = get(path),
		choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
		apply = function(v)
			return run(command .. (v and " on" or " off"))
		end }
end

-- A row whose default is Off lists Off first (P1: the default is the first choice).
local function offOn(label, path, command)
	local row = onOff(label, path, command)
	row.choices = { { value = false, text = L.SET_OFF }, { value = true, text = L.SET_ON } }
	return row
end

-- Bags --------------------------------------------------------------------
local function bagsRows()
	local W = SB.BagsWindow
	return {
		{ kind = "choice", label = L.SET_VIEW, get = function()
			return W.View()
		end, choices = { { value = "sections", text = L.VIEW_TO_SECTIONS }, { value = "list", text = L.VIEW_TO_LIST },
			{ value = "grid", text = L.VIEW_TO_GRID } },
		apply = function(v)
			if SB.Config.readOnly then
				return L.SETTINGS_READONLY
			end
			W.SetView(v, true)
			return (v == "grid" and L.VIEW_GRID) or (v == "list" and L.VIEW_LIST) or L.VIEW_SECTIONS
		end },
		{ kind = "choice", label = L.SET_COLUMNS, get = get("bags.columns"), width = 56,
			choices = { { value = 12, text = tostring(12) }, { value = 10, text = tostring(10) },
				{ value = 14, text = tostring(14) }, { value = 16, text = tostring(16) } },
			apply = function(v)
				if not SB.Config.Set("bags.columns", v) then
					return L.SETTINGS_READONLY
				end
				W.RequestLayout("columns")
				return L.SET_COLUMNS_DONE:format(v)
			end },
		{ kind = "choice", label = L.SET_SCALE, get = get("bags.scale"), width = 56,
			choices = { { value = 1.0, text = L.SET_PERCENT:format(100) }, { value = 0.8, text = L.SET_PERCENT:format(80) },
				{ value = 0.9, text = L.SET_PERCENT:format(90) }, { value = 1.1, text = L.SET_PERCENT:format(110) },
				{ value = 1.25, text = L.SET_PERCENT:format(125) } },
			apply = function(v)
				if SB.Config.readOnly then
					return L.SETTINGS_READONLY
				end
				W.SetScale(v, true)
				return L.BAGS_SCALE:format(math.floor(v * 100 + 0.5))
			end },
		{ kind = "choice", label = L.SET_FREE, get = get("bags.freeTile"),
			choices = { { value = true, text = L.SET_FREE_TILE }, { value = false, text = L.SET_FREE_ALL } },
			apply = function(v)
				return run(v and "free tile" or "free all")
			end },
		{ kind = "choice", label = L.SET_STACKS, get = get("bags.stacks"),
			choices = { { value = "one", text = L.SET_STACKS_ONE }, { value = "all", text = L.SET_STACKS_ALL } },
			apply = function(v)
				return run("stacks " .. v)
			end },
		{ kind = "choice", label = L.SET_NEW, get = get("bags.newAlways"),
			choices = { { value = false, text = L.SET_NEW_AUTO }, { value = true, text = L.SET_NEW_ALWAYS } },
			apply = function(v)
				return run(v and "new always" or "new auto")
			end },
		{ kind = "choice", label = L.SET_REAGENTS, get = get("bags.reagentSeparate"),
			choices = { { value = false, text = L.SET_REAGENTS_MIXED }, { value = true, text = L.SET_REAGENTS_OWN } },
			apply = function(v)
				if not SB.Config.Set("bags.reagentSeparate", v) then
					return L.SETTINGS_READONLY
				end
				SB.Categories.Load()
				W.RequestLayout("reagents")
				return v and L.SET_REAGENTS_OWN_DONE or L.SET_REAGENTS_MIXED_DONE
			end },
		onOff(L.SET_TITLE_ILVL, "bags.showIlvl", "overlays title"),
		-- Week 9 (user pick 8): what Sort does; every click runs /swagbag sort.
		{ kind = "choice", label = L.SET_SORT, tip = L.SET_SORT_TIP, width = 150, get = get("sort.mode"),
			choices = { { value = "blizzard", text = L.SET_SORT_BLIZZARD }, { value = "stacks", text = L.SET_SORT_STACKS } },
			apply = function(v)
				return run("sort " .. v)
			end },
		-- Week 9 (user pick 11b): the login line about another bag addon; every click runs /swagbag otherbags.
		{ kind = "choice", label = L.SET_OTHER_BAGS, tip = L.SET_OTHER_BAGS_TIP, width = 110, get = get("bags.warnOtherAddons"),
			choices = { { value = true, text = L.SET_OTHER_BAGS_WARN }, { value = false, text = L.SET_OTHER_BAGS_QUIET } },
			apply = function(v)
				return run(v and "otherbags on" or "otherbags off")
			end },
		{ kind = "choice", label = L.SET_LIST_SORT, get = function()
			return SB.Sort.Spec().by
		end, width = 90, choices = { { value = "value", text = L.LIST_COL_VALUE }, { value = "name", text = L.LIST_COL_NAME },
			{ value = "count", text = L.LIST_COL_COUNT }, { value = "ilvl", text = L.LIST_COL_ILVL } },
		apply = function(v)
			return run("list " .. v)
		end },
		{ kind = "choice", label = L.SET_LIST_ORDER, get = function()
			return SB.Sort.Spec().desc
		end, width = 150, choices = { { value = true, text = L.SET_LIST_DESC }, { value = false, text = L.SET_LIST_ASC } },
		apply = function(v)
			return run("list " .. SB.Sort.Spec().by .. (v and " desc" or " asc"))
		end },
	}
end

-- Bank and guild bank -----------------------------------------------------
-- TSM's price strings, from the one list SwagBag offers (Adapter.TSM_PRICES).
local function tsmChoices()
	local list = {}
	for _, name in ipairs(SB.Adapter.TSM_PRICES) do
		list[#list + 1] = { value = name, text = name }
	end
	return list
end

-- The gold glow's amounts; one typed with /swagbag worth (say 250) gets its own button, selected (week 7 deferred).
-- Built again each time the page is drawn (SW.Render calls rows()), so it shows the stored amount; only while
-- the glow is in that fixed mode (final review item 5: never an unselected stray next to "top" or "Off").
local function worthChoices()
	local list = {}
	for _, gold in ipairs({ 100, 500, 1000 }) do
		list[#list + 1] = { value = gold, text = L.SET_WORTH_GOLD:format(gold) }
	end
	local own = SB.Config.Get("prices.worthGold")
	if SB.Config.Get("prices.worth") == "fixed" and own ~= 100 and own ~= 500 and own ~= 1000 then
		list[#list + 1] = { value = own, text = L.SET_WORTH_GOLD:format(own) }
	end
	list[#list + 1] = { value = "top", text = L.SET_WORTH_TOP:format(SB.Config.Get("prices.worthTop")) }
	list[#list + 1] = { value = "off", text = L.SET_OFF }
	return list
end

local function bankRows()
	return {
		{ kind = "choice", label = L.SET_BANK_FRAME, get = get("bank.blizzardFrame"),
			choices = { { value = "tiny", text = L.SET_BANK_TINY }, { value = "beside", text = L.SET_BANK_BESIDE } },
			apply = function(v)
				return run("bank " .. v)
			end },
		{ kind = "choice", label = L.SET_BANK_SHOW, get = get("bank.show"),
			choices = { { value = "one", text = L.SET_BANK_SHOW_ONE }, { value = "both", text = L.SET_BANK_SHOW_BOTH } },
			apply = function(v)
				return run("bank " .. v)
			end },
		onOff(L.SET_BANK_COLORS, "bank.groupColors", "bank colors"),
		{ kind = "choice", label = L.SET_BANK_GOLD, get = get("bank.gold"),
			choices = { { value = true, text = L.SET_SHOW }, { value = false, text = L.SET_HIDE } },
			apply = function(v)
				return run("bank gold " .. (v and "on" or "off"))
			end },
		{ kind = "choice", label = L.SET_GUILD_MODE, get = get("guildBank.mode"),
			choices = { { value = "full", text = L.SET_GUILD_FULL }, { value = "view", text = L.SET_GUILD_VIEW } },
			apply = function(v)
				return run("guild " .. v)
			end },
		{ kind = "choice", label = L.SET_GUILD_ANYTAB, get = get("guildBank.withdrawAnyTab"),
			choices = { { value = false, text = L.SET_GUILD_SELECTED }, { value = true, text = L.SET_GUILD_ANY } },
			apply = function(v)
				return run("guild anytab " .. (v and "on" or "off"))
			end },
		{ kind = "choice", label = L.SET_TOTALS, get = get("prices.headerTotals"),
			choices = { { value = true, text = L.SET_SHOW }, { value = false, text = L.SET_HIDE } },
			apply = function(v)
				if not SB.Config.Set("prices.headerTotals", v) then
					return L.SETTINGS_READONLY
				end
				SB.Emit("SB_PRICES_CHANGED") -- open windows re-read their header texts in place
				return v and L.SET_TOTALS_ON or L.SET_TOTALS_OFF
			end },
		-- Week 7 (user pick 7): the gold glow at the bank; every click runs /swagbag worth.
		{ kind = "choice", label = L.SET_WORTH, tip = L.SET_WORTH_TIP, width = 90, get = function()
			local mode = SB.Config.Get("prices.worth")
			if mode == "fixed" then
				return SB.Config.Get("prices.worthGold")
			end
			return mode
		end, choices = worthChoices(),
		apply = function(v)
			if v == "top" then
				return run("worth top " .. SB.Config.Get("prices.worthTop"))
			end
			return run("worth " .. v)
		end },
		-- Week 9 (user pick 10): who prices items, and TSM's price; every click runs /swagbag price.
		{ kind = "choice", label = L.SET_PRICE_SOURCE, tip = L.SET_PRICE_SOURCE_TIP, width = 90, get = get("prices.source"),
			choices = { { value = "auto", text = L.SET_PRICE_AUTO }, { value = "auctionator", text = "Auctionator" },
				{ value = "tsm", text = "TSM" }, { value = "vendor", text = L.SET_PRICE_VENDOR } },
			apply = function(v)
				return run("price " .. v)
			end },
		-- TSM's price only (/swagbag price string): it never switches where prices come from (preflight S7).
		{ kind = "choice", label = L.SET_PRICE_TSM, tip = L.SET_PRICE_TSM_TIP, width = 130, get = function()
			return SB.Prices.TSMString()
		end, choices = tsmChoices(),
		apply = function(v)
			return run("price string " .. v)
		end },
		{ kind = "note", label = L.SET_BANK_NOTE },
	}
end

-- Overlays ----------------------------------------------------------------
local OVERLAYS = {
	{ "ilvl", "overlays.ilvl", L.SET_OV_ILVL }, { "track", "overlays.track", L.SET_OV_TRACK },
	{ "upgrade", "overlays.upgrade", L.SET_OV_UPGRADE }, { "keystone", "overlays.keystone", L.SET_OV_KEYSTONE },
	{ "junk", "overlays.junk", L.SET_OV_JUNK }, { "bind", "overlays.bind", L.SET_OV_BIND },
	{ "learn", "overlays.learn", L.SET_OV_LEARN }, { "lock", "overlays.lock", L.SET_OV_LOCK },
	{ "uncollected", "overlays.uncollected", L.SET_OV_UNCOLLECTED },
}

local function overlayRows()
	local rows = {}
	for _, o in ipairs(OVERLAYS) do
		rows[#rows + 1] = (SB.Config.Defaults.settings.overlays[o[1]] == false and offOn or onOff)(o[3], o[2],
			"overlays " .. o[1])
	end
	rows[#rows + 1] = { kind = "choice", label = L.SET_OV_PAWN, get = get("overlays.usePawn"),
		choices = { { value = false, text = L.SET_PAWN_ILVL }, { value = true, text = L.SET_PAWN_PAWN } },
		apply = function(v)
			return run("overlays pawn " .. (v and "on" or "off"))
		end }
	return rows
end

SW.AddPage({ id = "bags", title = L.SET_PAGE_BAGS, rows = bagsRows })
SW.AddPage({ id = "bank", title = L.SET_PAGE_BANK, rows = bankRows })
SW.AddPage({ id = "overlays", title = L.SET_PAGE_OVERLAYS, rows = overlayRows })
