-- SwagBag settings: the Focus modes page (spec 6, AC8.1-8.5, AC15.1). Switching modes on and
-- off, move to the top or collapse the rest (week 6), merge or strict priority, peek or keep open
-- (the collapse style), announce, account-wide or this character
-- only, and each mode's section set with "Reset to default" next to it (spec 6.3). The bags
-- window's Pause button opens this page at the active mode with a right-click (AC8.5).
--   SettingsFocus.Edit(modeId)   open the page with that mode's sections shown
-- The page starts with a plain-words note, and every row with buttons has a tooltip (row.tip, week 6).
-- Every write goes through Config.Set or the Focus writers; Config emits SB_CONFIG_CHANGED and
-- Focus refreshes on it, so an open bag re-stacks at once (guarded as in Task 3). The editor
-- reads and writes the raw section list (W4-2): only the effective view filters Gathering.
local _, SB = ...

local L = SB.L
local SF = { editing = "mplus" }
SB.SettingsFocus = SF

-- Every focus setting: "This character only" makes each one a character override (AC15.1).
function SF.Paths()
	local paths = { "focus.auto", "focus.style", "focus.resolve", "focus.peek", "focus.announce" }
	for _, m in ipairs(SB.Focus.MODES) do
		paths[#paths + 1] = "focus.on." .. m.id
		paths[#paths + 1] = "focus.sections." .. m.id
	end
	return paths
end

-- True when any focus setting is this character's own (the layer being edited).
local function anyOverride()
	for _, path in ipairs(SF.Paths()) do
		if SB.Config.IsCharOverride(path) then
			return true
		end
	end
	return false
end

-- A label that names the layer when it is this character's.
local function layered(text)
	return anyOverride() and L.SET_THIS_CHARACTER:format(text) or text
end

local function modeName(id)
	return L[SB.Focus.byId[id].name]
end

-- The Focus writers return false, "readonly" | "unknown".
local function refusal(why)
	return why == "unknown" and L.SET_FOCUS_UNKNOWN or L.SETTINGS_READONLY
end

local function setting(label, path, choices, done, tip)
	return { kind = "choice", label = label, choices = choices, tip = tip, get = function()
		return SB.Config.Get(path)
	end, apply = function(v)
		if not SB.Config.Set(path, v) then
			return L.SETTINGS_READONLY
		end
		return done(v)
	end }
end

-- The sections the mode being edited opens, with one Open / Collapsed row per category.
-- New is always open, so it has no row; Free has one (W4-4).
local function sectionRows(rows)
	local F, id = SB.Focus, SF.editing
	local open = {}
	for _, sid in ipairs(F.Sections(id, true)) do
		open[sid] = true
	end
	rows[#rows + 1] = { kind = "note", label = layered(L.SET_SECTIONS_OF:format(modeName(id))) }
	for _, sid in ipairs(SB.Categories.SectionOrder()) do
		if sid ~= SB.Categories.NEW then
			local name = SB.Categories.Name(sid)
			rows[#rows + 1] = { kind = "choice", label = name, width = 96, tip = L.SET_SECTION_TIP:format(modeName(id)),
				choices = { { value = true, text = L.SET_SECTION_OPEN }, { value = false, text = L.SET_SECTION_CLOSED } },
				get = function()
					return open[sid] == true
				end,
				apply = function(v)
					local list = {}
					for _, s in ipairs(F.Sections(id, true)) do
						if s ~= sid then
							list[#list + 1] = s
						end
					end
					if v then
						list[#list + 1] = sid
					end
					local ok, why = F.SetSections(id, list)
					if not ok then
						return refusal(why)
					end
					return (v and L.SET_SECTION_NOW_OPEN or L.SET_SECTION_NOW_CLOSED):format(name, modeName(id))
				end }
		end
	end
	rows[#rows + 1] = { kind = "actions", label = L.SET_SECTIONS_DEFAULT_LABEL, tip = L.SET_SECTIONS_DEFAULT_TIP,
		actions = { { text = L.SET_RESET_DEFAULT,
		run = function()
			local ok, why = F.ResetSections(id)
			if not ok then
				return refusal(why)
			end
			return L.SET_SECTIONS_RESET:format(modeName(id))
		end } } }
	if id == "gathering" then
		rows[#rows + 1] = { kind = "note", label = L.SET_GATHERING_NOTE }
	end
end

-- When each mode switches on, for its row's tooltip.
local function whenText(id)
	return ({ mplus = L.SET_MODE_WHEN_MPLUS, raid = L.SET_MODE_WHEN_RAID, delves = L.SET_MODE_WHEN_DELVES,
		gathering = L.SET_MODE_WHEN_GATHERING, fishing = L.SET_MODE_WHEN_FISHING, market = L.SET_MODE_WHEN_MARKET })[id]
		or ""
end

local function rows()
	local F = SB.Focus
	local out = {
		{ kind = "note", label = L.SET_FOCUS_INTRO }, -- week 6: what focus modes are, in plain words (D18)
		setting(L.SET_FOCUS_AUTO, "focus.auto", { { value = true, text = L.SET_FOCUS_AUTO_ON },
			{ value = false, text = L.SET_OFF } }, function(v)
			return v and L.SET_FOCUS_AUTO_DONE or L.SET_FOCUS_OFF_DONE
		end, L.SET_FOCUS_AUTO_TIP),
		-- Week 6: move the mode's sections up (default) or collapse the rest (the week-4 way). The same
		-- writer as /swagbag mode style, so both answer alike and refuse while read-only.
		{ kind = "choice", label = L.SET_FOCUS_STYLE, tip = L.SET_FOCUS_STYLE_TIP,
			choices = { { value = "front", text = L.SET_FOCUS_STYLE_FRONT },
			{ value = "collapse", text = L.SET_FOCUS_STYLE_COLLAPSE } },
			get = F.Style,
			apply = function(v)
				local ok, why = F.SetStyle(v)
				if not ok then
					return refusal(why)
				end
				return v == "front" and L.MODE_STYLE_FRONT or L.MODE_STYLE_COLLAPSE
			end },
		setting(L.SET_FOCUS_RESOLVE, "focus.resolve", { { value = "merge", text = L.SET_FOCUS_MERGE },
			{ value = "priority", text = L.SET_FOCUS_PRIORITY } }, function(v)
			return v == "merge" and L.SET_FOCUS_MERGE_DONE or L.SET_FOCUS_PRIORITY_DONE
		end, L.SET_FOCUS_RESOLVE_TIP),
		setting(L.SET_FOCUS_PEEK, "focus.peek", { { value = "peek", text = L.SET_FOCUS_PEEK_PEEK },
			{ value = "keep", text = L.SET_FOCUS_PEEK_KEEP } }, function(v)
			return v == "peek" and L.SET_FOCUS_PEEK_DONE or L.SET_FOCUS_KEEP_DONE
		end, L.SET_FOCUS_PEEK_TIP),
		setting(L.SET_FOCUS_ANNOUNCE, "focus.announce", { { value = false, text = L.SET_FOCUS_QUIET },
			{ value = true, text = L.SET_FOCUS_LOUD } }, function(v)
			return v and L.SET_FOCUS_LOUD_DONE or L.SET_FOCUS_QUIET_DONE
		end, L.SET_FOCUS_ANNOUNCE_TIP),
		{ kind = "choice", label = L.SET_FOCUS_SCOPE, tip = L.SET_FOCUS_SCOPE_TIP,
			choices = { { value = false, text = L.SET_FOCUS_ACCOUNT },
			{ value = true, text = L.SET_FOCUS_CHARACTER } },
			get = anyOverride,
			apply = function(v)
				if not SB.Config.CharOverrideMany(SF.Paths(), v) then
					return L.SETTINGS_READONLY
				end
				return v and L.SET_FOCUS_CHARACTER_DONE or L.SET_FOCUS_ACCOUNT_DONE
			end },
	}
	for _, m in ipairs(F.MODES) do
		out[#out + 1] = { kind = "choice", label = layered(L.SET_MODE_LABEL:format(L[m.name])),
			tip = L.SET_MODE_TIP:format(whenText(m.id)),
			choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
			get = function()
				return F.IsEnabled(m.id)
			end,
			apply = function(v)
				local ok, why = F.SetEnabled(m.id, v)
				if not ok then
					return refusal(why)
				end
				return (v and L.SET_MODE_ON or L.SET_MODE_OFF):format(L[m.name])
			end }
	end
	local pick = { kind = "choice", label = L.SET_EDIT_MODE, width = 76, tip = L.SET_EDIT_MODE_TIP, choices = {}, get = function()
		return SF.editing
	end, apply = function(v)
		SF.editing = v
		return L.SET_EDITING:format(modeName(v))
	end }
	for _, m in ipairs(F.MODES) do
		pick.choices[#pick.choices + 1] = { value = m.id, text = L[m.name] }
	end
	out[#out + 1] = pick
	sectionRows(out)
	return out
end

SB.SettingsWindow.AddPage({ id = "focus", title = L.SET_PAGE_FOCUS, rows = rows })

-- Open the page at one mode's sections (the Pause button's right-click, AC8.5).
function SF.Edit(modeId)
	if modeId and SB.Focus.byId[modeId] then
		SF.editing = modeId
	end
	SB.SettingsWindow.Show("focus")
	SB.SettingsWindow.Say(L.SET_EDITING:format(modeName(SF.editing)))
end
