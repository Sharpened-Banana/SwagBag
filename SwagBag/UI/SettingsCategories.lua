-- SwagBag settings: the Categories page (week 11, spec F6: the visual rule builder, AC6.1, AC6.2). Every category in
-- display order with its priority, Edit, Up and Down, and New category. The editor works on a draft that only Save
-- writes:
--   a name; On / Off; the rule as rows of [keyword] [operator] [value] in groups (All of these / Any of these, Not on
--   a row and on a group; Engine/Query/Rows.lua); the rule as text (Advanced: shown on request, always for a rule too
--   nested for rows; it takes the whole query language, so a rule the rows can't show is never out of reach); a live
--   count of the bags' items it matches with every warning Validate gives, "Show matches" (the bags' own search
--   dimming, which never moves an item: AC5.2; closing the settings window clears that search again, if the bags
--   still search for it); the priority in steps (1 to 89; Junk, Equipment sets, Keystone & Crests and Reagents keep
--   theirs).
-- Save runs Categories.Save / Create (spec 7.9: Validate too): a rule that does not compile is never dropped (AC6.2):
-- a category with a rule that works keeps that rule in use and the broken text waits as its draft (spec 7.5 #3),
-- which the editor opens and the list marks; one with no rule that works is saved switched off with its error said.
-- Save refuses while a row the user changed is not finished (an empty name, a number that isn't one), naming that
-- row. A rule whose rows were never touched is saved exactly as it was typed (its own spelling); rows that were
-- changed are written in Query.Pretty's spelling (the same rule: Rows' lossless round trip). A click on the rows (a
-- change, Add a rule, Change, a value box's Enter) after text was typed but not read reads the text first and does
-- nothing else, so typed text is never lost. Nothing in the open bags moves: the new rules sort the items the next
-- time the bags open, or at Reflow (P5). Delete and Reset to default ask once more (the same button again); every
-- other click forgets the question; after a Reset the page is back at the list. Every click answers once in the
-- status line (P2). Plain frames only (the settings window's own); no secure frame, no item button.
--   SC.Edit(id) / SC.New() / SC.Save() / SC.Cancel() -> feedback     SC.draft, SC.picking (the keyword lists shown),
--   SC.confirmDelete / SC.confirmReset (the id asked about), SC.shown (the text Show matches put in the bags' search)
-- Paste a Baganator search (week 11 Task 4, AC6.3): a box for the string, read by Engine/Query/Paste.lua (nothing in
-- it ever runs); what SwagBag reads it as, every difference in words, what it matches in the bags now (and Show
-- matches); Make category saves it as a new category of the user's (source "import") under a name they may change.
-- A string Paste refuses makes nothing, and says why and where.
--   SC.Paste() -> feedback       SC.paste = { text, result, why, detail, name } while the paste view is open
local _, SB = ...

local L = SB.L
local Guard = SB.ErrorTrap.Guard
local C, Rows, Paste = SB.Categories, SB.QueryRows, SB.QueryPaste
local SC = { draft = nil, picking = nil, confirmDelete = nil, confirmReset = nil, shown = nil, paste = nil,
	STEPS = { -10, -1, 1, 10 }, MAX_NOTES = 6 }
SB.SettingsCategories = SC

local function run(line)
	return SB.SettingsWindow.RunCommand(line)
end

local NAME_WHY = { EMPTY = "CAT_NAME_EMPTY", LONG = "CAT_NAME_LONG", CHARS = "CAT_NAME_CHARS", TAKEN = "CAT_NAME_TAKEN" }

local function refusal(why, name)
	if why == "readonly" then
		return L.SETTINGS_READONLY
	elseif why == "long" then
		return L.CAT_TOO_LONG:format(C.MAX_QUERY)
	elseif why == "code" then
		return L.CAT_CODE
	elseif why == "LONG" then
		return L.CAT_NAME_LONG:format(C.MAX_NAME)
	elseif NAME_WHY[why] then
		return L[NAME_WHY[why]]:format(tostring(name or ""))
	end
	return L.CAT_UNKNOWN
end

-- Every button but Delete and Reset forgets a pending "sure?" (the question is about the very next click).
local function forget(fn)
	return function(...)
		SC.confirmDelete, SC.confirmReset = nil, nil
		return fn(...)
	end
end

local function edited(id)
	local edits = SB.Config.db and SB.Config.db.userEdits
	return type(edits) == "table" and edits[id] ~= nil
end

-- The text after a change of the rows: Pretty's spelling. A rule nobody touched keeps the user's own.
local function rulesChanged(d)
	d.text = Rows.ToText(d.rules)
	d.textTyped, d.rowsEdited = false, true
end

local function readText(d)
	local rules, why, err = Rows.FromText(d.text)
	d.rules, d.why, d.err, d.textTyped, d.rowsEdited = rules, why, err, false, false
	if rules and #rules.blocks == 0 then
		rules.blocks[1] = { join = "and", negate = false, rows = {} } -- a group to add the first rule to
	end
end

local function ruleNow(d)
	return d.text:find("%S") and L.CAT_RULE_NOW:format(d.text) or L.CAT_RULE_NONE
end

-- A click on the rows (a change, Add a rule, Change, a value box's Enter): text typed but not read yet is read first
-- instead and the click does nothing else (the rows on screen are then redrawn from it), so typed text is never lost
-- and a click never lands on a row that changed under it.
local function rowsClick(fn)
	return forget(function(...)
		local d = SC.draft
		if d.textTyped then
			readText(d)
			return L.CAT_TEXT_FIRST
		end
		return fn(d, ...)
	end)
end

local function change(fn)
	return rowsClick(function(d)
		fn(d)
		rulesChanged(d)
		return ruleNow(d)
	end)
end

function SC.Edit(id)
	local c = C.Get(id)
	if not c then
		return L.CAT_UNKNOWN
	end
	-- A draft (a change saved with an error) opens in place of the rule in use, which "Back to the working rule" brings.
	SC.draft = { id = id, builtin = c.builtin, pinned = C.PINNED[id], fallback = c.fallback, setting = c.setting,
		name = c.name, text = c.draft or (type(c.query) == "string" and c.query or ""), enabled = c.enabled or c.error ~= nil,
		priority = c.priority, working = c.draft and c.query, draftError = c.draftError }
	SC.picking, SC.confirmDelete, SC.confirmReset, SC.paste = nil, nil, nil, nil
	readText(SC.draft)
	return L.CAT_EDITING:format(c.name)
end

function SC.New()
	SC.draft = { name = "", text = "", enabled = true, priority = C.USER_PRIORITY }
	SC.picking, SC.confirmDelete, SC.confirmReset, SC.paste = nil, nil, nil, nil
	readText(SC.draft)
	return L.CAT_NEW_HINT
end

function SC.Cancel()
	SC.draft, SC.picking, SC.confirmDelete, SC.confirmReset = nil, nil, nil, nil
	return L.CAT_CANCELLED
end

-- A warning in words (Query.Validate's): a word that is no keyword (with the keyword one letter away), or an unknown
-- #keyword.
local function warningText(w)
	if w.kind == "text" then
		local near = Rows.Nearest(w.value)
		return L.CAT_WARN_WORD:format(w.value) .. (near and L.CAT_DID_YOU_MEAN:format(near) or "")
	end
	return SB.Query.FormatWarning(w)
end

-- The first row the user changed that can't be saved yet: its number and why, or nil.
local function unfinished(d)
	local n = 0
	for _, b in ipairs(d.rules.blocks) do
		for _, r in ipairs(b.rows) do
			n = n + 1
			local why = Rows.Problem(r)
			if why then
				return n, why
			end
		end
	end
end

function SC.Save()
	local d = SC.draft
	if d.textTyped then
		readText(d) -- the text as typed is what is saved
	end
	if d.rowsEdited and d.rules then
		local n, problem = unfinished(d)
		if n then
			return L.CAT_SAVE_ROW:format(n, L["CAT_PROBLEM_" .. problem]) -- an empty name row would take every item
		end
	end
	local fields = { name = d.name, query = d.text }
	if not (d.fallback or d.setting) then
		fields.enabled = d.enabled
	end
	if not (d.pinned or d.fallback) then
		fields.priority = d.priority
	end
	local id, ok, why, detail = d.id
	if id then
		ok, why, detail = C.Save(id, fields)
	else
		id, why, detail = C.Create(d.name, d.text)
		ok = id ~= nil
		if ok then
			d.id = id -- made: a refused follow-up save leaves the draft on it, so the next Save saves it, never makes it twice
			local ok2, why2, detail2 = C.Save(id, { enabled = fields.enabled, priority = fields.priority })
			if not ok2 then
				return refusal(why2, d.name)
			end
			if why2 then
				why, detail = why2, detail2
			end
		end
	end
	if not ok then
		return refusal(why, d.name)
	end
	local name = C.Get(id).name
	SC.draft, SC.picking, SC.confirmDelete, SC.confirmReset = nil, nil, nil, nil
	if why == "broken" then
		return L.CAT_SAVED_BROKEN:format(name, detail)
	elseif why == "draft" then
		return L.CAT_SAVED_DRAFT:format(name, detail)
	elseif why == "warned" then
		local said = {}
		for i, w in ipairs(detail) do
			said[i] = warningText(w)
		end
		return L.CAT_SAVED_WARNED:format(name, table.concat(said, " "))
	end
	return L.CAT_SAVED:format(name)
end

local function delete()
	local d = SC.draft
	SC.confirmReset = nil
	if SC.confirmDelete ~= d.id then
		SC.confirmDelete = d.id
		return L.CAT_DELETE_ASK:format(d.name)
	end
	SC.confirmDelete = nil
	local name = C.Get(d.id) and C.Get(d.id).name or d.name
	local ok, why = C.Delete(d.id)
	if not ok then
		return refusal(why)
	end
	SC.draft, SC.picking = nil, nil
	return L.CAT_DELETED:format(name)
end

-- Reset to default asks once more, like Delete: it forgets every change, the items dragged onto or off the category
-- too. Done, the page is back at the list (an editor left open would hold the changes the reset just forgot).
local function reset()
	local d = SC.draft
	SC.confirmDelete = nil
	if SC.confirmReset ~= d.id then
		SC.confirmReset = d.id
		return L.CAT_RESET_ASK:format(C.Name(d.id))
	end
	SC.confirmReset = nil
	local ok, why = C.ResetBuiltin(d.id)
	if not ok then
		return refusal(why)
	end
	SC.draft, SC.picking = nil, nil
	return L.CAT_RESET_DONE:format(C.Name(d.id))
end

local function move(id, step)
	local ok, why = C.Move(id, step)
	local name = C.Name(id)
	if ok then
		return (step < 0 and L.CAT_MOVED_UP or L.CAT_MOVED_DOWN):format(name)
	elseif why == "edge" then
		return (step < 0 and L.CAT_EDGE_FIRST or L.CAT_EDGE_LAST):format(name)
	end
	return refusal(why)
end

-- A bare word that is a keyword (not one that only takes a number: a bare "ilvl" matches item names).
local function isKeyword(r)
	local kind = r.kind == "word" and Rows.KindOf(r.value)
	return kind == "flag" or kind == "both"
end

-- One row in words, for its label: "ilvl >= 600", "boe", "not epic", "item name contains "fish"".
local function summary(r)
	local s
	if r.kind == "num" then
		s = r.name .. " " .. r.op .. " " .. (r.raw ~= "" and r.raw or "?")
	elseif r.kind == "exact" then
		s = "#" .. r.value
	elseif isKeyword(r) then
		s = r.value
	else
		s = L.CAT_SUM_NAME:format(r.value)
	end
	return r.negate and L.CAT_SUM_NOT:format(s) or s
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------
-- A category's line: its name, what state it is in, and its priority (Other has none: it takes what no rule takes).
local function state(c)
	local s = c.name
	if c.error then
		s = L.CAT_STATE_BROKEN:format(c.name)
	elseif c.draft then
		s = L.CAT_STATE_DRAFT:format(c.name)
	elseif not c.enabled then
		s = L.CAT_STATE_OFF:format(c.name)
	elseif not c.builtin then
		s = L.CAT_STATE_YOURS:format(c.name)
	elseif edited(c.id) then
		s = L.CAT_STATE_CHANGED:format(c.name)
	end
	if c.fallback then
		return s
	end
	return L.CAT_LIST_PRIORITY:format(s, c.priority)
end

local function listRows()
	C.Ensure()
	local out = {
		{ kind = "note", label = L.CAT_INTRO },
		{ kind = "actions", label = L.CAT_MAKE, actions = { { text = L.CAT_NEW_BUTTON, run = forget(SC.New) },
			{ text = L.PASTE_BUTTON, tip = L.PASTE_TIP, run = forget(function()
				return SC.Paste()
			end) } } },
	}
	for _, c in ipairs(C.display) do
		local id = c.id
		out[#out + 1] = { kind = "actions", label = state(c), width = 56, actions = {
			{ text = L.CAT_EDIT, run = forget(function()
				return SC.Edit(id)
			end) },
			{ text = L.CAT_UP, run = forget(function()
				return move(id, -1)
			end) },
			{ text = L.CAT_DOWN, run = forget(function()
				return move(id, 1)
			end) },
		} }
	end
	return out
end

---------------------------------------------------------------------------
-- The editor
---------------------------------------------------------------------------
local function pick(word, asNumber)
	return forget(function()
		local d, p = SC.draft, SC.picking
		local block = d.rules.blocks[p.block]
		local row = Rows.NewRow(word, asNumber)
		if p.row and block.rows[p.row] then
			row.negate = block.rows[p.row].negate
			block.rows[p.row] = row
		else
			block.rows[#block.rows + 1] = row
		end
		SC.picking = nil
		rulesChanged(d)
		if word == nil or asNumber then
			return L.CAT_TYPE_VALUE
		end
		return ruleNow(d)
	end)
end

local function pickerRows(out)
	out[#out + 1] = { kind = "actions", label = L.CAT_PICK, actions = { { text = L.CAT_CANCEL, run = forget(function()
		SC.picking = nil
		return L.CAT_PICK_CANCELLED
	end) } } }
	out[#out + 1] = { kind = "actions", label = L.CAT_PICK_NAME_LABEL, actions = { { text = L.CAT_PICK_NAME,
		run = pick(nil) } } }
	for _, fam in ipairs(Rows.FAMILIES) do
		local actions = {}
		for i, word in ipairs(fam.words) do
			actions[i] = { text = word, run = pick(word, fam.numbers) }
		end
		out[#out + 1] = { kind = "actions", label = L[fam.label], width = 60, actions = actions }
	end
end

local function valueRow(out, r)
	local isNum = r.kind == "num"
	local function put(text)
		if isNum then
			r.raw = text
		else
			r.kind, r.value = "text", text -- a name the user typed is always quoted: no word turns into a keyword
		end
		rulesChanged(SC.draft)
	end
	out[#out + 1] = { kind = "input", label = isNum and L.CAT_VALUE_NUMBER:format(r.name) or L.CAT_VALUE_NAME,
		boxWidth = 200, maxLetters = C.MAX_QUERY + 20, -- over the limit: a longer paste is refused, not cut

		get = function()
			return isNum and r.raw or r.value
		end,
		set = function(text)
			if not SC.draft.textTyped then -- text typed in the rule's box waits to be read: a value never overwrites it
				put(text)
			end
		end,
		commit = rowsClick(function(_, text)
			put(text)
			local why = Rows.Problem(r)
			return why and L["CAT_PROBLEM_" .. why] or ruleNow(SC.draft)
		end) }
end

local function ruleRows(out, d)
	local rules = d.rules
	if #rules.blocks > 1 then
		out[#out + 1] = { kind = "actions", label = L.CAT_GROUPS_JOIN, actions = {
			{ text = L.CAT_ALL_GROUPS, selected = rules.join == "and", run = change(function()
				rules.join = "and"
			end) },
			{ text = L.CAT_ANY_GROUP, selected = rules.join == "or", run = change(function()
				rules.join = "or"
			end) },
		} }
	end
	local n = 0
	for i, b in ipairs(rules.blocks) do
		local acts = {
			{ text = L.CAT_ALL_OF, selected = b.join == "and", run = change(function()
				b.join = "and"
			end) },
			{ text = L.CAT_ANY_OF, selected = b.join == "or", run = change(function()
				b.join = "or"
			end) },
			{ text = L.CAT_NOT, selected = b.negate, run = change(function()
				b.negate = not b.negate
			end) },
			{ text = L.CAT_ADD_RULE, run = rowsClick(function()
				SC.picking = { block = i }
				return L.CAT_PICK_HINT
			end) },
		}
		if #rules.blocks > 1 then
			acts[#acts + 1] = { text = L.CAT_REMOVE_GROUP, run = change(function()
				table.remove(rules.blocks, i)
			end) }
		end
		out[#out + 1] = { kind = "actions", label = #rules.blocks > 1 and L.CAT_GROUP:format(i) or L.CAT_RULES,
			actions = acts }
		for j, r in ipairs(b.rows) do
			n = n + 1
			local ra = { { text = L.CAT_CHANGE, run = rowsClick(function()
				SC.picking = { block = i, row = j }
				return L.CAT_PICK_HINT
			end) } }
			if r.kind == "num" then
				for _, op in ipairs(Rows.NUMBER_OPS) do
					ra[#ra + 1] = { text = op, selected = r.op == op, run = change(function()
						r.op = op
					end) }
				end
			end
			ra[#ra + 1] = { text = L.CAT_NOT, selected = r.negate, run = change(function()
				r.negate = not r.negate
			end) }
			ra[#ra + 1] = { text = L.CAT_REMOVE, run = change(function()
				table.remove(b.rows, j)
				if #b.rows == 0 and #rules.blocks > 1 then
					table.remove(rules.blocks, i)
				end
			end) }
			out[#out + 1] = { kind = "actions", label = L.CAT_RULE:format(n, summary(r)), width = 44, actions = ra }
			if r.kind ~= "exact" and not isKeyword(r) then
				valueRow(out, r)
			end
			local why = Rows.Problem(r)
			if why then
				out[#out + 1] = { kind = "note", label = L["CAT_PROBLEM_" .. why] }
			end
		end
	end
	out[#out + 1] = { kind = "actions", label = L.CAT_MORE, actions = { { text = L.CAT_ADD_GROUP, run = change(function()
		rules.blocks[#rules.blocks + 1] = { join = "and", negate = false, rows = {} }
	end) } } }
end

-- noHint: the paste view names its differences itself (Paste's notes), so no warnings and no "did you mean" there.
local function previewRows(out, text, noHint)
	local n, total = C.Preview(text)
	out[#out + 1] = { kind = "note", label = n and L.CAT_PREVIEW:format(n, total) or L.CAT_PREVIEW_ERROR:format(total) }
	if n and not noHint then
		for _, w in ipairs(SB.Query.Validate(SB.Query.Compile(text)).warnings) do
			out[#out + 1] = { kind = "note", label = warningText(w) } -- every warning, not only the first (spec 7.9)
		end
	end
	out[#out + 1] = { kind = "actions", label = L.CAT_SEE, tip = L.CAT_SEE_TIP, actions = {
		{ text = L.CAT_SHOW_MATCHES, run = forget(function()
			SC.shown = text:match("^%s*(.-)%s*$") -- the command trims it; the close compares with what it stored
			return run("search " .. text)
		end) },
		{ text = L.CAT_CLEAR_MATCHES, run = forget(function()
			SC.shown = nil
			return run("search")
		end) },
	} }
end

local function editorRows()
	local d = SC.draft
	local out = { { kind = "note", label = d.id and L.CAT_EDITING:format(d.name) or L.CAT_EDITING_NEW } }
	if d.builtin then
		out[#out + 1] = { kind = "note", label = L.CAT_BUILTIN_NOTE }
	end
	if d.working then
		out[#out + 1] = { kind = "note", label = L.CAT_DRAFT_NOTE:format(d.draftError or "") }
	end
	local acts = { { text = L.CAT_SAVE, run = forget(SC.Save) }, { text = L.CAT_CANCEL, run = forget(SC.Cancel) } }
	if d.id and not d.builtin then
		acts[#acts + 1] = { text = SC.confirmDelete == d.id and L.CAT_DELETE_SURE or L.CAT_DELETE, run = delete }
	end
	if d.builtin and edited(d.id) then
		acts[#acts + 1] = { text = SC.confirmReset == d.id and L.CAT_RESET_SURE or L.SET_RESET_DEFAULT, run = reset }
	end
	if d.working then
		acts[#acts + 1] = { text = L.CAT_DRAFT_DROP, run = forget(function()
			d.text, d.working = d.working, nil
			readText(d)
			return L.CAT_DRAFT_DROPPED
		end) }
	end
	out[#out + 1] = { kind = "actions", label = L.CAT_ACTIONS, actions = acts }
	if SC.picking then
		pickerRows(out)
		return out
	end
	out[#out + 1] = { kind = "input", label = L.CAT_NAME, maxLetters = C.MAX_NAME + 20, boxWidth = 200,
		get = function()
			return d.name
		end,
		set = function(text)
			d.name = text
		end,
		commit = forget(function(text)
			d.name = text
			local clean, why = C.CheckName(text, d.id)
			if not clean then
				return refusal(why, text)
			end
			return L.CAT_NAME_OK:format(clean)
		end) }
	if d.fallback then
		out[#out + 1] = { kind = "note", label = L.CAT_OTHER_NOTE }
		return out
	end
	if d.setting then
		out[#out + 1] = { kind = "note", label = L.CAT_SETTING_NOTE }
	else
		out[#out + 1] = { kind = "choice", label = L.CAT_ON, choices = { { value = true, text = L.SET_ON },
			{ value = false, text = L.SET_OFF } },
			get = function()
				return d.enabled
			end,
			apply = forget(function(v)
				d.enabled = v
				return v and L.CAT_ON_DONE or L.CAT_OFF_DONE
			end) }
	end
	if d.rules then
		ruleRows(out, d)
	else
		out[#out + 1] = { kind = "note", label = L.CAT_TEXT_ONLY:format(L["CAT_WHY_" .. d.why:upper()]) }
	end
	if d.rules then
		out[#out + 1] = { kind = "actions", label = L.CAT_ADVANCED, tip = L.CAT_ADVANCED_TIP, actions = {
			{ text = d.showText and L.CAT_HIDE_TEXT or L.CAT_SHOW_TEXT, run = forget(function()
				d.showText = not d.showText
				return d.showText and L.CAT_TEXT_SHOWN or L.CAT_TEXT_HIDDEN
			end) } } }
	end
	if d.showText or not d.rules then
		-- Twice the limit, so a longer pasted rule is refused with its length instead of cut into another rule.
		out[#out + 1] = { kind = "input", label = L.CAT_TEXT, maxLetters = 2 * C.MAX_QUERY,
			get = function()
				return d.text
			end,
			set = function(text)
				d.text, d.textTyped = text, true
			end,
			commit = forget(function(text)
				d.text = text
				readText(d)
				if d.rules then
					return L.CAT_TEXT_READ:format(ruleNow(d))
				elseif d.why == "error" then
					local c = d.id and C.Get(d.id)
					local said = c and not c.error and L.CAT_TEXT_ERROR_KEEP or L.CAT_TEXT_ERROR
					return said:format(SB.Query.FormatError(d.err))
				elseif d.why == "toolong" then
					return L.CAT_TEXT_TOOLONG:format(#d.text, C.MAX_QUERY)
				end
				return L.CAT_TEXT_ONLY:format(L["CAT_WHY_" .. d.why:upper()])
			end) }
	end
	previewRows(out, d.text)
	if d.pinned then
		out[#out + 1] = { kind = "note", label = L.CAT_PINNED_NOTE }
	else
		local steps = {}
		for i, step in ipairs(SC.STEPS) do
			steps[i] = { text = (step > 0 and "+" or "") .. step, run = forget(function()
				d.priority = math.max(C.MIN_PRIORITY, math.min(C.MAX_PRIORITY, d.priority + step))
				return L.CAT_PRIORITY_NOW:format(d.priority)
			end) }
		end
		out[#out + 1] = { kind = "actions", label = L.CAT_PRIORITY:format(d.priority), tip = L.CAT_PRIORITY_TIP,
			width = 44, actions = steps }
	end
	return out
end

---------------------------------------------------------------------------
-- Paste a Baganator search (AC6.3)
---------------------------------------------------------------------------
-- "From Baganator", else "From Baganator 2", 3...: a name no category has yet.
local function freeName()
	for n = 1, 99 do
		local name = n == 1 and L.PASTE_NAME or (L.PASTE_NAME .. " " .. n)
		if C.CheckName(name) then
			return name
		end
	end
	return ""
end

function SC.Paste()
	SC.draft, SC.picking, SC.confirmDelete, SC.confirmReset = nil, nil, nil, nil
	SC.paste = { text = "", name = "" }
	return L.PASTE_HINT
end

local function readPaste(p)
	local result, why, detail = Paste.Translate(p.text)
	p.result, p.why, p.detail = result, why, detail
	if not result then
		return L["PASTE_ERR_" .. why]:format(tostring(detail or ""))
	end
	if p.name == "" then
		p.name = freeName()
	end
	return L.PASTE_READ:format(result.query)
end

local function noteText(n)
	if n.kind == "NAME" then
		local starting = Paste.Prefixed(n.value)
		return L.PASTE_NOTE_NAME:format(n.value)
			.. (#starting > 0 and L.PASTE_NOTE_PREFIX:format(table.concat(starting, ", ")) or "")
	elseif n.kind == "ALSO" then
		return L.PASTE_NOTE_ALSO:format(n.value, table.concat(Paste.Prefixed(n.value), ", "))
	end
	return L["PASTE_NOTE_" .. n.kind]:format(tostring(n.value or ""))
end

local function make()
	local p = SC.paste
	if not p.result then
		return L.PASTE_READ_FIRST
	end
	local id, why = C.Create(p.name, p.result.query, "import")
	if not id then
		return refusal(why, p.name)
	end
	SC.paste = nil
	return L.PASTE_MADE:format(C.Get(id).name)
end

local function pasteRows()
	local p = SC.paste
	local out = {
		{ kind = "note", label = L.PASTE_INTRO },
		{ kind = "actions", label = L.PASTE_TITLE, actions = { { text = L.CAT_CANCEL, run = forget(function()
			SC.paste = nil
			return L.PASTE_CANCELLED
		end) } } },
		{ kind = "input", label = L.PASTE_BOX, maxLetters = 2 * Paste.MAX,
			get = function()
				return p.text
			end,
			set = function(text)
				p.text, p.result, p.why = text, nil, nil -- a changed string is read again before anything is made
			end,
			commit = forget(function(text)
				p.text = text
				return readPaste(p)
			end) },
	}
	if p.why then
		out[#out + 1] = { kind = "note", label = L["PASTE_ERR_" .. p.why]:format(tostring(p.detail or "")) }
	end
	if not p.result then
		return out
	end
	out[#out + 1] = { kind = "note", label = L.PASTE_READS_AS:format(p.result.query) }
	for i, n in ipairs(p.result.notes) do
		if i > SC.MAX_NOTES then
			out[#out + 1] = { kind = "note", label = L.PASTE_MORE:format(#p.result.notes - SC.MAX_NOTES) }
			break
		end
		out[#out + 1] = { kind = "note", label = noteText(n) }
	end
	previewRows(out, p.result.query, true)
	out[#out + 1] = { kind = "input", label = L.CAT_NAME, maxLetters = C.MAX_NAME + 20, boxWidth = 200,
		get = function()
			return p.name
		end,
		set = function(text)
			p.name = text
		end,
		commit = forget(function(text)
			p.name = text
			local clean, why = C.CheckName(text)
			if not clean then
				return refusal(why, text)
			end
			return L.PASTE_NAME_OK:format(clean)
		end) }
	out[#out + 1] = { kind = "actions", label = L.PASTE_SAVE_LABEL, actions = { { text = L.PASTE_MAKE, run = forget(make) } } }
	return out
end

SB.SettingsWindow.AddPage({ id = "categories", title = L.SET_PAGE_CATEGORIES, rows = function()
	if SC.paste then
		return pasteRows()
	elseif SC.draft then
		return editorRows()
	end
	return listRows()
end })

-- Closing the settings window takes Show matches' search out of the bags again, so they are not left dimmed: only
-- when the bags still search for exactly that (a search the user typed since is theirs). No click, so no answer.
SB.SettingsWindow.frame:HookScript("OnHide", Guard("settings.categoriesHide", function()
	local shown = SC.shown
	SC.shown = nil
	if shown and SB.Search and SB.Search.IsActive() and SB.Search.text == shown then
		run("search")
	end
end, "none"))
