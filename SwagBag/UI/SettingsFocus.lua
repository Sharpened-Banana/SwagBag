-- SwagBag settings: the Focus modes page (spec 6, AC8.1-8.5, AC15.1). Switching modes on and
-- off, move to the top or collapse the rest (week 6), merge or strict priority, peek or keep open
-- (the collapse style), announce, account-wide or this character
-- only, and each mode's section set with "Reset to default" next to it (spec 6.3). The bags
-- window's Pause button opens this page at the active mode with a right-click (AC8.5).
--   SettingsFocus.Edit(modeId)   open the page with that mode's sections shown
-- Week 12 (AC8.7): modes of the user's own. "New mode" opens a short form (a name, when it switches on, Make mode);
-- a mode of the user's is edited like a built-in (its sections, with no default to go back to) and also has its name,
-- its trigger and Delete (asks once more; any other click on the page forgets the question). A manual mode's row in
-- the mode list switches it on or off for this session (as /swagbag mode on / off).
-- The page starts with a plain-words note, and every row with buttons has a tooltip (row.tip, week 6).
-- Every write goes through Config.Set or the Focus writers; Config emits SB_CONFIG_CHANGED and
-- Focus refreshes on it, so an open bag re-stacks at once (guarded as in Task 3). The editor
-- reads and writes the raw section list (W4-2): only the effective view filters Gathering.
local _, SB = ...

local L = SB.L
local SF = { editing = "mplus", creating = nil, confirmDelete = nil, renameText = nil }
SB.SettingsFocus = SF

-- Every focus setting: "This character only" makes each one a character override (AC15.1).
function SF.Paths()
	local paths = { "focus.auto", "focus.style", "focus.resolve", "focus.peek", "focus.announce" }
	for _, m in ipairs(SB.Focus.All()) do -- week 12: the user's own modes too
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
	return SB.Focus.NameOf(id)
end

-- The Focus writers return false, "readonly" | "unknown"; the user's modes' writers also a name or trigger reason.
local function refusal(why)
	if why == "readonly" then
		return L.SETTINGS_READONLY
	elseif why and rawget(L, "SET_CUSTOM_WHY_" .. why:upper()) then
		return L["SET_CUSTOM_WHY_" .. why:upper()]
	end
	return L.SET_FOCUS_UNKNOWN
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
	if F.IsCustom(id) then
		return -- a mode of the user's has no default set; its own rows follow (customRows)
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

-- A trigger's words ("At a vendor").
local function triggerName(id)
	for _, t in ipairs(SB.Focus.TRIGGERS) do
		if t.id == id then
			return L[t.name]
		end
	end
	return tostring(id)
end

-- The triggers as choices (manual first), for the new-mode form and a mode of the user's.
local function triggerChoices()
	local out = {}
	for _, t in ipairs(SB.Focus.TRIGGERS) do
		out[#out + 1] = { value = t.id, text = L[t.name] }
	end
	return out
end

-- Week 12: "New mode" and its short form. Nothing is made before Make mode; Cancel forgets it.
local function newModeRows(out)
	local F = SB.Focus
	out[#out + 1] = { kind = "actions", label = L.SET_CUSTOM_LABEL, tip = L.SET_CUSTOM_TIP, actions = {
		{ text = L.SET_CUSTOM_NEW, selected = SF.creating ~= nil, run = function()
			SF.creating = { name = "", trigger = "manual" }
			return L.SET_CUSTOM_NEW_HINT
		end } } }
	local d = SF.creating
	if not d then
		return
	end
	out[#out + 1] = { kind = "input", label = L.SET_CUSTOM_NAME, maxLetters = 2 * F.MAX_NAME,
		get = function()
			return d.name
		end,
		set = function(text)
			d.name = text
		end,
		commit = function(text)
			d.name = text
			local clean, why = F.CheckName(text)
			return clean and L.SET_CUSTOM_NAME_OK:format(clean) or refusal(why)
		end }
	out[#out + 1] = { kind = "choice", label = L.SET_CUSTOM_TRIGGER, tip = L.SET_CUSTOM_TRIGGER_TIP, width = 90,
		choices = triggerChoices(),
		get = function()
			return d.trigger
		end,
		apply = function(v)
			d.trigger = v
			return L.SET_CUSTOM_TRIGGER_PICKED:format(triggerName(v))
		end }
	out[#out + 1] = { kind = "actions", label = L.SET_CUSTOM_MAKE_LABEL, tip = L.SET_CUSTOM_MAKE_TIP, actions = {
		{ text = L.SET_CUSTOM_MAKE, run = function()
			local id, why = F.CreateMode(d.name, d.trigger)
			if not id then
				return refusal(why)
			end
			if anyOverride() then -- "This character only" is on: the new mode's settings are this character's too
				SB.Config.CharOverrideMany({ "focus.on." .. id, "focus.sections." .. id }, true)
			end
			SF.creating, SF.editing, SF.renameText = nil, id, nil
			local name = modeName(id)
			if d.trigger == "manual" then
				return L.SET_CUSTOM_MADE_MANUAL:format(name, name)
			end
			return L.SET_CUSTOM_MADE:format(name)
		end },
		{ text = L.SET_CUSTOM_CANCEL, run = function()
			SF.creating = nil
			return L.SET_CUSTOM_CANCELLED
		end } } }
end

-- Week 12: the rows of the user's mode being edited, after its sections: its name, when it switches on, Delete.
local function customRows(out)
	local F, id = SB.Focus, SF.editing
	if not F.IsCustom(id) then
		return
	end
	out[#out + 1] = { kind = "input", label = L.SET_CUSTOM_RENAME, maxLetters = 2 * F.MAX_NAME,
		get = function()
			return SF.renameText or modeName(id)
		end,
		set = function(text)
			SF.renameText = text
		end,
		commit = function(text)
			local old = modeName(id)
			local ok, why = F.RenameMode(id, text)
			if not ok then
				SF.renameText = text -- what was typed stays in the box, to be fixed
				return refusal(why)
			end
			SF.renameText = nil
			return L.SET_CUSTOM_RENAMED:format(old, modeName(id))
		end }
	out[#out + 1] = { kind = "choice", label = L.SET_CUSTOM_TRIGGER, tip = L.SET_CUSTOM_TRIGGER_TIP, width = 90,
		choices = triggerChoices(),
		get = function()
			return F.Mode(id).triggerId
		end,
		apply = function(v)
			local ok, why = F.SetTrigger(id, v)
			if not ok then
				return refusal(why)
			end
			return L.SET_CUSTOM_TRIGGER_SET:format(modeName(id), triggerName(v))
		end }
	local sure = SF.confirmDelete == id
	out[#out + 1] = { kind = "actions", label = L.SET_CUSTOM_DELETE_LABEL, tip = L.SET_CUSTOM_DELETE_TIP, actions = {
		{ text = sure and L.SET_CUSTOM_DELETE_SURE or L.SET_CUSTOM_DELETE, selected = sure, keepsQuestion = true,
		run = function()
			local name = modeName(id)
			if SF.confirmDelete ~= id then
				SF.confirmDelete = id
				return L.SET_CUSTOM_DELETE_ASK:format(L.SET_CUSTOM_DELETE_SURE, name)
			end
			SF.confirmDelete = nil
			local ok, why = F.DeleteMode(id)
			if not ok then
				return refusal(why)
			end
			SF.editing = "mplus"
			return L.SET_CUSTOM_DELETED:format(name)
		end } } }
end

-- Every click on the page but Delete's own forgets Delete's question (week 7's Unlock-all pattern).
local function forgetting(list)
	local function wrap(f)
		return function(...)
			SF.confirmDelete = nil
			return f(...)
		end
	end
	for _, row in ipairs(list) do
		if row.apply then
			row.apply = wrap(row.apply)
		end
		if row.commit then
			row.commit = wrap(row.commit)
		end
		for _, a in ipairs(row.actions or {}) do
			if not a.keepsQuestion then
				a.run = wrap(a.run)
			end
		end
	end
	return list
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
	for _, m in ipairs(F.All()) do
		local name = modeName(m.id)
		if m.triggerId == "manual" then
			-- Week 12: a manual mode of the user's is switched on and off here, for this session.
			-- Session state, not a layered setting: no "(this character)" label.
			out[#out + 1] = { kind = "choice", label = L.SET_MODE_LABEL:format(L.MODE_LIST_MANUAL:format(name)),
				tip = L.SET_MANUAL_TIP:format(name),
				choices = { { value = true, text = L.SET_MANUAL_ON }, { value = false, text = L.SET_OFF } },
				get = function()
					return F.ManualOn(m.id)
				end,
				apply = function(v)
					local ok, why = F.SetManual(m.id, v)
					if not ok then
						return refusal(why)
					end
					return v and L.MODE_MANUAL_ON:format(name) or L.MODE_MANUAL_OFF:format(name)
				end }
		else
			out[#out + 1] = { kind = "choice", label = layered(L.SET_MODE_LABEL:format(name)),
				tip = m.custom and L.SET_CUSTOM_MODE_TIP:format(triggerName(m.triggerId))
					or L.SET_MODE_TIP:format(whenText(m.id)),
				choices = { { value = true, text = L.SET_ON }, { value = false, text = L.SET_OFF } },
				get = function()
					return F.IsEnabled(m.id)
				end,
				apply = function(v)
					local ok, why = F.SetEnabled(m.id, v)
					if not ok then
						return refusal(why)
					end
					return (v and L.SET_MODE_ON or L.SET_MODE_OFF):format(name)
				end }
		end
	end
	newModeRows(out)
	if not F.Mode(SF.editing) then
		SF.editing = "mplus" -- the mode being edited was deleted (here, or by a profile or a reset)
	end
	local pick = { kind = "choice", label = L.SET_EDIT_MODE, width = 76, tip = L.SET_EDIT_MODE_TIP, choices = {}, get = function()
		return SF.editing
	end, apply = function(v)
		SF.editing = v
		SF.renameText = nil
		return L.SET_EDITING:format(modeName(v))
	end }
	for _, m in ipairs(F.All()) do
		pick.choices[#pick.choices + 1] = { value = m.id, text = modeName(m.id) }
	end
	out[#out + 1] = pick
	sectionRows(out)
	customRows(out)
	return forgetting(out)
end

SB.SettingsWindow.AddPage({ id = "focus", title = L.SET_PAGE_FOCUS, rows = rows, onLeave = function()
	SF.confirmDelete, SF.creating, SF.renameText = nil, nil, nil
end })

-- Open the page at one mode's sections (the Pause button's right-click, AC8.5).
function SF.Edit(modeId)
	if modeId and SB.Focus.Mode(modeId) then
		SF.editing, SF.renameText = modeId, nil
	end
	SB.SettingsWindow.Show("focus")
	SB.SettingsWindow.Say(L.SET_EDITING:format(modeName(SF.editing)))
end
