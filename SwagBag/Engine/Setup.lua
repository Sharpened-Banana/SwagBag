-- SwagBag setup (spec F7: AC7.1, AC7.2; AC9.2; week 12): what the setup wizard picks, kept as a draft in memory, and
-- what Finish writes. No frames: UI/QuickSetup.lua draws the four steps and calls these.
--   Setup.STYLES                              the five playstyles, in the wizard's order
--   Setup.Preset(picked, get) -> { { path, value } }   what each picked style sets (AC9.2: its overlays too); get
--                                             (optional, Config.Get) lets Gold switch the gold glow on only when it is off
--   Setup.Order(display, promote) -> order | nil       the category order with the promoted styles' categories
--                                             moved up, right after Keystone & Crests (spec 7.6)
--   Setup.New() -> draft                      pre-filled: the styles picked last time (setup.styles), every value as set now
--   Setup.Toggle(d, style)                    pick or unpick a style
--   Setup.Value(d, key) -> value              what the wizard shows: the user's own choice in this run, else what a
--                                             picked style sets, else the setting now ("order.gold" and
--                                             "order.collector": the picked style's categories move up)
--   Setup.Set(d, key, value)                  a choice on steps 2 to 4
--   Setup.Switches(d) -> { key }              step 2's on/off lines: "Switch by themselves" (focus.auto, off unless the
--                                             user switches it on here; no style sets it), the six focus modes, what the picked styles set,
--                                             then the categories they move up
--   Setup.Label(key) -> text                  a switch's name in plain words
--   Setup.Plan(d) -> { { path, value } }      what Finish writes, by path: every setting a picked style sets (an
--                                             explicit value, AC9.2) and every other one this run changed; nothing else
--                                             (Config keeps only the values somebody chose)
--   Setup.Finish(d) -> feedback               writes the plan, the category order, setup.styles and setup.done, then the
--                                             windows follow; refuses while read-only, writing nothing
--   Setup.Skip() -> feedback                  only setup.done (AC7.2: the defaults, or the settings as they are)
-- Nothing is written before Finish: Back and Next are free, and closing the wizard keeps everything as it was.
local _, SB = ...

local L = SB.L
local Setup = {}
SB.Setup = Setup

Setup.STYLES = {
	{ id = "mplus", name = "QS_MPLUS" }, { id = "raid", name = "QS_RAID" }, { id = "gold", name = "QS_GOLD" },
	{ id = "casual", name = "QS_CASUAL" }, { id = "collector", name = "QS_COLLECTOR" },
}
local STYLE = {}
for _, s in ipairs(Setup.STYLES) do
	STYLE[s.id] = s
end

-- Categories a style moves up, right after Keystone & Crests (spec 7.6: "Gold promotes Trade Goods and BoE gear").
local PROMOTE = { gold = { "c_tradegoods", "c_boe" }, collector = { "c_collect" } }
local ORDER_KEYS = { { key = "order.gold", style = "gold" }, { key = "order.collector", style = "collector" } }

-- Pure: the settings each style sets. Every style only switches things on, except Casual on its own, which switches
-- the consumables warning and the upgrade track off. Week 12 (AC9.2): M+ and Raid make the gear marks explicit,
-- Gold the junk coin (and the gold glow when it is off), Collector the collection marks.
function Setup.Preset(picked, get)
	local out = {}
	local function set(path, value)
		out[#out + 1] = { path, value }
	end
	if picked.mplus then
		set("focus.on.mplus", true)
		set("consumables.warn", true)
		set("overlays.keystone", true)
		set("overlays.track", true)
		set("overlays.upgrade", true)
		set("overlays.ilvl", true)
	end
	if picked.raid then
		set("focus.on.raid", true)
		set("consumables.warn", true)
		set("overlays.upgrade", true)
		set("overlays.ilvl", true)
		set("overlays.track", true)
	end
	if picked.gold then
		set("prices.headerTotals", true)
		set("overlays.junk", true)
		if get and get("prices.worth") == "off" then
			set("prices.worth", "fixed") -- a glow the user set (an amount, or the top %) stays as it is
		end
	end
	if picked.casual and not picked.mplus and not picked.raid then
		set("consumables.warn", false)
		set("overlays.track", false)
	end
	if picked.collector then
		set("overlays.uncollected", true)
		set("overlays.learn", true)
	end
	return out
end

-- Pure: the display order with the promoted styles' categories moved up, or nil when none moves. Only ids in the
-- display list move; one that Keystone & Crests could not be put after (it is not listed) goes at the end, never lost.
function Setup.Order(display, promote)
	local listed, up, moved, out = {}, {}, {}, {}
	for _, id in ipairs(display) do
		listed[id] = true
	end
	for _, s in ipairs(Setup.STYLES) do
		for _, id in ipairs(promote[s.id] and PROMOTE[s.id] or {}) do
			if listed[id] and not moved[id] then
				up[#up + 1] = id
				moved[id] = true
			end
		end
	end
	if #up == 0 then
		return nil
	end
	local placed = false
	for _, id in ipairs(display) do
		if not moved[id] then
			out[#out + 1] = id
			if id == "c_keystone" then
				for _, u in ipairs(up) do
					out[#out + 1] = u
				end
				placed = true
			end
		end
	end
	if not placed then
		for _, u in ipairs(up) do
			out[#out + 1] = u
		end
	end
	return out
end

local function get(path)
	return SB.Config.Get(path)
end

function Setup.New()
	local d = { styles = {}, touched = {} }
	local saved = get("setup.styles")
	if type(saved) == "string" then
		for id in saved:gmatch("[^,]+") do
			if STYLE[id] then
				d.styles[id] = true
			end
		end
	end
	return d
end

function Setup.Toggle(d, style)
	if STYLE[style] then
		d.styles[style] = not d.styles[style] or nil
	end
end

local function presetMap(d)
	local map = {}
	for _, p in ipairs(Setup.Preset(d.styles, get)) do
		map[p[1]] = p[2]
	end
	return map
end

function Setup.Value(d, key)
	if d.touched[key] ~= nil then
		return d.touched[key]
	end
	for _, o in ipairs(ORDER_KEYS) do
		if o.key == key then
			return d.styles[o.style] == true
		end
	end
	local preset = presetMap(d)[key]
	if preset ~= nil then
		return preset
	end
	return get(key)
end

function Setup.Set(d, key, value)
	d.touched[key] = value
end

function Setup.Switches(d)
	local out, seen = {}, {}
	local function add(key)
		if not seen[key] then
			seen[key] = true
			out[#out + 1] = key
		end
	end
	add("focus.auto") -- the master switch comes first: off unless the user switches it on here (0.14.3)
	for _, m in ipairs(SB.Focus and SB.Focus.MODES or {}) do
		if not m.custom and not m.id:match("^m_") then -- the user's own modes are managed in Settings
			add("focus.on." .. m.id)
		end
	end
	for _, p in ipairs(Setup.Preset(d.styles, get)) do
		if type(p[2]) == "boolean" then
			add(p[1])
		end
	end
	for _, o in ipairs(ORDER_KEYS) do
		if d.styles[o.style] then
			add(o.key)
		end
	end
	return out
end

local LABELS = {
	["consumables.warn"] = "WIZ_SW_WARN", ["overlays.keystone"] = "WIZ_SW_KEYSTONE", ["overlays.track"] = "WIZ_SW_TRACK",
	["overlays.upgrade"] = "WIZ_SW_UPGRADE", ["overlays.ilvl"] = "WIZ_SW_ILVL", ["prices.headerTotals"] = "WIZ_SW_TOTALS",
	["overlays.junk"] = "WIZ_SW_JUNK", ["overlays.uncollected"] = "WIZ_SW_UNCOLLECTED", ["overlays.learn"] = "WIZ_SW_LEARN",
	["focus.auto"] = "WIZ_SW_AUTO", ["order.gold"] = "WIZ_SW_ORDER_GOLD", ["order.collector"] = "WIZ_SW_ORDER_COLLECTOR",
}

function Setup.Label(key)
	local mode = key:match("^focus%.on%.(.+)$")
	local m = mode and SB.Focus and SB.Focus.byId[mode]
	if m then
		return L.WIZ_SW_MODE:format(L[m.name])
	end
	return LABELS[key] and L[LABELS[key]] or key
end

function Setup.Plan(d)
	local preset, keys, seen = presetMap(d), {}, {}
	local function add(key)
		if not seen[key] and not key:match("^order%.") then
			seen[key] = true
			keys[#keys + 1] = key
		end
	end
	for key in pairs(preset) do
		add(key)
	end
	for key in pairs(d.touched) do
		add(key)
	end
	table.sort(keys)
	-- The amount only means something while the glow is "fixed": picked and then switched Off or to the top %, it is
	-- not written.
	local fixed = Setup.Value(d, "prices.worth") == "fixed"
	local out = {}
	for _, key in ipairs(keys) do
		local v = Setup.Value(d, key)
		if (preset[key] ~= nil or v ~= get(key)) and (key ~= "prices.worthGold" or fixed) then
			out[#out + 1] = { key, v }
		end
	end
	return out
end

local function names(picked)
	local out = {}
	for _, s in ipairs(Setup.STYLES) do
		if picked[s.id] then
			out[#out + 1] = L[s.name]
		end
	end
	return out
end

local function styleList(picked)
	local ids = {}
	for _, s in ipairs(Setup.STYLES) do
		if picked[s.id] then
			ids[#ids + 1] = s.id
		end
	end
	return table.concat(ids, ",")
end

-- The open windows follow at once (SB.FollowSettings, Core/Init.lua; ruling R12), the look and the bags' size too.
local function follow(look, scale)
	if look and SB.Theme and SB.Theme.Apply then
		SB.Theme.Apply(look, false)
	end
	SB.FollowSettings("setup")
	local W = SB.BagsWindow
	if scale and W and W.SetScale and W.IsOpen and W.IsOpen() then
		W.SetScale(scale, true)
	end
end

function Setup.Finish(d)
	local C = SB.Config
	if C.readOnly then
		return L.SETTINGS_READONLY
	end
	local look, scale
	for _, p in ipairs(Setup.Plan(d)) do
		C.Set(p[1], p[2])
		if p[1] == "theme.name" then
			look = p[2]
		elseif p[1] == "bags.scale" then
			scale = p[2]
		end
	end
	local promote = {}
	for _, o in ipairs(ORDER_KEYS) do
		promote[o.style] = d.styles[o.style] == true and Setup.Value(d, o.key) == true
	end
	local display = {}
	for _, c in ipairs(SB.Categories.display) do
		display[#display + 1] = c.id
	end
	local order = Setup.Order(display, promote)
	if order then
		C.db.categoryOrder = order
		if SB.Profiles and SB.Profiles.CategoriesChanged then
			SB.Profiles.CategoriesChanged() -- a profile Undo never puts an older order back over this one
		end
	end
	local styles = styleList(d.styles)
	if get("setup.styles") ~= styles then
		C.Set("setup.styles", styles)
	end
	C.Set("setup.done", true)
	-- The settings are saved; a refresh error must not turn that into "failed".
	local refreshed = SB.ErrorTrap.Run("setup.refresh", "none", follow, look, scale)
	local list = names(d.styles)
	local line = #list > 0 and L.QS_APPLIED:format(table.concat(list, ", ")) or L.WIZ_DONE_NONE
	if not refreshed then
		line = line .. " " .. L.QS_REFRESH_NOTE
	end
	return line
end

-- First run: "keeps its defaults". A re-run: "keeps your current settings", since the defaults are no longer what is set.
function Setup.Skip()
	local rerun = get("setup.done") == true
	if not SB.Config.Set("setup.done", true) then
		return L.SETTINGS_READONLY
	end
	return rerun and L.QS_SKIPPED_KEPT or L.QS_SKIPPED
end
